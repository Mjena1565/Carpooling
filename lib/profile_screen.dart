// screens/profile_screen.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _employeeIdController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;
  String? _errorMessage;

  // Store original values to check for changes and revert
  String _originalName = '';
  String _originalPhone = '';
  String _originalEmployeeId = '';
  String _originalAddress = "";

  // New variables for daily edit limit
  int _editsToday = 0;
  final int _maxDailyEdits = 5;

  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    // databaseId: 'carpoolingv1',
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _employeeIdController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _errorMessage = "User not authenticated. Please log in.";
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        final userData = docSnapshot.data()!;

        _nameController.text = userData['name'] ?? '';
        _phoneController.text = userData['phone'] ?? '';
        _employeeIdController.text = userData['employeeId']?.toString() ?? '';
        _addressController.text = userData['address'] ?? '';

        _originalName = _nameController.text;
        _originalPhone = _phoneController.text;
        _originalEmployeeId = _employeeIdController.text;
        _originalAddress = _addressController.text;
        
        // Retrieve and check edit count
        final lastEditDate = (userData['lastEditDate'] as Timestamp?)?.toDate();
        final now = DateTime.now();

        if (lastEditDate != null && DateUtils.isSameDay(lastEditDate, now)) {
          // It's the same day, so retrieve the edit count
          _editsToday = userData['editsToday'] ?? 0;
        } else {
          // It's a new day, so reset the edit count to 0 in Firestore
          _editsToday = 0;
          await docRef.update({
            'editsToday': 0,
            'lastEditDate': FieldValue.serverTimestamp(),
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'User profile not found in database.';
          });
        }
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Firestore error: ${e.message}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateUserProfile() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _errorMessage = "User not authenticated.";
          _isSaving = false;
        });
      }
      return;
    }
    final String phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isNotEmpty && phoneNumber.length != 10) {
      if (mounted) {
        setState(() {
          _errorMessage = "Mobile Number must be exactly 10 digits.";
          _isSaving = false;
        });
      }
      return;
    }
    // Check if the user has reached the daily edit limit
    if (_editsToday >= _maxDailyEdits) {
      if (mounted) {
        setState(() {
          _errorMessage = "You have reached your daily limit of $_maxDailyEdits profile edits.";
          _isSaving = false;
        });
      }
      return;
    }

    final Map<String, dynamic> updateData = {};
    if (_nameController.text.trim() != _originalName) {
      updateData['name'] = _nameController.text.trim();
    }
    if (_phoneController.text.trim() != _originalPhone) {
      updateData['phone'] = _phoneController.text.trim();
    }
    if (_addressController.text.trim() != _originalAddress) {
      updateData['address'] = _addressController.text.trim();
    }

    if (updateData.isEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage = "No changes to save.";
          _isSaving = false;
          _isEditing = false;
        });
      }
      return;
    }

    try {
      // Increment the edit counter and update the timestamp within the same transaction
      await _firestore.runTransaction((transaction) async {
        final docSnapshot = await transaction.get(_firestore.collection('users').doc(user.uid));
        
        if (!docSnapshot.exists) {
          throw Exception("User document does not exist!");
        }
        
        final userData = docSnapshot.data()!;
        final currentEdits = userData['editsToday'] ?? 0;
        final lastEditTimestamp = (userData['lastEditDate'] as Timestamp?)?.toDate();
        final now = DateTime.now();
        
        int newEdits = currentEdits;
        
        if (lastEditTimestamp == null || !DateUtils.isSameDay(lastEditTimestamp, now)) {
          // Reset edits if it's a new day
          newEdits = 1;
        } else {
          // Increment edits for the same day
          newEdits++;
        }

        if (newEdits > _maxDailyEdits) {
          throw Exception("Daily edit limit exceeded. New edits count: $newEdits");
        }
        
        // Update the document with new data and the incremented counter
        transaction.update(
          _firestore.collection('users').doc(user.uid),
          {
            ...updateData,
            'editsToday': newEdits,
            'lastEditDate': FieldValue.serverTimestamp(),
          },
        );
      });
      
      // Update local state on success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        _originalName = _nameController.text;
        _originalPhone = _phoneController.text;
        _originalAddress = _addressController.text;
        
        setState(() {
          _editsToday++; 
          _isEditing = false;
        });
      }

    } on FirebaseException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to update profile: ${e.message}';
        });
      }
    } catch (e) {
      if (e.toString().contains("Daily edit limit exceeded")) {
        if (mounted) {
           setState(() {
            _errorMessage = "You have reached your daily limit of $_maxDailyEdits profile edits.";
           });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'An unexpected error occurred: $e';
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        _nameController.text = _originalName;
        _phoneController.text = _originalPhone;
        _employeeIdController.text = _originalEmployeeId;
        _addressController.text = _originalAddress;
        _errorMessage = null;
      }
    });
  }

  Widget _buildProfileDisplayField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool isEditing = false,
    bool isEditable = true,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final bool enabledInEditMode = isEditing && isEditable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ),
        enabledInEditMode
            ? CustomTextField(
                controller: controller,
                label: '',
                hintText: 'Enter your $label',
                enabled: true,
                keyboardType: keyboardType,
                contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
              )
            : Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  child: Row(
                    children: [
                      Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          controller.text.isEmpty ? 'N/A' : controller.text,
                          style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("User Profile", style: TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: Icon(
                _isEditing ? Icons.check_circle_outline : Icons.edit,
                color: Colors.white,
              ),
              onPressed: _isEditing ? _updateUserProfile : _toggleEditMode,
              tooltip: _isEditing ? 'Save Changes' : 'Edit Profile',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 70,
                          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                          child: Icon(
                            Icons.person,
                            size: 70,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _nameController.text.isEmpty ? "No Name Provided" : _nameController.text,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _phoneController.text.isEmpty ? "Phone Number Not Available" : _phoneController.text,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildProfileDisplayField(
                    label: "Name",
                    controller: _nameController,
                    icon: Icons.person_outline,
                    isEditing: _isEditing,
                  ),
                  _buildProfileDisplayField(
                    label: "Employee ID",
                    controller: _employeeIdController,
                    icon: Icons.badge_outlined,
                    isEditing: _isEditing,
                    isEditable: false,
                  ),
                  _buildProfileDisplayField(
                    label: "Mobile Number",
                    controller: _phoneController,
                    icon: Icons.phone,
                    isEditing: _isEditing,
                    keyboardType: TextInputType.number,
                  ),
                  _buildProfileDisplayField(
                    label: "Address",
                    controller: _addressController,
                    icon: Icons.location_on_outlined,
                    isEditing: _isEditing,
                  ),
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
                  const SizedBox(height: 20),
                  Text(
                    "You have $_editsToday out of $_maxDailyEdits edits used today.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _editsToday >= _maxDailyEdits ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_isEditing)
                    Column(
                      children: [
                        CustomButton(
                          text: "Save Changes",
                          onPressed: _isSaving ? null : _updateUserProfile,
                          isLoading: _isSaving,
                          icon: Icons.save,
                        ),
                        const SizedBox(height: 15),
                        CustomButton(
                          text: "Cancel",
                          onPressed: _isSaving ? null : _toggleEditMode,
                          buttonColor: Colors.grey.shade600,
                          icon: Icons.cancel,
                        ),
                      ],
                    )
                  else
                    CustomButton(
                      text: "Back to Home",
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: Icons.arrow_back,
                      buttonColor: Theme.of(context).primaryColor,
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}