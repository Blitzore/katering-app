// File: lib/screens/customer/checkout_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Untuk ambil User ID
import 'package:http/http.dart' as http; // Import HTTP
import 'dart:convert'; // Import untuk jsonEncode/Decode
import '../../models/subscription_slot.dart';
import 'payment_webview_screen.dart'; 

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
      // selectedMenu tidak mungkin null karena dicek di halaman sebelumnya
      total += slot.selectedMenu!.harga;
    }
    return total;
  }

  /// Memulai proses pembayaran
  Future<void> _startPayment(BuildContext context, int totalHarga) async {
    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anda harus login ulang!')),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      // GANTI dengan URL Vercel Anda + /createTransaction
      final url = Uri.parse('https://katering-app.vercel.app/createTransaction');
      
      // Siapkan data untuk dikirim (Body)
      final Map<String, dynamic> dataToSend = {
        'finalPrice': totalHarga,
        'userId': user.uid, 
        'slots': widget.slots
            .map((slot) => {
                  'day': slot.day,
                  'mealTime': slot.mealTime,
                  'selectedMenu': slot.selectedMenu!.toJson(), 
                })
            .toList(),
      };

      // Kirim request POST
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(dataToSend),
      );

      if (response.statusCode == 200) {
        // Ambil URL pembayaran dari hasil
        final responseData = jsonDecode(response.body);
        final paymentUrl = responseData['paymentUrl'];

        if (!mounted) return;
        setState(() => _isLoading = false);

        // Navigasi ke WebView
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PaymentWebViewScreen(paymentUrl: paymentUrl),
          ),
        );
      } else {
        // Handle error dari server (bukan 200)
        throw Exception('Gagal membuat transaksi: ${response.body}');
      }

    } catch (e) {
      setState(() => _isLoading = false);
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat transaksi: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
            // --- [PERBAIKAN DI SINI] ---
            // Menggunakan 'totalHarga' (dari parameter)
            // bukan 'finalPrice' (yang tidak ada)
            onPressed: _isLoading ? null : () => _startPayment(context, totalHarga),
            // --- [AKHIR PERBAIKAN] ---
            child: const Text('Bayar Sekarang'),
          ),
        ],
      ),
    );
  }
}