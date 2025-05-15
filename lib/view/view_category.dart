import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../view/view_product.dart';
import '/theme_notifier.dart';
import 'package:intl/intl.dart';

class ViewCategory extends StatefulWidget {
  final String categoryName;
  final String categoryId;

  const ViewCategory({
    super.key,
    required this.categoryName,
    required this.categoryId,
  });

  @override
  State<ViewCategory> createState() => _ViewCategoryState();
}

class _ViewCategoryState extends State<ViewCategory> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _categoryProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  final Map<String, int> _cartQuantities = {}; // Track quantities of items in the cart
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategoryProducts();
    _listenToCartChanges();
  }

  Future<void> _loadCategoryProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final productsQuery = await _firestore
          .collection('products')
          .where('categoryId', isEqualTo: widget.categoryId)
          .get();

      setState(() {
        _categoryProducts = productsQuery.docs.map((doc) => doc.data()).toList();
        _filteredProducts = _categoryProducts; // Initially, all products are shown
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading category products: ${e.toString()}')),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _search(String query) {
    setState(() {
      _filteredProducts = _categoryProducts
          .where((product) =>
              (product['name'] ?? '').toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add items to your cart.')),
      );
      return;
    }

    final cartRef = _firestore.collection('carts').doc(userId);

    try {
      final cartDoc = await cartRef.get();

      if (cartDoc.exists) {
        // Cart exists, update it
        final cartData = cartDoc.data();
        final items = List<Map<String, dynamic>>.from(cartData?['items'] ?? []);

        final existingItemIndex = items.indexWhere((item) => item['productId'] == product['productId']);

        if (existingItemIndex != -1) {
          // Product already in cart, increment quantity
          items[existingItemIndex]['quantity'] += 1;
          _cartQuantities[product['productId']] = items[existingItemIndex]['quantity'];
        } else {
          // Product not in cart, add it
          items.add({'productId': product['productId'], 'quantity': 1});
          _cartQuantities[product['productId']] = 1;
        }

        await cartRef.update({'items': items, 'updatedAt': FieldValue.serverTimestamp()});
      } else {
        // Cart does not exist, create it
        await cartRef.set({
          'userId': userId,
          'items': [
            {'productId': product['productId'], 'quantity': 1}
          ],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _cartQuantities[product['productId']] = 1;
      }

      if (!mounted) return;
      setState(() {}); // Trigger UI update
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product added to cart!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding to cart: ${e.toString()}')),
      );
    }
  }

  Future<void> _updateQuantity(Map<String, dynamic> product, int change) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to update your cart.')),
      );
      return;
    }

    final cartRef = _firestore.collection('carts').doc(userId);

    try {
      final cartDoc = await cartRef.get();

      if (cartDoc.exists) {
        final cartData = cartDoc.data();
        final items = List<Map<String, dynamic>>.from(cartData?['items'] ?? []);

        final existingItemIndex = items.indexWhere((item) => item['productId'] == product['productId']);

        if (existingItemIndex != -1) {
          // Update quantity
          items[existingItemIndex]['quantity'] += change;

          if (items[existingItemIndex]['quantity'] <= 0) {
            // Remove item if quantity is 0
            items.removeAt(existingItemIndex);
            _cartQuantities.remove(product['productId']);
          } else {
            _cartQuantities[product['productId']] = items[existingItemIndex]['quantity'];
          }

          await cartRef.update({'items': items, 'updatedAt': FieldValue.serverTimestamp()});
        }

        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating cart: ${e.toString()}')),
      );
    }
  }

  void _listenToCartChanges() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      _firestore.collection('carts').doc(userId).snapshots().listen((cartDoc) {
        if (cartDoc.exists) {
          final cartData = cartDoc.data();
          final items = List<Map<String, dynamic>>.from(cartData?['items'] ?? []);

          if (mounted) {
            setState(() {
              _cartQuantities.clear();
              for (var item in items) {
                _cartQuantities[item['productId']] = item['quantity'];
              }
            });
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
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
          // Search Bar with added space above and below
          Padding(
            padding: const EdgeInsets.all(16.0), // Add vertical spacing
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.grey[200]
                        : Colors.grey[900],
                    borderRadius: BorderRadius.circular(24.0),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _searchController.text.isEmpty ? Icons.search : Icons.arrow_back, // Show back icon if searching
                        ),
                        onPressed: () {
                          if (_searchController.text.isNotEmpty) {
                            setState(() {
                              _searchController.clear(); // Clear the text in the search bar
                              _filteredProducts = _categoryProducts; // Reset the filtered products
                            });
                          }
                        },
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController, // Attach the controller to the TextField
                          onChanged: _search,
                          decoration: const InputDecoration(
                            hintText: 'Search',
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _filteredProducts.isEmpty
                    ? const Center(
                        child: Text('Coming Soon...'),
                      )
                    : ListView.builder(
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = _filteredProducts[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ViewProduct(product: product),
                                  ),
                                );
                              },
                              child: Center(
                                child: SizedBox(
                                  height: 300,
                                  width: 400,
                                  child: Card(
                                    elevation: 4,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius: const BorderRadius.vertical(
                                            top: Radius.circular(8),
                                          ),
                                          child: product['images'] != null && product['images'].isNotEmpty
                                              ? Image.network(
                                                  product['images'][0],
                                                  height: 150,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return const Icon(Icons.error, size: 50);
                                                  },
                                                )
                                              : const Icon(Icons.image, size: 150),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product['name'] ?? 'N/A',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${formatPrice(product['price']?.toInt() ?? 0)}/-', // Format price with commas
                                                style: const TextStyle(fontSize: 14),
                                              ),
                                              const SizedBox(height: 8),
                                              _cartQuantities[product['productId']] == null
                                                  ? ElevatedButton(
                                                      onPressed: () => _addToCart(product),
                                                        child: const Icon(Icons.shopping_cart, 
                                                        color: Colors.black),
                                                    )
                                                  : Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        IconButton(
                                                          onPressed: () => _updateQuantity(product, -1),
                                                          icon: const Icon(Icons.remove),
                                                        ),
                                                        Text(
                                                          '${_cartQuantities[product['productId']] ?? 0}',
                                                          style: const TextStyle(fontSize: 16),
                                                        ),
                                                        IconButton(
                                                          onPressed: () => _updateQuantity(product, 1),
                                                          icon: const Icon(Icons.add),
                                                        ),
                                                      ],
                                                    ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

String formatPrice(num price) {
  final formatter = NumberFormat('#,##0');
  return formatter.format(price);
}