import * as geofire from "geofire-common";
import { TripEvent, CalculatedHotspot } from "./models";
import { FieldValue } from "firebase-admin/firestore";

// /////////////////////////////////////////////////////////////////////////////
// 
//  MVP 3: The Cloud AI Brain - Core Algorithm
//
//  This file contains the core scientific logic for hotspot calculation.
//  It's designed as a pure function for testability and maintainability.
//
//  INPUT: An array of `TripEvent` objects.
//  OUTPUT: An array of `CalculatedHotspot` objects.
//
// /////////////////////////////////////////////////////////////////////////////


/**
 * The precision for the geohash. 
 * A precision of 7 creates a box of ~153m x 153m, ideal for city block-level hotspots.
 */
const GEOHASH_PRECISION = 7;

/**
 * The minimum number of events required in a geohash area to be considered a hotspot.
 * This filters out random, insignificant drop-offs.
 */
const MIN_EVENTS_PER_HOTSPOT = 3;


/**
 * Processes a list of trip events to find high-density hotspots.
 * @param events An array of TripEvent objects.
 * @returns A promise that resolves to an array of CalculatedHotspot objects.
 */
export function processTripEvents(events: TripEvent[]): CalculatedHotspot[] {
  
  // Step 1: Group events by their geohash.
  const eventsByGeohash = new Map<string, TripEvent[]>();

  for (const event of events) {
    const lat = event.location.latitude;
    const lon = event.location.longitude;
    const hash = geofire.geohashForLocation([lat, lon], GEOHASH_PRECISION);

    if (!eventsByGeohash.has(hash)) {
      eventsByGeohash.set(hash, []);
    }
    eventsByGeohash.get(hash)?.push(event);
  }

  // Step 2: Filter for significant clusters and calculate hotspot properties.
  const calculatedHotspots: CalculatedHotspot[] = [];

  for (const [hash, clusteredEvents] of eventsByGeohash.entries()) {
    
    // Apply the filter threshold.
    if (clusteredEvents.length < MIN_EVENTS_PER_HOTSPOT) {
      continue;
    }

    // --- Calculation ---

    // a. Calculate the hotness score.
    const hotnessScore = clusteredEvents.length;

    // b. Calculate the average center point of the cluster.
    let totalLat = 0;
    let totalLon = 0;
    for (const event of clusteredEvents) {
      totalLat += event.location.latitude;
      totalLon += event.location.longitude;
    }
    const centerLat = totalLat / clusteredEvents.length;
    const centerLon = totalLon / clusteredEvents.length;

    // --- Transformation ---
    
    // c. Assemble the final CalculatedHotspot object.
    calculatedHotspots.push({
      geohash: hash,
      hotness_score: hotnessScore,
      center_latitude: centerLat,
      center_longitude: centerLon,
      last_updated: FieldValue.serverTimestamp(),
    });
  }
  
  // Step 3: Return the final list of hotspots.
  return calculatedHotspots;
}
