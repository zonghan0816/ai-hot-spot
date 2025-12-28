import { FieldValue, GeoPoint, Timestamp } from "firebase-admin/firestore";

/**
 * Represents a single trip event document from the `trip_events` collection.
 * This is the INPUT for our AI algorithm.
 */
export interface TripEvent {
  // Assuming a field named 'location' of type GeoPoint exists in your documents.
  location: GeoPoint;
  
  // Assuming a field named 'timestamp' of type Timestamp exists.
  timestamp: Timestamp;
}

/**
 * Represents a single hotspot document in the `calculated_hotspots` collection.
 * This is the OUTPUT of our AI algorithm.
 * The structure is designed to be directly consumed by the frontend PredictionService.
 */
export interface CalculatedHotspot {
  // The center point of the clustered hotspot.
  center_latitude: number;
  center_longitude: number;

  // The geohash of the hotspot area.
  geohash: string;

  // A score representing the density of trip events.
  hotness_score: number;

  // The timestamp when this hotspot was last updated.
  last_updated: FieldValue;
}
