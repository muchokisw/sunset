import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Import intl package
import '../theme_notifier.dart'; // Import ThemeNotifier
import '../view/view_product.dart'; // Import ViewProduct page
import 'dart:html' as html; // Import for setting the title

class CheckOut extends StatefulWidget {
  const CheckOut({super.key});

  @override
  State<CheckOut> createState() => _CheckOutState();
}

class _CheckOutState extends State<CheckOut> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _orderItems = [];
  double _totalPrice = 0.0;
  int _totalItems = 0;
  double _deliveryCost = 5.0; // Fixed delivery cost

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  String formatPrice(num price) {
    final formatter = NumberFormat('#,##0');
    return formatter.format(price);
  }

  Future<void> _loadOrderDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in to proceed with checkout.')),
          );
        }
        return;
      }

      // Fetch cart data
      final cartDoc = await _firestore.collection('carts').doc(userId).get();
      if (!cartDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your cart is empty.')),
          );
        }
        return;
      }

      final cartData = cartDoc.data();
      final cartItems = List<Map<String, dynamic>>.from(cartData?['items'] ?? []);
      if (cartItems.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your cart is empty.')),
          );
        }
        return;
      }

      double totalPrice = 0.0;
      double totalDeliveryCost = 0.0; // Initialize total delivery cost
      int totalItems = 0;
      final List<Map<String, dynamic>> orderItems = [];

      for (var item in cartItems) {
        final productDoc = await _firestore.collection('products').doc(item['productId']).get();
        if (productDoc.exists) {
          final productData = productDoc.data();
          final price = productData?['price'] ?? 0.0;
          final deliveryCost = productData?['deliveryCost'] ?? 0.0; // Fetch delivery cost for the product
          final quantity = (item['quantity'] as num).toInt(); // Explicitly cast to int
          totalPrice += price * quantity;
          totalDeliveryCost += deliveryCost * quantity; // Add delivery cost for the product
          totalItems += quantity;

          orderItems.add({
            'productId': item['productId'],
            'quantity': quantity,
            'price': price,
            'deliveryCost': deliveryCost, // Include delivery cost in the item details
            'name': productData?['name'],
            'description': productData?['description'], // Include description in the product map
            'images': productData?['images'],
          });
        }
      }

      if (mounted) {
        setState(() {
          _orderItems = orderItems;
          _totalPrice = totalPrice;
          _totalItems = totalItems;
          _deliveryCost = totalDeliveryCost; // Update total delivery cost
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading order details: ${e.toString()}')),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _placeOrder() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in to place an order.')),
          );
        }
        return;
      }

      // Fetch user's delivery address
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      final deliveryAddress = userData?['deliveryAddress'] ?? 'No address provided';

      // Calculate delivery date based on the maximum delivery time of products
      int maxDeliveryTime = 0;
      for (var item in _orderItems) {
        final productDoc = await _firestore.collection('products').doc(item['productId']).get();
        if (productDoc.exists) {
          final productData = productDoc.data();
          final deliveryTime = productData?['deliveryTime'] ?? 0;
          maxDeliveryTime = deliveryTime > maxDeliveryTime ? deliveryTime : maxDeliveryTime;
        }
      }
      final deliveryDate = DateTime.now().add(Duration(days: maxDeliveryTime));
      final formattedDeliveryDate = '${deliveryDate.year}-${deliveryDate.month.toString().padLeft(2, '0')}-${deliveryDate.day.toString().padLeft(2, '0')}'; // Format the date

      // Create order
      final orderId = _firestore.collection('orders').doc().id;
      await _firestore.collection('orders').doc(orderId).set({
        'orderId': orderId,
        'userId': userId,
        'items': _orderItems,
        'deliveryCost': _deliveryCost,
        'totalCost': _totalPrice + _deliveryCost,
        'status': 'Pending',
        'deliveryDate': formattedDeliveryDate, // Use the formatted date
        'deliveryAddress': deliveryAddress,
        'paymentId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Clear cart
      await _firestore.collection('carts').doc(userId).update({
        'items': [],
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order placed successfully!')),
        );

        // Navigate back or to a confirmation page
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error placing order: ${e.toString()}')),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Always set the title on every build
    html.document.title = 'Sunset Marketplace';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
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
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // Order Items List
                  Expanded(
                    child: ListView.builder(
                      itemCount: _orderItems.length,
                      itemBuilder: (context, index) {
                        final item = _orderItems[index];
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 800), // Limit card width to 800
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Card(
                                elevation: 4,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ViewProduct(product: item),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Product Image
                                        if (item['images'] != null && item['images'].isNotEmpty)
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8.0),
                                            child: Image.network(
                                              item['images'][0],
                                              height: 100,
                                              width: 100,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        const SizedBox(width: 16),
                                        // Product Details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['name'] ?? 'N/A',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${formatPrice(item['price']?.toInt() ?? 0)}/-', // Format price with commas
                                                style: const TextStyle(fontSize: 14),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Quantity: ${item['quantity']}',
                                                style: const TextStyle(fontSize: 14),
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
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Order Summary Card
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800, minWidth: 500),
                      child: Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                'Order Summary',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text('Items: $_totalItems', style: const TextStyle(fontSize: 14)),
                              Text(
                                'Price: ${formatPrice(_totalPrice.toInt())}/-', // Format total price with commas
                                style: const TextStyle(fontSize: 14),
                              ),
                              Text(
                                'Delivery Cost: ${formatPrice(_deliveryCost.toInt())}/-', // Format delivery cost with commas
                                style: const TextStyle(fontSize: 14),
                              ),
                              Text(
                                'Total Cost: ${formatPrice((_totalPrice + _deliveryCost).toInt())}/-', // Format total cost with commas
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _placeOrder,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 12.0),
                                ),
                                child: const Text('Place Order', style: TextStyle(fontSize: 14)),
                              ),
                              const SizedBox(height: 16),
                              // Add Google Pay Button
                            ],
                          ),
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