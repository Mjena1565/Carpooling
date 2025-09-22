// utils/location_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart'; 

class LocationService {
  static Future<Position?> getCurrentLocation(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled. Please enable them to use this feature.')),
        );
      }
      // Open location settings for the user
      await Geolocator.openLocationSettings();
      return null;
    }

    // Check permissions.
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
        }
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      
      if (context.mounted) {
        _showPermissionDeniedForeverDialog(context);
      }
      return null;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10), // Timeout after 10 seconds
  );
  debugPrint("Current Location: Lat ${position.latitude}, Lon ${position.longitude}");
  debugPrint("Accuracy: ${position.accuracy}m");
  debugPrint("Timestamp: ${position.timestamp}");
  return position;
} catch (e) {
      debugPrint("Error getting location: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get current location: $e')),
        );
      }
      return null;
    }
  }

  static void _showPermissionDeniedForeverDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Location Permission Denied"),
          content: const Text(
            "Location permissions are permanently denied. Please go to your app settings to enable them.",
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text("Open Settings"),
              onPressed: () {
                Geolocator.openAppSettings();
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  static Future<void> requestInitialPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }
}