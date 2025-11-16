// File: lib/screens/customer/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/cart_provider.dart';
import 'customization_screen.dart'; // Import halaman kustomisasi

/// Halaman Keranjang Belanja
/// Menampilkan item yang dipilih dan opsi paket langganan.
class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // Opsi paket
  final List<int> _packageDays = [7, 14, 30];
  final List<int> _mealsPerDayOptions = [1, 2]; // 1x atau 2x makan
  final List<String> _mealTimeOptions = ['Makan Siang', 'Makan Malam'];

  // Nilai default yang dipilih
  int _selectedDays = 7;
  int _selectedMealsPerDay = 1;
  String _selectedMealTime = 'Makan Siang'; // State baru untuk pilihan 1x

  // Helper untuk format mata uang
  final currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  /// Menghitung total harga berdasarkan item di keranjang dan paket
  int _calculateTotalPrice(CartProvider cart) {
    if (cart.itemCount == 0) return 0;

    // Asumsi: Harga menu adalah HARGA RATA-RATA dari item di keranjang
    int totalHargaMenu = cart.items
        .map((menu) => menu.harga)
        .reduce((value, element) => value + element);
    
    double hargaRataRata = totalHargaMenu / cart.itemCount;

    // Total = Harga Rata-rata * Jumlah Hari * Makanan Per Hari
    return (hargaRataRata * _selectedDays * _selectedMealsPerDay).toInt();
  }

  /// Menangani navigasi ke halaman kustomisasi
  void _navigateToCustomization(BuildContext context, CartProvider cart) {
    if (cart.itemCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keranjang Anda kosong. Silakan pilih menu terlebih dahulu.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomizationScreen(
          totalDays: _selectedDays,
          mealsPerDay: _selectedMealsPerDay,
          // Kirim pilihan waktu makan (hanya relevan jika mealsPerDay == 1)
          selectedMealTime: _selectedMealTime,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Gunakan Consumer agar UI update saat item dihapus
    return Consumer<CartProvider>(
      builder: (context, cart, child) {
        final totalHarga = _calculateTotalPrice(cart);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Keranjang Saya'),
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Daftar Menu di Keranjang
                      _buildCartListSection(cart),
                      const Divider(height: 32),

                      // 2. Opsi Paket
                      _buildPackageSection(context),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // 3. Footer Total Harga
              if (cart.itemCount > 0)
                _buildCheckoutFooter(context, cart, totalHarga),
            ],
          ),
        );
      },
    );
  }

  /// Widget untuk menampilkan daftar item di keranjang
  Widget _buildCartListSection(CartProvider cart) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Menu Pilihan (${cart.itemCount} item)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (cart.itemCount == 0)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('Keranjang Anda kosong.'),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cart.itemCount,
              itemBuilder: (context, index) {
                final menu = cart.items[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Image.network(
                      menu.fotoUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                    title: Text(menu.namaMenu),
                    subtitle: Text(currencyFormatter.format(menu.harga)),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      tooltip: 'Hapus',
                      onPressed: () {
                        // Hapus item dari keranjang
                        cart.removeItem(menu);
                      },
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// Widget untuk opsi durasi dan frekuensi
  Widget _buildPackageSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Atur Langganan Anda',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          // Opsi Durasi (7, 14, 30 hari)
          DropdownButtonFormField<int>(
            value: _selectedDays,
            decoration: const InputDecoration(
              labelText: 'Durasi Langganan',
              border: OutlineInputBorder(),
            ),
            items: _packageDays.map((days) {
              return DropdownMenuItem<int>(
                value: days,
                child: Text('$days Hari'),
              );
            }).toList(),
            onChanged: (int? value) {
              if (value != null) {
                setState(() {
                  _selectedDays = value;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          // Opsi Frekuensi (1x atau 2x)
          DropdownButtonFormField<int>(
            value: _selectedMealsPerDay,
            decoration: const InputDecoration(
              labelText: 'Frekuensi Makan per Hari',
              border: OutlineInputBorder(),
            ),
            items: _mealsPerDayOptions.map((meals) {
              String text = (meals == 1) 
                  ? '1 kali per hari' 
                  : '2 kali (Siang & Malam)';
              return DropdownMenuItem<int>(
                value: meals,
                child: Text(text),
              );
            }).toList(),
            onChanged: (int? value) {
              if (value != null) {
                setState(() {
                  _selectedMealsPerDay = value;
                });
              }
            },
          ),

          // --- [PERUBAHAN DI SINI] ---
          // Tampilkan pilihan Siang/Malam HANYA JIKA frekuensi 1x
          if (_selectedMealsPerDay == 1)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: DropdownButtonFormField<String>(
                value: _selectedMealTime,
                decoration: const InputDecoration(
                  labelText: 'Pilih Waktu Makan',
                  border: OutlineInputBorder(),
                ),
                items: _mealTimeOptions.map((time) {
                  return DropdownMenuItem<String>(
                    value: time,
                    child: Text(time),
                  );
                }).toList(),
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() {
                      _selectedMealTime = value;
                    });
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Widget untuk footer Total dan Tombol
  Widget _buildCheckoutFooter(BuildContext context, CartProvider cart, int totalHarga) {
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
                'Estimasi Total',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Text(
                currencyFormatter.format(totalHarga),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _navigateToCustomization(context, cart),
            child: const Text('Lanjut ke Kustomisasi Menu'),
          ),
        ],
      ),
    );
  }
}