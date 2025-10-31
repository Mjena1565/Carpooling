import math
from typing import Dict, List, Tuple, Union
import logging
import os
from firebase_functions import firestore_fn
from firebase_admin import initialize_app
from datetime import datetime

# Initialize Firebase Admin (lightweight)
initialize_app()

# Configure Logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Global variables for lazy initialization
_db = None
_api_key = None

def get_db():
    """Lazy initialization of Firestore client"""
    # global _db
    # if _db is None:
    from google.cloud import firestore
    _db = firestore.Client(project="carpooling-88fbd")
    return _db

def get_api_key():
    """Lazy initialization of API key"""
    global _api_key
    if _api_key is None:
        _api_key = os.getenv("GOOGLEMAPS_KEY")
        if not _api_key:
            logging.error("\u274c GOOGLEMAPS_KEY not found in environment!")
            raise ValueError("GOOGLEMAPS_KEY environment variable is required")
    return _api_key


# Utility functions
class GeoUtils:
    @staticmethod
    def calculate_aerial_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """Compute the distance between two latitude-longitude points in kilometers."""
        try:
            R = 6371  # Radius of the Earth in kilometers
            dLat = GeoUtils.deg2rad(lat2 - lat1)
            dLon = GeoUtils.deg2rad(lon2 - lon1)
            a = math.sin(dLat / 2) ** 2 + math.cos(GeoUtils.deg2rad(lat1)) * math.cos(GeoUtils.deg2rad(lat2)) * math.sin(dLon / 2) ** 2
            c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
            return R * c
        except Exception as e:
            logging.error(f"Error Calculating aerial distance (GeoUtils): {e}")
            return float('inf')

    @staticmethod
    def deg2rad(deg: float) -> float:
        """Convert degrees to radians."""
        try:
            return deg * (math.pi / 180)
        except Exception as e:
            logging.error(f"Error Calculating deg2rad (GeoUtils): {e}")
            return 0.0


# Google Maps API wrapper
class GoogleMapsAPI:
    def __init__(self, api_key: str):
        self.api_key = api_key
        
    def _format_location_param(self, location: Union[str, Tuple[float, float]]) -> str:
        """
        Helper to format a location (address string or lat/lon tuple)
        into the string format required by Google Maps API.
        """
        if isinstance(location, tuple) and len(location) == 2 and \
           isinstance(location[0], (float, int)) and isinstance(location[1], (float, int)):
            return f"{location[0]},{location[1]}"
        elif isinstance(location, str):
            return location
        else:
            logging.error(f"Invalid location format: {location}. Must be a string address or (lat, lon) tuple.")
            raise ValueError("Location must be an address string or a (lat, lon) tuple.")
            
    def check_connectivity(self) -> bool:
        import requests
        try:
            url = "https://maps.googleapis.com/maps/api/geocode/json"
            params = {'address': 'test', 'key': self.api_key}
            response = requests.get(url, params=params, timeout=5)
            response.raise_for_status()
            return True
        except Exception as e:
            logging.error(f"Connectivity check failed: {e}")
            return False

    def get_lat_lon(self, address: str) -> Tuple[float, float]:
        """Geocode an address to latitude and longitude."""
        import requests
        try:
            url = "https://maps.googleapis.com/maps/api/geocode/json"
            params = {'address': address, 'key': self.api_key}
            response = requests.get(url, params=params, timeout=10).json()
            if response['status'] != 'OK':
                raise ValueError(f"Error fetching geocode Data: {response['status']}")
            location = response['results'][0]['geometry']['location']
            return location['lat'], location['lng']
        except Exception as e:
            logging.error(f"Failed to Get_lat_lon(GoogleMapsAPI) for address {address}: {e}")
            return None

    def get_directions(self,
                       origin: Union[str, Tuple[float, float]],
                       destination: Union[str, Tuple[float, float]],
                       mode: str = 'driving') -> Tuple[List[Tuple[float, float]], float, str]:
        """
        Retrieve directions and decode polyline, also returning total distance and duration.
        """
        import requests
        import polyline
        
        try:
            formatted_origin = self._format_location_param(origin)
            formatted_destination = self._format_location_param(destination)

            url = "https://maps.googleapis.com/maps/api/directions/json"
            params = {
                'origin': formatted_origin,
                'destination': formatted_destination,
                'mode': mode,
                'key': self.api_key
            }
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()
            data = response.json()

            if data['status'] == 'OK':
                legs = data['routes'][0]['legs'][0]
                distance_km = float(legs['distance']['text'].split()[0])
                duration_text = legs['duration']['text']
                polyline_str = data['routes'][0]['overview_polyline']['points']
                decoded_points = polyline.decode(polyline_str)
                return decoded_points, distance_km, duration_text
            else:
                logging.error(f"Error fetching Directions: {data['status']}")
                return [], float('inf'), "Unknown"
        except Exception as e:
            logging.error(f"Failed to Get_directions(GoogleMapsAPI): {e}")
            return [], float('inf'), "Unknown"

    def get_distance_duration(self,
                              origin: Union[str, Tuple[float, float]],
                              destination: Union[str, Tuple[float, float]],
                              mode: str = 'driving') -> Tuple[float, str]:
        """
        Get road distance and duration between two points.
        """
        import requests
        
        try:
            formatted_origin = self._format_location_param(origin)
            formatted_destination = self._format_location_param(destination)

            url = "https://maps.googleapis.com/maps/api/directions/json"
            params = {
                'origin': formatted_origin,
                'destination': formatted_destination,
                'mode': mode,
                'key': self.api_key
            }
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()
            data = response.json()

            if data['status'] == 'OK':
                legs = data['routes'][0]['legs'][0]
                distance_km = float(legs['distance']['text'].split()[0])
                duration_text = legs['duration']['text']
                return distance_km, duration_text
            else:
                logging.error(f"Error fetching distance/duration: {data['status']}")
                return float('inf'), "Unknown"
        except Exception as e:
            logging.error(f"Failed to Get_distance_duration(GoogleMapsAPI): {e}")
            return float('inf'), "Unknown"


# Core logic
class CarpoolMatcher:
    def __init__(self, api: GoogleMapsAPI, buffer_time: int = 5):
        self.api = api
        self.buffer_time = buffer_time

    def find_best_paths(self, locations: Dict[str, Dict[str, str]]) -> Dict[str, List[Tuple[float, float]]]:
        """Compute the shortest paths from drivers to the office."""
        office_location = locations['office']
        paths = {}

        for driver, address in locations['drivers'].items():
            paths[driver] = self.api.get_directions(address, office_location)
        return paths

    def calculate_aerial_distances(self, driver_paths: Dict[str, Tuple[List[Tuple[float, float]], float, str]], companions: Dict[str, Tuple[float, float]]) -> Dict[Tuple[str, str], List[Tuple[Tuple[float, float], float]]]:
        """Calculate the top 5 closest nodes for each driver-companion pair based on aerial distance."""
        aerial_distances = {}
        for driver, path_info in driver_paths.items():
            path_coords = path_info[0]
            for companion_name, companion_coords in companions.items():
                distances = [(node, GeoUtils.calculate_aerial_distance(
                    companion_coords[0], companion_coords[1],
                    node[0], node[1]
                )) for node in path_coords]

                aerial_distances[(driver, companion_name)] = sorted(distances, key=lambda x: x[1])[:5]
        return aerial_distances

    def find_best_intersection_node(self, driver_paths: Dict[str, List[Tuple[float, float]]], companions: Dict[str, Tuple[float, float]], aerial_distances: Dict[Tuple[str, str], List[Tuple[Tuple[float, float], float]]]) -> Dict[Tuple[str, str], Tuple[float, float, int]]:
        """Find the best intersection node among the top 5 nodes for each driver-companion pair."""
        road_distances = {}
        logging.info(f"AERIAL DISTANCE {aerial_distances}")
        
        for (driver, companion), nodes in aerial_distances.items():
            best_node = None
            shortest_road_distance = float('inf')

            for node, _ in nodes:
                companion_distance, companion_time = self.api.get_distance_duration(companions[companion], node)
                driver_distance, driver_time = self.api.get_distance_duration(driver_paths[driver][0][0], node)
                driver_time = int(driver_time.split()[0])
                companion_time = int(companion_time.split()[0])
                
                try:
                    if companion_distance < shortest_road_distance and driver_time + self.buffer_time >= companion_time:
                        shortest_road_distance = companion_distance
                        best_node = node
                except Exception as e:
                    logging.error(f"Check for companion time {companion_time} and driver time {driver_time}: {e}")

            road_distances[(driver, companion)] = (shortest_road_distance, best_node)
            
        sorted_road_distances = sorted(road_distances.items(), key=lambda item: item[1][0])
        assignment = {sorted_road_distances[0][0][0]: [(sorted_road_distances[0][0][1], sorted_road_distances[0][1][1])]}
        return assignment


# Helper function
class CarpoolHelper:
    @staticmethod
    def match(locations) -> Tuple[Dict[str, str], Dict[str, List[Tuple[str, Tuple[float, float]]]], Dict[str, List[Tuple[float, float]]]]:
        logging.info(f"Locations being processed by CarpoolHelper.match: {locations}")
        
        api_key = get_api_key()
        api_client = GoogleMapsAPI(api_key)
        
        if not api_client.check_connectivity():
            logging.error("Unable to connect to Google API")
            raise ConnectionError("Google Maps API connectivity check failed")
        
        logging.info("Google Maps API connected successfully")
        
        try:
            matcher = CarpoolMatcher(api_client)
            companions_coords = {name: api_client.get_lat_lon(address) for name, address in locations['companions'].items()}
            driver_paths = matcher.find_best_paths(locations)
            aerial_distances = matcher.calculate_aerial_distances(driver_paths, companions_coords)
            best_intersection = matcher.find_best_intersection_node(driver_paths, companions_coords, aerial_distances)
            logging.info(f"Best Intersection point is {best_intersection}")
            return locations, best_intersection, driver_paths
        except Exception as e:
            logging.error(f"Critical failure in match: {e}")
            raise


def store_algo_output(locations, best_intersection, driver_paths):
    """
    Store algorithm outputs in Firestore
    
    best_intersection: Dict[Tuple[str, str], Tuple[float, float, int]]
        Format: {('driver_id', 'companion_id'): (lat, lon, something)}
    
    driver_paths: Dict[str, List[Tuple[float, float]]]
        Format: {'driver_id': [(lat1, lon1), (lat2, lon2), ...]}
    """
    from google.cloud import firestore
    db = get_db()
    timestamp = datetime.now()
    
    try:
        # Create a collection called 'algo_outputs' to dump everything
        output_ref = db.collection('algo_outputs').document()
        
        # Convert best_intersection from Dict[Tuple[str, str], Tuple] to storable format
        best_intersection_serialized = {}
        for (driver_id, companion_id), intersection_data in best_intersection.items():
            key = f"{driver_id}_{companion_id}"
            best_intersection_serialized[key] = {
                "driver_id": driver_id,
                "companion_id": companion_id,
                "intersection_point": {
                    "lat": intersection_data[0],
                    "lon": intersection_data[1]
                }
            }
        
        # Convert driver_paths to storable format
        driver_paths_serialized = {}
        for driver_id, path in driver_paths.items():
            # path is a tuple: (list_of_coords, distance, duration)
            coords_list = path[0] if isinstance(path, tuple) else path
            driver_paths_serialized[driver_id] = {
                "path": [{"lat": coord[0], "lon": coord[1]} for coord in coords_list],
                "distance_km": path[1] if isinstance(path, tuple) and len(path) > 1 else None,
                "duration": path[2] if isinstance(path, tuple) and len(path) > 2 else None
            }
        
        # Store everything
        output_data = {
            "timestamp": firestore.SERVER_TIMESTAMP,
            "locations": locations,
            "best_intersection": best_intersection_serialized,
            "driver_paths": driver_paths_serialized,
            "created_at": timestamp.isoformat()
        }
        
        output_ref.set(output_data)
        logging.info(f"\u2705 Successfully stored algo output with ID: {output_ref.id}")
        return output_ref.id
        
    except Exception as e:
        logging.error(f"\u274c Failed to store algo output: {e}")
        raise


@firestore_fn.on_document_created(document="companionrequests/{docId}")
def on_companion_request_created(event: firestore_fn.Event[firestore_fn.DocumentSnapshot]) -> None:
    """Triggered when a companion request is created"""
    return carpool_match(event)


@firestore_fn.on_document_created(document="driveroffers/{docId}")
def on_driver_offer_created(event: firestore_fn.Event[firestore_fn.DocumentSnapshot]) -> None:
    """Triggered when a driver offer is created"""
    return carpool_match(event)


def carpool_match(event: firestore_fn.Event[firestore_fn.DocumentSnapshot]) -> None:
    """
    Triggered whenever a document is created in either companionrequests or driveroffers
    inside the 'carpool' Firestore database.
    """
    helper = CarpoolHelper()
    db = get_db()

    try:
        logging.info(f"Triggered by creation in: {event.params}")

        # --- Fetch active companion requests
        companion_snapshot = (
            db.collection("companionrequests")
            .where("status", "==", "active")
            .stream()
        )

        companions = []
        for doc in companion_snapshot:
            data = doc.to_dict()
            companions.append((data["user_id"], (data["lat"], data["lon"])))

        # --- Fetch active driver offers
        driver_snapshot = (
            db.collection("driveroffers")
            .where("status", "==", "active")
            .stream()
        )

        drivers = []
        for doc in driver_snapshot:
            data = doc.to_dict()
            drivers.append((data["driver_id"], (data["lat"], data["lon"])))

        # --- Build the final Tuple
        locations: Tuple[
            Dict[str, str],
            Dict[str, List[Tuple[str, Tuple[float, float]]]],
            Dict[str, List[Tuple[str, Tuple[float, float]]]]
        ] = (
            {"office": "Brigade Tech Garden, Bangalore"},
            {"drivers": drivers},
            {"companions": companions},
        )

        logging.info(f"Structured locations for match(): {locations}")

        # --- Call your match function
        locations, best_intersection, driver_paths = helper.match(locations)
        logging.info(f"Match result - Best intersection: {best_intersection}")
        
        # --- Store the outputs in Firestore
        output_id = store_algo_output(locations, best_intersection, driver_paths)
        logging.info(f"Stored output with ID: {output_id}")

    except Exception as e:
        logging.error(f"Error in carpool_match: {e}")
        raise