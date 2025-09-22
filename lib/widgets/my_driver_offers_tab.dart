import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../driver_service.dart';
import '../widgets/custom_button.dart';
import '../login_page.dart';
import '../driver_offer_detail_screen.dart';

typedef MyDriverOffersTabState = _MyDriverOffersTabState;

class MyDriverOffersTab extends StatefulWidget {
  final VoidCallback onOfferCancelledOrCompleted;
  final bool initialCheckCompleted;

  const MyDriverOffersTab({
    super.key,
    required this.onOfferCancelledOrCompleted,
    this.initialCheckCompleted = false,
  });

  @override
  State<MyDriverOffersTab> createState() => _MyDriverOffersTabState();
}

class _MyDriverOffersTabState extends State<MyDriverOffersTab> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _activeDriverOffer;
  bool _isFetchingOffer = true;
  String? _errorMessage;
  late StreamSubscription _activeOfferSubscription;
  
  // This stream will listen for real-time updates to the active offer
  // We'll use a stream from our DriverService to get the active offer for the current user.
  late Stream<Map<String, dynamic>?> _activeOfferStream;

  Map<String, dynamic>? get activeDriverOffer => _activeDriverOffer;

  Future<void> navigateToDriverOfferDetailFromOutside(Map<String, dynamic> offerDetails) async {
    await _navigateToDriverOfferDetail(offerDetails);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
  super.initState();

  // Transform the DocumentSnapshot? stream into Map<String, dynamic>? stream
  _activeOfferStream = driverService.getActiveDriverOfferStream().map((snapshot) {
    if (snapshot != null && snapshot.exists) {
      final data = snapshot.data() as Map<String, dynamic>?;
      if (data != null) {
        return {'id': snapshot.id, ...data};
      }
    }
    return null;
  });

  _activeOfferSubscription = _activeOfferStream.listen((offer) {
    if (mounted) {
      setState(() {
        _activeDriverOffer = offer;
        _isFetchingOffer = false;
      });
    }
  }, onError: (error) {
    if (mounted) {
      setState(() {
        _isFetchingOffer = false;
        _errorMessage = 'Failed to load active offer: $error';
      });
    }
  });
}

  @override
  void dispose() {
    _activeOfferSubscription.cancel();
    super.dispose();
  }

  Future<void> refreshActiveOffer() async {
    if(mounted) {
      setState(() {
        _isFetchingOffer = true;
        _errorMessage = null;
      });
      // A small delay to simulate fetching, then let the stream update.
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          _isFetchingOffer = false;
        });
      }
    }
  }

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final DateTime dateTime = timestamp.toDate().toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
    } catch (e) {
      debugPrint("Error parsing timestamp: $e");
      return 'N/A';
    }
  }

  String _getDisplayTime(dynamic timeValue) {
    if (timeValue is Timestamp) {
      return _formatDateTime(timeValue);
    } else if (timeValue is String) {
      // Handle the case where the timestamp was saved as a String.
      // For now, we'll just display the raw string.
      return timeValue;
    }
    return 'N/A';
  }

  Future<void> _navigateToDriverOfferDetail(Map<String, dynamic> offerDetails) async {
    // Note: 'id' is the Firestore document ID which is a string.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DriverOfferDetailScreen(
          driverInputId: offerDetails['id'] as String,
          initialDriverOfferDetails: offerDetails,
          onOfferCancelled: () {
            // This callback is triggered when the offer is cancelled from the detail screen.
            // We don't need to manually check again due to the stream, but this is good practice
            // to ensure UI consistency if other states are affected.
            widget.onOfferCancelledOrCompleted();
          },
        ),
      ),
    );
    // After returning from the detail screen, the stream will have already updated the state,
    // so no need for an explicit _checkForActiveDriverOffer() call.
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isFetchingOffer) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Theme.of(context).primaryColor),
            const SizedBox(height: 16),
            const Text("Checking for active offers..."),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "My Active Ride Offers",
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "View or manage your current ride offer.",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),

          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Card(
                color: Colors.red.withOpacity(0.08),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  side: const BorderSide(color: Colors.red, width: 1.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 14),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (_activeDriverOffer != null)
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              margin: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active Offer Details',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                    ),
                    const Divider(height: 24, thickness: 1.5),
                    _buildInfoRow(
                        Icons.location_on_outlined,
                        'Location:',
                        _activeDriverOffer!['location'] ?? 'N/A'),
                    _buildInfoRow(
                        _activeDriverOffer!['office_direction'] == true
                            ? Icons.arrow_circle_right_outlined
                            : Icons.arrow_circle_left_outlined,
                        'Direction:',
                        (_activeDriverOffer!['office_direction'] == true)
                            ? 'To Office'
                            : 'From Office'),
                    _buildInfoRow(
                        Icons.schedule,
                        'Time:',
                        _getDisplayTime(_activeDriverOffer!['scheduled_time'] ??
                            _activeDriverOffer!['created_at'])),
                    _buildInfoRow(
                        Icons.group_outlined,
                        'Companions Occupied:',
                        (_activeDriverOffer!['companions_occupied']?.toString() ?? '0')),
                    const SizedBox(height: 16),
                    CustomButton(
                      text: "View Full Offer Details",
                      onPressed: () => _navigateToDriverOfferDetail(_activeDriverOffer!),
                      buttonColor: Theme.of(context).primaryColor,
                      icon: Icons.info_outline,
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                Icon(
                  Icons.directions_car_outlined,
                  size: 100,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 20),
                Text(
                  "You have no active ride offers.",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Create a new offer in the 'New Ride Offer' tab.",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                CustomButton(
                  text: "Refresh",
                  onPressed: refreshActiveOffer,
                  buttonColor: Theme.of(context).primaryColor,
                  icon: Icons.refresh,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.secondary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}