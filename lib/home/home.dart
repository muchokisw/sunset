import 'package:flutter/material.dart';
import 'dart:html' as html;
import '../auth/sign_in.dart'; // Import the sign-in page
//import '../auth/sign_up.dart'; // Import the sign-up page
import '../tabs/home_tab.dart'; // Import the HomeTab widget
import '../tabs/about_tab.dart'; // Import the AboutTab widget
import '../tabs/contact_tab.dart'; // Import the ContactTab widget
import '../theme_notifier.dart'; // Import ThemeNotifier

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // List of widgets for each tab
  final List<Widget> _pages = [
    const HomeTab(), // Home tab
    const AboutTab(), // About tab
    const ContactTab(), // Contact tab
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    //html.document.title = 'Sunset Marketplace'; // Set your desired title
  }

  @override
  Widget build(BuildContext context) {
    
    // Always set the title on every build
    html.document.title = 'Sunset Marketplace';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sunset Preview'), // Updated title
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SignIn()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black, // Button background color
              foregroundColor: Colors.grey, // Button text color
              elevation: 2, // Add slight elevation
            ),
            child: const Text('Sign In'),
          ),
          const SizedBox(width: 8), // Add spacing between buttons
          /*ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NormalSignup()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black, // Button background color
              foregroundColor: Colors.grey, // Button text color
              elevation: 2, // Add slight elevation
            ),
            child: const Text('Sign Up'),
          ),
          const SizedBox(width: 8),*/ // Add spacing between buttons
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
      body: _pages[_selectedIndex], // Display the selected page
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.shifting, // Set the type to shifting
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.white, // Color for selected icons
        unselectedItemColor: Colors.black, // Color for unselected icons
        backgroundColor: Colors.grey, // Background color of the bar
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
            backgroundColor: Colors.grey, // Background color of the bar
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.lightbulb),
            label: 'About',
            backgroundColor: Colors.grey, // Background color of the bar
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mail),
            label: 'Contact',
            backgroundColor: Colors.grey, // Background color of the bar
          ),
        ],
      ),
    );
  }
}