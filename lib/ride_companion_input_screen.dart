// File: lib/ride_companion_input_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_service.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import '../location_service.dart';
import './login_page.dart';
import '../widgets/my_companion_requests_tab.dart';

class RideCompanionInputScreen extends StatefulWidget {
  const RideCompanionInputScreen({super.key});

  @override
  State<RideCompanionInputScreen> createState() => _RideCompanionInputScreenState();
}

class _RideCompanionInputScreenState extends State<RideCompanionInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _locationController = TextEditingController();
  bool _isOfficeDirection = true;
  bool _isLoading = false;
  String? _errorMessage;

  bool _isRideLater = false;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  double? _latitude;
  double? _longitude;
  bool _isFetchingLocation = false;

  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final GlobalKey<MyCompanionRequestsTabState> _myRequestsTabKey = GlobalKey();
  final ValueNotifier<bool> _isDateTimePickedNotifier = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _locationController.dispose();
    _isDateTimePickedNotifier.dispose();
    super.dispose();
  }

  String _getCompanionLocationHint() {
    return _isOfficeDirection
        ? "E.g., Your Home Address or current location"
        : "E.g., Office Building, Tech Park";
  }

  String _getCompanionLocationLabel() {
    return _isOfficeDirection
        ? "Your Pickup Location"
        : "Your Drop-off Location (from Office)";
  }

  String? _validateLocation(String? value) {
    if ((value == null || value.isEmpty) && (_latitude == null || _longitude == null)) {
      return 'Please enter your location or use current location.';
    }
    if (_latitude == null && _longitude == null && (value == null || value.trim().isEmpty)) {
      return 'Location cannot be empty.';
    }
    return null;
  }

  String? _validateRideLater() {
    if (_isRideLater) {
      if (_selectedDate == null) {
        return 'Please select a date for your ride.';
      }
      if (_selectedTime == null) {
        return 'Please select a time for your ride.';
      }
      final DateTime selectedDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
      if (selectedDateTime.isBefore(DateTime.now().subtract(const Duration(minutes: 1)))) {
        return "Selected time cannot be in the past. Please choose a future time.";
      }
    }
    return null;
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: _selectedTime ?? TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: ThemeData.light().copyWith(
              colorScheme: ColorScheme.light(
                primary: Theme.of(context).primaryColor,
                onPrimary: Colors.white,
                onSurface: Colors.black,
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).primaryColor,
                ),
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDate = pickedDate;
          _selectedTime = pickedTime;
          _errorMessage = null;
        });
        _isDateTimePickedNotifier.value = true;
      }
    }
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() {
      _isFetchingLocation = true;
      _errorMessage = null;
    });

    try {
      final Position? position = await LocationService.getCurrentLocation(context);
      if (position != null) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _locationController.text = "Current Location (Lat: ${_latitude!.toStringAsFixed(4)}, Lon: ${_longitude!.toStringAsFixed(4)})";
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Current location fetched successfully!')),
          );
        });
      } else {
        setState(() {
          _latitude = null;
          _longitude = null;
          _locationController.clear();
          _errorMessage = 'Failed to get current location. Please enter manually.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isFetchingLocation = false;
      });
      _formKey.currentState?.validate();
    }
  }

  Future<void> _submitCompanionRequest() async {
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _errorMessage = "Please fill all required fields correctly.";
      });
      return;
    }

    String? rideLaterError = _validateRideLater();
    if (rideLaterError != null) {
      setState(() {
        _errorMessage = rideLaterError;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Authentication error: Please log in again.")),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginAuthScreen()),
        );
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Check for an active request before submitting
    final activeRequests = await _firestoreService.getLiveCompanionRequests(user.uid);
    if (activeRequests.isNotEmpty) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Request in Progress'),
            content: const Text(
                'You already have an active ride request. Please cancel it from the "My Requests" tab before creating a new one.'),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    String? scheduledTime;
    String activeStatus = 'waiting'; // Default status for 'ride later'
    
    // Logic to determine the status and scheduled time before submission
    if (_isRideLater && _selectedDate != null && _selectedTime != null) {
      final DateTime combinedDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
      scheduledTime = combinedDateTime.toIso8601String();

      // Check if the scheduled time is within 15 minutes of now
      final differenceInMinutes = combinedDateTime.difference(DateTime.now()).inMinutes;
      if (differenceInMinutes <= 15 && differenceInMinutes >= -15) {
        activeStatus = 'active';
      }
    } else {
      activeStatus = 'active';
      scheduledTime = DateTime.now().toIso8601String();
    }

    try {
      await _firestoreService.addCompanionRequest(
        userId: user.uid,
        location: _locationController.text.trim(),
        isOfficeDirection: _isOfficeDirection,
        isRideLater: _isRideLater,
        scheduledTime: scheduledTime,
        latitude: _latitude,
        longitude: _longitude,
        activeStatus: activeStatus,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isRideLater ? 'Ride request scheduled!' : 'Live ride request submitted!')),
        );
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Request Submitted'),
            content: Text(
              _isRideLater
                  ? 'Your ride request has been scheduled successfully!'
                  : 'Your live ride request has been submitted successfully!',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to submit request: $e';
        });
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Companion Dashboard", style: TextStyle(color: Colors.white)),
          backgroundColor: Theme.of(context).primaryColor,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: const [
              Tab(icon: Icon(Icons.add_location_alt), text: "Request Ride"),
              Tab(icon: Icon(Icons.list_alt), text: "My Requests"),
            ],
          ),
        ),
        backgroundColor: Colors.grey[50],
        body: TabBarView(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Need a ride?",
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Tell us where you are and where you're headed.",
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    CustomTextField(
                      controller: _locationController,
                      label: _getCompanionLocationLabel(),
                      hintText: _getCompanionLocationHint(),
                      validator: _validateLocation,
                      enabled: !_isFetchingLocation,
                      onChanged: (value) {
                        if (_latitude != null && _longitude != null && !value.startsWith("Current Location")) {
                          setState(() {
                            _latitude = null;
                            _longitude = null;
                            _formKey.currentState?.validate();
                          });
                        }
                      },
                      prefixIcon: Icon(Icons.location_on, color: Theme.of(context).primaryColor),
                      suffixIcon: _isFetchingLocation
                          ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).primaryColor,
                        ),
                      )
                          : IconButton(
                        icon: Icon(Icons.my_location, color: Theme.of(context).primaryColor),
                        onPressed: _fetchCurrentLocation,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Direction:",
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<bool>(
                                title: const Text('To Office'),
                                value: true,
                                groupValue: _isOfficeDirection,
                                onChanged: (bool? value) {
                                  setState(() {
                                    _isOfficeDirection = value!;
                                    _locationController.clear();
                                    _latitude = null;
                                    _longitude = null;
                                  });
                                },
                                activeColor: Theme.of(context).primaryColor,
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<bool>(
                                title: const Text('From Office'),
                                value: false,
                                groupValue: _isOfficeDirection,
                                onChanged: (bool? value) {
                                  setState(() {
                                    _isOfficeDirection = value!;
                                    _locationController.clear();
                                    _latitude = null;
                                    _longitude = null;
                                  });
                                },
                                activeColor: Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    SwitchListTile(
                      title: Text(
                        "Schedule for later",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      value: _isRideLater,
                      onChanged: (bool value) {
                        setState(() {
                          _isRideLater = value;
                          if (!value) {
                            _selectedDate = null;
                            _selectedTime = null;
                            _errorMessage = null;
                            _formKey.currentState?.validate();
                          }
                        });
                      },
                      activeColor: Theme.of(context).primaryColor,
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_isRideLater) ...[
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: () => _pickDateTime(context),
                        child: AbsorbPointer(
                          child: CustomTextField(
                            controller: TextEditingController(
                              text: _selectedDate == null || _selectedTime == null
                                  ? ''
                                  : '${DateFormat('dd MMM yyyy').format(_selectedDate!)} at ${_selectedTime!.format(context)}',
                            ),
                            label: "Scheduled Time",
                            hintText: "Tap to select date and time",
                            suffixIcon: Icon(Icons.calendar_today, color: Theme.of(context).primaryColor),
                            validator: (value) => _validateRideLater(),
                          ),
                        ),
                      ),
                    ],
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
                    CustomButton(
                      text: _isRideLater ? "Schedule Ride" : "Request Ride Now",
                      onPressed: _isLoading ? null : _submitCompanionRequest,
                      isLoading: _isLoading,
                      icon: _isRideLater ? Icons.schedule : Icons.drive_eta,
                    ),
                    const SizedBox(height: 20),
                    CustomButton(
                      text: "Cancel",
                      onPressed: () => Navigator.pop(context),
                      buttonColor: Colors.grey[400],
                      icon: Icons.cancel_outlined,
                    ),
                  ],
                ),
              ),
            ),
            MyCompanionRequestsTab(key: _myRequestsTabKey),
          ],
        ),
      ),
    );
  }
}