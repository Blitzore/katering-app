// File: lib/screens/customer/checkout_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/subscription_slot.dart';

/// Halaman Ringkasan Pesanan (Checkout).
/// Menampilkan semua slot yang dipilih dan total harga final.
class CheckoutScreen extends StatelessWidget {
  final List<SubscriptionSlot> slots;

  const CheckoutScreen({Key? key, required this.slots}) : super(key: key);

  /// Menghitung total harga final dari semua menu yang dipilih di slot.
  int _calculateFinalPrice() {
    int total = 0;
    for (var slot in slots) {
      // selectedMenu tidak mungkin null karena dicek di halaman sebelumnya
      total += slot.selectedMenu!.harga;
    }
    return total;
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
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: slots.length,
              itemBuilder: (context, index) {
                final slot = slots[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      slot.label, // Misal: "Hari 1 - Siang"
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      slot.selectedMenu!.namaMenu, // Misal: "Nasi Goreng"
                    ),
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
            onPressed: () {
              // TODO (Minggu ke-5): Integrasi Payment Gateway
              print('Mulai proses pembayaran...');
            },
            child: const Text('Bayar Sekarang'),
          ),
        ],
      ),
    );
  }
}