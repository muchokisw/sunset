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
    html.document.title = 'Sunset Marketplace';

    final isWideScreen = MediaQuery.of(context).size.width > 850;

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
      body: Row(
        children: [
          if (isWideScreen)
            Theme(
              data: Theme.of(context).copyWith(
                focusColor: Theme.of(context).brightness == Brightness.light
                    ? Colors.grey[400]
                    : Colors.grey[600],
              ),
              child: NavigationRail(
                leading: const SizedBox(height: 5),
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onItemTapped,
                labelType: NavigationRailLabelType.all,
                backgroundColor: Theme.of(context).brightness == Brightness.light
                    ? Colors.white
                    : Colors.black,
                indicatorColor: Theme.of(context).brightness == Brightness.light
                    ? Colors.grey[200]
                    : Colors.grey[900],
                selectedIconTheme: IconThemeData(
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.black
                      : Colors.white,
                  size: 28,
                ),
                unselectedIconTheme: IconThemeData(
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.black
                      : Colors.white,
                  size: 24,
                ),
                selectedLabelTextStyle: TextStyle(
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.black
                      : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelTextStyle: TextStyle(
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.grey
                      : Colors.grey[400],
                ),
                destinations: [
                  const NavigationRailDestination(
                    icon: Tooltip(
                      message: 'Discover',
                      child: Icon(Icons.auto_awesome),
                    ),
                    label: Text(''),
                  ),
                  NavigationRailDestination(
                    icon: Tooltip(
                      message: 'Cart',
                      child: Stack(
                        children: [
                          const Icon(Icons.shopping_cart),
                          if (_cartItemCount > 0)
                            Positioned(
                              right: 0,
                              top: 1,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness == Brightness.light
                                      ? Colors.black
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$_cartItemCount',
                                  style: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.light
                                        ? Colors.white
                                        : Colors.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    label: const Text(''),
                  ),
                  const NavigationRailDestination(
                    icon: Tooltip(
                      message: 'Store',
                      child: Icon(Icons.store),
                    ),
                    label: Text(''),
                  ),
                  NavigationRailDestination(
                    icon: Tooltip(
                      message: 'Notifications',
                      child: Stack(
                        children: [
                          const Icon(Icons.notifications),
                          if (_unreadNotificationCount > 0)
                            Positioned(
                              right: 0,
                              top: 1,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness == Brightness.light
                                      ? Colors.black
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$_unreadNotificationCount',
                                  style: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.light
                                        ? Colors.white
                                        : Colors.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    label: const Text(''),
                  ),
                  const NavigationRailDestination(
                    icon: Tooltip(
                      message: 'Profile',
                      child: Icon(Icons.person),
                    ),
                    label: Text(''),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _pages[_selectedIndex],
          ),
        ],
      ),
      bottomNavigationBar: isWideScreen
          ? null
          : BottomNavigationBar(
              type: BottomNavigationBarType.shifting,
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              selectedItemColor: Theme.of(context).brightness == Brightness.light
                  ? Colors.black
                  : Colors.white,
              unselectedItemColor: Theme.of(context).brightness == Brightness.light
                  ? Colors.black
                  : Colors.white,
              backgroundColor: Theme.of(context).brightness == Brightness.light
                  ? Colors.white
                  : Colors.black,
              items: [
                BottomNavigationBarItem(
                  icon: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome),
                      if (_selectedIndex == 0)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 24,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.light
                                ? Colors.grey[200]
                                : Colors.black,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                    ],
                  ),
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        children: [
                          const Icon(Icons.shopping_cart),
                          if (_cartItemCount > 0)
                            Positioned(
                              right: 0,
                              top: 1,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness == Brightness.light
                                      ? Colors.black
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$_cartItemCount',
                                  style: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.light
                                        ? Colors.white
                                        : Colors.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (_selectedIndex == 1)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 24,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.light
                                ? Colors.grey[200]
                                : Colors.black,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                    ],
                  ),
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.store),
                      if (_selectedIndex == 2)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 24,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.light
                                ? Colors.grey[200]
                                : Colors.black,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                    ],
                  ),
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        children: [
                          const Icon(Icons.notifications),
                          if (_unreadNotificationCount > 0)
                            Positioned(
                              right: 0,
                              top: 1,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness == Brightness.light
                                      ? Colors.black
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$_unreadNotificationCount',
                                  style: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.light
                                        ? Colors.white
                                        : Colors.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (_selectedIndex == 3)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 24,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.light
                                ? Colors.grey[200]
                                : Colors.black,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                    ],
                  ),
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person),
                      if (_selectedIndex == 4)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 24,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.light
                                ? Colors.grey[200]
                                : Colors.black,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                    ],
                  ),
                  label: '',
                ),
              ],
            ),
    );
  }
}

