// File: lib/screens/customer/checkout_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/subscription_slot.dart';
import 'payment_webview_screen.dart'; // Import WebView

/// Halaman Ringkasan Pesanan (Checkout).
/// Menampilkan semua slot yang dipilih dan total harga final.
class CheckoutScreen extends StatefulWidget {
  final List<SubscriptionSlot> slots;

  const CheckoutScreen({Key? key, required this.slots}) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isLoading = false;

  /// Menghitung total harga final dari semua menu yang dipilih di slot.
  int _calculateFinalPrice() {
    int total = 0;
    for (var slot in widget.slots) {
      total += slot.selectedMenu!.harga;
    }
    return total;
  }

  /// Memulai proses pembayaran
  Future<void> _startPayment(BuildContext context, int finalPrice) async {
    setState(() => _isLoading = true);
    
    // --- DI SINI ANDA MEMANGGIL BACKEND (CLOUD FUNCTION) ---
    // 1. Panggil Cloud Function 'createTransaction' dengan mengirim:
    //    - finalPrice
    //    - widget.slots (data menu yang dipilih)
    //    - User ID
    // 2. Cloud Function akan memanggil SDK Midtrans/Xendit
    // 3. Cloud Function mengembalikan URL Pembayaran (paymentUrl)
    
    // --- SIMULASI (HAPUS INI DI PRODUKSI) ---
    // Kita anggap backend butuh 2 detik dan mengembalikan URL sandbox
    await Future.delayed(const Duration(seconds: 2));
    // Ini adalah URL sandbox demo Midtrans
    const simulatedPaymentUrl = 'https://app.sandbox.midtrans.com/snap/v3/redirection/4726e6d1-4E57-4581-8071-1E6500000000'; 
    // --- AKHIR SIMULASI ---

    if (!mounted) return;

    setState(() => _isLoading = false);

    // Navigasi ke WebView
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const PaymentWebViewScreen(paymentUrl: simulatedPaymentUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final finalPrice = _calculateFinalPrice();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ringkasan Pesanan'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: widget.slots.length,
                  itemBuilder: (context, index) {
                    final slot = widget.slots[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          slot.label,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(slot.selectedMenu!.namaMenu),
                        trailing: Text(
                          currencyFormatter.format(slot.selectedMenu!.harga),
                          style: const TextStyle(color: Colors.green),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Footer Total Harga dan Tombol Bayar
              _buildPaymentFooter(context, currencyFormatter, finalPrice),
            ],
          ),
          
          // Tampilkan loading overlay jika _isLoading
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Membuat transaksi...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Widget untuk footer Total dan Tombol
  Widget _buildPaymentFooter(
      BuildContext context, NumberFormat formatter, int totalHarga) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Pembayaran',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Text(
                formatter.format(totalHarga),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            // Nonaktifkan tombol saat loading
            onPressed: _isLoading ? null : () => _startPayment(context, totalHarga),
            child: const Text('Bayar Sekarang'),
          ),
        ],
      ),
    );
  }
}