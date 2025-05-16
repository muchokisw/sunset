import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../add/add_category.dart';
import '../edit/edit_category.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _selectedIndex = 0;

  // Pages for each tab
  final List<Widget> _pages = [
    const Center(child: Text('Manage Users')), // Users tab content
    const Center(child: Text('Manage Stores')), // Stores tab content
    const ProductsPage(), // Products tab with subtabs
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home'); // Redirect to home page
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Home'),
        actions: [
          TextButton(
            onPressed: () async {
              await _signOut();
            },
            child: const Text(
              'Sign Out',
              //style: TextStyle(color: Colors.white), // White text for visibility
            ),
          ),
        ],
      ),
      body: _pages[_selectedIndex], // Display the selected tab's content
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.white, // Color for selected icons
        unselectedItemColor: Colors.black, // Color for unselected icons
        backgroundColor: Colors.grey, // Background color of the bar
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store),
            label: 'Stores',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Products',
          ),
        ],
      ),
    );
  }
}

class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2, // Two subtabs: Categories and Products
      child: Scaffold(
        backgroundColor: Colors.white, // Set the background color to white
        body: Column(
          children: [
            TabBar(
              labelColor: Colors.black, // Text color for selected items
              unselectedLabelColor: Colors.black, // Text color for unselected items
              indicatorColor: Colors.black, // Indicator color for the selected tab
              tabs: [
                Tab(text: 'Categories'),
                Tab(text: 'Products'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  CategoriesTab(), // Categories subtab content
                  ProductsTab(), // Products subtab content
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoriesTab extends StatefulWidget {
  const CategoriesTab({super.key});

  @override
  State<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<CategoriesTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch categories from Firestore
      final categoriesQuery = await _firestore.collection('categories').get();
      final categories = categoriesQuery.docs.map((doc) => doc.data()).toList();

      setState(() {
        _categories = List<Map<String, dynamic>>.from(categories);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading categories: ${e.toString()}')),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_categories.isEmpty) {
      return const Center(
        child: Text('No categories found.'),
      );
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 600, // Limit the width of the category list to 600 pixels
          ),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              return Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  leading: category['image'] != null && category['image'].isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            category['image'],
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(Icons.category, size: 50),
                  title: Text(category['name'] ?? 'N/A'),
                  subtitle: Text(category['description'] ?? 'No description available.'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditCategoryPage(
                          categoryId: category['categoryId'],
                          categoryDetails: category,
                        ),
                      ),
                    ).then((_) {
                      // Reload categories after returning from the Edit Category page
                      _loadCategories();
                    });
                  },
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddCategoryPage(),
            ),
          ).then((_) {
            // Reload categories after returning from the Add Category page
            _loadCategories();
          });
        },
        backgroundColor: Colors.grey,
        tooltip: 'Add Category',
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}

class ProductsTab extends StatelessWidget {
  const ProductsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Manage Products',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}