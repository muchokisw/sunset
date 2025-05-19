import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../theme_notifier.dart'; // Import ThemeNotifier
import '../home/user_home.dart'; // Import user home
import 'sign_in.dart'; // Import sign-in page
import 'dart:html' as html; // For setting the document title

class NormalSignup extends StatefulWidget {
  const NormalSignup({super.key});

  @override
  State<NormalSignup> createState() => _NormalSignupState();
}

class _NormalSignupState extends State<NormalSignup> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  String _email = '';
  String _name = '';
  String _phone = '';
  String _deliveryAddress = '';
  String _city = '';
  String _country = '';
  DateTime? _dateOfBirth;
  int _age = 0;

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  Future<void> _signup() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match!')),
        );
        return;
      }

      try {
        // Create user with email and password
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: _email,
          password: _passwordController.text,
        );

        // Generate userId
        final userId = userCredential.user!.uid;

        // Save user details in Firestore
        await _firestore.collection('users').doc(userId).set({
          'userId': userId,
          'email': _email,
          'name': _name,
          'phone': _phone,
          'deliveryAddress': _deliveryAddress,
          'city': _city,
          'country': _country,
          'dateOfBirth': _dateOfBirth?.toIso8601String(),
          'age': _age,
          'role': 'buyer', // Default role is buyer
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign-up successful!')),
        );

        // Navigate to the user home page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const UserHome()),
        );
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message}')),
        );
      }
    }
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)), // Default to 18 years ago
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _dateOfBirth) {
      setState(() {
        _dateOfBirth = picked;
        _age = DateTime.now().year - picked.year;
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Always set the title on every build
    html.document.title = 'Sunset Marketplace';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
        centerTitle: false, // Align title to the left
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
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              elevation: 4,
              margin: const EdgeInsets.all(16.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      const Text(
                        'Create an Account',
                        style: TextStyle(fontSize: 24),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      // Name field
                      _buildInputField(
                        hintText: 'Name',
                        onSaved: (value) => _name = value!,
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Please enter your name.' : null,
                      ),
                      const SizedBox(height: 16),
                      // Date of Birth field
                      GestureDetector(
                        onTap: _selectDateOfBirth, // Trigger the date picker
                        child: AbsorbPointer( // Prevent manual input
                          child: _buildInputField(
                            hintText: _dateOfBirth == null
                                ? 'Date of Birth'
                                : DateFormat.yMMMd().format(_dateOfBirth!),
                            validator: (value) => null, // No validation needed for date
                            onSaved: (value) {}, // No saving needed for date
                            controller: TextEditingController(
                              text: _dateOfBirth == null
                                  ? ''
                                  : DateFormat.yMMMd().format(_dateOfBirth!),
                            ), // Display the selected date as text
                            obscureText: false,
                            suffixIcon: const Icon(Icons.calendar_today, color: Colors.grey),
                            readOnly: true, // Make the field read-only for Date of Birth
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Email field
                      _buildInputField(
                        hintText: 'Email',
                        onSaved: (value) => _email = value!,
                        validator: (value) =>
                            value == null || !value.contains('@') ? 'Please enter a valid email.' : null,
                      ),
                      const SizedBox(height: 16),
                      // Phone field
                      _buildInputField(
                        hintText: 'Phone',
                        onSaved: (value) => _phone = value!,
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Please enter your phone number.' : null,
                      ),
                      const SizedBox(height: 16),
                      // Password field
                      _buildInputField(
                        controller: _passwordController,
                        hintText: 'Password',
                        obscureText: !_isPasswordVisible,
                        validator: (value) =>
                            value == null || value.length < 6 ? 'Password must be at least 6 characters.' : null,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                            color: Theme.of(context).brightness == Brightness.light
                                ? Colors.grey
                                : Colors.grey[600],
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Confirm Password field
                      _buildInputField(
                        controller: _confirmPasswordController,
                        hintText: 'Confirm Password',
                        obscureText: !_isConfirmPasswordVisible,
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Please confirm your password.' : null,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                            color: Theme.of(context).brightness == Brightness.light
                                ? Colors.grey
                                : Colors.grey[600],
                          ),
                          onPressed: () {
                            setState(() {
                              _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Country field
                      _buildInputField(
                        hintText: 'Country',
                        onSaved: (value) => _country = value!,
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Please enter your country.' : null,
                      ),
                      const SizedBox(height: 16),
                      // City field
                      _buildInputField(
                        hintText: 'City',
                        onSaved: (value) => _city = value!,
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Please enter your city.' : null,
                      ),
                      const SizedBox(height: 16),
                      // Delivery Address field
                      _buildInputField(
                        hintText: 'Delivery Address',
                        onSaved: (value) => _deliveryAddress = value!,
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Please enter your delivery address.' : null,
                        maxLines: 2, // Make the field twice as tall
                      ),
                      const SizedBox(height: 24),
                      // Submit button
                      Center(
                        child: ElevatedButton(
                          onPressed: _signup,
                          child: const Text('Sign Up'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Sign in link
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const SignIn()),
                          );
                        },
                        child: const Text('Already have an account? Sign In'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    TextEditingController? controller,
    required String hintText,
    required FormFieldValidator<String> validator,
    FormFieldSetter<String>? onSaved,
    bool obscureText = false,
    Widget? suffixIcon,
    int maxLines = 1,
    bool readOnly = false, // Default to false for fields that allow input
  }) {
    final hintTextColor = Theme.of(context).brightness == Brightness.light
        ? Colors.grey[600]
        : Colors.grey[600];

    return Container(
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
        readOnly: readOnly, // Apply readOnly only when needed
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: hintTextColor),
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          suffixIcon: suffixIcon,
        ),
        onSaved: onSaved,
        validator: validator,
      ),
    );
  }
}