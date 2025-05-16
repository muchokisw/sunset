import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
//import 'edit_profile.dart';
import '../add/open_store.dart';
import '../edit/edit_store.dart';
import '../add/add_product.dart';
import '../edit/edit_product.dart';
//import 'home_tab.dart';

class StoreTab extends StatefulWidget {
  const StoreTab({super.key});

  @override
  State<StoreTab> createState() => _StoreTabState();
}

class _StoreTabState extends State<StoreTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
                Tab(text: 'Store Profile'),
                Tab(text: 'Products'),
              ],
            ),
          ),
          // TabBarView for the tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                StoreProfileTab(),
                ProductsTab(),
              ],
            ),
          ),
        ],
      ),
      // Floating Action Button for the Products tab
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddProductPage(),
                  ),
                ).then((_) {
                  // Reload products after returning from the Add Product page
                  if (mounted) {
                    setState(() {});
                  }
                });
              },
              backgroundColor: Colors.grey,
              tooltip: 'Add Product',
              heroTag: 'addProductFAB',
              child: const Icon(Icons.add, color: Colors.black),
            )
          : null,
    );
  }
}

class StoreProfileTab extends StatefulWidget {
  const StoreProfileTab({super.key});

  @override
  State<StoreProfileTab> createState() => _StoreProfileTabState();
}

class _StoreProfileTabState extends State<StoreProfileTab> {
  final _auth = FirebaseAuth.instance;
  String? _storeId;
  Map<String, dynamic>? _storeDetails;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStoreData();
  }

  Future<void> _loadStoreData() async {
    if (!mounted) return; // Ensure the widget is still in the tree
    setState(() {
      _isLoading = true;
    });

    final user = _auth.currentUser;
    if (user != null) {
      // Fetch the user's storeId from the users collection
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data();

      if (userData != null && userData['storeId'] != null) {
        final storeId = userData['storeId'];

        // Fetch the store details from the stores collection
        final storeDoc = await FirebaseFirestore.instance.collection('stores').doc(storeId).get();
        final storeData = storeDoc.data();

        if (storeData != null) {
          if (!mounted) return; // Ensure the widget is still in the tree
          setState(() {
            _storeId = storeId;
            _storeDetails = storeData;
          });
        }
      } else {
        if (!mounted) return; // Ensure the widget is still in the tree
        setState(() {
          _storeId = null;
        });
      }
    }

    if (!mounted) return; // Ensure the widget is still in the tree
    setState(() {
      _isLoading = false;
    });
  }

  void _navigateToEditStorePage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditStorePage(
          storeId: _storeId!,
          storeDetails: _storeDetails!,
        ),
      ),
    ).then((_) {
      // Reload store data after returning from the Edit Store page
      _loadStoreData();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_storeId != null && _storeDetails != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 600,
          ),
          child: Card(
            elevation: 4,
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Store Details',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    // Display the banner with tap-to-view functionality
                    if (_storeDetails!['banner'] != null &&
                        _storeDetails!['banner'] is String &&
                        _storeDetails!['banner'] != '')
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return Dialog(
                                insetPadding: const EdgeInsets.all(16),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 600,
                                    maxHeight: 300,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      _storeDetails!['banner'] as String,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _storeDetails!['banner'] as String,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 50,
                            backgroundColor: Theme.of(context).brightness == Brightness.dark 
                              ? Colors.grey[900] 
                              : Colors.white,
                          backgroundImage: _storeDetails!['logo'] != null &&
                                  _storeDetails!['logo'] is String &&
                                  _storeDetails!['logo'] != ''
                              ? NetworkImage(_storeDetails!['logo'] as String)
                              : null,
                          child: _storeDetails!['logo'] == null || _storeDetails!['logo'] == ''
                              ? null // Show nothing while the logo is loading
                              : null,
                        ),
                        if (_storeDetails!['logo'] != null && _storeDetails!['logo'] != '')
                          Positioned.fill(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      return Dialog(
                                        insetPadding: const EdgeInsets.all(16),
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 600,
                                            maxHeight: 300,
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.network(
                                              _storeDetails!['logo'],
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                                borderRadius: BorderRadius.circular(50),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Store Name:'),
                      subtitle: Text(_storeDetails!['name'] ?? 'N/A'),
                    ),
                    ListTile(
                      title: const Text('Description:'),
                      subtitle: Text(_storeDetails!['description'] ?? 'N/A'),
                    ),
                    ListTile(
                      title: const Text('Location:'),
                      subtitle: Text(
                        _storeDetails!['location'] != null
                            ? '${_storeDetails!['location']['city'] ?? 'Unknown City'}, ${_storeDetails!['location']['country'] ?? 'Unknown Country'}'
                            : 'N/A',
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: ElevatedButton(
                        onPressed: _navigateToEditStorePage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Edit Store'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      // User has not opened a store, show the "Open Store" button
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const OpenStorePage()),
                ).then((_) {
                  // Reload store data after returning from the Open Store page
                  _loadStoreData();
                });
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Open Store',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }
  }
}

class ProductsTab extends StatefulWidget {
  const ProductsTab({super.key});

  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  final _auth = FirebaseAuth.instance;
  String? _storeId;
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Fetch the user's storeId from the users collection
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final userData = userDoc.data();

        if (userData != null && userData['storeId'] != null) {
          _storeId = userData['storeId'];

          // Fetch products associated with the storeId
          final productsQuery = await FirebaseFirestore.instance
              .collection('products')
              .where('storeId', isEqualTo: _storeId)
              .get();

          setState(() {
            _products = productsQuery.docs.map((doc) => doc.data()).toList();
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading products: ${e.toString()}')),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _viewProductDetails(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) {
        int currentIndex = 0;
        final PageController pageController = PageController();

        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 600,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image carousel with PageView
                        if (product['images'] != null && product['images'].isNotEmpty)
                          Column(
                            children: [
                              SizedBox(
                                height: 200,
                                child: PageView.builder(
                                  controller: pageController,
                                  itemCount: product['images'].length,
                                  onPageChanged: (index) {
                                    setState(() {
                                      currentIndex = index;
                                    });
                                  },
                                  itemBuilder: (context, index) {
                                    return GestureDetector(
                                      onTap: () {
                                        // Open full-screen view on tapping the image
                                        showDialog(
                                          context: context,
                                          builder: (context) {
                                            return Dialog(
                                              insetPadding: const EdgeInsets.all(16),
                                              child: ConstrainedBox(
                                                constraints: const BoxConstraints(
                                                  maxWidth: 600,
                                                  maxHeight: 300,
                                                ),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: Image.network(
                                                    product['images'][index],
                                                    fit: BoxFit.contain,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          product['images'][index],
                                          height: 200,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Dots indicator with click functionality
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  product['images'].length,
                                  (index) => GestureDetector(
                                    onTap: () {
                                      // Move to the selected page when a dot is clicked
                                      pageController.animateToPage(
                                        index,
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                      );
                                      setState(() {
                                        currentIndex = index;
                                      });
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: currentIndex == index
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
                        Text(
                          product['name'] ?? 'N/A',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${product['price']?.toInt() ?? 'N/A'}/-', // Updated price format
                          style: const TextStyle(fontSize: 16),
                        ),
                        Text(
                          product['description'] ?? 'No description available.',
                          style: const TextStyle(fontSize: 16),
                        ),
                        Text(
                          '${product['inventory'] ?? 'N/A'} left',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context); // Close the dialog
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditProductPage(
                                    productId: product['productId'],
                                    productDetails: product,
                                  ),
                                ),
                              ).then((_) {
                                // Reload products after returning from the Edit Product page
                                _loadProducts();
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              foregroundColor: Colors.black,
                            ),
                            child: const Text('Edit Product'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_products.isEmpty) {
      return const Center(
        child: Text('No products found.'),
      );
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 600,
          ),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _products.length,
            itemBuilder: (context, index) {
              final product = _products[index];
              return Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  leading: product['images'] != null && product['images'].isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            product['images'][0],
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(Icons.image, size: 50),
                  title: Text(product['name'] ?? 'N/A'),
                  subtitle: Text('${product['price']?.toInt() ?? 'N/A'}/-'), // Remove decimals and add /- at the end
                  onTap: () => _viewProductDetails(product),
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
              builder: (context) => const AddProductPage(),
            ),
          ).then((_) {
            // Reload products after returning from the Add Product page
            _loadProducts();
          });
        },
        backgroundColor: Colors.grey,
        tooltip: 'Add Product',
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}