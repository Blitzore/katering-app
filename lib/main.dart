// File: lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'firebase_options.dart';
import 'providers/cart_provider.dart'; // Import CartProvider

// Import halaman
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth_wrapper.dart';
import 'screens/home_placeholder.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/verification_list_screen.dart';
import 'screens/customer/cart_screen.dart';
import 'screens/customer/payment_success_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Bungkus MyApp dengan Provider
  runApp(
    ChangeNotifierProvider(
      create: (context) => CartProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  /// Palet warna utama aplikasi
  static const Color primaryColor = Color(0xFF2E7D32);
  static const Color accentColor = Color(0xFFFFA000);
  static const Color backgroundColor = Color(0xFFF9F9F9);
  static const Color textColor = Color(0xFF333333);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Katering App',
      theme: ThemeData(
        primaryColor: primaryColor,
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: backgroundColor,
        
        // Tema AppBar
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
          elevation: 1,
          titleTextStyle: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(color: Colors.white),
        ),

        // Tema Tombol
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Tema Input Form
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
          labelStyle: const TextStyle(color: textColor),
          prefixIconColor: Colors.grey[600],
        ),
        
        // Tema Teks
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          titleLarge: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(color: textColor),
          bodySmall: TextStyle(color: Color(0xFF757575)),
        ),
        
        // Tema TextButton
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryColor,
          ),
        ),
      ),

      /// Rute utama ('/') akan diarahkan ke AuthWrapper
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(), // Penjaga gerbang
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomePlaceholder(),
        
        // Rute Admin
        '/admin_dashboard': (context) => const AdminDashboardScreen(),
        '/admin_verification_list': (context) => const VerificationListScreen(),
        
        // Rute Pelanggan
        // Rute Pelanggan
        '/cart': (context) => const CartScreen(),
        '/payment_success': (context) => const PaymentSuccessScreen(),
      },
    );
  }
}