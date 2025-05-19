import 'package:flutter/material.dart';
//import '../tabs/home_tab.dart';
import '../tabs/store_tab.dart';
import '../tabs/profile_tab.dart';
import '../tabs/cart_tab.dart';
import '../tabs/discover_tab.dart';
import '../tabs/notifications_tab.dart'; // Import the NotificationsTab widget
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../theme_notifier.dart'; // Import ThemeNotifier
import 'dart:html' as html;

class SellerHome extends StatefulWidget {
  const SellerHome({super.key});

  @override
  State<SellerHome> createState() => _SellerHomeState();
}

class _SellerHomeState extends State<SellerHome> {
  int _selectedIndex = 0;
  int _cartItemCount = 0; // Track the number of items in the cart
  int _unreadNotificationCount = 0; // Track the number of unread notifications
  StreamSubscription<DocumentSnapshot>? _cartSubscription; // Firestore listener for cart
  StreamSubscription<QuerySnapshot>? _notificationSubscription; // Firestore listener for notifications

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    html.document.title = 'Sunset Marketplace'; // Set your desired title
    _listenToCartCount();
    _listenToUnreadNotifications();
    _pages.addAll([
      const DiscoverTab(),
      CartTab(onCartItemCountChanged: _updateCartItemCount), // Pass callback to CartTab
      const StoreTab(),
      const NotificationsTab(),
      const ProfileTab(),
    ]);
  }

  @override
  void dispose() {
    _cartSubscription?.cancel(); // Cancel Firestore listener for cart
    _notificationSubscription?.cancel(); // Cancel Firestore listener for notifications
    super.dispose();
  }

  void _listenToCartCount() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      _cartSubscription = FirebaseFirestore.instance
          .collection('carts')
          .doc(userId)
          .snapshots()
          .listen((cartDoc) {
        if (cartDoc.exists) {
          final cartData = cartDoc.data();
          final items = List<Map<String, dynamic>>.from(cartData?['items'] ?? []);
          int totalItems = 0;
          for (var item in items) {
            totalItems += (item['quantity'] as num).toInt();
          }
          if (mounted) {
            setState(() {
              _cartItemCount = totalItems;
            });
          }
        }
      });
    }
  }

  void _listenToUnreadNotifications() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      _notificationSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('read', isEqualTo: false) // Only listen to unread notifications
          .snapshots()
          .listen((querySnapshot) {
        if (mounted) {
          setState(() {
            _unreadNotificationCount = querySnapshot.docs.length;
          });
        }
      });
    }
  }

  void _updateCartItemCount(int count) {
    if (mounted) {
      setState(() {
        _cartItemCount = count; // Update the cart item count
      });
    }
  }

  void _onItemTapped(int index) {
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    
  // Always set the title on every build
    html.document.title = 'Sunset Marketplace';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sunset Preview'),
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeNotifier.themeMode,
            builder: (context, mode, _) => IconButton(
             icon: Icon(
               mode == ThemeMode.light ? Icons.dark_mode : Icons.light_mode,
              ),
               onPressed: () {
                ThemeNotifier.toggleTheme();
              },
            ),
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.black,
        backgroundColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome),
            label: 'Discover',
            backgroundColor: Colors.grey,
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.shopping_cart),
                if (_cartItemCount > 0) // Show badge only if there are items
                  Positioned(
                    right: 0,
                    top: 1,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.grey,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_cartItemCount',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Cart',
            backgroundColor: Colors.grey,
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.store),
            label: 'Store',
            backgroundColor: Colors.grey,
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.notifications),
                if (_unreadNotificationCount > 0) // Show badge only if there are unread notifications
                  Positioned(
                    right: 0,
                    top: 1,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.grey,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_unreadNotificationCount',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Notifications',
            backgroundColor: Colors.grey,
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
            backgroundColor: Colors.grey,
          ),
        ],
      ),
    );
  }
}

