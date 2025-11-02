import 'dart:io';

/// Model data untuk satu item menu.
class MenuItem {
  File imageFile;
  String namaMenu;
  int harga;

  MenuItem({
    required this.imageFile,
    required this.namaMenu,
    required this.harga,
  });
}