import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false; 

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // Navigasi akan di-handle oleh AuthWrapper (di tugas berikutnya)
    } on FirebaseAuthException catch (e) {
      String message = 'Terjadi kesalahan.';
      if (e.code == 'user-not-found') {
        message = 'Email tidak ditemukan.';
      } else if (e.code == 'wrong-password') {
        message = 'Password salah.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
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
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.restaurant_menu,
                        size: 60,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Selamat Datang!",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 26),
                    ),
                    Text(
                      "Login ke akun katering Anda",
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
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Login"),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pushNamed(context, '/register'),
                      child: const Text("Belum punya akun? Daftar di sini"),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}