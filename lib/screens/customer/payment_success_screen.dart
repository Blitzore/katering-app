// File: lib/screens/customer/payment_success_screen.dart
import 'package:flutter/material.dart';

/// Halaman yang ditampilkan setelah pembayaran berhasil.
class PaymentSuccessScreen extends StatelessWidget {
  const PaymentSuccessScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Theme.of(context).primaryColor,
                size: 120,
              ),
              const SizedBox(height: 24),
              Text(
                'Pembayaran Berhasil!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 26,
                    ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pesanan Anda sedang diproses dan akan segera kami siapkan. Terima kasih.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  // Kembali ke halaman home (AuthWrapper)
                  // dan menghapus semua halaman sebelumnya (checkout, cart, dll)
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/', (route) => false);
                },
                child: const Text('Kembali ke Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}