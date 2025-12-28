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
exports.processTripEvents = void 0;
const geofire = __importStar(require("geofire-common"));
const firestore_1 = require("firebase-admin/firestore");
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
function processTripEvents(events) {
    var _a;
    // Step 1: Group events by their geohash.
    const eventsByGeohash = new Map();
    for (const event of events) {
        const lat = event.location.latitude;
        const lon = event.location.longitude;
        const hash = geofire.geohashForLocation([lat, lon], GEOHASH_PRECISION);
        if (!eventsByGeohash.has(hash)) {
            eventsByGeohash.set(hash, []);
        }
        (_a = eventsByGeohash.get(hash)) === null || _a === void 0 ? void 0 : _a.push(event);
    }
    // Step 2: Filter for significant clusters and calculate hotspot properties.
    const calculatedHotspots = [];
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
            last_updated: firestore_1.FieldValue.serverTimestamp(),
        });
    }
    // Step 3: Return the final list of hotspots.
    return calculatedHotspots;
}
exports.processTripEvents = processTripEvents;
//# sourceMappingURL=algorithm.js.map