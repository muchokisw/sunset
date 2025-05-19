import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart'; // Import the generated Firebase options
import 'home/home.dart'; // Import home for unauthenticated users
import 'home/user_home.dart'; // Import user home
import 'home/seller_home.dart'; // Import seller home
import 'home/admin_home.dart'; // Import admin home
import 'auth/sign_in.dart'; // Import sign-in page
import 'theme_notifier.dart';
//import 'dart:html' as html;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //html.document.title = 'Sunset Marketplace'; // Set global title
  // Initialize Firebase with platform-specific options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeNotifier.themeMode,
      builder: (context, themeMode, child) {
        return MaterialApp(
          theme: ThemeData(
            primaryColor: Colors.grey,
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.grey,
              foregroundColor: Colors.black,
              elevation: 0,
              toolbarHeight: 56,
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: Colors.grey,
            ),
            colorScheme: const ColorScheme.light(
              primary: Colors.grey,
              secondary: Colors.black,
              surface: Colors.white,
              onPrimary: Colors.black,
              onSecondary: Colors.white,
              onSurface: Colors.black,
            ),
            inputDecorationTheme: const InputDecorationTheme(
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.grey,
                  width: 2,
                ),
              ),
              labelStyle: TextStyle(
                color: Colors.grey,
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.black,
              ),
            ),
          ),
          darkTheme: ThemeData(
            primaryColor: Colors.black,
            scaffoldBackgroundColor: Colors.black,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.grey,
              foregroundColor: Colors.black,
              elevation: 0,
              toolbarHeight: 56,
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: Colors.grey,
            ),
            colorScheme: const ColorScheme.dark(
              primary: Colors.black,
              secondary: Colors.grey,
              surface: Color.fromRGBO(33, 33, 33, 1),
              onPrimary: Colors.white,
              onSecondary: Colors.black,
              onSurface: Colors.white,
            ),
            inputDecorationTheme: const InputDecorationTheme(
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.white,
                  width: 2,
                ),
              ),
              labelStyle: TextStyle(
                color: Colors.white,
              ),
            ),
            textSelectionTheme: const TextSelectionThemeData(
              cursorColor: Colors.white, // Cursor color
              selectionColor: Colors.grey, // Text selection color
              selectionHandleColor: Colors.white, // Handle color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.black,
              ),
            ),
            progressIndicatorTheme: const ProgressIndicatorThemeData(
              color: Colors.grey, // Circular progress indicator color
            ),
          ),
          themeMode: themeMode, // Use the current theme mode
          initialRoute: '/',
          routes: {
            '/': (context) => const AuthWrapper(),
            '/home': (context) => const HomeScreen(),
            '/login': (context) => const SignIn(),
            '/user_home': (context) => const UserHome(),
            '/seller_home': (context) => const SellerHome(),
            '/admin_home': (context) => const AdminHome(),
          },
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          // Anonymous or signed out
          return const HomeScreen();
        }

        // Signed in — check role
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final userData = userSnapshot.data!.data() as Map<String, dynamic>;
              final role = userData['role'];

              switch (role) {
                case 'admin':
                  return const AdminHome();
                case 'seller':
                  return const SellerHome();
                case 'user':
                default:
                  return const UserHome();
              }
            } else {
              return const HomeScreen();
            }
          },
        );
      },
    );
  }
}

