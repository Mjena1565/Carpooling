import 'package:flutter/material.dart';

import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import 'login_page.dart'; // Import the login screen
import '../driver_service.dart';

class DriverRegistrationScreen extends StatefulWidget {
  const DriverRegistrationScreen({super.key});

  @override
  State<DriverRegistrationScreen> createState() => _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState extends State<DriverRegistrationScreen> {
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _carModelController = TextEditingController();
  final TextEditingController _licensePlateController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _capacityController.dispose();
    _carModelController.dispose();
    _licensePlateController.dispose();
    super.dispose();
  }

  Future<void> _registerDriver() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final int? capacity = int.tryParse(_capacityController.text.trim());
    final String carModel = _carModelController.text.trim();
    final String licensePlate = _licensePlateController.text.trim();

    if (capacity == null || capacity <= 0) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Please enter a valid car capacity (a positive number).";
        _isLoading = false;
      });
      return;
    }
    if (carModel.isEmpty) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Car model is required.";
        _isLoading = false;
      });
      return;
    }
    if (licensePlate.isEmpty) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "License plate is required.";
        _isLoading = false;
      });
      return;
    }

    final Map<String, dynamic> driverProfileData = {
      'seat_capacity': capacity,
      'car_model': carModel,
      'license_plate': licensePlate,
    };

    try {
      await driverService.createDriverProfile(driverProfileData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver profile created successfully!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An unexpected error occurred: $e';
        _isLoading = false;
      });
    }
  }

  void _handleAuthError() {
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginAuthScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Register as Driver"),
        backgroundColor: Theme.of(context).primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Become a Driver",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              "Enter your car details and capacity to start offering rides.",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            CustomTextField(
              controller: _carModelController,
              label: "Car Model",
              hintText: "E.g., Honda Civic",
            ),
            const SizedBox(height: 20),
            CustomTextField(
              controller: _licensePlateController,
              label: "License Plate",
              hintText: "E.g., KA01AB1234",
            ),
            const SizedBox(height: 20),
            CustomTextField(
              controller: _capacityController,
              label: "Car Capacity (Available Seats)",
              hintText: "E.g., 3 (for 3 passengers)",
              keyboardType: TextInputType.number,
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
              text: "Register as Driver",
              onPressed: _isLoading ? null : _registerDriver,
              isLoading: _isLoading,
              icon: Icons.app_registration,
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text("Cancel"),
            ),
          ],
        ),
      ),
    );
  }
}
