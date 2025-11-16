// File: lib/screens/customer/package_selection_screen.dart
import 'package:flutter/material.dart';
import '../../models/menu_model.dart';
import 'package:intl/intl.dart'; // Import untuk format angka

/// Halaman untuk memilih paket langganan (durasi) untuk menu tertentu.
class PackageSelectionScreen extends StatefulWidget {
  final MenuModel menu;

  const PackageSelectionScreen({Key? key, required this.menu})
      : super(key: key);

  @override
  _PackageSelectionScreenState createState() => _PackageSelectionScreenState();
}

class _PackageSelectionScreenState extends State<PackageSelectionScreen> {
  // Opsi paket dalam jumlah hari
  final List<int> _packageDays = [7, 14, 30];
  int _selectedDays = 7; // Nilai default

  // Helper untuk format mata uang
  final currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _selectedDays = _packageDays[0]; // Set default ke 7 hari
  }

  /// Menghitung total harga berdasarkan hari yang dipilih
  int _calculateTotalPrice() {
    return widget.menu.harga * _selectedDays;
  }

  @override
  Widget build(BuildContext context) {
    final totalHarga = _calculateTotalPrice();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Paket Langganan'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Detail Menu yang Dipilih
                  _buildMenuHeader(),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),

                  // 2. Pilihan Paket
                  Text(
                    'Pilih Durasi Paket',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildPackageOptions(),
                ],
              ),
            ),
          ),

          // 3. Footer Total Harga dan Tombol Checkout
          _buildCheckoutFooter(totalHarga),
        ],
      ),
    );
  }

  /// Widget untuk header detail menu
  Widget _buildMenuHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            widget.menu.fotoUrl,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, st) =>
                const Icon(Icons.broken_image, size: 100),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.menu.namaMenu,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                currencyFormatter.format(widget.menu.harga) + ' / hari',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Widget untuk membangun opsi paket (Radio button)
  Widget _buildPackageOptions() {
    return Column(
      children: _packageDays.map((days) {
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: RadioListTile<int>(
            title: Text('$days Hari Langganan'),
            subtitle: Text(
              'Total: ' +
                  currencyFormatter.format(widget.menu.harga * days),
            ),
            value: days,
            groupValue: _selectedDays,
            onChanged: (int? value) {
              if (value != null) {
                setState(() {
                  _selectedDays = value;
                });
              }
            },
            activeColor: Theme.of(context).primaryColor,
          ),
        );
      }).toList(),
    );
  }

  /// Widget untuk footer Total dan Tombol
  Widget _buildCheckoutFooter(int totalHarga) {
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
                'Total Harga (${_selectedDays} hari)',
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
            onPressed: () {
              // TODO: Navigasi ke Halaman Kustomisasi Menu (Minggu ke-4)
              print(
                  'Lanjut ke Kustomisasi: ${widget.menu.namaMenu} - $_selectedDays hari');
            },
            child: const Text('Lanjut ke Kustomisasi Menu'),
          ),
        ],
      ),
    );
  }
}