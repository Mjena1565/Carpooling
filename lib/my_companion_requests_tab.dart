// File: lib/screens/my_companion_requests_tab.dart
import 'package:firebasetestapp/firestore_service.dart';
import 'package:firebasetestapp/login_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/custom_button.dart';
import 'package:firebase_auth/firebase_auth.dart';

typedef MyCompanionRequestsTabState = _MyCompanionRequestsTabState;

class MyCompanionRequestsTab extends StatefulWidget {
  const MyCompanionRequestsTab({super.key});

  @override
  State<MyCompanionRequestsTab> createState() => _MyCompanionRequestsTabState();
}

class _MyCompanionRequestsTabState extends State<MyCompanionRequestsTab> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    // No need to manually fetch on initState, StreamBuilder handles it
  }

  Future<void> _cancelCompanionRequest(String requestId) async {
    final bool? confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('Confirm Cancellation'),
        content: const Text('Are you sure you want to cancel this ride request?'),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: const Text('No'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    try {
      await _firestoreService.cancelCompanionRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ride request cancelled successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel request: ${e.toString()}')),
        );
      }
    }
  }

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final DateTime dateTime = timestamp.toDate().toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
    } catch (e) {
      return 'Invalid date';
    }
  }

  @override
  Widget build(BuildContext context) {
    // If user is not logged in, navigate to login screen
    if (_auth.currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginAuthScreen()),
        );
      });
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestoreService.getCompanionRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 50),
                  const SizedBox(height: 10),
                  Text(
                    'Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  CustomButton(
                    text: "Retry",
                    onPressed: () => setState(() {}), // A simple way to trigger a refresh
                    icon: Icons.refresh,
                    buttonColor: Colors.blueGrey,
                  )
                ],
              ),
            ),
          );
        }

        final _companionRequests = snapshot.data ?? [];

        if (_companionRequests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, color: Colors.grey[400], size: 60),
                const SizedBox(height: 16),
                Text(
                  "No active ride requests found.",
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                CustomButton(
                  text: "Request a New Ride",
                  onPressed: () {
                    DefaultTabController.of(context)?.animateTo(0);
                  },
                  icon: Icons.add_location_alt,
                  buttonColor: Theme.of(context).primaryColor,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: _companionRequests.length,
          itemBuilder: (context, index) {
            final request = _companionRequests[index];
            final bool isScheduled = request['isRideLater'] ?? false;
            final String status = (request['status'] as String? ?? 'unknown').toUpperCase();
            final Color statusColor = status == 'WAITING' ? Colors.orange : (status == 'MATCHED' ? Colors.green : Colors.blue);
            final IconData statusIcon = status == 'WAITING' ? Icons.hourglass_empty : (status == 'MATCHED' ? Icons.check_circle : Icons.info);

            return Card(
              elevation: 4,
              margin: const EdgeInsets.only(bottom: 16.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isScheduled ? "SCHEDULED RIDE" : "LIVE RIDE",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(statusIcon, color: statusColor, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              status,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 20, thickness: 1),
                    _buildInfoRow(Icons.location_on, "Location:", request['location'] ?? 'N/A'),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      request['isOfficeDirection'] == true ? Icons.arrow_circle_right : Icons.arrow_circle_left,
                      "Direction:",
                      request['isOfficeDirection'] == true ? "To Office" : "From Office",
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.access_time,
                      "Time:",
                      _formatDateTime(request['scheduledTime'] ?? request['createdAt']),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 120, // Constrain button width
                        child: CustomButton(
                          text: "Cancel",
                          onPressed: () => _cancelCompanionRequest(request['id']),
                          buttonColor: Colors.red[400],
                          icon: Icons.close,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey[600], size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}