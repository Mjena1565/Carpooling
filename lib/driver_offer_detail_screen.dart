import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/custom_button.dart';
import '../driver_service.dart';
import 'map_driver_screen.dart';

class DriverOfferDetailScreen extends StatefulWidget {
  final String driverInputId;
  final Map<String, dynamic> initialDriverOfferDetails;
  final VoidCallback? onOfferCancelled;

  const DriverOfferDetailScreen({
    super.key,
    required this.driverInputId,
    required this.initialDriverOfferDetails,
    this.onOfferCancelled,
  });

  @override
  State<DriverOfferDetailScreen> createState() =>
      _DriverOfferDetailScreenState();
}

class _DriverOfferDetailScreenState extends State<DriverOfferDetailScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  late Map<String, dynamic> _driverOfferDetails;
  Map<String, dynamic>? _driverProfile;

  @override
  void initState() {
    super.initState();
    _driverOfferDetails = widget.initialDriverOfferDetails;
    _listenForOfferUpdates();
    _fetchDriverProfile();
  }

  void _listenForOfferUpdates() {
    driverService
        .getDriverOfferStream(widget.driverInputId)
        .listen(
          (offerData) {
            if (!mounted) return;
            if (offerData != null) {
              // Create a safe, mutable copy of the data to perform type conversions.
              final safeOfferData = Map<String, dynamic>.from(offerData);

              // Safely convert potential String timestamps to Timestamp objects.
              // This prevents the 'String' is not a subtype of 'Timestamp' error.
              void convertStringToTimestamp(String key) {
                final value = safeOfferData[key];
                if (value is String) {
                  final dateTime = DateTime.tryParse(value);
                  if (dateTime != null) {
                    safeOfferData[key] = Timestamp.fromDate(dateTime);
                  } else {
                    safeOfferData[key] = null;
                  }
                }
              }

              convertStringToTimestamp('scheduled_time');
              convertStringToTimestamp('created_at');

              setState(() {
                _driverOfferDetails = safeOfferData;
                _isLoading = false;
              });
            } else {
              _showErrorAndNavigateBack(
                "The ride offer was not found or has been completed/cancelled.",
              );
            }
          },
          onError: (e) {
            if (!mounted) return;
            setState(() {
              _errorMessage = 'Failed to load offer details. Please try again.';
              _isLoading = false;
            });
          },
        );
  }

  Future<void> _fetchDriverProfile() async {
    final driverId = widget.initialDriverOfferDetails['driver_id'];

    if (driverId != null) {
      try {
        final profile = await driverService.getDriverProfileById(driverId);
        if (profile.exists) {
          setState(() {
            _driverProfile = {
              'id': profile.id,
              ...profile.data() as Map<String, dynamic>,
            };
          });
        }
      } catch (e) {
        debugPrint('Error fetching driver profile: $e');
        setState(() {
          _driverProfile = null;
        });
      }
    }
  }

  Future<void> _matchDriver() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<Map<String, dynamic>> matchingRiders = await driverService
          .findMatchingRiders(_driverOfferDetails);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Matching process initiated!'),
          backgroundColor: Colors.green,
        ),
      );
      // debugPrint('Driver Offer Details: $_driverOfferDetails');
      final bool isRideLater = _driverOfferDetails['scheduled_time'] != null;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (context) => MapDriverScreen(
                title: "Matching Results",
                responseData: jsonEncode({'matches': matchingRiders}),
                isRideLater: isRideLater,
              ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to initiate matching: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelRideOffer() async {
    final bool confirm =
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text(
                'Confirm Cancellation',
                style: TextStyle(color: Colors.red),
              ),
              content: const Text(
                'Are you sure you want to cancel this ride offer? This cannot be undone.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'No',
                    style: TextStyle(color: Theme.of(context).primaryColor),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Yes, Cancel'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirm) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await driverService.cancelDriverOffer(widget.driverInputId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride offer cancelled successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      widget.onOfferCancelled?.call();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to cancel offer: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorAndNavigateBack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
    widget.onOfferCancelled?.call();
    Navigator.of(context).pop();
  }

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final DateTime dateTime = timestamp.toDate().toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
    } catch (e) {
      return 'N/A';
    }
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).hintColor),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: valueColor),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Driver Offer Details: $_driverOfferDetails');

    final bool isRideLater = _driverOfferDetails['scheduled_time'] != null;
    final bool isCancelledOrCompleted =
        _driverOfferDetails['status'] == 'cancelled' ||
        _driverOfferDetails['status'] == 'completed';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isRideLater ? "Scheduled Ride Offer" : "Your Ride Offer",
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.grey[50],
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).primaryColor,
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isRideLater
                          ? "Your ride has been scheduled!"
                          : "Your ride offer has been created!",
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: Card(
                          color: Colors.red.withOpacity(0.08),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            side: const BorderSide(
                              color: Colors.red,
                              width: 1.0,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.left,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Offer Details",
                              style: Theme.of(
                                context,
                              ).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                            const Divider(height: 20, thickness: 1),
                            _buildDetailRow(
                              context,
                              "Status:",
                              _driverOfferDetails['status']
                                      ?.toString()
                                      .toUpperCase() ??
                                  'N/A',
                              Icons.info_outline,
                              valueColor:
                                  isCancelledOrCompleted
                                      ? Colors.red
                                      : Colors.green,
                            ),
                            _buildDetailRow(
                              context,
                              "Location:",
                              _driverOfferDetails['location'] ?? 'N/A',
                              Icons.location_on,
                            ),
                            _buildDetailRow(
                              context,
                              "Direction:",
                              _driverOfferDetails['office_direction'] == true
                                  ? 'To Office'
                                  : 'From Office',
                              _driverOfferDetails['office_direction'] == true
                                  ? Icons.arrow_circle_right
                                  : Icons.arrow_circle_left,
                            ),
                            _buildDetailRow(
                              context,
                              "Available_seats:",
                              (_driverOfferDetails['available_seats'] ?? 0)
                                  .toString(),
                              Icons.people,
                            ),
                            if (isRideLater)
                              _buildDetailRow(
                                context,
                                "Scheduled Time:",
                                _formatDateTime(
                                  _driverOfferDetails['scheduled_time']
                                      as Timestamp?,
                                ),
                                Icons.schedule,
                              ),
                            if (!isRideLater &&
                                _driverOfferDetails['created_at'] != null)
                              _buildDetailRow(
                                context,
                                "Created At:",
                                _formatDateTime(
                                  _driverOfferDetails['created_at']
                                      as Timestamp?,
                                ),
                                Icons.access_time,
                              ),
                            const SizedBox(height: 10),
                            Text(
                              "Driver Profile:",
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            // Use a FutureBuilder to handle the async data fetching
                            FutureBuilder<Map<String, dynamic>?>(
                              future: Future.value(_driverProfile),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const CircularProgressIndicator();
                                } else if (snapshot.hasError ||
                                    snapshot.data == null) {
                                  return _buildDetailRow(
                                    context,
                                    'Driver Profile:',
                                    'N/A (Details unavailable)',
                                    Icons.person_off,
                                  );
                                } else {
                                  final profile = snapshot.data!;
                                  return Column(
                                    children: [
                                      _buildDetailRow(
                                        context,
                                        "Car Model:",
                                        profile['car_model'] ?? 'N/A',
                                        Icons.directions_car,
                                      ),
                                      _buildDetailRow(
                                        context,
                                        "Plate Number:",
                                        profile['license_plate'] ?? 'N/A',
                                        Icons.tag,
                                      ),
                                      _buildDetailRow(
                                        context,
                                        "Seat Capacity:",
                                        (profile['seat_capacity'] ?? 'N/A')
                                            .toString(),
                                        Icons.event_seat,
                                      ),
                                    ],
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    if (!isCancelledOrCompleted) ...[
                      CustomButton(
                        text:
                            isRideLater
                                ? "View Scheduled Offers"
                                : "Find Companions Now!",
                        onPressed: _isLoading ? null : _matchDriver,
                        isLoading: _isLoading,
                        icon: Icons.search,
                        buttonColor: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(height: 15),
                      CustomButton(
                        text:
                            _isLoading ? "Cancelling..." : "Cancel Ride Offer",
                        onPressed: _isLoading ? null : _cancelRideOffer,
                        buttonColor: Colors.redAccent,
                        icon: Icons.cancel,
                      ),
                      const SizedBox(height: 15),
                    ],
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        elevation: 3,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_back, size: 24),
                          SizedBox(width: 8),
                          Text(
                            "Go Back",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
