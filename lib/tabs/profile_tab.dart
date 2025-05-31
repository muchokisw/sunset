import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../edit/edit_profile.dart';
import '../home/home.dart'; // Import your HomeScreen widget
import 'dart:html' as html;
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
  String _deliveryAddress = '';
  String? _photoUrl;
  String _country = '';
  String _city = '';
  DateTime? _dateOfBirth;

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
          _deliveryAddress = userData['deliveryAddress'] ?? '';
          _photoUrl = userData['photo'];
          _country = userData['country'] ?? '';
          _city = userData['city'] ?? '';
          final dob = userData['dateOfBirth'];
          if (dob != null && dob is String && dob.isNotEmpty) {
            _dateOfBirth = DateTime.tryParse(dob);
          } else {
            _dateOfBirth = null;
          }
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
          address: _deliveryAddress,
          photoUrl: _photoUrl,
          country: _country,
          city: _city,
          dateOfBirth: _dateOfBirth ?? DateTime(2000, 1, 1),
        ),
      ),
    ).then((_) {
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
    // Always set the title on every build
    html.document.title = 'Sunset Marketplace';
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
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              if (_photoUrl != null) {
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    return Dialog(
                                      insetPadding: const EdgeInsets.all(16),
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 600,
                                          maxHeight: 400,
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: _photoUrl != null
                                              ? Image.network(
                                                  _photoUrl!,
                                                  fit: BoxFit.contain,
                                                )
                                              : const Icon(
                                                  Icons.person,
                                                  size: 100,
                                                  color: Colors.grey,
                                                ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }
                            },
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey[300],
                              backgroundImage: _photoUrl != null
                                  ? NetworkImage(_photoUrl!) as ImageProvider
                                  : null,
                              child: _photoUrl == null
                                  ? const Icon(Icons.person, size: 50, color: Colors.grey)
                                  : null,
                            ),
                          ),
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
                          title: const Text('Delivery Address:'),
                          subtitle: Text(_deliveryAddress),
                        ),
                        ListTile(
                          title: const Text('Country:'),
                          subtitle: Text(_country),
                        ),
                        ListTile(
                          title: const Text('City:'),
                          subtitle: Text(_city),
                        ),
                        ListTile(
                          title: const Text('Date of Birth:'),
                          subtitle: Text(
                            _dateOfBirth != null
                                ? "${_dateOfBirth!.toLocal()}".split(' ')[0]
                                : '',
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _navigateToEditProfilePage,
                          style: ElevatedButton.styleFrom(
                            //backgroundColor: Colors.grey,
                            //foregroundColor: Colors.black,
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