import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

class EditStorePage extends StatefulWidget {
  final String storeId;
  final Map<String, dynamic> storeDetails;

  const EditStorePage({
    super.key,
    required this.storeId,
    required this.storeDetails,
  });

  @override
  State<EditStorePage> createState() => _EditStorePageState();
}

class _EditStorePageState extends State<EditStorePage> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _description;
  late String _location;
  Uint8List? _logoBytes;
  Uint8List? _bannerBytes;

  @override
  void initState() {
    super.initState();
    _name = widget.storeDetails['name'] ?? '';
    _description = widget.storeDetails['description'] ?? '';
    
    // Handle location as a Map or String
    final location = widget.storeDetails['location'];
    if (location is Map) {
      _location = '${location['city'] ?? 'Unknown City'}, ${location['country'] ?? 'Unknown Country'}';
    } else if (location is String) {
      _location = location;
    } else {
      _location = 'Unknown Location';
    }
  }

  Future<String> _uploadToFirebaseStorage(Uint8List fileBytes, String path) async {
    final storageRef = FirebaseStorage.instance.ref().child(path);
    final uploadTask = storageRef.putData(fileBytes);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> _updateStoreDetails() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      try {
        String? logoUrl = widget.storeDetails['logo'];
        String? bannerUrl = widget.storeDetails['banner'];

        // Upload new logo if selected
        if (_logoBytes != null) {
          logoUrl = await _uploadToFirebaseStorage(_logoBytes!, 'stores/${widget.storeId}/logo.png');
        }

        // Upload new banner if selected
        if (_bannerBytes != null) {
          bannerUrl = await _uploadToFirebaseStorage(_bannerBytes!, 'stores/${widget.storeId}/banner.png');
        }

        // Parse location into a Map
        final locationParts = _location.split(',').map((part) => part.trim()).toList();
        final locationMap = {
          'city': locationParts.isNotEmpty ? locationParts[0] : null,
          'country': locationParts.length > 1 ? locationParts[1] : null,
        };

        // Update store details in Firestore
        await FirebaseFirestore.instance.collection('stores').doc(widget.storeId).update({
          'name': _name,
          'description': _description,
          'location': locationMap,
          'logo': logoUrl,
          'banner': bannerUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Store updated successfully!')),
        );

        Navigator.pop(context); // Go back to the previous page
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

  Future<void> _deleteStore() async {
    try {
      // Delete the store from Firestore
      await FirebaseFirestore.instance.collection('stores').doc(widget.storeId).delete();

      // Remove the storeId from the user's document
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .where('storeId', isEqualTo: widget.storeId)
          .get();

      if (userDoc.docs.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.docs.first.id)
            .update({'storeId': FieldValue.delete()});
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Store deleted successfully!')),
      );

      Navigator.pop(context); // Go back to the previous page
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Store'),
          content: const Text(
            'Are you sure you want to delete this store? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
                _deleteStore(); // Call the delete store function
              },
              
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Store'),
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Edit Store Details',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            initialValue: _name,
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
                            onChanged: (value) {
                              _name = value;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            initialValue: _description,
                            decoration: InputDecoration(
                              labelText: 'Description',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            maxLines: 5,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter the store description.';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              _description = value;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            initialValue: _location,
                            decoration: InputDecoration(
                              labelText: 'Location',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter the store location.';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              _location = value;
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              TextButton(
                                onPressed: _pickLogo,
                                child: const Text('Change Logo'),
                              ),
                              const SizedBox(width: 16),
                              if (_logoBytes != null)
                                const Text('Logo Selected', style: TextStyle(color: Colors.green)),
                            ],
                          ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: _pickBanner,
                                child: const Text('Change Banner'),
                              ),
                              const SizedBox(width: 16),
                              if (_bannerBytes != null)
                                const Text('Banner Selected', style: TextStyle(color: Colors.green)),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context); // Cancel and go back
                                },
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _updateStoreDetails,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey,
                                  foregroundColor: Colors.black,
                                ),
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: _showDeleteConfirmationDialog,
              
              child: const Text('Delete Store'),
            ),
          ),
        ],
      ),
    );
  }
}