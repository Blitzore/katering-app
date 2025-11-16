// File: lib/providers/cart_provider.dart
import 'package:flutter/material.dart';
import '../models/menu_model.dart';

/// Mengelola state keranjang belanja (daftar menu yang dipilih).
class CartProvider with ChangeNotifier {
  /// Daftar menu yang ada di keranjang.
  /// Kita gunakan Map untuk mencegah duplikasi menu,
  /// kuncinya adalah menuId.
  final Map<String, MenuModel> _items = {};

  /// Mendapatkan daftar menu sebagai List (untuk ditampilkan).
  List<MenuModel> get items => _items.values.toList();

  /// Mendapatkan jumlah item di keranjang.
  int get itemCount => _items.length;

  /// Menambahkan item ke keranjang.
  /// Jika item sudah ada, tidak akan terjadi apa-apa.
  void addItem(MenuModel menu) {
    if (_items.containsKey(menu.menuId)) {
      // (Opsional) Tampilkan pesan "Sudah ada di keranjang"
      print("Item sudah ada di keranjang.");
      return;
    }
    _items.putIfAbsent(menu.menuId, () => menu);
    print("Item ditambahkan ke keranjang.");
    // Beri tahu widget yang mendengarkan bahwa data berubah.
    notifyListeners();
  }

  /// Menghapus item dari keranjang.
  void removeItem(MenuModel menu) {
    if (_items.containsKey(menu.menuId)) {
      _items.remove(menu.menuId);
      print("Item dihapus dari keranjang.");
      notifyListeners();
    }
  }

  /// Mengosongkan keranjang.
  void clearCart() {
    _items.clear();
    print("Keranjang dikosongkan.");
    notifyListeners();
  }
}