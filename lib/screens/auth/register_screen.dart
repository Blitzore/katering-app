// File: lib/screens/auth/register_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../onboarding/resto_form_screen.dart'; // Menggunakan path relatif

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  String? _selectedRole;
  final List<String> _roles = ['pelanggan', 'restoran', 'driver'];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Menangani logika pendaftaran berdasarkan role:
  /// 1. Pelanggan: Langsung membuat akun Auth dan data Firestore.
  /// 2. Mitra (Resto/Driver): Membawa data ke halaman form berikutnya.
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Silakan pilih role Anda'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      if (_selectedRole == 'pelanggan') {
        // Alur 1: Pelanggan (Langsung Daftar)
        UserCredential userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        User? user = userCredential.user;

        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'uid': user.uid,
            'email': user.email,
            'role': _selectedRole,
            'createdAt': Timestamp.now(),
          });

          // --- INI PERBAIKANNYA ---
          // Reset navigasi kembali ke AuthWrapper ('/')
          // Ini akan menghapus halaman Login & Register dari tumpukan
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
                context, '/', (route) => false);
          }
          // --- SELESAI PERBAIKAN ---
        }
      } else if (_selectedRole == 'restoran') {
        // Alur 2: Restoran (Lanjut ke Form)
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RestoFormScreen(
                email: email,
                password: password,
              ),
            ),
          );
        }
      } else if (_selectedRole == 'driver') {
        // Alur 3: Driver (Nanti Dibuat)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alur driver belum tersedia')),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Terjadi kesalahan.';
      if (e.code == 'weak-password') {
        message = 'Password terlalu lemah.';
      } else if (e.code == 'email-already-in-use') {
        message = 'Email ini sudah terdaftar.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red),
      );
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Teks tombol berubah berdasarkan role
    final buttonText = _selectedRole == 'pelanggan' ? 'Daftar' : 'Lanjut';

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Daftar Akun Baru"),
          elevation: 0,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    "Buat Akun Anda",
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontSize: 26),
                  ),
                  Text(
                    "Isi data di bawah untuk mendaftar",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null ||
                          value.isEmpty ||
                          !value.contains('@')) {
                        return 'Masukkan email yang valid';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: "Password",
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty || value.length < 6) {
                        return 'Password minimal 6 karakter';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: "Daftar sebagai",
                      prefixIcon: Icon(Icons.person_pin_circle_outlined),
                    ),
                    hint: const Text('Pilih role Anda'),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedRole = newValue;
                      });
                    },
                    items: _roles.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value[0].toUpperCase() + value.substring(1)),
                      );
                    }).toList(),
                    validator: (value) {
                      if (value == null) {
                        return 'Silakan pilih role Anda';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(buttonText), // Teks tombol dinamis
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}