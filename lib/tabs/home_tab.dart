// ignore_for_file: deprecated_member_use

import 'dart:async'; // Import for StreamSubscription
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/view/view_product.dart';
import '/view/view_category.dart';
import '../chat/chatbot_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController(); // Use ScrollController for ListView
  final TextEditingController _searchController = TextEditingController(); // Controller for search bar
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>(); // GlobalKey for Scaffold
  final List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _searchResults = []; // Define _searchResults
  bool _isLoading = true;
  String _searchQuery = '';
  int _currentPage = 0; // Track the current visible card for dot indicators
  final Map<String, int> _cartQuantities = {}; // Track quantities of items in the cart
  StreamSubscription<DocumentSnapshot>? _cartSubscription; // Store the Firestore listener

  @override
  void initState() {
    super.initState();
    _loadData();
    _listenToCartChanges();
    _scrollController.addListener(_onScroll); // Attach listener to ScrollController
  }

  @override
  void dispose() {
    _cartSubscription?.cancel(); // Cancel the Firestore listener
    _scrollController.dispose(); // Dispose the ScrollController
    _searchController.dispose(); // Dispose the search controller
    super.dispose();
  }

Future<void> _loadData() async {
  setState(() {
    _isLoading = true;
  });

  try {
    // Fetch products
    final productsQuery = await _firestore.collection('products').get();
    final products = productsQuery.docs.map((doc) {
      final data = doc.data();
      data['productId'] = doc.id; // Add the document ID as productId
      return data;
    }).toList();

    // Fetch categories
    final categoriesQuery = await _firestore.collection('categories').get();
    final categories = categoriesQuery.docs.map((doc) {
      final data = doc.data();
      data['categoryId'] = doc.id; // Add the document ID as categoryId
      return data;
    }).toList();

    setState(() {
      _products.clear();
      _products.addAll(products);
      _categories = categories;
      _searchResults = List.from(_products); // Initialize search results with all products
    });
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error loading data: ${e.toString()}')),
    );
  }

  setState(() {
    _isLoading = false;
  });
}

  void _onScroll() {
    if (_scrollController.hasClients) {
      final offset = _scrollController.offset;
      final page = (offset / 250).round(); // Calculate the current visible card
      if (page != _currentPage) {
        setState(() {
          _currentPage = page;
        });
      }
    }
  }

  void _search(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _searchResults = _products.where((product) {
        final name = product['name']?.toLowerCase() ?? '';
        final description = product['description']?.toLowerCase() ?? '';
        final price = product['price']?.toString() ?? '';
        final category = product['category']?.toLowerCase() ?? '';

        return name.contains(_searchQuery) ||
            description.contains(_searchQuery) ||
            price.contains(_searchQuery) ||
            category.contains(_searchQuery);
      }).toList();
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
      _cartSubscription = _firestore.collection('carts').doc(userId).snapshots().listen((cartDoc) {
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

  IconData _getCategoryIcon(String description) {
    switch (description.toLowerCase()) {
      case 'microwave':
        return Icons.microwave;
      case 'chair':
        return Icons.chair;
      case 'spa':
        return Icons.spa;
      case 'local_grocery_store':
        return Icons.local_grocery_store;
      case 'sports':
        return Icons.sports;
      case 'directions_car':
        return Icons.directions_car;
      case 'menu_book':
        return Icons.menu_book;
      case 'toys':
        return Icons.toys;
      case 'pets':
        return Icons.pets;
      case 'child_friendly':
        return Icons.child_friendly;
      case 'build':
        return Icons.build;
      case 'brush':
        return Icons.brush;
      case 'smartphone':
        return Icons.smartphone;
      case 'videogame_asset':
        return Icons.videogame_asset;
      case 'music_note':
        return Icons.music_note;
      case 'card_travel':
        return Icons.card_travel;
      case 'devices':
        return Icons.devices;
      case 'checkroom':
        return Icons.checkroom;
      case 'camera_alt_rounded':
        return Icons.camera_alt_rounded;
      default:
        return Icons.category; // Default icon if no match is found
    }
  }

  String formatPrice(num price) {
    final formatter = NumberFormat('#,##0');
    return formatter.format(price);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: Drawer(
        child: Column(
          children: [
            Container(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[900]
                  : Colors.white, // Sidebar header background color for light theme
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'Categories',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black, // Text color based on theme
                      ),
                ),
              ),
            ),
            const SizedBox(height: 8), // Add some space below the title
            // Categories List
            Expanded(
              child: FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance.collection('categories').get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No categories available.'));
                  }

                  final categories = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index].data() as Map<String, dynamic>;
                      final icon = _getCategoryIcon(category['description'] ?? '');

                      return ListTile(
                        leading: Icon(
                          icon,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                        title: Text(
                          category['name'] ?? 'Unknown',
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ViewCategory(
                                categoryName: category['name'] ?? 'Unknown',
                                categoryId: category['categoryId'],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search Bar
            Center(
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
                          _searchQuery.isEmpty ? Icons.search : Icons.arrow_back, // Show back icon if searching
                        ),
                        onPressed: () {
                          if (_searchQuery.isNotEmpty) {
                            setState(() {
                              _searchQuery = ''; // Clear the search query
                              _searchController.clear(); // Clear the text in the search bar
                              _searchResults = _products; // Reset search results
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
                      if (_searchQuery.isEmpty) // Only show the menu icon when not searching
                        IconButton(
                          icon: const Icon(Icons.menu), // Add a menu icon for the category sidebar
                          onPressed: () {
                            _scaffoldKey.currentState?.openEndDrawer(); // Open the sidebar
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Display Search Results or Categories
            Expanded(
              child: _searchQuery.isEmpty
                  ? ListView.builder(
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final categoryProducts = _products
                            .where((product) => product['categoryId'] == category['categoryId'])
                            .toList();

                        if (categoryProducts.isEmpty) {
                          return const SizedBox();
                        }

                        final ScrollController categoryScrollController = ScrollController();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            Center(
                              child: Text(
                                category['name'] ?? 'N/A',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Horizontal ListView with Arrow Buttons
                            SizedBox(
                              height: 450, // Set a fixed height for the carousel
                              child: Stack(
                                children: [
                                  ListView.builder(
                                    controller: categoryScrollController,
                                    scrollDirection: Axis.horizontal,
                                    itemCount: categoryProducts.length,
                                    itemBuilder: (context, productIndex) {
                                      final product = categoryProducts[productIndex];

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                        child: GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => ViewProduct(product: product),
                                              ),
                                            );
                                          },
                                          child: SizedBox(
                                            width: 250, // Fixed card width
                                            child: Card(
                                              elevation: 4,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  ClipRRect(
                                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                                    child: product['images'] != null && product['images'].isNotEmpty
                                                        ? Image.network(
                                                            product['images'][0],
                                                            height: 300, // Fixed height for images
                                                            width: double.infinity,
                                                            fit: BoxFit.cover, // Ensure consistent aspect ratio
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
                                                                child: const Icon(Icons.shopping_cart, color: Colors.black),
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
                                      );
                                    },
                                  ),
                                  // Left Arrow Button
                                  Positioned(
                                    left: 0,
                                    top: 0,
                                    bottom: 0,
                                    child: IconButton(
                                      icon: Icon(Icons.arrow_forward, color: Colors.black.withOpacity(0.0)), // Transparent icon for left arrow
                                      onPressed: () {
                                        categoryScrollController.animateTo(
                                          categoryScrollController.offset - 250, // Scroll left by 250 pixels
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                        );
                                      },
                                    ),
                                  ),
                                  // Right Arrow Button
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    bottom: 0,
                                    child: IconButton(
                                      // ignore: duplicate_ignore
                                      // ignore: deprecated_member_use
                                      icon: Icon(Icons.arrow_forward, color: Colors.black.withOpacity(0.0)),
                                      onPressed: () {
                                        categoryScrollController.animateTo(
                                          categoryScrollController.offset + 250, // Scroll right by 250 pixels
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    )
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final product = _searchResults[index];

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0), // Add vertical spacing
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
                                width: MediaQuery.of(context).size.width * 0.85 > 400
                                    ? 400
                                    : MediaQuery.of(context).size.width * 0.85,
                                height: 450,
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
                                                height: 300, // Match the height of the carousel images
                                                width: double.infinity,
                                                fit: BoxFit.cover,
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
                                              '${formatPrice(product['price']?.toInt() ?? 0)}/-', // Format price and add /- at the end
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                            const SizedBox(height: 8),
                                            _cartQuantities[product['productId']] == null
                                                ? ElevatedButton(
                                                    onPressed: () => _addToCart(product),
                                                    child: const Icon(Icons.shopping_cart, color: Colors.black),
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatbotScreen()),
          );
        },
        backgroundColor: Colors.grey,
        tooltip: 'Shop Assist', // Tooltip for the FAB
        heroTag: 'homeChatFAB', // Unique hero tag for this FAB
        child: const Icon(Icons.auto_awesome, color: Colors.black),
      ),
    );
  }
}