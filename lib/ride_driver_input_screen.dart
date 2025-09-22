import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import '/location_service.dart';
import 'driver_registration_screen.dart';
import 'driver_profile_edit_screen.dart';
import 'login_page.dart';
import 'driver_offer_detail_screen.dart';
import '../driver_service.dart';
import '../widgets/my_driver_offers_tab.dart';

class RideDriverInputScreen extends StatefulWidget {
  const RideDriverInputScreen({super.key});

  @override
  State<RideDriverInputScreen> createState() => _RideDriverInputScreenState();
}

class _RideDriverInputScreenState extends State<RideDriverInputScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<MyDriverOffersTabState> _myOffersTabKey = GlobalKey();

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _companionsOccupiedController = TextEditingController(text: '0');
  bool _isOfficeDirection = true;

  bool _isLoading = false;
  String? _errorMessage;

  List<dynamic> _userDriverProfiles = [];
  String? _selectedDriverId; 

  bool _isRideLater = false;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  double? _latitude;
  double? _longitude;
  bool _isFetchingLocation = false;

  Map<String, dynamic>? _activeDriverOffer;
  late StreamSubscription _activeOfferSubscription;
  bool _initialActiveOfferCheckCompleted = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeScreen();
    _tabController.addListener(_handleTabSelection);
    _setupActiveOfferListener();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _locationController.dispose();
    _companionsOccupiedController.dispose();
    _activeOfferSubscription.cancel();
    super.dispose();
  }

  void _setupActiveOfferListener() {
    _activeOfferSubscription = driverService.getActiveDriverOfferStream().listen((snapshot) {
      if (mounted) {
        if (snapshot != null && snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>?;
          setState(() {
            _activeDriverOffer = data;
            if (_activeDriverOffer != null) {
              _activeDriverOffer!['id'] = snapshot.id;
            }
            _initialActiveOfferCheckCompleted = true;
          });
        } else {
          setState(() {
            _activeDriverOffer = null;
            _initialActiveOfferCheckCompleted = true;
          });
        }
      }
    }, onError: (error) {
      if (mounted) {
        debugPrint('Error listening to active offer: $error');
        setState(() {
          _activeDriverOffer = null;
          _initialActiveOfferCheckCompleted = true;
        });
      }
    });
  }


  void _handleTabSelection() {
    if (!_tabController.indexIsChanging && _tabController.index == 1) {
      // The stream handles automatic updates, so no extra logic is needed here
    }
  }

  void _initializeScreen() {
    _loadDriverProfiles();
  }

  void _clearForm() {
    _locationController.clear();
    _companionsOccupiedController.text = '0';
    setState(() {
      _isOfficeDirection = true;
      _selectedDate = null;
      _selectedTime = null;
      _isRideLater = false;
      _latitude = null;
      _longitude = null;
      _errorMessage = null;
    });
    _formKey.currentState?.reset();
  }

  String _getDriverLocationHint() {
    return _isOfficeDirection
        ? "E.g., Your Home Address or starting point"
        : "E.g., Office Building or final drop-off point";
  }

  String _getDriverLocationLabel() {
    return _isOfficeDirection
        ? "Your Starting Location (to Office)"
        : "Your End Location (from Office)";
  }

  String? _validateLocation(String? value) {
    if ((value == null || value.isEmpty) && (_latitude == null || _longitude == null)) {
      return 'Please enter your location or use current location.';
    }
    return null;
  }

  String? _validateCompanionsOccupied(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter the number of companions.';
    }
    final int? companions = int.tryParse(value);
    if (companions == null || companions < 0) {
      return 'Please enter a valid non-negative number.';
    }
    return null;
  }

  String? _validateRideLater() {
    if (_isRideLater) {
      if (_selectedDate == null) {
        return 'Please select a date for your ride offer.';
      }
      if (_selectedTime == null) {
        return 'Please select a time for your ride offer.';
      }
    }
    return null;
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
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
        initialTime: TimeOfDay.now(),
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
          final DateTime selectedDateTime = DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
            _selectedTime!.hour,
            _selectedTime!.minute,
          );
          if (selectedDateTime.isBefore(DateTime.now().subtract(const Duration(minutes: 1)))) {
            _selectedDate = null;
            _selectedTime = null;
            _errorMessage = "Selected time cannot be in the past. Please choose a future time.";
          } else {
            _errorMessage = null;
          }
        });
      }
    }
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() {
      _isFetchingLocation = true;
      _errorMessage = null;
    });

    final Position? position = await LocationService.getCurrentLocation(context);

    if (position != null) {
      setState(() {
        _latitude = double.parse(position.latitude.toStringAsFixed(6));
        _longitude = double.parse(position.longitude.toStringAsFixed(6));
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

    setState(() {
      _isFetchingLocation = false;
    });
    _formKey.currentState?.validate();
  }

  Future<void> _loadDriverProfiles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profiles = await driverService.getDriverProfiles();
      setState(() {
        _userDriverProfiles = profiles;
        // Check if the previously selected profile still exists
        if (_selectedDriverId != null &&
            !_userDriverProfiles.any((profile) => profile['id'] == _selectedDriverId)) {
          _selectedDriverId = null;
        }
        // Select the first profile if no profile is selected
        if (_selectedDriverId == null && _userDriverProfiles.isNotEmpty) {
          _selectedDriverId = _userDriverProfiles[0]['id'];
        } else if (_userDriverProfiles.isEmpty) {
          _selectedDriverId = null;
        }
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load driver profiles: $e';
      });
      debugPrint('Error loading profiles: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showActiveSessionDialogForOverride() {
    final currentActiveOffer = _activeDriverOffer;

    if (currentActiveOffer == null) {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Active Ride Offer Found!'),
          content: Text(
            'You currently have an active ride offer '
            '${(currentActiveOffer['is_ride_later'] as bool? ?? false) ? "scheduled for " : "created "} '
            '${_formatDateTime(currentActiveOffer['scheduled_time'] ?? currentActiveOffer['created_at'])} '
            'from ${currentActiveOffer['location']} '
            '(${(currentActiveOffer['office_direction'] as bool? ?? true) ? 'To Office' : 'From Office'}).\n\n'
            'Do you want to override it and create a new offer, or view your current active offer?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _tabController.animateTo(1);
                _myOffersTabKey.currentState?.navigateToDriverOfferDetailFromOutside(currentActiveOffer);
              },
              child: Text('No, View Active', style: TextStyle(color: Theme.of(context).primaryColor)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _proceedWithNewOfferSubmission();
              },
              child: const Text('Yes, Override'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitDriverOffer() async {
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _errorMessage = "Please fill all required fields.";
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

    if (_activeDriverOffer != null) {
      _showActiveSessionDialogForOverride();
      return;
    }

    _proceedWithNewOfferSubmission();
  }

  Future<void> _proceedWithNewOfferSubmission() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (_selectedDriverId == null) {
      setState(() {
        _errorMessage = "Please select a driver profile.";
        _isLoading = false;
      });
      return;
    }

    // Deactivate any existing active offer before creating a new one
    if (_activeDriverOffer != null) {
      await driverService.updateDriverOffer(
        _activeDriverOffer!['id'],
        {'is_current_active_offer': false},
      );
    }

    final String location = _locationController.text.trim();
    final int? companionsOccupied = int.tryParse(_companionsOccupiedController.text.trim());

    String? scheduledTime;
    String activeStatus = 'waiting';
    if (_isRideLater && _selectedDate != null && _selectedTime != null) {
      final DateTime combinedDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
      scheduledTime = combinedDateTime.toIso8601String();

      final differenceInMinutes = combinedDateTime.difference(DateTime.now()).inMinutes;
      if (differenceInMinutes <= 15 && differenceInMinutes >= -15) {
        activeStatus = 'active';
      }
    } else {
      activeStatus = 'active';
      scheduledTime = DateTime.now().toIso8601String();
    }

    final offerData = {
      'driver_id': _selectedDriverId,
      'location': location,
      'office_direction': _isOfficeDirection,
      'companions_occupied': companionsOccupied,
      'status': activeStatus,
      'scheduled_time': scheduledTime,
      'latitude': _latitude,
      'longitude': _longitude,
      'is_current_active_offer': true,
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      final newOfferData = await driverService.createDriverOffer(offerData);

      if (mounted) {
        _clearForm();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isRideLater ? "Ride offer scheduled!" : "Ride offer created!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => DriverOfferDetailScreen(
              driverInputId: newOfferData['id'],
              initialDriverOfferDetails: newOfferData,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to submit offer: $e';
      });
      debugPrint('Offer Submission Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToDriverRegistration() async {
    final bool? registered = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DriverRegistrationScreen()),
    );
    if (registered == true) {
      await _loadDriverProfiles();
    }
  }

  Future<void> _navigateToDriverEdit(String driverId) async {
    final bool? edited = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DriverProfileEditScreen(profileId: driverId)),
    );
    if (edited == true) {
      await _loadDriverProfiles();
    }
  }

  Future<void> _deleteDriverProfile(String driverId) async {
    final bool confirm = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Deletion', style: TextStyle(color: Colors.red)),
              content: const Text('Are you sure you want to delete this driver profile? This action cannot be undone.'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancel', style: TextStyle(color: Theme.of(context).primaryColor)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirm) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await driverService.deleteDriverProfile(driverId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver profile deleted successfully!')),
        );
        await _loadDriverProfiles();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to delete driver profile: $e';
      });
      debugPrint('Driver Profile Delete Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDateTime(dynamic isoDateTime) {
    if (isoDateTime == null) return 'N/A';
    if (isoDateTime is Timestamp) {
      return DateFormat('dd MMM yyyy, hh:mm a').format(isoDateTime.toDate().toLocal());
    }
    if (isoDateTime is String) {
      try {
        final DateTime dateTime = DateTime.parse(isoDateTime).toLocal();
        return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
      } catch (e) {
        debugPrint("Error parsing date: $e");
        return isoDateTime;
      }
    }
    return 'N/A';
  }

  void _onOfferActionCompleted() {
    _clearForm();
    _tabController.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final bool showOverallLoading = _isLoading && _userDriverProfiles.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Offer a Ride", style: TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: "New Ride Offer", icon: Icon(Icons.add_circle_outline)),
            Tab(text: "My Active Offers", icon: Icon(Icons.directions_car_filled)),
          ],
        ),
      ),
      backgroundColor: Colors.grey[50],
      body: showOverallLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Theme.of(context).primaryColor),
                  const SizedBox(height: 16),
                  const Text("Loading driver profiles..."),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildNewOfferTab(),
                MyDriverOffersTab(
                  key: _myOffersTabKey,
                  onOfferCancelledOrCompleted: _onOfferActionCompleted,
                  initialCheckCompleted: _initialActiveOfferCheckCompleted,
                ),
              ],
            ),
    );
  }

  Widget _buildNewOfferTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Offer a ride to your colleagues!",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              "Help others commute and share the journey.",
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
            if (_userDriverProfiles.isEmpty && !_isLoading)
              _buildNoDriverProfileMessage()
            else
              _buildOfferRideFormContent(),
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
    );
  }

  Widget _buildNoDriverProfileMessage() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        children: [
          Icon(Icons.directions_car_filled, size: 80, color: Theme.of(context).primaryColor.withOpacity(0.6)),
          const SizedBox(height: 20),
          Text(
            "Looks like you haven't registered as a driver yet!",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            "To offer rides, please create your driver profile first.",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          CustomButton(
            text: "Register as Driver",
            onPressed: _isLoading ? null : _navigateToDriverRegistration,
            icon: Icons.app_registration,
          ),
        ],
      ),
    );
  }

  Widget _buildOfferRideFormContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Your Driver Profiles:",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedDriverId,
                decoration: InputDecoration(
                  labelText: 'Select Driver Profile',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                ),
                items: _userDriverProfiles.map<DropdownMenuItem<String>>((profile) {
                  return DropdownMenuItem<String>(
                    value: profile['id'],
                    child: Text(
                      '${(profile['car_model'] as String).length > 8 ? '${(profile['car_model'] as String).substring(0, 8)}...' : profile['car_model']} - ${profile['seat_capacity']} seats',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: _isLoading
                    ? null
                    : (String? newValue) {
                        setState(() {
                          _selectedDriverId = newValue;
                        });
                      },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a driver profile.';
                  }
                  return null;
                },
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit, color: Theme.of(context).primaryColor),
              onPressed: (_selectedDriverId != null && !_isLoading)
                  ? () => _navigateToDriverEdit(_selectedDriverId!)
                  : null,
              tooltip: 'Edit selected profile',
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever),
              onPressed: (_selectedDriverId != null && !_isLoading)
                  ? () => _deleteDriverProfile(_selectedDriverId!)
                  : null,
              tooltip: 'Delete selected profile',
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_userDriverProfiles.length < 3)
          CustomButton(
            text: "Add New Profile",
            onPressed: _isLoading ? null : _navigateToDriverRegistration,
            icon: Icons.add,
          ),
        const SizedBox(height: 20),
        CustomTextField(
          controller: _locationController,
          label: _getDriverLocationLabel(),
          hintText: _getDriverLocationHint(),
          prefixIcon: const Icon(Icons.location_on),
          validator: _validateLocation,
          readOnly: _isFetchingLocation,
          keyboardType: TextInputType.streetAddress,
          suffixIcon: _isFetchingLocation
              ? const CircularProgressIndicator(strokeWidth: 2)
              : IconButton(
                  icon: const Icon(Icons.my_location),
                  onPressed: _fetchCurrentLocation,
                  tooltip: 'Use current location',
                ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: RadioListTile<bool>(
                title: const Text("To Office"),
                value: true,
                groupValue: _isOfficeDirection,
                onChanged: _isLoading
                    ? null
                    : (bool? value) {
                        setState(() {
                          _isOfficeDirection = value!;
                          _locationController.clear();
                          _latitude = null;
                          _longitude = null;
                        });
                        _formKey.currentState?.validate();
                      },
              ),
            ),
            Expanded(
              child: RadioListTile<bool>(
                title: const Text("From Office"),
                value: false,
                groupValue: _isOfficeDirection,
                onChanged: _isLoading
                    ? null
                    : (bool? value) {
                        setState(() {
                          _isOfficeDirection = value!;
                          _locationController.clear();
                          _latitude = null;
                          _longitude = null;
                        });
                        _formKey.currentState?.validate();
                      },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        CustomTextField(
          controller: _companionsOccupiedController,
          label: 'Companions Occupied',
          hintText: 'E.g., 2',
          prefixIcon: const Icon(Icons.people),
          validator: _validateCompanionsOccupied,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Ride Later?", style: TextStyle(fontSize: 16)),
            Switch(
              value: _isRideLater,
              onChanged: _isLoading
                  ? null
                  : (bool value) {
                      setState(() {
                        _isRideLater = value;
                        if (!value) {
                          _selectedDate = null;
                          _selectedTime = null;
                          _errorMessage = null;
                        }
                      });
                    },
            ),
          ],
        ),
        if (_isRideLater)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: CustomButton(
              text: _selectedDate == null && _selectedTime == null
                  ? "Select Date and Time"
                  : DateFormat('dd MMM yyyy, hh:mm a')
                      .format(DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _selectedTime!.hour, _selectedTime!.minute)),
              onPressed: _isLoading ? null : () => _pickDateTime(context),
              icon: Icons.calendar_today,
            ),
          ),
        const SizedBox(height: 20),
        CustomButton(
          text: _isLoading ? "Submitting..." : (_activeDriverOffer != null ? "Override Active Offer" : "Offer Ride"),
          onPressed: _isLoading ? null : _submitDriverOffer,
          icon: Icons.directions_car_filled,
        ),
      ],
    );
  }
}
