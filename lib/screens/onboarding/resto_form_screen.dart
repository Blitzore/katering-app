// File: lib/screens/onboarding/resto_form_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/menu_item.dart';

/// Halaman stateful untuk form pendaftaran data restoran & menu awal.
/// Menerima [email] dan [password] dari halaman register.
class RestoFormScreen extends StatefulWidget {
  final String email;
  final String password;

  const RestoFormScreen({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  _RestoFormScreenState createState() => _RestoFormScreenState();
}

class _RestoFormScreenState extends State<RestoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaTokoController = TextEditingController();
  final _alamatTokoController = TextEditingController();

  final List<MenuItem> _menuItems = [];
  String? _loadingMessage;

  final cloudinary =
      CloudinaryPublic('drdfrxobm', 'katering_app', cache: false);

  @override
  void dispose() {
    _namaTokoController.dispose();
    _alamatTokoController.dispose();
    super.dispose();
  }

  /// Helper untuk mengambil & mengompres gambar dari galeri.
  Future<File?> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50, // Kompres kualitas
      maxWidth: 1080, // Ubah ukuran lebar
    );
    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    return null;
  }

  /// Menampilkan dialog untuk menambah data menu baru.
  Future<void> _showAddMenuDialog() async {
    final menuFormKey = GlobalKey<FormState>();
    final namaMenuController = TextEditingController();
    final hargaMenuController = TextEditingController();
    File? menuImageFile;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Tambah Menu Baru'),
              content: Form(
                key: menuFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          final file = await _pickImage();
                          if (file != null) {
                            setDialogState(() {
                              menuImageFile = file;
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
                          child: menuImageFile == null
                              ? const Center(
                                  child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.fastfood,
                                        size: 40, color: Colors.grey),
                                    Text('Pilih Foto Makanan')
                                  ],
                                ))
                              : Image.file(menuImageFile!, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: namaMenuController,
                        decoration:
                            const InputDecoration(labelText: 'Nama Makanan'),
                        validator: (v) => v!.isEmpty ? 'Nama wajib diisi' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: hargaMenuController,
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
                    if (menuFormKey.currentState!.validate() &&
                        menuImageFile != null) {
                      final newItem = MenuItem(
                        imageFile: menuImageFile!,
                        namaMenu: namaMenuController.text,
                        harga: int.parse(hargaMenuController.text),
                      );
                      setState(() {
                        _menuItems.add(newItem);
                      });
                      Navigator.of(ctx).pop();
                    } else if (menuImageFile == null) {
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

  /// Menjalankan proses pendaftaran lengkap dengan urutan:
  /// 1. Upload foto menu ke Cloudinary
  /// 2. Buat akun di Firebase Auth
  /// 3. Simpan data role ke 'users'
  /// 4. Simpan data toko ke 'restaurants'
  /// 5. Simpan data menu ke subkoleksi 'menus'
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_menuItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan minimal 1 menu makanan')),
      );
      return;
    }

    setState(() {
      _loadingMessage = "Mengunggah menu (1/${_menuItems.length})...";
    });

    try {
      // 1. Upload Foto Menu
      List<Map<String, dynamic>> menuDataToSave = [];
      int counter = 1;

      for (var item in _menuItems) {
        setState(() {
          _loadingMessage = "Mengunggah menu ($counter/${_menuItems.length})...";
        });

        String menuId = FirebaseFirestore.instance.collection('temp').doc().id;

        CloudinaryResponse response = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(item.imageFile.path,
              resourceType: CloudinaryResourceType.Image,
              folder: 'foto_menu',
              publicId: 'menu_$menuId'),
        );
        
        menuDataToSave.add({
          'menuId': menuId,
          'namaMenu': item.namaMenu,
          'harga': item.harga,
          'fotoUrl': response.secureUrl,
          'isAvailable': true,
        });
        counter++;
      }
      
      // 2. Buat Akun Firebase Auth
      setState(() { _loadingMessage = "Membuat akun..."; });
      
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: widget.email,
        password: widget.password,
      );

      final user = userCredential.user;
      if (user == null) throw Exception("Gagal membuat akun");

      // 3. Simpan Data Role ke 'users'
      setState(() { _loadingMessage = "Menyimpan data (1/3)..."; });
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'role': 'restoran',
        'createdAt': Timestamp.now(),
      });

      // 4. Simpan data Restoran ke 'restaurants'
      setState(() { _loadingMessage = "Menyimpan data (2/3)..."; });
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(user.uid)
          .set({
        'uid': user.uid,
        'email': widget.email,
        'namaToko': _namaTokoController.text,
        'alamat': _alamatTokoController.text,
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });

      // 5. Simpan semua data menu (Batch Write)
      setState(() { _loadingMessage = "Menyimpan data (3/3)..."; });
      final batch = FirebaseFirestore.instance.batch();
      for (var menuData in menuDataToSave) {
        final menuDocRef = FirebaseFirestore.instance
            .collection('restaurants')
            .doc(user.uid)
            .collection('menus')
            .doc(menuData['menuId']);
        batch.set(menuDocRef, menuData);
      }
      await batch.commit();

      // Selesai. Reset navigasi kembali ke AuthWrapper (akar)
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }

    } on FirebaseAuthException catch (e) {
      _showErrorDialog('Error Pendaftaran', e.code == 'email-already-in-use'
          ? 'Email ini sudah terdaftar. Silakan kembali dan gunakan email lain.'
          : 'Terjadi error: ${e.message}');
          
    } catch (e) {
      _showErrorDialog('Terjadi Error', 'Detail Error: ${e.toString()}');
    }

    if (mounted) {
      setState(() {
        _loadingMessage = null;
      });
    }
  }

  /// Helper untuk menampilkan dialog error.
  void _showErrorDialog(String title, String content) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(ctx).pop(),
          )
        ],
      ),
    );
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
                
                // Tombol Submit dengan status loading
                ElevatedButton(
                  onPressed: _loadingMessage != null ? null : _submitForm,
                  child: _loadingMessage != null
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            const SizedBox(width: 16),
                            Flexible(child: Text(_loadingMessage!)),
                          ],
                        )
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