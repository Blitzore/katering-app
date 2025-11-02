import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih role Anda'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Buat user di Firebase Auth
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;

      if (user != null) {
        // 2. Simpan data user (termasuk role) ke Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'role': _selectedRole,
          'createdAt': Timestamp.now(),
        });
        
        // Navigasi akan di-handle oleh AuthWrapper (di tugas berikutnya)
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
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
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
                  // ... (UI dari Minggu 1 tetap sama, tidak perlu saya copy-paste lagi) ...
                  // ... (Text "Buat Akun Anda", TextFormField Email, Password, Dropdown Role) ...
                  const SizedBox(height: 20),
                  Text(
                    "Buat Akun Anda",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 26),
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
                      if (value == null || value.isEmpty || !value.contains('@')) {
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
                    onPressed: _isLoading ? null : _register,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Daftar"),
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