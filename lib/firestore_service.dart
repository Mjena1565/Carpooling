// File: lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    // databaseId: 'carpoolingv1',
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Add a new companion request to Firestore
  Future<DocumentReference> addCompanionRequest({
    required String userId,
    required String location,
    required double? latitude,
    required double? longitude,
    required bool isOfficeDirection,
    required bool isRideLater,
    String? scheduledTime,
    String? activeStatus,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated.');
    }

    final data = {
      'userId': userId,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'isOfficeDirection': isOfficeDirection,
      'isRideLater': isRideLater,
      'scheduledTime': scheduledTime,
      'status': activeStatus,
      'createdAt': FieldValue.serverTimestamp(),
    };
    
    // Using a DocumentReference to get the ID after adding the document.
    return await _db.collection('companionRequests').add(data);
  }

 
  Stream<QuerySnapshot> getUserCompanionRequestsStream(String userId) {
    return _db
        .collection('companionRequests')
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['waiting', 'matched','active'])
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Fetches a list of the current user's active companion requests.
  Future<List<DocumentSnapshot>> getLiveCompanionRequests(String userId) async {
    final querySnapshot = await _db
        .collection('companionRequests')
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['waiting', 'matched'])
        .get();
    return querySnapshot.docs;
  }

  // A different approach to get requests as a list of maps.
  // The method above (getUserCompanionRequestsStream) is more suitable for the StreamBuilder widget.
  Stream<List<Map<String, dynamic>>> getCompanionRequests() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _db
        .collection('companionRequests')
        .where('userId', isEqualTo: user.uid)
        .where('status', whereIn: ['waiting', 'matched']) 
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id; 
            return data;
          }).toList();
        });
  }

  Future<void> cancelCompanionRequest(String requestId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated.');
    }

    await _db.collection('companionRequests').doc(requestId).update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }
    Future<void> deleteCompanionRequest(String requestId) async {
      return await _db
          .collection('companionRequests')
          .doc(requestId)
          .delete();
    }
}