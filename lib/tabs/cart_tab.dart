import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../view/view_product.dart'; // Import the ViewProduct page
import 'dart:async'; // Import for StreamSubscription
import '../add/check_out.dart'; // Import the CheckOut page
import 'package:intl/intl.dart'; // Import intl package

String formatPrice(num price) {
  final formatter = NumberFormat('#,##0');
  return formatter.format(price);
}

class CartTab extends StatefulWidget {
  final Function(int) onCartItemCountChanged; // Callback to notify item count changes

  const CartTab({super.key, required this.onCartItemCountChanged});

  @override
  State<CartTab> createState() => _CartTabState();
}

class _CartTabState extends State<CartTab> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<Map<String, dynamic>> _cartItems = [];
  final List<Map<String, dynamic>> _orderItems = []; // List to store order items
  bool _isCartLoading = true;
  bool _isOrdersLoading = true;
  int _totalItems = 0;
  double _totalPrice = 0.0;
  StreamSubscription<DocumentSnapshot>? _cartSubscription;
  late TabController _tabController;
  int _currentPage = 0; // Track the current page for dot indicators
  final PageController _pageController = PageController(); // Controller for PageView

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCart();
    _loadOrders();
  }

  Future<void> _reloadData() async {
    await _loadCart();
    await _loadOrders();
  }

  @override
  void dispose() {
    _cartSubscription?.cancel();
    _tabController.dispose();
    _pageController.dispose(); // Dispose the PageController
    super.dispose();
  }

  Future<void> _loadCart() async {
    setState(() {
      _isCartLoading = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final cartDoc = await _firestore.collection('carts').doc(userId).get();
        if (cartDoc.exists) {
          final cartData = cartDoc.data();
          final items = List<Map<String, dynamic>>.from(cartData?['items'] ?? []);
          double totalPrice = 0.0;
          int totalItems = 0;

          _cartItems.clear();
          for (var item in items) {
            final productDoc = await _firestore
                .collection('products')
                .doc(item['productId'])
                .get();
            if (productDoc.exists) {
              final productData = productDoc.data();
              final quantity = (item['quantity'] as num).toInt();
              totalItems += quantity;
              totalPrice += (productData?['price'] ?? 0.0) * quantity;

              _cartItems.add({
                'productId': item['productId'],
                'quantity': quantity,
                'name': productData?['name'],
                'price': productData?['price'],
                'images': productData?['images'],
                'description': productData?['description'],
              });
            }
          }

          setState(() {
            _totalItems = totalItems;
            _totalPrice = totalPrice;
          });

          widget.onCartItemCountChanged(_totalItems);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading cart: ${e.toString()}')),
        );
      }
    }

    setState(() {
      _isCartLoading = false;
    });
  }

  Future<void> _updateQuantity(Map<String, dynamic> item, int change) async {
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

        final existingItemIndex =
            items.indexWhere((cartItem) => cartItem['productId'] == item['productId']);

        if (existingItemIndex != -1) {
          // Update quantity
          items[existingItemIndex]['quantity'] += change;

          if (items[existingItemIndex]['quantity'] <= 0) {
            // Remove item if quantity is 0
            items.removeAt(existingItemIndex);
          }

          await cartRef.update({'items': items, 'updatedAt': FieldValue.serverTimestamp()});
          _cartItems.clear();
          _loadCart(); // Reload cart after updating
        }
      }
    } catch (e) {
      if (!mounted) return; // Check if widget is still mounted before showing
      if (mounted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating cart: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isOrdersLoading = true; // Set loading to true at the start
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final ordersQuery = await _firestore
            .collection('orders')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .get();

        _orderItems.clear();
        for (var orderDoc in ordersQuery.docs) {
          final orderData = orderDoc.data();
          final items = List<Map<String, dynamic>>.from(orderData['items'] ?? []);

          final orderDetails = {
            'orderId': orderDoc.id, // Include the orderId
            'deliveryCost': orderData['deliveryCost'],
            'totalCost': orderData['totalCost'],
            'status': orderData['status'],
            'deliveryDate': orderData['deliveryDate'],
            'deliveryAddress': orderData['deliveryAddress'],
            'items': [],
          };

          for (var item in items) {
            final productDoc = await _firestore
                .collection('products')
                .doc(item['productId'])
                .get();
            if (productDoc.exists) {
              final productData = productDoc.data();
              orderDetails['items'].add({
                'productId': item['productId'],
                'quantity': item['quantity'],
                'price': item['price'],
                'name': productData?['name'],
                'images': productData?['images'],
              });
            }
          }

          _orderItems.add(orderDetails);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading orders: ${e.toString()}')),
      );
    }

    if (!mounted) return; // Check if widget is still mounted before updating state
    setState(() {
      _isOrdersLoading = false; // Set loading to false after orders are fetched
    });
  }

  Future<void> _cancelOrder(String orderId) async {
  try {
    await _firestore.collection('orders').doc(orderId).update({
      'status': 'Cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order cancelled successfully.')),
    );

    // Reload orders after cancelling
    _loadOrders();
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error cancelling order: ${e.toString()}')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // TabBar without AppBar
          Container(
            color: Theme.of(context).brightness == Brightness.dark 
            ? Colors.black : Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).brightness == Brightness.dark 
              ? Colors.white : Colors.black,
              unselectedLabelColor: Theme.of(context).brightness == Brightness.dark 
              ? Colors.white : Colors.black,
              indicatorColor: Theme.of(context).brightness == Brightness.dark 
              ? Colors.white : Colors.black,
              indicatorWeight: 3.0,
              tabs: const [
                Tab(text: 'Cart'),
                Tab(text: 'Orders'),
              ],
            ),
          ),
          // TabBarView for the tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // Cart Tab
                _isCartLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _cartItems.isEmpty
                        ? const Center(
                            child: Text(
                              'Your Cart is Empty',
                              style: TextStyle(fontSize: 16),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Cart Items
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: _cartItems.length,
                                    itemBuilder: (context, index) {
                                      final item = _cartItems[index];

                                      return Center(
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(maxWidth: 800),
                                          child: GestureDetector(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => ViewProduct(product: item),
                                                ),
                                              );
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                                              child: Card(
                                                elevation: 4,
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
                                                              '${formatPrice(item['price']?.toInt() ?? 0)}/-', // Remove decimals and add /- at the end
                                                              style: const TextStyle(fontSize: 14),
                                                            ),
                                                            const SizedBox(height: 8),
                                                            // Quantity Controls
                                                            Row(
                                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                              children: [
                                                                IconButton(
                                                                  onPressed: () => _updateQuantity(item, -1),
                                                                  icon: const Icon(Icons.remove),
                                                                ),
                                                                Text(
                                                                  '${item['quantity']}',
                                                                  style: const TextStyle(fontSize: 14),
                                                                ),
                                                                IconButton(
                                                                  onPressed: () => _updateQuantity(item, 1),
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
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Total Items and Price in a Card
                                Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 800, minWidth: 500),
                                    child: Card(
                                      elevation: 4,
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.center, // Center content horizontally
                                          children: [
                                            // Centered Cart Icon and Text
                                            const Center(
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min, // Center the row's content
                                                children: [
                                                  Icon(
                                                    Icons.shopping_cart,
                                                    size: 24,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'Your Cart',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            // Total Items and Price
                                            Text(
                                              'Items: $_totalItems',
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                            Text(
                                              'Price: ${formatPrice(_totalPrice.toInt())}/-', // Remove decimals and add /- at the end
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                            const SizedBox(height: 16),
                                            // Centered Checkout Button
                                            ElevatedButton(
                                              onPressed: () async {
                                                await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => const CheckOut(),
                                                  ),
                                                );
                                                // Reload cart and orders after returning from checkout
                                                _reloadData();
                                              },
                                              style: ElevatedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 12.0),
                                              ),
                                              child: const Text(
                                                'Checkout',
                                                style: TextStyle(fontSize: 14),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                // Orders Tab
                _isOrdersLoading
                    ? const Center(child: CircularProgressIndicator(),)
                    : _orderItems.isEmpty
                        ? const Center(
                            child: Text(
                              'No Orders Found',
                              style: TextStyle(fontSize: 16),
                            ),
                          )
                        : Column(
                            children: [
                              // Spacing between Tab Bar and Dot Indicators
                              const SizedBox(height: 24),
                              // Dot Indicators at the Top
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  _orderItems.length,
                                  (index) => GestureDetector(
                                    onTap: () {
                                      if (_pageController.hasClients) {
                                        _pageController.animateToPage(
                                          index,
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                        );
                                      }
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _currentPage == index
                                          ? (Theme.of(context).brightness == Brightness.dark 
                                          ? Colors.white : Colors.black)
                                          : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: PageView.builder(
                                  controller: _pageController,
                                  itemCount: _orderItems.length,
                                  onPageChanged: (index) {
                                    setState(() {
                                      _currentPage = index;
                                    });
                                  },
                                  itemBuilder: (context, orderIndex) {
                                    final order = _orderItems[orderIndex];
                                    return Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Items in the Order
                                          Expanded(
                                            child: ListView.builder(
                                              itemCount: order['items'].length,
                                              itemBuilder: (context, itemIndex) {
                                                final item = order['items'][itemIndex];
                                                return Center(
                                                  child: ConstrainedBox(
                                                    constraints: const BoxConstraints(maxWidth: 800),
                                                    child: GestureDetector(
                                                      onTap: () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) => ViewProduct(product: item),
                                                          ),
                                                        );
                                                      },
                                                      child: Padding(
                                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                                        child: Card(
                                                          elevation: 4,
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
                                                                        '${formatPrice(item['price']?.toInt() ?? 0)}/-', // Remove decimals and add /- at the end
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
                                          // Delivery Information Card
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
                                                      const Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Icon(Icons.local_shipping, size: 20),
                                                          SizedBox(width: 8),
                                                          Text(
                                                            'Delivery Information',
                                                            style: TextStyle(
                                                              fontSize: 16,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        'Delivery Cost: ${formatPrice(order['deliveryCost'].toInt())}/-', // Remove decimals and add /- at the end
                                                        style: const TextStyle(fontSize: 14),
                                                      ),
                                                      Text(
                                                        'Total Cost: ${formatPrice(order['totalCost'].toInt())}/-', // Remove decimals and add /- at the end
                                                        style: const TextStyle(fontSize: 14),
                                                      ),
                                                      Text(
                                                        'Delivery Date: ${order['deliveryDate'] ?? 'N/A'}',
                                                        style: const TextStyle(fontSize: 14),
                                                      ),
                                                      Text(
                                                        'Delivery Address: ${order['deliveryAddress'] ?? 'N/A'}',
                                                        style: const TextStyle(fontSize: 14),
                                                      ),
                                                      Text(
                                                        'Status: ${order['status']}',
                                                        style: const TextStyle(fontSize: 14),
                                                      ),
                                                      const SizedBox(height: 16),
                                                      // Cancel Order Button
                                                      if (order['status'] != 'Delivered')
                                                        ElevatedButton(
                                                          onPressed: () async {
                                                            await _cancelOrder(order['orderId']);
                                                          },
                                                          style: ElevatedButton.styleFrom(
                                                            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 12.0),
                                                          ),
                                                          child: const Text(
                                                            'Cancel Order',
                                                            style: TextStyle(fontSize: 14),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
