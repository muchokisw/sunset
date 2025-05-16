import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

class EditProductPage extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productDetails;

  const EditProductPage({
    super.key,
    required this.productId,
    required this.productDetails,
  });

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _description;
  late double _price;
  String? _selectedCategoryId; // Selected category ID
  late int _inventory;
  List<String> _imageUrls = []; // Existing image URLs
  final List<Uint8List> _newImageBytes = []; // New images to upload
  List<Map<String, dynamic>> _categories = []; // List of categories
  bool _isLoading = true; // Loading state for fetching categories

  @override
  void initState() {
    super.initState();
    _name = widget.productDetails['name'] ?? '';
    _description = widget.productDetails['description'] ?? '';
    _price = widget.productDetails['price']?.toDouble() ?? 0.0;
    _selectedCategoryId = widget.productDetails['categoryId']; // Use categoryId
    _inventory = widget.productDetails['inventory'] ?? 0;
    _imageUrls = List<String>.from(widget.productDetails['images'] ?? []);
    _fetchCategories(); // Fetch categories from Firestore
  }

  Future<void> _fetchCategories() async {
    try {
      // Fetch categories from Firestore
      final categoriesQuery = await FirebaseFirestore.instance.collection('categories').get();
      final categories = categoriesQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'categoryId': data['categoryId'],
          'name': data['name'],
        };
      }).toList();

      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching categories: ${e.toString()}')),
      );
    }
  }

  Future<String> _uploadToFirebaseStorage(Uint8List fileBytes, String path) async {
    final storageRef = FirebaseStorage.instance.ref().child(path);
    final uploadTask = storageRef.putData(fileBytes);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> _updateProductDetails() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      try {
        // Upload new images if selected
        for (int i = 0; i < _newImageBytes.length; i++) {
          final imageUrl = await _uploadToFirebaseStorage(
            _newImageBytes[i],
            'products/${widget.productId}/image_${DateTime.now().millisecondsSinceEpoch}.png',
          );
          _imageUrls.add(imageUrl); // Add new image URLs to the list
        }

        // Update product details in Firestore
        await FirebaseFirestore.instance.collection('products').doc(widget.productId).update({
          'name': _name,
          'description': _description,
          'price': _price,
          'category': _categories.firstWhere((cat) => cat['categoryId'] == _selectedCategoryId)['name'],
          'categoryId': _selectedCategoryId,
          'inventory': _inventory,
          'images': _imageUrls, // Update the images array
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product updated successfully!')),
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
      allowMultiple: false, // Allow one image at a time
    );
    if (result != null && result.files.isNotEmpty) {
      final fileBytes = result.files.first.bytes;
      final fileName = result.files.first.name;

      if (fileBytes != null) {
        try {
          final imageUrl = await _uploadToFirebaseStorage(
            fileBytes,
            'products/${widget.productId}/$fileName',
          );
          setState(() {
            _imageUrls.add(imageUrl); // Add the uploaded image URL to the list
          });
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error uploading image: ${e.toString()}')),
          );
        }
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imageUrls.removeAt(index); // Remove the image URL from the list
    });
  }

  Future<void> _deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Product'),
          content: const Text('Are you sure you want to delete this product? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false), // Cancel
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true), // Confirm
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        // Delete product document from Firestore
        await FirebaseFirestore.instance.collection('products').doc(widget.productId).delete();

        // Optionally, delete images from Firebase Storage
        for (final imageUrl in _imageUrls) {
          final ref = FirebaseStorage.instance.refFromURL(imageUrl);
          await ref.delete();
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product deleted successfully!')),
        );

        Navigator.pop(context); // Go back to the previous page
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting product: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Product'),
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
                              'Edit Product Details',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              initialValue: _name,
                              decoration: InputDecoration(
                                labelText: 'Product Name',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter the product name.';
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
                                  return 'Please enter the product description.';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                _description = value;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              initialValue: _price.toString(),
                              decoration: InputDecoration(
                                labelText: 'Price',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter the product price.';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Please enter a valid number.';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                _price = double.tryParse(value) ?? 0.0;
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _selectedCategoryId,
                              items: _categories
                                  .map((category) => DropdownMenuItem<String>(
                                        value: category['categoryId']?.toString() ?? '',
                                        child: Text(category['name']?.toString() ?? 'Unnamed Category'),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedCategoryId = value;
                                });
                              },
                              decoration: InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a category.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              initialValue: _inventory.toString(),
                              decoration: InputDecoration(
                                labelText: 'Inventory',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter the inventory count.';
                                }
                                if (int.tryParse(value) == null) {
                                  return 'Please enter a valid number.';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                _inventory = int.tryParse(value) ?? 0;
                              },
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Images',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: _pickAndUploadImage,
                                  child: const Text('Upload Images, One by One'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_imageUrls.isNotEmpty)
                              SizedBox(
                                height: 100,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _imageUrls.length,
                                  itemBuilder: (context, index) {
                                    return Stack(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.network(
                                              _imageUrls[index],
                                              fit: BoxFit.cover,
                                              width: 100,
                                              height: 100,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: IconButton(
                                            icon: const Icon(Icons.close, color: Colors.black),
                                            onPressed: () => _removeImage(index),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
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
                                  onPressed: _updateProductDetails,
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
          ),
          Center(
            child: TextButton(
              onPressed: _deleteProduct,
              style: TextButton.styleFrom(
                //foregroundColor: Colors.black,
              ),
              child: const Text('Delete Product'),
            ),
          ),
        ],
      ),
    );
  }
}