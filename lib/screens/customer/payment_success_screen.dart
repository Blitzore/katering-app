// File: lib/screens/customer/payment_success_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import Provider
import '../../providers/cart_provider.dart'; // Import CartProvider

/// Halaman yang ditampilkan setelah pembayaran berhasil.
class PaymentSuccessScreen extends StatefulWidget { // Ubah ke StatefulWidget
  const PaymentSuccessScreen({Key? key}) : super(key: key);

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  @override
  void initState() {
    super.initState();
    // Panggil clearCart() saat halaman ini pertama kali dimuat
    // 'listen: false' karena kita tidak perlu widget ini me-rebuild
    // jika cart berubah. Kita hanya perlu memanggil metodenya.
    Provider.of<CartProvider>(context, listen: false).clearCart();
  }

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