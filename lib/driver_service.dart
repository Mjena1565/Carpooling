import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

const String __app_id = '';
const String __firebase_config = '';
const String __initial_auth_token = '';

class DriverService {
  late final FirebaseFirestore _db;
  late final FirebaseAuth _auth;
  final String appId;

  DriverService() : appId = kIsWeb ? __app_id : 'default-app-id' {
    _initializeFirebase();
  }

  void _initializeFirebase() {
    try {
      debugPrint('[DriverService] Initializing Firebase...');
      final app = Firebase.app();
      _db = FirebaseFirestore.instanceFor(app: app, /* databaseId: 'carpoolingv1' */);
      _auth = FirebaseAuth.instanceFor(app: app);
      _db.settings = const Settings(persistenceEnabled: true);
      
      if (__initial_auth_token.isNotEmpty) {
        debugPrint('[DriverService] Signing in with custom token...');
        _auth.signInWithCustomToken(__initial_auth_token).then((_) {
          debugPrint('[DriverService] Signed in as user: ${_auth.currentUser?.uid}');
        });
      } else {
        debugPrint('[DriverService] Signing in anonymously...');
        _auth.signInAnonymously().then((_) {
          debugPrint('[DriverService] Signed in as anonymous user: ${_auth.currentUser?.uid}');
        });
      }
    } catch (e) {
      debugPrint('[DriverService] Firebase initialization error: $e');
      // Handle Firebase initialization errors.
    }
  }

  // Use the authenticated user's UID directly for the path.
  String get _driverProfilesCollectionPath {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('[DriverService] ERROR: User not authenticated for private data access.');
      throw Exception('User not authenticated for private data access.');
    }
    final path = '/users/${user.uid}/driverProfiles';
    debugPrint('[DriverService] Generated driver profiles path: $path');
    return path;
  }
  
  String get _driverOffersCollectionPath => '/driverOffers';

  Future<DocumentReference> createDriverProfile(Map<String, dynamic> profileData) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated.');
    }

    debugPrint('[DriverService] Checking for existing driver profiles...');
    final existingProfiles = await _db.collection(_driverProfilesCollectionPath).get();
    if (existingProfiles.docs.length >= 3) {
      debugPrint('[DriverService] Profile creation failed. User already has 3 profiles.');
      throw Exception('You have reached the maximum limit of 3 driver profiles.');
    }
    debugPrint('[DriverService] User has ${existingProfiles.docs.length} profiles. Proceeding with creation.');

    profileData['createdAt'] = FieldValue.serverTimestamp();
    return await _db.collection(_driverProfilesCollectionPath).add(profileData);
  }

  Future<DocumentSnapshot> getDriverProfileById(String profileId) async {
    return await _db.collection(_driverProfilesCollectionPath).doc(profileId).get();
  }

  Future<List<Map<String, dynamic>>> getDriverProfiles() async {
    debugPrint('[DriverService] Attempting to get driver profiles...');
    try {
      final querySnapshot = await _db.collection(_driverProfilesCollectionPath).get();
      debugPrint('[DriverService] Query successful. Found ${querySnapshot.docs.length} documents.');
      final profiles = querySnapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();
      debugPrint('[DriverService] Successfully mapped ${profiles.length} profiles.');
      return profiles;
    } catch (e) {
      debugPrint('[DriverService] FAILED to get driver profiles: $e');
      return [];
    }
  }

  Future<void> updateDriverProfile(String profileId, Map<String, dynamic> data) async {
    await _db.collection(_driverProfilesCollectionPath).doc(profileId).update(data);
  }

  Future<void> deleteDriverProfile(String profileId) async {
    await _db.collection(_driverProfilesCollectionPath).doc(profileId).delete();
  }

  Future<Map<String, dynamic>> createDriverOffer(Map<String, dynamic> offerData) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated.');
    }
    final data = {
      ...offerData,
      'userId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final DocumentReference docRef = await _db.collection(_driverOffersCollectionPath).add(data);
    final DocumentSnapshot docSnapshot = await docRef.get();
    final Map<String, dynamic> newOfferData = docSnapshot.data() as Map<String, dynamic>;
    newOfferData['id'] = docSnapshot.id; 

    return newOfferData; 
  }

  Stream<DocumentSnapshot?> getActiveDriverOfferStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(null);
    }
    return _db
        .collection(_driverOffersCollectionPath)
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: "active")
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty ? snapshot.docs.first : null);
  }

  Stream<List<Map<String, dynamic>>> getMyDriverOffersStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }
    return _db.collection(_driverOffersCollectionPath).where('userId', isEqualTo: user.uid).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();
    });
  }
  
  Stream<Map<String, dynamic>?> getDriverOfferStream(String offerId) {
    return _db.collection(_driverOffersCollectionPath).doc(offerId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return {'id': snapshot.id, ...snapshot.data() as Map<String, dynamic>};
      }
      return null;
    });
  }

  Future<void> updateDriverOffer(String offerId, Map<String, dynamic> data) async {
    await _db.collection(_driverOffersCollectionPath).doc(offerId).update(data);
  }

  Future<void> cancelDriverOffer(String offerId) async {
    await _db.collection(_driverOffersCollectionPath).doc(offerId).delete();
  }

  Future<List<Map<String, dynamic>>> findMatchingRiders(Map<String, dynamic> offerDetails) async {
    // This is a dummy method. Real-time matching logic would go here.
    return [
      {'name': 'Dummy Rider 1', 'location': 'Some Dummy Location', 'destination': 'Dummy Office'},
      {'name': 'Dummy Rider 2', 'location': 'Another Dummy Location', 'destination': 'Dummy Office'},
    ];
  }
}

final driverService = DriverService();