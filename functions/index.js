const functions = require("firebase-functions");
const admin = require("firebase-admin");
const ngeohash = require("ngeohash");

admin.initializeApp();
const db = admin.firestore();

const HOTSPOT_GRID_PRECISION = 7;
const MIN_POINTS_FOR_HOTSPOT = 5;
const RAW_DATA_TTL_DAYS = 30;

exports.submitTripData = functions
    .region("us-central1")
    .https.onRequest(async (req, res) => {
      res.set("Access-Control-Allow-Origin", "*");
      res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
      res.set("Access-Control-Allow-Headers", "Content-Type");

      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }

      if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
      }

      const {latitude, longitude, timestamp} = req.body;

      if (typeof latitude !== "number" || typeof longitude !== "number" ||
          typeof timestamp !== "string") {
        res.status(400).send("Invalid data format.");
        return;
      }

      try {
        await db.collection("raw_pickup_data").add({
          latitude: latitude,
          longitude: longitude,
          timestamp: admin.firestore.Timestamp.fromDate(new Date(timestamp)),
        });
        res.status(201).send("Data submitted successfully.");
      } catch (error) {
        functions.logger.error("Error submitting trip data:", error);
        res.status(500).send("Internal Server Error.");
      }
    });

exports.getHotspotsByLocation = functions
    .region("us-central1")
    .https.onRequest(async (req, res) => {
      res.set("Access-Control-Allow-Origin", "*");

      if (req.method === "OPTIONS") {
        res.set("Access-Control-Allow-Methods", "GET");
        res.set("Access-Control-Allow-Headers", "Content-Type");
        res.set("Access-Control-Max-Age", "3600");
        res.status(204).send("");
        return;
      }

      const lat = parseFloat(req.query.lat);
      const lon = parseFloat(req.query.lon);

      if (isNaN(lat) || isNaN(lon)) {
        res.status(400).send(
            "Invalid or missing 'lat'/'lon' query parameters.",
        );
        return;
      }

      const centerGeohash = ngeohash.encode(lat, lon, 6);
      const neighbors = ngeohash.neighbors(centerGeohash);
      const queryArea = [centerGeohash, ...neighbors];

      try {
        const querySnapshot = await db.collection("calculated_hotspots")
            .where("geohash", "in", queryArea)
            .get();

        if (querySnapshot.empty) {
          res.status(200).json([]);
          return;
        }

        const hotspots = querySnapshot.docs.map((doc) => {
          return {
            id: doc.id,
            ...doc.data(),
          };
        });

        res.status(200).json(hotspots);
      } catch (error) {
        functions.logger.error("Error querying hotspots:", error);
        res.status(500).send("Internal Server Error.");
      }
    });

exports.processRawData = functions.pubsub.schedule("every 1 hours")
    .timeZone("Asia/Taipei")
    .onRun(async (context) => {
      functions.logger.info("Starting raw data processing task...");

      const cutoff = new Date(
          Date.now() - RAW_DATA_TTL_DAYS * 24 * 60 * 60 * 1000,
      );
      const rawDataSnapshot = await db.collection("raw_pickup_data")
          .where("timestamp", ">=", cutoff)
          .get();

      if (rawDataSnapshot.empty) {
        functions.logger.info("No recent raw data to process. Task finished.");
        return null;
      }

      functions.logger.info(`Fetched ${rawDataSnapshot.size} raw data points.`);

      const clusters = new Map();
      rawDataSnapshot.forEach((doc) => {
        const data = doc.data();
        const hash = ngeohash.encode(
            data.latitude, data.longitude, HOTSPOT_GRID_PRECISION);

        if (!clusters.has(hash)) {
          clusters.set(hash, []);
        }
        clusters.get(hash).push(data);
      });

      const newHotspots = [];
      const now = Date.now();
      for (const [hash, points] of clusters.entries()) {
        if (points.length >= MIN_POINTS_FOR_HOTSPOT) {
          let totalLat = 0;
          let totalLon = 0;
          let totalHotness = 0;

          points.forEach((point) => {
            totalLat += point.latitude;
            totalLon += point.longitude;
            const weight = _calculateTimeDecayWeight(
                point.timestamp.toMillis(), now);
            totalHotness += weight;
          });

          const centerLat = totalLat / points.length;
          const centerLon = totalLon / points.length;

          newHotspots.push({
            center_latitude: centerLat,
            center_longitude: centerLon,
            geohash: hash,
            hotness_score: Math.round(totalHotness),
            point_count: points.length,
            last_updated: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }

      functions.logger.info(
          `Processed into ${newHotspots.length} valid hotspots.`);

      await _overwriteCollection(
          db.collection("calculated_hotspots"), newHotspots);
      await _cleanupOldRawData();

      functions.logger.info("Hotspot processing task finished successfully.");
      return null;
    });

/**
 * Calculates a weight for a data point based on its age.
 * @param {number} timestampMs The timestamp of the data point in milliseconds.
 * @param {number} nowMs The current time in milliseconds.
 * @return {number} The calculated weight (e.g., 0.1 to 1.0).
 */
function _calculateTimeDecayWeight(timestampMs, nowMs) {
  const ageInHours = (nowMs - timestampMs) / (1000 * 60 * 60);
  if (ageInHours < 6) return 1.0; // Last 6 hours
  if (ageInHours < 24) return 0.8; // Up to a day
  if (ageInHours < 24 * 7) return 0.5; // Up to a week
  if (ageInHours < 24 * 14) return 0.2; // Up to two weeks
  return 0.1; // Older
}

/**
 * Deletes all documents in a collection and replaces them with new ones.
 * @param {FirebaseFirestore.CollectionReference} collectionRef The collection.
 * @param {Array<Object>} newData The array of new documents to add.
 */
async function _overwriteCollection(collectionRef, newData) {
  const existingDocs = await collectionRef.limit(500).get();
  const batch = db.batch();

  existingDocs.forEach((doc) => {
    batch.delete(doc.ref);
  });

  newData.forEach((item) => {
    const docRef = collectionRef.doc();
    batch.set(docRef, item);
  });

  await batch.commit();

  if (existingDocs.size === 500) {
    await _overwriteCollection(collectionRef, []);
  }
}

/**
 * Deletes documents from raw_pickup_data older than RAW_DATA_TTL_DAYS.
 */
async function _cleanupOldRawData() {
  const cutoffDate = new Date(
      Date.now() - RAW_DATA_TTL_DAYS * 24 * 60 * 60 * 1000,
  );
  const oldDataSnapshot = await db.collection("raw_pickup_data")
      .where("timestamp", "<", cutoffDate)
      .limit(500)
      .get();

  if (oldDataSnapshot.empty) {
    return;
  }

  const batch = db.batch();
  oldDataSnapshot.forEach((doc) => {
    batch.delete(doc.ref);
  });

  await batch.commit();
  functions.logger.info(
      `Cleaned up ${oldDataSnapshot.size} old raw data points.`);

  if (oldDataSnapshot.size === 500) {
    await new Promise((resolve) => setTimeout(resolve, 1000));
    await _cleanupOldRawData();
  }
}
