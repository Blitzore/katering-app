import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; 

// Import layar/halaman
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // Definisikan palet warna aplikasi
  static const Color primaryColor = Color(0xFF2E7D32); // Hijau Tua
  static const Color accentColor = Color(0xFFFFA000); // Kuning/Oranye
  static const Color backgroundColor = Color(0xFFF9F9F9); // Putih sedikit abu
  static const Color textColor = Color(0xFF333333); // Abu-abu Tua untuk teks

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Katering App',
      theme: ThemeData(
        // Tema utama aplikasi
        primaryColor: primaryColor,
        primarySwatch: Colors.green, 
        scaffoldBackgroundColor: backgroundColor, 

        // Tema untuk AppBar
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
          elevation: 1,
          titleTextStyle: TextStyle(
            color: Colors.white, 
            fontSize: 20, 
            fontWeight: FontWeight.bold
          ),
          iconTheme: IconThemeData(color: Colors.white), 
        ),

        // Tema untuk Tombol
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

        // Tema untuk Form Input
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
        
        // Tema untuk Teks
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          titleLarge: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(color: textColor),
          bodySmall: TextStyle(color: Color(0xFF757575)),
        ),

        // Tema untuk TextButton
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryColor, 
          ),
        ),
      ),
      
      initialRoute: '/login', 
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
      },
    );
  }
}