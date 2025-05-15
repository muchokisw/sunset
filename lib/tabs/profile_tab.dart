import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../edit/edit_profile.dart';
import '../home/home.dart'; // Import your HomeScreen widget
//import 'open_store.dart';
//import 'edit_store.dart';
//import 'add_product.dart';
//import 'edit_product.dart';
//import 'home_tab.dart';
//import 'store_tab.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _auth = FirebaseAuth.instance;
  String _name = '';
  String _email = '';
  String _phone = '';
  String _deliveryAddress = ''; // Updated to use deliveryAddress
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data();
      if (userData != null) {
        if (!mounted) return;
        setState(() {
          _name = userData['name'] ?? '';
          _email = userData['email'] ?? '';
          _phone = userData['phone'] ?? '';
          _deliveryAddress = userData['deliveryAddress'] ?? ''; // Fetch deliveryAddress
          _photoUrl = userData['photo'];
        });
      }
    }
  }

  void _navigateToEditProfilePage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilePage(
          name: _name,
          phone: _phone,
          address: _deliveryAddress, // Pass deliveryAddress to EditProfilePage
          photoUrl: _photoUrl,
        ),
      ),
    ).then((_) {
      // Reload profile data after returning from the Edit Profile page
      _loadUserData();
    });
  }

  Future<void> _logout() async {
    try {
      await _auth.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()), // Replace with your HomeScreen widget
        (route) => false, // Remove all previous routes
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
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
                      children: [
                        const Text(
                          'Profile',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundImage: _photoUrl != null
                                  ? NetworkImage(_photoUrl!)
                                  : null,
                            ),
                            if (_photoUrl != null)
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
                                                maxWidth: 600, // Limit width to 600
                                                maxHeight: 300, // Limit height to 300
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: Image.network(
                                                  _photoUrl!,
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return const Icon(Icons.error, size: 50);
                                                  },
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
                          title: const Text('Name:'),
                          subtitle: Text(_name),
                        ),
                        ListTile(
                          title: const Text('Email:'),
                          subtitle: Text(_email),
                        ),
                        ListTile(
                          title: const Text('Phone:'),
                          subtitle: Text(_phone),
                        ),
                        ListTile(
                          title: const Text('Delivery Address:'), // Updated label
                          subtitle: Text(_deliveryAddress), // Display deliveryAddress
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _navigateToEditProfilePage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Edit Profile'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: _logout,
            child: const Text('Logout'),
          ),
        ),
      ],
    );
  }
}