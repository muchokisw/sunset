import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../theme_notifier.dart'; // Import ThemeNotifier

class EditProfilePage extends StatefulWidget {
  final String name;
  final String phone;
  final String address;
  final String? photoUrl;
  final String? country;
  final String? city;
  final DateTime? dateOfBirth;

  const EditProfilePage({
    super.key,
    required this.name,
    required this.phone,
    required this.address,
    this.photoUrl,
    this.country,
    this.city,
    this.dateOfBirth,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _phone;
  late String _deliveryAddress; // Corrected variable name
  late String _country;
  late String _city;
  DateTime? _dateOfBirth;
  int? _age;
  Uint8List? _photoBytes;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _name = widget.name;
    _phone = widget.phone;
    _deliveryAddress = widget.address; // Use the correct field for deliveryAddress
    _photoUrl = widget.photoUrl;
    _country = widget.country ?? '';
    _city = widget.city ?? '';
    _dateOfBirth = widget.dateOfBirth;
    _age = _dateOfBirth != null ? _calculateAge(_dateOfBirth!) : null;
  }

  int _calculateAge(DateTime dateOfBirth) {
    final today = DateTime.now();
    int age = today.year - dateOfBirth.year;
    if (today.month < dateOfBirth.month ||
        (today.month == dateOfBirth.month && today.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _photoBytes = result.files.single.bytes;
      });
    }
  }

  Future<void> _removePhoto() async {
    setState(() {
      _photoBytes = null;
      _photoUrl = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'photo': FieldValue.delete(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo removed successfully!')),
      );
    }
  }

  Future<String> _uploadToFirebaseStorage(Uint8List fileBytes, String path) async {
    final storageRef = FirebaseStorage.instance.ref().child(path);
    final uploadTask = storageRef.putData(fileBytes);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      try {
        String? photoUrl = _photoUrl;

        // Upload new photo if selected
        if (_photoBytes != null) {
          photoUrl = await _uploadToFirebaseStorage(_photoBytes!, 'users/profile_photo.png');
        }

        // Calculate age if dateOfBirth is provided
        if (_dateOfBirth != null) {
          _age = _calculateAge(_dateOfBirth!);
        }

        // Update user details in Firestore
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'name': _name,
            'phone': _phone,
            'deliveryAddress': _deliveryAddress, // Save deliveryAddress correctly
            'photo': photoUrl,
            'country': _country,
            'city': _city,
            'dateOfBirth': _dateOfBirth?.toIso8601String(),
            'age': _age,
          });

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );

          Navigator.pop(context); // Go back to the previous page
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _pickDateOfBirth() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (selectedDate != null) {
      setState(() {
        _dateOfBirth = selectedDate;
        _age = _calculateAge(selectedDate); // Update age when dateOfBirth is selected
      });
    }
  }

  Widget _buildLabeledInputField({
    required String label,
    TextEditingController? controller,
    required FormFieldValidator<String> validator,
    FormFieldSetter<String>? onSaved,
    bool obscureText = false,
    Widget? suffixIcon,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    final hintTextColor = Theme.of(context).brightness == Brightness.light
        ? Colors.grey[600]
        : Colors.grey[600];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // Align label to the left
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0), // Add space to align with field text
          child: Text(
            '$label:', // Add colon after the label
            style: const TextStyle(
              fontSize: 16, // Set font size to 16
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.grey[200]
                : Colors.black,
            borderRadius: BorderRadius.circular(24.0),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            maxLines: maxLines,
            readOnly: readOnly,
            decoration: InputDecoration(
              hintText: null,
              hintStyle: TextStyle(color: hintTextColor),
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              suffixIcon: suffixIcon,
            ),
            onSaved: onSaved,
            validator: validator,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          IconButton(
            icon: Icon(
              ThemeNotifier.themeMode.value == ThemeMode.light
                  ? Icons.dark_mode
                  : Icons.light_mode,
            ),
            onPressed: () {
              ThemeNotifier.toggleTheme(); // Toggle the theme
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 600, // Limit the width to 600 pixels
                ),
                child: Card(
                  elevation: 4,
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Center(
                              child: Text(
                                'Edit Profile Details',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Profile photo section
                            Center(
                              child: GestureDetector(
                                onTap: () {
                                  if (_photoBytes != null || _photoUrl != null) {
                                    showDialog(
                                      context: context,
                                      builder: (context) {
                                        return Dialog(
                                          insetPadding: const EdgeInsets.all(16),
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 600,
                                              maxHeight: 400,
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: _photoBytes != null
                                                  ? Image.memory(
                                                      _photoBytes!,
                                                      fit: BoxFit.contain,
                                                    )
                                                  : (_photoUrl != null
                                                      ? Image.network(
                                                          _photoUrl!,
                                                          fit: BoxFit.contain,
                                                        )
                                                      : const Icon(
                                                          Icons.person,
                                                          size: 100,
                                                          color: Colors.grey,
                                                        )),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  }
                                },
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.grey[300],
                                  backgroundImage: _photoBytes != null
                                      ? MemoryImage(_photoBytes!)
                                      : (_photoUrl != null
                                          ? NetworkImage(_photoUrl!) as ImageProvider
                                          : null),
                                  child: _photoBytes == null && _photoUrl == null
                                      ? const Icon(Icons.person, size: 50, color: Colors.grey)
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  TextButton(
                                    onPressed: _pickPhoto,
                                    child: const Text('Change Photo'),
                                  ),
                                  const SizedBox(width: 16),
                                  TextButton(
                                    onPressed: _removePhoto,
                                    child: const Text('Remove Photo'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildLabeledInputField(
                              label: 'Name',
                              controller: TextEditingController(text: _name),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your name.';
                                }
                                return null;
                              },
                              onSaved: (value) {
                                _name = value!;
                              },
                            ),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: _pickDateOfBirth,
                              child: AbsorbPointer(
                                child: _buildLabeledInputField(
                                  label: 'Date of Birth',
                                  controller: TextEditingController(
                                    text: _dateOfBirth != null
                                        ? _dateOfBirth!.toLocal().toString().split(' ')[0]
                                        : '',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select your date of birth.';
                                    }
                                    return null;
                                  },
                                  onSaved: (value) {},
                                  readOnly: true, // Make the field read-only for Date of Birth
                                  suffixIcon: const Icon(Icons.calendar_today, color: Colors.grey),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildLabeledInputField(
                              label: 'Phone',
                              controller: TextEditingController(text: _phone),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your phone number.';
                                }
                                return null;
                              },
                              onSaved: (value) {
                                _phone = value!;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildLabeledInputField(
                              label: 'Country',
                              controller: TextEditingController(text: _country),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your country.';
                                }
                                return null;
                              },
                              onSaved: (value) {
                                _country = value!;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildLabeledInputField(
                              label: 'City',
                              controller: TextEditingController(text: _city),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your city.';
                                }
                                return null;
                              },
                              onSaved: (value) {
                                _city = value!;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildLabeledInputField(
                              label: 'Delivery Address',
                              controller: TextEditingController(text: _deliveryAddress),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your delivery address.';
                                }
                                return null;
                              },
                              onSaved: (value) {
                                _deliveryAddress = value!;
                              },
                              maxLines: 3, // Make the field three times as tall
                            ),
                            const SizedBox(height: 24),
                            Center(
                              child: ElevatedButton(
                                onPressed: _saveProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey,
                                  foregroundColor: Colors.black,
                                ),
                                child: const Text('Save'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: _changePassword,
              child: const Text('Change Password'),
            ),
          ),
        ],
      ),
    );
  }
}