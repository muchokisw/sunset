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
    html.document.title = 'Sunset Marketplace';

    final isWideScreen = MediaQuery.of(context).size.width > 850;
    final isSmallScreen = MediaQuery.of(context).size.width < 850;

    return Scaffold(
      appBar: AppBar(
        title: isSmallScreen
            ? const Text(' ')
            : const Text('Sunset Preview'), // Blank title for small screens
        actions: [
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SignIn()),
              );
            },
            style: ElevatedButton.styleFrom(
              //backgroundColor: Colors.grey, // Button background color
              //foregroundColor: Colors.black, // Button text color
              elevation: 2, // Add slight elevation
            ),
            child: const Text(
              'Sign In',
              //style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          
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
          const SizedBox(width: 16),
           // Add spacing between buttons
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
        ],
      ),
      body: Row(
        children: [
          if (isWideScreen)
            Theme(
              data: Theme.of(context).copyWith(
                focusColor: Theme.of(context).brightness == Brightness.light
                    ? Colors.grey[400] // Light theme focus color
                    : Colors.grey[600], // Dark theme focus color
              ),
              child: NavigationRail(
                leading: const SizedBox(height: 5), // <-- Add this line for spacing
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onItemTapped,
                labelType: NavigationRailLabelType.all,
                backgroundColor: Theme.of(context).brightness == Brightness.light
                    ? Colors.white 
                    : Colors.black,
                indicatorColor: Theme.of(context).brightness == Brightness.light
                    ? Colors.grey[200] // Light theme indicator
                    : Colors.grey[900], // Dark theme indicator
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
                  //fontWeight: FontWeight.bold,
                ),
                unselectedLabelTextStyle: TextStyle(
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.grey
                      : Colors.grey[400],
                ),
                destinations: const [
                  NavigationRailDestination(
                    icon: Tooltip(
                      message: 'Home',
                      child: Icon(Icons.home),
                    ),
                    label: Text(''),
                  ),
                  NavigationRailDestination(
                    icon: Tooltip(
                      message: 'About',
                      child: Icon(Icons.lightbulb),
                    ),
                    label: Text(''),
                  ),
                  NavigationRailDestination(
                    icon: Tooltip(
                      message: 'Contact',
                      child: Icon(Icons.mail),
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
                      const Icon(Icons.home),
                      if (_selectedIndex == 0)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 24,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.light
                                ? Colors.grey[200] // Same as NavigationRail indicator
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
                      const Icon(Icons.lightbulb),
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
                      const Icon(Icons.mail),
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
              ],
            ),
    );
  }
}