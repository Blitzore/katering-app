// File: lib/screens/customer/widgets/cart_badge.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import '../../../providers/cart_provider.dart';

/// Widget ikon keranjang dengan badge yang menunjukkan jumlah item.
class CartBadge extends StatelessWidget {
  const CartBadge({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Gunakan Consumer untuk mendengarkan perubahan pada CartProvider
    return Consumer<CartProvider>(
      builder: (context, cart, child) {
        return badges.Badge(
          // Tampilkan badge hanya jika ada item
          showBadge: cart.itemCount > 0,
          position: badges.BadgePosition.topEnd(top: 0, end: 3),
          badgeContent: Text(
            cart.itemCount.toString(),
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
          child: child, // child-nya adalah IconButton di bawah
        );
      },
      // child ini adalah IconButton,
      // ia tidak akan di-build ulang saat CartProvider berubah
      // (lebih efisien)
      child: IconButton(
        icon: const Icon(Icons.shopping_cart_outlined),
        tooltip: 'Keranjang',
        onPressed: () {
          // Navigasi ke Halaman Keranjang
          Navigator.pushNamed(context, '/cart');
        },
      ),
    );
  }
}