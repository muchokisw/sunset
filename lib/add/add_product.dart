import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _description = '';
  double _price = 0.0;
  String? _selectedCategoryId; // Selected category ID
  int _inventory = 0;
  int _deliveryTime = 0; // Delivery time in days
  double _deliveryCost = 0.0; // Delivery cost
  final List<String> _imageUrls = []; // List to store uploaded image URLs
  String? _storeId; // Store ID associated with the logged-in user
  bool _isLoading = true; // Loading state for fetching storeId and categories
  List<Map<String, dynamic>> _categories = []; // List of categories

  @override
  void initState() {
    super.initState();
    _fetchStoreIdAndCategories();
  }

  Future<void> _fetchStoreIdAndCategories() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final userData = userDoc.data();
        if (userData != null && userData['storeId'] != null) {
          _storeId = userData['storeId'];
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No store associated with this account.')),
          );
          Navigator.pop(context); // Go back if no store is found
          return;
        }
      }

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
        SnackBar(content: Text('Error fetching data: ${e.toString()}')),
      );
      Navigator.pop(context); // Go back if an error occurs
    }
  }

  Future<void> _addProduct() async {
    if (_storeId == null || _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Store ID or Category not selected. Cannot add product.')),
      );
      return;
    }

    try {
      final productId = FirebaseFirestore.instance.collection('products').doc().id;

      // Add product to Firestore
      await FirebaseFirestore.instance.collection('products').doc(productId).set({
        'productId': productId,
        'storeId': _storeId,
        'name': _name,
        'description': _description,
        'price': _price,
        'category': _categories.firstWhere((cat) => cat['categoryId'] == _selectedCategoryId)['name'],
        'categoryId': _selectedCategoryId,
        'inventory': _inventory,
        'images': _imageUrls,
        'ratingAvg': 0.0,
        'ratingCount': 0,
        'deliveryTime': _deliveryTime,
        'deliveryCost': _deliveryCost,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product added successfully!')),
      );

      Navigator.pop(context); // Go back to the previous page
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _pickAndUploadImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false, // Allow only one image at a time
    );
    if (result != null && result.files.isNotEmpty) {
      final fileBytes = result.files.first.bytes;
      final fileName = result.files.first.name;

      if (fileBytes != null) {
        try {
          final imageUrl = await _uploadToFirebaseStorage(fileBytes, 'products/$_storeId/$fileName');
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

  Future<String> _uploadToFirebaseStorage(Uint8List fileBytes, String path) async {
    final storageRef = FirebaseStorage.instance.ref().child(path);
    final uploadTask = storageRef.putData(fileBytes);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
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
        title: const Text('Add Product'),
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
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Product Details',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
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
                                  value: category['categoryId']?.toString() ?? '', // Explicitly cast to String
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
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Delivery Time (in days)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter the delivery time.';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Please enter a valid number.';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          _deliveryTime = int.tryParse(value) ?? 0;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Delivery Cost',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter the delivery cost.';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number.';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          _deliveryCost = double.tryParse(value) ?? 0.0;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          TextButton(
                            onPressed: _pickAndUploadImage,
                            child: const Text('Upload Images, One by One'),
                          ),
                          const SizedBox(width: 16),
                          if (_imageUrls.isNotEmpty)
                            Text(
                              '${_imageUrls.length} Images Uploaded',
                              style: const TextStyle(color: Colors.green),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_imageUrls.isNotEmpty)
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _imageUrls.length,
                            itemBuilder: (context, index) {
                              return Padding(
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
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              _addProduct();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Add Product',
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
      ),
    );
  }
}