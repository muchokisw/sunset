// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../view/view_product.dart'; // Import the ViewProduct page
import '../chat/chatbot_screen.dart'; // Import the ChatbotScreen page
import '../view/view_category.dart'; // Import the ViewCategory page
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:html' as html; // Import for setting the document title

class DiscoverTab extends StatefulWidget {
  const DiscoverTab({super.key});

  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>(); // Add a GlobalKey for the Scaffold
  final TextEditingController _searchController = TextEditingController(); // Add a TextEditingController
  final FocusNode _searchFocusNode = FocusNode();
  bool _isLoading = true;
  List<Map<String, dynamic>> _trendingProducts = [];
  List<Map<String, dynamic>> _recentlyViewedProducts = [];
  List<Map<String, dynamic>> _categoryRecommendations = [];
  List<Map<String, dynamic>> _locationBasedRecommendations = [];
  List<Map<String, dynamic>> _allProducts = []; // All products for search
  List<Map<String, dynamic>> _searchResults = []; // Search results
  String _searchQuery = ''; // Current search query

  final Map<String, int> _cartQuantities = {};
  final ScrollController _trendingScrollController = ScrollController();
  final ScrollController _recentlyViewedScrollController = ScrollController();
  final ScrollController _categoryScrollController = ScrollController();
  final ScrollController _locationScrollController = ScrollController();

  int _trendingCurrentPage = 0;
  int _recentlyViewedCurrentPage = 0;
  int _categoryCurrentPage = 0;
  int _locationCurrentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadCartQuantities();
    _loadRecommendations();
    _loadAllProducts(); // Load all products for search
  }

  @override
  void dispose() {
    _searchController.dispose(); // Dispose the controller when the widget is disposed
    _searchFocusNode.dispose();
    _trendingScrollController.dispose();
    _recentlyViewedScrollController.dispose();
    _categoryScrollController.dispose();
    _locationScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRecommendations() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final location = await _getUserLocation();
      final country = location['country'] ?? '';
      final city = location['city'] ?? '';

      // Fetch trending products
      final trendingQuery = await FirebaseFirestore.instance
          .collection('products')
          .orderBy('viewerCount', descending: true)
          .limit(10)
          .get();
      final trendingProducts = trendingQuery.docs.map((doc) => doc.data()).toList();

      // Fetch recently viewed products
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final recentlyViewed = List<Map<String, dynamic>>.from(userDoc.data()?['recentlyViewed'] ?? []);
      final recentlyViewedIds = recentlyViewed
          .map((item) => item['productId'])
          .where((id) => id != null)
          .cast<String>()
          .toList();

      List<Map<String, dynamic>> recentlyViewedProducts = [];
      if (recentlyViewedIds.isNotEmpty) {
        recentlyViewedProducts = await _fetchProductsInChunks(recentlyViewedIds);
      }

      // Fetch category recommendations
      final categoryIds = recentlyViewed
          .map((item) => item['categoryId'])
          .where((id) => id != null)
          .toSet()
          .toList();

      List<Map<String, dynamic>> categoryRecommendations = [];
      if (categoryIds.isNotEmpty) {
        categoryRecommendations = await _fetchAllCategoryRecommendations(categoryIds.cast<String>());
      }

      // Fetch location-based recommendations
      final locationBasedRecommendations = await _getLocationBasedRecommendations(country, city);

      if (!mounted) return;
      setState(() {
        _trendingProducts = trendingProducts;
        _recentlyViewedProducts = recentlyViewedProducts;
        _categoryRecommendations = categoryRecommendations;
        _locationBasedRecommendations = locationBasedRecommendations;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading recommendations: ${e.toString()}')),
        );
      }
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCartQuantities() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) return;

    try {
      final cartDoc = await FirebaseFirestore.instance.collection('carts').doc(userId).get();

      if (cartDoc.exists) {
        final cartData = cartDoc.data();
        final items = List<Map<String, dynamic>>.from(cartData?['items'] ?? []);

        for (var item in items) {
          _cartQuantities[item['productId']] = item['quantity'];
        }

        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading cart data: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add items to your cart.')),
      );
      return;
    }

    final cartRef = FirebaseFirestore.instance.collection('carts').doc(userId);

    try {
      final cartDoc = await cartRef.get();

      if (cartDoc.exists) {
        final cartData = cartDoc.data();
        final items = List<Map<String, dynamic>>.from(cartData?['items'] ?? []);

        final existingItemIndex = items.indexWhere((item) => item['productId'] == product['productId']);

        if (existingItemIndex != -1) {
          items[existingItemIndex]['quantity'] += 1;
          _cartQuantities[product['productId']] = items[existingItemIndex]['quantity'];
        } else {
          items.add({'productId': product['productId'], 'quantity': 1});
          _cartQuantities[product['productId']] = 1;
        }

        await cartRef.update({'items': items, 'updatedAt': FieldValue.serverTimestamp()});
      } else {
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
      setState(() {});
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

    final cartRef = FirebaseFirestore.instance.collection('carts').doc(userId);

    try {
      final cartDoc = await cartRef.get();

      if (cartDoc.exists) {
        final cartData = cartDoc.data();
        final items = List<Map<String, dynamic>>.from(cartData?['items'] ?? []);

        final existingItemIndex = items.indexWhere((item) => item['productId'] == product['productId']);

        if (existingItemIndex != -1) {
          items[existingItemIndex]['quantity'] += change;

          if (items[existingItemIndex]['quantity'] <= 0) {
            items.removeAt(existingItemIndex);
            _cartQuantities.remove(product['productId']);
          } else {
            _cartQuantities[product['productId']] = items[existingItemIndex]['quantity'];
          }

          await cartRef.update({'items': items, 'updatedAt': FieldValue.serverTimestamp()});
        }

        if (!mounted) return;
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating cart: ${e.toString()}')),
      );
    }
  }

  Future<Map<String, String>> _getUserLocation() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return {};

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final userData = userDoc.data();
      if (userData != null) {
        return {
          'country': userData['country'] ?? '',
          'city': userData['city'] ?? '',
        };
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching user location: ${e.toString()}')),
        );
      }
    }
    return {};
  }

  Future<List<Map<String, dynamic>>> _getLocationBasedRecommendations(String country, String city) async {
    try {
      final storesQuery = await FirebaseFirestore.instance
          .collection('stores')
          .where('location.country', isEqualTo: country)
          .where('location.city', isEqualTo: city)
          .get();

      final storeIds = storesQuery.docs.map((doc) => doc['storeId']).toList();

      if (storeIds.isEmpty) return [];

      final productsQuery = await FirebaseFirestore.instance
          .collection('products')
          .where('storeId', whereIn: storeIds)
          .limit(10)
          .get();

      return productsQuery.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching location-based recommendations: ${e.toString()}')),
        );
      }
      return [];
    }
  }

  Future<void> _loadAllProducts() async {
    try {
      final productsQuery = await FirebaseFirestore.instance.collection('products').get();
      final allProducts = productsQuery.docs.map((doc) => doc.data()).toList();

      if (!mounted) return;
      setState(() {
        _allProducts = allProducts;
        _searchResults = allProducts;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: ${e.toString()}')),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchProductsInChunks(List<String> ids) async {
    List<Map<String, dynamic>> products = [];
    const int chunkSize = 30;

    for (int i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.sublist(i, i + chunkSize > ids.length ? ids.length : i + chunkSize);
      final querySnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('productId', whereIn: chunk)
          .get();

      products.addAll(querySnapshot.docs.map((doc) => doc.data()));
    }

    return products;
  }

  Future<List<Map<String, dynamic>>> _fetchAllCategoryRecommendations(List<String> categoryIds) async {
    List<Map<String, dynamic>> recommendations = [];

    for (String categoryId in categoryIds) {
      final categoryRecommendations = await _fetchCategoryRecommendations(categoryId);
      recommendations.addAll(categoryRecommendations);
    }

    return recommendations;
  }

  Future<List<Map<String, dynamic>>> _fetchCategoryRecommendations(String categoryId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('categoryId', isEqualTo: categoryId)
          .limit(10) // Limit the number of recommendations
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('Error fetching category recommendations: $e');
      return [];
    }
  }

  void _search(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _searchResults = _allProducts.where((product) {
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

  String formatPrice(num price) {
    final formatter = NumberFormat('#,###'); // Formats numbers with commas
    return formatter.format(price);
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

  @override
  Widget build(BuildContext context) {
    // Always set the title on every build
    html.document.title = 'Sunset Marketplace'; // Set your desired title
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
                  : Colors.white,
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'Categories',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 8),
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
                          _searchQuery.isEmpty ? Icons.search : Icons.arrow_back,
                        ),
                        onPressed: () {
                          if (_searchQuery.isEmpty) {
                            // Request focus for the search bar
                            _searchFocusNode.requestFocus();
                          } else {
                            // Clear the search query
                            setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                              _searchResults = _allProducts;
                            });
                          }
                        },
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: _search,
                          decoration: const InputDecoration(
                            hintText: 'Search',
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                      if (_searchQuery.isEmpty)
                        IconButton(
                          icon: const Icon(Icons.menu),
                          onPressed: () {
                            _scaffoldKey.currentState?.openEndDrawer();
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _searchQuery.isEmpty
                  ? ListView(
                      children: [
                        _buildSection(
                          'Trending Products',
                          _trendingProducts,
                          _trendingScrollController,
                          (index) => setState(() => _trendingCurrentPage = index),
                          _trendingCurrentPage,
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          'Recently Viewed',
                          _recentlyViewedProducts,
                          _recentlyViewedScrollController,
                          (index) => setState(() => _recentlyViewedCurrentPage = index),
                          _recentlyViewedCurrentPage,
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          'Recommended for You',
                          _categoryRecommendations,
                          _categoryScrollController,
                          (index) => setState(() => _categoryCurrentPage = index),
                          _categoryCurrentPage,
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          'Products Near You',
                          _locationBasedRecommendations,
                          _locationScrollController,
                          (index) => setState(() => _locationCurrentPage = index),
                          _locationCurrentPage,
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final product = _searchQuery.isEmpty ? _allProducts[index] : _searchResults[index];

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
                                          height: 300,
                                          width: double.infinity,
                                          fit: BoxFit.cover, // Ensure the image fits the space
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
                                                child: Icon(
                                                Icons.shopping_cart,
                                                color: Theme.of(context).brightness == Brightness.dark
                                                  ? Colors.black
                                                  : Colors.white,
                                                ),
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
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black,
        tooltip: 'Shop Assist',
        heroTag: 'geminiChatFAB',
        child: Icon(
          Icons.auto_awesome,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.black
              : Colors.white,
        ),
      ),
    );
  }

  Widget _buildSection(
    String title,
    List<Map<String, dynamic>> products,
    ScrollController scrollController,
    Function(int) onPageChanged,
    int currentPage,
  ) {
    if (products.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 450,
          child: Stack(
            children: [
              // Horizontal ListView
              ListView.builder(
                controller: scrollController,
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  final productId = product['productId'];
                  final quantity = _cartQuantities[productId] ?? 0;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ViewProduct(product: product),
                        ),
                      );
                    },
                    child: SizedBox(
                      width: 250,
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
                                      height: 300,
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
                                    '${formatPrice(product['price']?.toInt() ?? 0)}/-', // Format price with commas
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 8),
                                  quantity == 0
                                      ? ElevatedButton(
                                          onPressed: () => _addToCart(product),
                                          style: ElevatedButton.styleFrom(
                                            //backgroundColor: Colors.grey,
                                          ),
                                            child: Icon(
                                            Icons.shopping_cart,
                                            color: Theme.of(context).brightness == Brightness.dark
                                              ? Colors.black
                                              : Colors.white,
                                            ),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            IconButton(
                                              onPressed: () => _updateQuantity(product, -1),
                                              icon: const Icon(Icons.remove),
                                            ),
                                            Text(
                                              '$quantity',
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
                  );
                },
              ),
              // Left Arrow Button
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.black.withOpacity(0.0)), // Transparent icon
                  onPressed: () {
                    scrollController.animateTo(
                      scrollController.offset - 250, // Scroll left by 250 pixels
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
                  icon: Icon(Icons.arrow_forward, color: Colors.black.withOpacity(0.0)), // Transparent icon
                  onPressed: () {
                    scrollController.animateTo(
                      scrollController.offset + 250, // Scroll right by 250 pixels
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
  }
}

