// my_companion_requests_tab.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../firestore_service.dart';
import '../widgets/custom_button.dart';

// Create a typedef for the state class
typedef MyCompanionRequestsTabState = _MyCompanionRequestsTabState;

class MyCompanionRequestsTab extends StatefulWidget {
  const MyCompanionRequestsTab({super.key});

  @override
  State<MyCompanionRequestsTab> createState() => _MyCompanionRequestsTabState();
}

class _MyCompanionRequestsTabState extends State<MyCompanionRequestsTab> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<QuerySnapshot> _getUserRequestsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return _firestoreService.getUserCompanionRequestsStream(user.uid);
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
      await _firestoreService.deleteCompanionRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ride request cancelled successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel request: $e')),
        );
      }
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final DateTime dateTime = timestamp.toDate().toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
    } else if (timestamp is String) {
      try {
        final DateTime dateTime = DateTime.parse(timestamp).toLocal();
        return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
      } catch (e) {
        return 'Invalid Date';
      }
    }
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getUserRequestsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 16),
                  Text(
                    'An error occurred: ${snapshot.error.toString()}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: "Refresh",
                    onPressed: () {
                      setState(() {});
                    },
                    icon: Icons.refresh,
                    buttonColor: Theme.of(context).primaryColor,
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, color: Colors.grey[400], size: 80),
                  const SizedBox(height: 16),
                  Text(
                    "You have no active ride requests.",
                    style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500),
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
            ),
          );
        }

        final requests = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final data = request.data() as Map<String, dynamic>;

            // Fetching data directly from Firestore
            final bool isScheduled = data['isRideLater'] ?? false;
            final String status = (data['status'] as String? ?? 'unknown').toUpperCase();
            final dynamic timestamp = isScheduled
                ? data['scheduledTime']
                : data['createdAt'];

            final Color statusColor = status == 'WAITING'
                ? Colors.orange
                : (status == 'ACTIVE' ? Colors.green : Colors.blue);
            final IconData statusIcon = status == 'WAITING'
                ? Icons.hourglass_empty
                : (status == 'ACTIVE' ? Icons.directions_run : Icons.info);

            return Card(
              elevation: 6,
              margin: const EdgeInsets.only(bottom: 20.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isScheduled ? "SCHEDULED RIDE" : "LIVE RIDE",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        Chip(
                          avatar: Icon(statusIcon, color: statusColor, size: 18),
                          label: Text(
                            status,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                          backgroundColor: statusColor.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: statusColor.withOpacity(0.4)),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, thickness: 1),
                    _buildInfoRow(
                      icon: Icons.location_on_outlined, 
                      label: "Location", 
                      value: data['location'] ?? 'N/A'
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      icon: Icons.alt_route,
                      label: "Direction",
                      value: data['isOfficeDirection'] == true ? "To Office" : "From Office",
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      icon: Icons.access_time_outlined,
                      label: "Time",
                      value: _formatTimestamp(timestamp),
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 180,
                        child: CustomButton(
                          text: "Cancel Request",
                          onPressed: () => _cancelCompanionRequest(request.id),
                          buttonColor: Colors.red[400],
                          // icon: Icons.cancel_outlined,
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

  Widget _buildInfoRow({required IconData icon, required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).primaryColor, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
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