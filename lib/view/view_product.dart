import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../theme_notifier.dart'; // Import ThemeNotifier
import 'dart:html' as html; // Import for setting the document title

class ViewProduct extends StatefulWidget {
  final Map<String, dynamic> product;

  const ViewProduct({super.key, required this.product});

  @override
  State<ViewProduct> createState() => _ViewProductState();
}

class _ViewProductState extends State<ViewProduct> {
  int _quantity = 0; // Track the quantity of the product in the cart
  bool _isLoading = false;
  int _currentImageIndex = 0; // Track the current image index for the carousel
  final PageController _pageController = PageController(); // Controller for the PageView

  @override
  void initState() {
    super.initState();
    _loadCartQuantity();
    _trackProductView(); // Track the product view
  }

  @override
  void dispose() {
    _pageController.dispose(); // Dispose the PageController
    super.dispose();
  }

  Future<void> _loadCartQuantity() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final cartDoc = await FirebaseFirestore.instance.collection('carts').doc(userId).get();
    if (cartDoc.exists) {
      final cartData = cartDoc.data();
      final items = List<Map<String, dynamic>>.from(cartData?['items'] ?? []);
      final existingItem = items.firstWhere(
        (item) => item['productId'] == widget.product['productId'],
        orElse: () => {},
      );
      if (existingItem.isNotEmpty) {
        setState(() {
          _quantity = existingItem['quantity'];
        });
      }
    }
  }

  Future<void> _addToCart() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add items to your cart.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final cartRef = FirebaseFirestore.instance.collection('carts').doc(userId);
    try {
      final cartDoc = await cartRef.get();
      if (cartDoc.exists) {
        final cartData = cartDoc.data();
        final items = List<Map<String, dynamic>>.from(cartData?['items'] ?? []);
        final existingItemIndex = items.indexWhere((item) => item['productId'] == widget.product['productId']);

        if (existingItemIndex != -1) {
          items[existingItemIndex]['quantity'] += 1;
        } else {
          items.add({'productId': widget.product['productId'], 'quantity': 1});
        }

        await cartRef.update({'items': items, 'updatedAt': FieldValue.serverTimestamp()});
      } else {
        await cartRef.set({
          'userId': userId,
          'items': [
            {'productId': widget.product['productId'], 'quantity': 1}
          ],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      setState(() {
        _quantity += 1;
      });

      if (!mounted) return; // Check if the widget is still mounted
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product added to cart!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding to cart: ${e.toString()}')),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _updateQuantity(int change) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to update your cart.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final cartRef = FirebaseFirestore.instance.collection('carts').doc(userId);
    try {
      final cartDoc = await cartRef.get();
      if (cartDoc.exists) {
        final cartData = cartDoc.data();
        final items = List<Map<String, dynamic>>.from(cartData?['items'] ?? []);
        final existingItemIndex = items.indexWhere((item) => item['productId'] == widget.product['productId']);

        if (existingItemIndex != -1) {
          items[existingItemIndex]['quantity'] += change;

          if (items[existingItemIndex]['quantity'] <= 0) {
            items.removeAt(existingItemIndex);
          }

          await cartRef.update({'items': items, 'updatedAt': FieldValue.serverTimestamp()});
        }

        setState(() {
          _quantity = (_quantity + change).clamp(0, 999); // Ensure quantity is non-negative
        });
      }
    } catch (e) {
      if (!mounted) return; // Check if the widget is still mounted
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating cart: ${e.toString()}')),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _trackProductView() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return; // Skip if the user is not logged in

    final productId = widget.product['productId'];
    final categoryId = widget.product['categoryId']; // Get the categoryId from the product
    final productRef = FirebaseFirestore.instance.collection('products').doc(productId);
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);

    try {
      // Create the viewer object
      final viewer = {
        'userId': userId,
        'createdAt': DateTime.now().toUtc(), // Use a fixed timestamp
        'updatedAt': DateTime.now().toUtc(), // Use a fixed timestamp
      };

      // Add the user to the product's viewers array and increment viewerCount
      await productRef.update({
        'viewers': FieldValue.arrayUnion([viewer]),
        'viewerCount': FieldValue.increment(1),
      });

      // Add the product to the user's recentlyViewed array
      final recentlyViewed = {
        'productId': productId,
        'categoryId': categoryId, // Include the categoryId
        'createdAt': DateTime.now().toUtc(), // Use a fixed timestamp
        'updatedAt': DateTime.now().toUtc(), // Use a fixed timestamp
      };

      await userRef.update({
        'recentlyViewed': FieldValue.arrayUnion([recentlyViewed]),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error tracking product view: ${e.toString()}')),
        );
      }
    }
  }

  /*void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 800,
              //maxHeight: 1000,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }*/

  @override
  Widget build(BuildContext context) {
    // Always set the title on every build
    html.document.title = 'Sunset Marketplace';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product['name'] ?? 'Product Details'),
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeNotifier.themeMode,
            builder: (context, themeMode, child) {
              return IconButton(
               icon: Icon(
              ThemeNotifier.themeMode.value == ThemeMode.light
                  ? Icons.dark_mode
                  : Icons.light_mode,
                ),
                onPressed: () {
                  ThemeNotifier.toggleTheme(); // Toggle the theme
                },
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Card(
                  elevation: 4,
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, // Align content to the left
                        children: [
                          // Image Carousel
                          if (widget.product['images'] != null && widget.product['images'].isNotEmpty)
                            Column(
                              children: [
                                SizedBox(
                                  height: 350, // Fixed height for the carousel
                                  child: PageView.builder(
                                    controller: _pageController, // Use PageController
                                    itemCount: widget.product['images'].length,
                                    onPageChanged: (index) {
                                      setState(() {
                                        _currentImageIndex = index;
                                      });
                                    },
                                    itemBuilder: (context, index) {
                                      return GestureDetector(
                                        //onTap: () => _showImageDialog(widget.product['images'][index]),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.network(
                                            widget.product['images'][index],
                                            height: 350,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Dot Indicators
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    widget.product['images'].length,
                                    (index) => GestureDetector(
                                      onTap: () {
                                        _pageController.animateToPage(
                                          index,
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                        );
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _currentImageIndex == index 
                                          ? (Theme.of(context).brightness == Brightness.dark 
                                          ? Colors.white : Colors.black)
                                          : Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 16),
                          // Product Name
                          Text(
                            widget.product['name'] ?? 'N/A',
                            style: const TextStyle(fontSize: 18, 
                            //fontWeight: FontWeight.bold
                            ),
                          ),
                          // Product Price
                          Text(
                            '${formatPrice(widget.product['price']?.toInt() ?? 0)}/-', // Format price with commas
                            style: const TextStyle(fontSize: 16, 
                            //fontWeight: FontWeight.bold
                            ),
                          ),
                          // Product Description
                          Text(
                            widget.product['description'] ?? '',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 10),
                          // Quantity Controls or Add to Cart Button
                          _quantity == 0
                              ? ElevatedButton(
                                  onPressed: _addToCart,
                                  /*style: ElevatedButton.styleFrom(
                                    //backgroundColor: Colors.grey,
                                    //foregroundColor: Colors.black,
                                  ),*/
                                  child: Icon(
                                        Icons.shopping_cart,
                                          color: Theme.of(context).brightness == Brightness.light
                                          ? Colors.white
                                          : Colors.black,
                                        ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.start, // Align controls to the left
                                  children: [
                                    IconButton(
                                      onPressed: () => _updateQuantity(-1),
                                      icon: const Icon(Icons.remove),
                                    ),
                                    Text(
                                      '$_quantity',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    IconButton(
                                      onPressed: () => _updateQuantity(1),
                                      icon: const Icon(Icons.add),
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
    );
  }
}

String formatPrice(num price) {
  final formatter = NumberFormat('#,##0');
  return formatter.format(price);
}