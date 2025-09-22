import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import '../driver_service.dart';

class DriverProfileEditScreen extends StatefulWidget {
  final String profileId;

  const DriverProfileEditScreen({super.key, required this.profileId});

  @override
  State<DriverProfileEditScreen> createState() => _DriverProfileEditScreenState();
}

class _DriverProfileEditScreenState extends State<DriverProfileEditScreen> {
  final TextEditingController _carModelController = TextEditingController();
  final TextEditingController _licensePlateController = TextEditingController();
  final TextEditingController _seatCapacityController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDriverProfile();
  }

  @override
  void dispose() {
    _carModelController.dispose();
    _licensePlateController.dispose();
    _seatCapacityController.dispose();
    super.dispose();
  }

  Future<void> _fetchDriverProfile() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final docSnapshot = await driverService.getDriverProfileById(widget.profileId);
      if (!mounted) return;
      if (docSnapshot.exists) {
        final profileData = docSnapshot.data() as Map<String, dynamic>;
        _carModelController.text = profileData['car_model'] ?? '';
        _licensePlateController.text = profileData['license_plate'] ?? '';
        _seatCapacityController.text = profileData['seat_capacity']?.toString() ?? '1';
      } else {
        setState(() {
          _errorMessage = 'Driver profile not found.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load profile. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateDriverProfile() async {
    if (!mounted) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final String carModel = _carModelController.text.trim();
    final String licensePlate = _licensePlateController.text.trim();
    final int? seatCapacity = int.tryParse(_seatCapacityController.text.trim());

    if (carModel.isEmpty || licensePlate.isEmpty || seatCapacity == null || seatCapacity <= 0) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "All fields are required and capacity must be positive.";
        _isSaving = false;
      });
      return;
    }

    try {
      await driverService.updateDriverProfile(widget.profileId, {
        'car_model': carModel,
        'license_plate': licensePlate,
        'seat_capacity': seatCapacity,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop(true);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to update profile: ${e.message}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An unexpected error occurred: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Driver Profile"),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 30),
                  CustomTextField(
                    controller: _carModelController,
                    label: "Car Model",
                    hintText: "E.g., Toyota Camry",
                    prefixIcon: Icon(Icons.directions_car),
                  ),
                  const SizedBox(height: 20),
                  CustomTextField(
                    controller: _licensePlateController,
                    label: "License Plate",
                    hintText: "E.g., ABC-1234",
                    prefixIcon: Icon(Icons.tag),
                  ),
                  const SizedBox(height: 20),
                  CustomTextField(
                    controller: _seatCapacityController,
                    label: "Seat Capacity",
                    hintText: "Number of available seats (excluding driver)",
                    keyboardType: TextInputType.number,
                    prefixIcon: Icon(Icons.event_seat),
                  ),
                  const SizedBox(height: 30),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: Colors.red),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 20),
                            const SizedBox(width: 10),
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
                  CustomButton(
                    text: "Save Changes",
                    onPressed: _isSaving ? null : _updateDriverProfile,
                    isLoading: _isSaving,
                    icon: Icons.save,
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context, false);
                    },
                    child: Text(
                      "Cancel",
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}