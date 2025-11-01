// signup_screen.dart
import 'package:firebasetestapp/login_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import 'email_verification_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _employeeIdController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _employeeIdController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<bool> _isEmployeeIdUnique(String employeeId) async {
    try {
      final namedDb = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: '(default)',
      );
      final querySnapshot =
          await namedDb
              .collection('users')
              .where('employeeId', isEqualTo: employeeId)
              .limit(1)
              .get();
      return querySnapshot.docs.isEmpty;
    } catch (e) {
      print('Error checking employee ID uniqueness: $e');
      return false;
    }
  }

  Future<void> _signup() async {
    print('--- _signup function called ---');

    if (!_formKey.currentState!.validate()) {
      setState(() {
        _errorMessage = "Please correct the errors in the form.";
        _isLoading = false;
      });
      print('--- Form validation failed ---');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final String employeeId = _employeeIdController.text.trim();

    // Check for employee ID uniqueness BEFORE creating the user
    final isUnique = await _isEmployeeIdUnique(employeeId);
    if (!isUnique) {
      setState(() {
        _errorMessage =
            'The Employee ID is already in use. Please use a different one.';
        _isLoading = false;
      });
      return;
    }
    try {
      print('--- Attempting to create user with email: $email ---');
      // 1. Create the user in Firebase Authentication
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      print(
        '--- User created successfully! UID: ${userCredential.user?.uid} ---',
      );

      final user = userCredential.user;
      if (user != null) {
        // 2. Save the additional user data to Firestore
        var namedDb = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseId: '(default)',
        );
        print(
          '--- Saving additional user data to Firestore for UID: ${user.uid} ---',
        );
        await namedDb.collection('users').doc(user.uid).set({
          'name': _nameController.text.trim(),
          'email': email,
          'employeeId': _employeeIdController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('--- User data saved to Firestore successfully ---');

        await user.sendEmailVerification();
        print('--- Verification email sent ---');
      }

      if (!mounted) return;
      //  for now no navigation to emailVerifciationScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const EmailVerificationScreen(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'The email address is already in use by another account.';
          break;
        case 'weak-password':
          message =
              'The password provided is too weak. Please choose a stronger one.';
          break;
        case 'invalid-email':
          message = 'The email address is not valid.';
          break;
        default:
          message =
              'An unknown authentication error occurred. Please try again.';
      }
      setState(() {
        _errorMessage = message;
      });
      print('--- FirebaseAuthException: ${e.code} - ${e.message} ---');
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: $e';
      });
      print('--- Caught generic exception: $e ---');
    } finally {
      setState(() {
        _isLoading = false;
      });
      print('--- Signup process finished ---');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sign Up", style: TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                "Create Your Account",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Join us and manage your employee data seamlessly.",
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 40),
              CustomTextField(
                controller: _nameController,
                label: "Full Name",
                hintText: "Enter your full name",
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Name is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              CustomTextField(
                controller: _employeeIdController,
                label: "Employee ID",
                keyboardType: TextInputType.number,
                hintText: "Your unique employee ID (numbers only)",
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Employee ID is required.';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Employee ID must be a number.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              CustomTextField(
                controller: _emailController,
                label: "Email Address",
                keyboardType: TextInputType.emailAddress,
                hintText: "example@company.com",
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Email is required.';
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return 'Please enter a valid email address.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              CustomTextField(
                controller: _phoneController,
                label: "Phone Number",
                keyboardType: TextInputType.phone,
                hintText: "e.g., 9876543210 (10 digits)",
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Phone number is required.';
                  }
                  if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                    return 'Please enter a valid 10-digit phone number.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              CustomTextField(
                controller: _addressController,
                label: "Residential Address",
                hintText: "Your current residential address",
                maxLines: 3,
                keyboardType: TextInputType.streetAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Address is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              CustomTextField(
                controller: _passwordController,
                label: "Your Password",
                obscureText: !_isPasswordVisible,
                hintText: "Minimum 8 characters",
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password is required.';
                  }
                  if (value.length < 8) {
                    return 'Password must be at least 8 characters long.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              CustomTextField(
                controller: _confirmPasswordController,
                label: "Confirm Your Password",
                obscureText: !_isConfirmPasswordVisible,
                hintText: "Re-enter your password",
                suffixIcon: IconButton(
                  icon: Icon(
                    _isConfirmPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                    });
                  },
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Confirm Password is required.';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
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
              CustomButton(
                text: "Sign Up",
                onPressed: _isLoading ? null : _signup,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Already have an account?",
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text(
                      "Login",
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
