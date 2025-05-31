import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

class EditCategoryPage extends StatefulWidget {
  final String categoryId;
  final Map<String, dynamic> categoryDetails;

  const EditCategoryPage({
    super.key,
    required this.categoryId,
    required this.categoryDetails,
  });

  @override
  State<EditCategoryPage> createState() => _EditCategoryPageState();
}

class _EditCategoryPageState extends State<EditCategoryPage> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _description;
  String? _imageUrl;
  Uint8List? _newImageBytes;

  @override
  void initState() {
    super.initState();
    _name = widget.categoryDetails['name'] ?? '';
    _description = widget.categoryDetails['description'] ?? '';
    _imageUrl = widget.categoryDetails['image'];
  }

  Future<String> _uploadToFirebaseStorage(Uint8List fileBytes, String path) async {
    final storageRef = FirebaseStorage.instance.ref().child(path);
    final uploadTask = storageRef.putData(fileBytes);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> _updateCategoryDetails() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      try {
        // Upload new image if selected
        if (_newImageBytes != null) {
          _imageUrl = await _uploadToFirebaseStorage(
            _newImageBytes!,
            'categories/${widget.categoryId}/image_${DateTime.now().millisecondsSinceEpoch}.png',
          );
        }

        // Update category details in Firestore
        await FirebaseFirestore.instance.collection('categories').doc(widget.categoryId).update({
          'name': _name,
          'description': _description,
          'image': _imageUrl ?? '',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category updated successfully!')),
        );

        Navigator.pop(context); // Go back to the previous page
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _newImageBytes = result.files.first.bytes;
        _imageUrl = null; // Clear the existing image URL
      });
    }
  }

  void _removeImage() {
    setState(() {
      _newImageBytes = null;
      _imageUrl = null;
    });
  }

  Future<void> _deleteCategory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Category'),
          content: const Text('Are you sure you want to delete this category? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false), // Cancel
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true), // Confirm
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        // Delete category document from Firestore
        await FirebaseFirestore.instance.collection('categories').doc(widget.categoryId).delete();

        // Optionally, delete the image from Firebase Storage
        if (_imageUrl != null && _imageUrl!.isNotEmpty) {
          final ref = FirebaseStorage.instance.refFromURL(_imageUrl!);
          await ref.delete();
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category deleted successfully!')),
        );

        Navigator.pop(context); // Go back to the previous page
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting category: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Category'),
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
                            const Text(
                              'Edit Category Details',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              initialValue: _name,
                              decoration: InputDecoration(
                                labelText: 'Category Name',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter the category name.';
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
                                  return 'Please enter the category description.';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                _description = value;
                              },
                            ),
                           const SizedBox(height: 16),
                                TextButton(
                                  onPressed: _pickAndUploadImage,
                                  child: const Text('Upload Image'),
                                ),
                                const SizedBox(width: 16),
                                if (_newImageBytes != null || _imageUrl != null)
                                  Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: _newImageBytes != null
                                            ? Image.memory(
                                                _newImageBytes!,
                                                width: 100,
                                                height: 100,
                                                fit: BoxFit.cover,
                                              )
                                            : Image.network(
                                                _imageUrl!,
                                                width: 100,
                                                height: 100,
                                                fit: BoxFit.cover,
                                              ),
                                      ),
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: IconButton(
                                          icon: const Icon(Icons.close, color: Colors.black),
                                          onPressed: _removeImage,
                                        ),
                                      ),
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
                                  onPressed: _updateCategoryDetails,
                                  /*style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey,
                                    foregroundColor: Colors.black,
                                  ),*/
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
          ),
          Center(
            child: TextButton(
              onPressed: _deleteCategory,
              style: TextButton.styleFrom(
                //foregroundColor: Colors.black,
              ),
              child: const Text('Delete Category'),
            ),
          ),
        ],
      ),
    );
  }
}