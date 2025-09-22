import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '/location_service.dart';
import '/welcome_screen.dart';
import '/login_page.dart';
import '/home_page.dart';
import '/email_verification_screen.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('Initializing Firebase...');
  try {
    await Firebase.initializeApp();
    print('Firebase initialized successfully.');
  } catch (e) {
    print('Firebase initialization error: $e');
  }

  print('Requesting location permission...');
  try {
    await LocationService.requestInitialPermission();
    print('Location permission granted.');
  } catch (e) {
    print('LocationService permission request failed: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryAppColor = Color(0xFF1A73E8);

    print('Building MaterialApp...');
    return MaterialApp(
      title: 'JLR Carpool App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: primaryAppColor,
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryAppColor,
          foregroundColor: Colors.white,
          elevation: 4,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        textTheme: TextTheme(
          displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.bold, color: Colors.grey[900]),
          displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.bold, color: Colors.grey[900]),
          displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.grey[900]),
          headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.grey[850]),
          headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.grey[850]),
          headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[800]),
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.grey[800]),
          titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.grey[700]),
          titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[600]),
          bodyLarge: TextStyle(fontSize: 16, color: Colors.grey[700]),
          bodyMedium: TextStyle(fontSize: 14, color: Colors.grey[700]),
          bodySmall: TextStyle(fontSize: 12, color: Colors.grey[600]),
          labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          labelMedium: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          labelSmall: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: const BorderSide(color: primaryAppColor, width: 2.0),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: const BorderSide(color: Colors.red, width: 1.0),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: const BorderSide(color: Colors.red, width: 2.0),
          ),
          labelStyle: TextStyle(color: Colors.grey[700]),
          hintStyle: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: primaryAppColor,
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: primaryAppColor.withOpacity(0.4),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          print('Auth state changed. Connection state: ${snapshot.connectionState}');
          if (snapshot.connectionState == ConnectionState.waiting) {
            print('Waiting for auth state...');
            return const CircularProgressIndicator(); 
          }
          final user = snapshot.data;
          print('Current user: $user');
          if (user != null) {
            print('User is signed in. Email verified: ${user.emailVerified}');
            if (user.emailVerified) {
              print('Navigating to HomeScreen...');
              return const HomeScreen();
            } else {
              print('Navigating to EmailVerificationScreen...');
              return const EmailVerificationScreen();
            }
          } else {
            print('No user signed in. Navigating to WelcomeScreen...');
            return const WelcomeScreen();
          }
        },
      ),
      routes: {
        '/login': (context) => const LoginAuthScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
