import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

class OpenStorePage extends StatefulWidget {
  const OpenStorePage({super.key});

  @override
  State<OpenStorePage> createState() => _OpenStorePageState();
}

class _OpenStorePageState extends State<OpenStorePage> {
  final _formKey = GlobalKey<FormState>();
  String _storeName = '';
  String _storeDescription = '';
  String _storeAddress = '';
  Uint8List? _logoBytes;
  Uint8List? _bannerBytes;

  Future<String> _uploadToFirebaseStorage(Uint8List fileBytes, String path) async {
    final storageRef = FirebaseStorage.instance.ref().child(path);
    final uploadTask = storageRef.putData(fileBytes);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> _submitStoreDetails() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Generate a unique storeId
          final storeId = FirebaseFirestore.instance.collection('stores').doc().id;

          // Upload logo and banner to Firebase Storage
          String? logoUrl;
          String? bannerUrl;

          if (_logoBytes != null) {
            logoUrl = await _uploadToFirebaseStorage(_logoBytes!, 'stores/$storeId/logo.png');
          }

          if (_bannerBytes != null) {
            bannerUrl = await _uploadToFirebaseStorage(_bannerBytes!, 'stores/$storeId/banner.png');
          }

          // Save store details to Firestore
          await FirebaseFirestore.instance.collection('stores').doc(storeId).set({
            'storeId': storeId,
            'userId': user.uid,
            'name': _storeName,
            'description': _storeDescription,
            'location': _storeAddress,
            'logo': logoUrl ?? '',
            'banner': bannerUrl ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Update the user's `storeId` in the `users` collection
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'storeId': storeId,
          });

          if (!mounted) return; // Check if the widget is still mounted
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Store created successfully!')),
          );

          Navigator.pop(context); // Go back to the Store Profile tab
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _logoBytes = result.files.single.bytes;
      });
    }
  }

  Future<void> _pickBanner() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _bannerBytes = result.files.single.bytes;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Store'),
      ),
      body: Center(
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Store Details',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Store Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the store name.';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        _storeName = value!;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Store Description',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      maxLines: 5, // Allow multi-line input
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the store description.';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        _storeDescription = value!;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Store Address',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the store address.';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        _storeAddress = value!;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _pickLogo,
                          child: const Text('Upload Logo'),
                        ),
                        const SizedBox(width: 16),
                        if (_logoBytes != null)
                          const Text('Logo Uploaded', style: TextStyle(color: Colors.green)),
                      ],
                    ),
                   
                    Row(
                      children: [
                        TextButton(
                          onPressed: _pickBanner,
                          child: const Text('Upload Banner'),
                        ),
                        const SizedBox(width: 16),
                        if (_bannerBytes != null)
                          const Text('Banner Uploaded', style: TextStyle(color: Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitStoreDetails,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Submit',
                          style: TextStyle(fontSize: 16),
                        ),
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