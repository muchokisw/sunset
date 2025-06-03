import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../home/admin_home.dart'; // Import admin home
import '../home/seller_home.dart'; // Import seller home
import '../home/user_home.dart'; // Import user home
import '../theme_notifier.dart'; // Import theme notifier
import 'sign_up.dart'; // Import the signup page
import 'dart:html' as html; // Import for setting the title

class SignIn extends StatefulWidget {
  const SignIn({super.key});

  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  bool _isPasswordVisible = false; // State for password visibility

  Future<void> _signin() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      try {
        // Sign in with email and password
        final userCredential = await _auth.signInWithEmailAndPassword(
          email: _email,
          password: _password,
        );

        // Fetch user details from Firestore
        final userDoc = await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        if (!userDoc.exists) {
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'User data not found in Firestore.',
          );
        }

        final userData = userDoc.data()!;
        final role = userData['role'];

        // Check if the widget is still mounted before using context
        if (!mounted) return;

        // Navigate to the appropriate home page based on role
        if (role == 'admin') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const AdminHome()),
            (route) => false, // Remove all previous routes
          );
        } else if (role == 'seller') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const SellerHome()),
            (route) => false, // Remove all previous routes
          );
        } else if (role == 'buyer') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const UserHome()),
            (route) => false, // Remove all previous routes
          );
        } else {
          throw FirebaseAuthException(
            code: 'invalid-role',
            message: 'Invalid user role.',
          );
        }
      } on FirebaseAuthException catch (e) {
        // Check if the widget is still mounted before using context
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Always set the title on every build
    html.document.title = 'Sunset Marketplace';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In'),
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600), // Limit the width to 600
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
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center, // Center content horizontally
                  children: [
                    const Text(
                      'Welcome',
                      style: TextStyle(
                        fontSize: 24,
                        //fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center, // Center the text
                    ),
                    const SizedBox(height: 16),
                    // Styled email input field
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.light
                              ? Colors.grey[200]
                              : Colors.black,
                          borderRadius: BorderRadius.circular(24.0),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                decoration: InputDecoration(
                                  labelText: 'Email', // This will float above the border when typing
                                  labelStyle: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.light
                                        ? Colors.grey
                                        : Colors.grey[700],
                                  ),
                                  border: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty || !value.contains('@')) {
                                    return 'Please enter a valid email.';
                                  }
                                  return null;
                                },
                                onSaved: (value) {
                                  _email = value!;
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Styled password input field with visibility toggle
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.light
                              ? Colors.grey[200]
                              : Colors.black,
                          borderRadius: BorderRadius.circular(24.0),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                decoration: InputDecoration(
                                  labelText: 'Password', // This will float above the border when typing
                                  labelStyle: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.light
                                        ? Colors.grey
                                        : Colors.grey[700],
                                  ),
                                  border: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                                obscureText: !_isPasswordVisible, // Toggle visibility
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password.';
                                  }
                                  return null;
                                },
                                onSaved: (value) {
                                  _password = value!;
                                },
                              ),
                            ),
                            IconButton(
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
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Centered Sign In button
                    ElevatedButton(
                      onPressed: _signin,
                      child: const Text(
                        'Sign In',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const NormalSignup()),
                          );
                        },
                        child: const Text('Don’t have an account? Sign Up'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}