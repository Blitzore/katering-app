// File: lib/screens/customer/customization_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/menu_model.dart';
import '../../models/subscription_slot.dart';
import '../../providers/cart_provider.dart';
import 'checkout_screen.dart'; // Pastikan file ini ada (lihat kode di bawah)

class CustomizationScreen extends StatefulWidget {
  final int totalDays;
  final int mealsPerDay;
  final String selectedMealTime; 

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
  late List<SubscriptionSlot> _slots;
  late List<MenuModel> _menuOptions;

  @override
  void initState() {
    super.initState();
    _menuOptions = Provider.of<CartProvider>(context, listen: false).items;
    _generateSlots();
  }

  void _generateSlots() {
    _slots = [];
    for (int day = 1; day <= widget.totalDays; day++) {
      if (widget.mealsPerDay == 1) {
        _slots.add(SubscriptionSlot(day: day, mealTime: widget.selectedMealTime));
      } else {
        _slots.add(SubscriptionSlot(day: day, mealTime: 'Makan Siang'));
        _slots.add(SubscriptionSlot(day: day, mealTime: 'Makan Malam'));
      }
    }
  }

  bool _areAllSlotsFilled() {
    return _slots.every((slot) => slot.selectedMenu != null);
  }

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
      appBar: AppBar(title: const Text('Kustomisasi Menu')),
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

  Widget _buildSlotCard(SubscriptionSlot slot) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              slot.label, 
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
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
                  child: Text(
                    '${menu.namaMenu} (Rp ${menu.harga})',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (MenuModel? newValue) {
                setState(() => slot.selectedMenu = newValue);
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- BAGIAN YANG DIPERBAIKI (PADDING & SIZEBOX) ---
  Widget _buildCheckoutFooter() {
    return Container(
      // Padding diperbesar agar tombol tidak nempel kiri-kanan
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20), 
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
      child: SafeArea(
        child: SizedBox(
          width: double.infinity, // Paksa lebar penuh (dikurangi padding)
          height: 50, // Tinggi tombol konsisten
          child: ElevatedButton(
            onPressed: _areAllSlotsFilled() ? _proceedToCheckout : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _areAllSlotsFilled() ? Theme.of(context).primaryColor : Colors.grey,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Sudut tumpul
            ),
            child: const Text(
              'Lanjut ke Ringkasan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}