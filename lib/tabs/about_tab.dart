import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:html' as html;

class AboutTab extends StatefulWidget {
  const AboutTab({super.key});

  @override
  State<AboutTab> createState() => _AboutTabState();
}

class _AboutTabState extends State<AboutTab> {
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Future<void> _submitEmail() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();

      try {
        await FirebaseFirestore.instance.collection('mails').add({'email': email});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email submitted successfully!')),
          );
        }
        _emailController.clear();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose(); // Dispose of the controller to free resources
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    // Always set the title on every build
    html.document.title = 'Sunset Marketplace';
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600), // Limit the width to 600
              child: Card(
                elevation: 4,
                margin: const EdgeInsets.all(16.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Welcome to Sunset, an AI and ML first online marketplace designed to connect suppliers, traders, and consumers.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 16.0),
                      const Text(
                        'The platform provides personalized shopping experiences and efficient supply chain solutions.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 16.0),
                      const Text(
                        'Be the first to know when the app fully launches!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 16.0),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Styled email input field with send icon button
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 600),
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
                                        controller: _emailController,
                                        decoration: InputDecoration(
                                          labelText: 'Email',
                                          labelStyle: TextStyle(
                                            color: Theme.of(context).brightness == Brightness.light
                                                ? Colors.grey
                                                : Colors.grey[700],
                                          ),
                                          border: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter your email';
                                          }
                                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                                            return 'Please enter a valid email';
                                          }
                                          return null;
                                        },
                                        onFieldSubmitted: (_) => _submitEmail(),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.send),
                                        color: Theme.of(context).brightness == Brightness.light
                                          ? Colors.grey
                                          : Colors.grey[700],
                                      onPressed: _submitEmail,
                                      tooltip: 'Send',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16.0),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}