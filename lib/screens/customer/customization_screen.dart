// File: lib/screens/customer/customization_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/menu_model.dart';
import '../../models/subscription_slot.dart';
import '../../providers/cart_provider.dart';
import 'checkout_screen.dart'; // Import halaman checkout baru

/// Halaman untuk kustomisasi menu harian (mengisi slot).
class CustomizationScreen extends StatefulWidget {
  final int totalDays;
  final int mealsPerDay;
  final String selectedMealTime; // Pilihan (Siang/Malam) jika mealsPerDay=1

  const CustomizationScreen({
    Key? key,
    required this.totalDays,
    required this.mealsPerDay,
    required this.selectedMealTime,
  }) : super(key: key);

  @override
  _CustomizationScreenState createState() => _CustomizationScreenState();
}

class _CustomizationScreenState extends State<CustomizationScreen> {
  /// Daftar semua slot yang harus diisi pelanggan.
  late List<SubscriptionSlot> _slots;

  /// Daftar menu yang tersedia (diambil dari keranjang).
  late List<MenuModel> _menuOptions;

  @override
  void initState() {
    super.initState();
    // Ambil menu dari keranjang saat halaman dibuka
    _menuOptions = Provider.of<CartProvider>(context, listen: false).items;
    // Buat slot berdasarkan data paket
    _generateSlots();
  }

  /// Membuat daftar slot berdasarkan pilihan paket
  void _generateSlots() {
    _slots = [];
    for (int day = 1; day <= widget.totalDays; day++) {
      if (widget.mealsPerDay == 1) {
        // Gunakan waktu makan yang dipilih dari halaman keranjang
        _slots.add(SubscriptionSlot(day: day, mealTime: widget.selectedMealTime));
      } else {
        // Jika 2x, selalu Siang dan Malam
        _slots.add(SubscriptionSlot(day: day, mealTime: 'Makan Siang'));
        _slots.add(SubscriptionSlot(day: day, mealTime: 'Makan Malam'));
      }
    }
  }

  /// Cek apakah semua slot sudah terisi
  bool _areAllSlotsFilled() {
    // Cek setiap slot, jika ada yg selectedMenu-nya null, return false
    return _slots.every((slot) => slot.selectedMenu != null);
  }

  /// Menangani tombol "Lanjut ke Checkout"
  void _proceedToCheckout() {
    if (!_areAllSlotsFilled()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap isi semua slot menu terlebih dahulu.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Navigasi ke Halaman Checkout dan kirim data slot
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(slots: _slots),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kustomisasi Menu'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _slots.length,
              itemBuilder: (context, index) {
                return _buildSlotCard(_slots[index]);
              },
            ),
          ),
          _buildCheckoutFooter(),
        ],
      ),
    );
  }

  /// Widget untuk satu slot (misal: "Hari 1 - Siang")
  Widget _buildSlotCard(SubscriptionSlot slot) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              slot.label, // Misal: "Hari 1 - Siang"
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            // Dropdown diisi dengan menu dari keranjang
            DropdownButtonFormField<MenuModel>(
              value: slot.selectedMenu,
              isExpanded: true,
              hint: const Text('Pilih Menu...'),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12.0),
              ),
              items: _menuOptions.map((MenuModel menu) {
                return DropdownMenuItem<MenuModel>(
                  value: menu,
                  // Tampilkan nama dan harga di dropdown
                  child: Text(
                    '${menu.namaMenu} (Rp ${menu.harga})',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (MenuModel? newValue) {
                setState(() {
                  slot.selectedMenu = newValue;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Widget untuk footer tombol Checkout
  Widget _buildCheckoutFooter() {
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
      child: ElevatedButton(
        // Tombol hanya aktif jika semua slot sudah terisi
        onPressed: _areAllSlotsFilled() ? _proceedToCheckout : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _areAllSlotsFilled()
              ? Theme.of(context).primaryColor
              : Colors.grey,
        ),
        child: const Text('Lanjut ke Ringkasan'),
      ),
    );
  }
}