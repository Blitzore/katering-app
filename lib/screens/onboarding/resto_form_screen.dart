// File: lib/screens/onboarding/resto_form_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/menu_item.dart'; // Menggunakan path relatif

/// Halaman stateful untuk form pendaftaran data restoran & menu awal.
/// Menerima [email] dan [password] dari halaman register.
class RestoFormScreen extends StatefulWidget {
  final String email;
  final String password;

  const RestoFormScreen({
    Key? key,
    required this.email,
    required this.password,
  }) : super(key: key);

  @override
  _RestoFormScreenState createState() => _RestoFormScreenState();
}

class _RestoFormScreenState extends State<RestoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaTokoController = TextEditingController();
  final _alamatTokoController = TextEditingController();

  final List<MenuItem> _menuItems = [];
  bool _isLoading = false;

  /// Inisialisasi klien Cloudinary.
  final cloudinary =
      CloudinaryPublic('drdfrxobm', 'katering_app', cache: false);

  @override
  void dispose() {
    _namaTokoController.dispose();
    _alamatTokoController.dispose();
    super.dispose();
  }

  /// Menampilkan dialog untuk menambah menu baru.
  Future<void> _showAddMenuDialog() async {
    final _menuFormKey = GlobalKey<FormState>();
    final _namaMenuController = TextEditingController();
    final _hargaMenuController = TextEditingController();
    File? _menuImageFile;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Tambah Menu Baru'),
              content: Form(
                key: _menuFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final pickedFile = await picker.pickImage(
                              source: ImageSource.gallery);
                          if (pickedFile != null) {
                            setDialogState(() {
                              _menuImageFile = File(pickedFile.path);
                            });
                          }
                        },
                        child: Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: _menuImageFile == null
                              ? const Center(
                                  child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.fastfood,
                                        size: 40, color: Colors.grey),
                                    Text('Pilih Foto Makanan')
                                  ],
                                ))
                              : Image.file(_menuImageFile!, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _namaMenuController,
                        decoration:
                            const InputDecoration(labelText: 'Nama Makanan'),
                        validator: (v) => v!.isEmpty ? 'Nama wajib diisi' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _hargaMenuController,
                        decoration:
                            const InputDecoration(labelText: 'Harga (Rp)'),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        validator: (v) => v!.isEmpty ? 'Harga wajib diisi' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_menuFormKey.currentState!.validate() &&
                        _menuImageFile != null) {
                      final newItem = MenuItem(
                        imageFile: _menuImageFile!,
                        namaMenu: _namaMenuController.text,
                        harga: int.parse(_hargaMenuController.text),
                      );
                      setState(() {
                        _menuItems.add(newItem);
                      });
                      Navigator.of(ctx).pop();
                    } else if (_menuImageFile == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Foto menu wajib diisi')),
                      );
                    }
                  },
                  child: const Text('Simpan Menu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Menjalankan proses pendaftaran lengkap untuk mitra:
  /// 1. Membuat akun di [FirebaseAuth]
  /// 2. Menyimpan data role ke [FirebaseFirestore] (koleksi 'users')
  /// 3. Menyimpan data restoran ke [FirebaseFirestore] (koleksi 'restaurants')
  /// 4. Mengunggah semua foto menu ke [Cloudinary]
  /// 5. Menyimpan data menu ke sub-koleksi 'menus'
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_menuItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan minimal 1 menu makanan')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Buat Akun Auth
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: widget.email,
        password: widget.password,
      );

      final user = userCredential.user;
      if (user == null) throw Exception("Gagal membuat akun");

      // 2. Simpan Data Role ke 'users'
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'role': 'restoran',
        'createdAt': Timestamp.now(),
      });

      // 3. Simpan data Restoran ke 'restaurants'
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(user.uid)
          .set({
        'uid': user.uid,
        'namaToko': _namaTokoController.text,
        'alamat': _alamatTokoController.text,
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });

      // 4. Loop dan Upload setiap menu
      for (var item in _menuItems) {
        String menuId = FirebaseFirestore.instance
            .collection('restaurants')
            .doc(user.uid)
            .collection('menus')
            .doc()
            .id;

        // Upload ke Cloudinary
        CloudinaryResponse response = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(item.imageFile.path,
              resourceType: CloudinaryResourceType.Image,
              folder: 'foto_menu',
              publicId: '${user.uid}_$menuId'),
        );

        final imageUrl = response.secureUrl;

        // 5. Simpan data menu ke sub-koleksi 'menus'
        await FirebaseFirestore.instance
            .collection('restaurants')
            .doc(user.uid)
            .collection('menus')
            .doc(menuId)
            .set({
          'menuId': menuId,
          'namaMenu': item.namaMenu,
          'harga': item.harga,
          'fotoUrl': imageUrl,
          'isAvailable': true,
        });
      }

      // Reset navigasi kembali ke AuthWrapper
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      // Tangani error jika email sudah ada
      String message = 'Terjadi kesalahan.';
      if (e.code == 'email-already-in-use') {
        message =
            'Email ini sudah terdaftar. Silakan kembali dan gunakan email lain.';
      }
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Error Pendaftaran'),
            content: Text(message),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () => Navigator.of(ctx).pop(),
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Terjadi Error'),
            content: Text('Detail Error: ${e.toString()}'),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () => Navigator.of(ctx).pop(),
              )
            ],
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Menampilkan dialog konfirmasi sebelum kembali ke halaman register.
  Future<bool> _onBackPressed() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kembali?'),
        content:
            const Text('Data yang sudah Anda isi di halaman ini akan hilang.'),
        actions: [
          TextButton(
            child: const Text('Lanjut Mengisi'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Ya, Kembali'),
            onPressed: () {
              Navigator.of(ctx).pop(true);
            },
          ),
        ],
      ),
    );
    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onBackPressed,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pendaftaran Restoran'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Kembali',
            onPressed: () async {
              if (await _onBackPressed()) {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Lengkapi Data Restoran Anda",
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                // Tampilkan email yang didaftarkan
                Text(
                  "Mendaftar dengan email: ${widget.email}",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _namaTokoController,
                  decoration:
                      const InputDecoration(labelText: 'Nama Toko / Warung'),
                  validator: (v) => v!.isEmpty ? 'Nama toko wajib diisi' : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _alamatTokoController,
                  decoration: const InputDecoration(labelText: 'Alamat Lengkap'),
                  maxLines: 3,
                  validator: (v) => v!.isEmpty ? 'Alamat wajib diisi' : null,
                ),
                const SizedBox(height: 30),
                Text(
                  "Menu Makanan (Minimal 1)",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                // Tampilkan daftar menu yang sudah ditambahkan
                Container(
                  height: _menuItems.isEmpty ? 0 : 150,
                  decoration: _menuItems.isEmpty
                      ? null
                      : BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(10),
                        ),
                  child: ListView.builder(
                    itemCount: _menuItems.length,
                    itemBuilder: (ctx, index) {
                      final item = _menuItems[index];
                      return ListTile(
                        leading: Image.file(item.imageFile,
                            width: 50, height: 50, fit: BoxFit.cover),
                        title: Text(item.namaMenu),
                        subtitle: Text('Rp ${item.harga}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _menuItems.removeAt(index);
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                // Tombol untuk memunculkan dialog tambah menu
                OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah Menu'),
                  onPressed: _showAddMenuDialog,
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: Theme.of(context).primaryColor,
                      side: BorderSide(color: Theme.of(context).primaryColor)),
                ),
                const SizedBox(height: 30),
                // Tombol Submit Utama
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Kirim Pendaftaran'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}