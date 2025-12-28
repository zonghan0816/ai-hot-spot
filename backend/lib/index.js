"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateHotspots = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const algorithm_1 = require("./algorithm");
// /////////////////////////////////////////////////////////////////////////////
//
//  MVP 3: The Cloud AI Brain - The Conductor
//
//  This file integrates all modules into a fully automated, scheduled function.
//  It acts as the "Conductor" that orchestrates the entire process:
//  1. Wakes up on a schedule.
//  2. Reads raw data from Firestore (INPUT).
//  3. Commands the "Scientist" (algorithm.ts) to perform analysis.
//  4. Atomically updates the results in Firestore (OUTPUT).
//
// /////////////////////////////////////////////////////////////////////////////
// Initialize the Firebase Admin SDK to access Firestore.
admin.initializeApp();
const db = admin.firestore();
/**
 * This is the main scheduled function that runs our AI brain automatically.
 * It triggers every 1 hour, processes the last hour's trip data,
 * and overwrites the calculated_hotspots collection with fresh results.
 */
exports.generateHotspots = functions
    .region("asia-east1") // Specify a region for lower latency if your DB is in Asia
    .pubsub.schedule("every 1 hours")
    .onRun(async (context) => {
    functions.logger.info("AI Brain waking up: Starting hotspot generation cycle.", { timestamp: context.timestamp });
    try {
        // --- 1. READ (Get Input Data) ---
        const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
        const tripEventsSnapshot = await db.collection("trip_events")
            .where("timestamp", ">=", oneHourAgo)
            .get();
        if (tripEventsSnapshot.empty) {
            functions.logger.info("No new trip events in the last hour. Cycle finished.");
            return null;
        }
        const tripEvents = tripEventsSnapshot.docs.map(doc => doc.data());
        functions.logger.log(`Fetched ${tripEvents.length} new trip events for analysis.`);
        // --- 2. PROCESS (Command the Scientist) ---
        const newHotspots = (0, algorithm_1.processTripEvents)(tripEvents);
        functions.logger.log(`AI algorithm processed data and found ${newHotspots.length} potential hotspots.`);
        if (newHotspots.length === 0) {
            functions.logger.info("No significant hotspots found in this cycle. Database remains unchanged.");
            return null;
        }
        // --- 3. WRITE (Atomically Update Results) ---
        const hotspotsCollectionRef = db.collection("calculated_hotspots");
        const batch = db.batch();
        // a. Schedule deletion of all old hotspots.
        const oldHotspotsSnapshot = await hotspotsCollectionRef.get();
        if (!oldHotspotsSnapshot.empty) {
            oldHotspotsSnapshot.docs.forEach(doc => {
                batch.delete(doc.ref);
            });
            functions.logger.log(`Scheduled ${oldHotspotsSnapshot.size} old hotspots for deletion.`);
        }
        // b. Schedule creation of all new hotspots.
        newHotspots.forEach((hotspot) => {
            const newDocRef = hotspotsCollectionRef.doc(); // Create a new doc with a random ID
            batch.set(newDocRef, hotspot);
        });
        functions.logger.log(`Scheduled ${newHotspots.length} new hotspots for creation.`);
        // c. Commit the atomic batch operation.
        await batch.commit();
        functions.logger.info("SUCCESS: Hotspot database has been atomically updated.", {
            newHotspotsCount: newHotspots.length,
            deletedHotspotsCount: oldHotspotsSnapshot.size,
        });
    }
    catch (error) {
        functions.logger.error("FATAL: An error occurred during the hotspot generation cycle.", error);
    }
    return null; // Function execution finished.
});
//# sourceMappingURL=index.js.map