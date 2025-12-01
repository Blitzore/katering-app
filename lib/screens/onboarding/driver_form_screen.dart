// File: lib/screens/onboarding/driver_form_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Halaman stateful untuk form pendaftaran data Driver.
/// Menerima [email] dan [password] dari halaman register.
class DriverFormScreen extends StatefulWidget {
  final String email;
  final String password;

  const DriverFormScreen({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  _DriverFormScreenState createState() => _DriverFormScreenState();
}

class _DriverFormScreenState extends State<DriverFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _noHpController = TextEditingController();
  final _noPolisiController = TextEditingController();

  File? _simImageFile;
  File? _ktpImageFile;
  String? _loadingMessage;

  final cloudinary =
      CloudinaryPublic('drdfrxobm', 'katering_app', cache: false);

  @override
  void dispose() {
    _namaController.dispose();
    _noHpController.dispose();
    _noPolisiController.dispose();
    super.dispose();
  }

  /// Helper untuk memilih gambar dari galeri DAN MENGOMPRES-nya.
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

  /// Menjalankan proses pendaftaran lengkap untuk driver:
  /// 1. Upload foto SIM & KTP ke Cloudinary
  /// 2. Buat akun di Firebase Auth
  /// 3. Simpan data role ke 'users'
  /// 4. Simpan data driver ke 'drivers'
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_simImageFile == null || _ktpImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto SIM dan KTP wajib diunggah')),
      );
      return;
    }

    setState(() {
      _loadingMessage = 'Mengunggah Foto SIM (1/2)...';
    });

    try {
      // 1. Upload Foto
      final simResponse = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(_simImageFile!.path,
            resourceType: CloudinaryResourceType.Image,
            folder: 'foto_sim',
            publicId: 'sim_${widget.email}'),
      );
      final simUrl = simResponse.secureUrl;

      setState(() { _loadingMessage = 'Mengunggah Foto KTP (2/2)...'; });
      final ktpResponse = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(_ktpImageFile!.path,
            resourceType: CloudinaryResourceType.Image,
            folder: 'foto_ktp',
            publicId: 'ktp_${widget.email}'),
      );
      final ktpUrl = ktpResponse.secureUrl;

      // 2. Buat Akun Firebase Auth
      setState(() { _loadingMessage = 'Membuat akun...'; });
      
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: widget.email,
        password: widget.password,
      );

      final user = userCredential.user;
      if (user == null) throw Exception("Gagal membuat akun");

      // 3. Simpan Data Role ke 'users'
      setState(() { _loadingMessage = 'Menyimpan data (1/2)...'; });
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'role': 'driver',
        'createdAt': Timestamp.now(),
      });
      
      // 4. Simpan data Driver ke 'drivers'
      setState(() { _loadingMessage = 'Menyimpan data (2/2)...'; });
      await FirebaseFirestore.instance.collection('drivers').doc(user.uid).set({
        'uid': user.uid,
        'email': widget.email,
        'namaLengkap': _namaController.text,
        'noHp': _noHpController.text,
        'noPolisi': _noPolisiController.text,
        'simUrl': simUrl,
        'ktpUrl': ktpUrl,
        'status': 'pending', 
        'createdAt': Timestamp.now(),
      });

      // Selesai. Reset navigasi kembali ke AuthWrapper (akar)
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }

    } on FirebaseAuthException catch (e) {
      _showErrorDialog('Error Pendaftaran', e.code == 'email-already-in-use'
          ? 'Email ini sudah terdaftar. Silakan kembali.'
          : 'Terjadi error: ${e.message}');
          
    } catch (e) {
      _showErrorDialog('Terjadi Error', 'Detail Error: ${e.toString()}');
    }

    if (mounted) {
      setState(() {
        _loadingMessage = null; // Sembunyikan loading
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
                    onPressed: () => Navigator.of(ctx).pop())
              ],
            ));
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
          title: const Text('Pendaftaran Driver'),
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
                  "Lengkapi Data Driver Anda",
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
                  controller: _namaController,
                  decoration: const InputDecoration(
                      labelText: 'Nama Lengkap (Sesuai KTP)'),
                  validator: (v) => v!.isEmpty ? 'Nama wajib diisi' : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _noHpController,
                  decoration:
                      const InputDecoration(labelText: 'Nomor HP (WhatsApp)'),
                  keyboardType: TextInputType.phone,
                  validator: (v) => v!.isEmpty ? 'Nomor HP wajib diisi' : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _noPolisiController,
                  decoration: const InputDecoration(
                      labelText: 'Nomor Polisi (Contoh: B 1234 ABC)'),
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) =>
                      v!.isEmpty ? 'Nomor polisi wajib diisi' : null,
                ),
                const SizedBox(height: 30),
                
                Text("Foto SIM C (Aktif)",
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    final file = await _pickImage();
                    if (file != null) setState(() => _simImageFile = file);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    height: 150,
                    width: double.infinity,
                    child: _simImageFile == null
                        ? const Center(
                            child: Icon(Icons.add_a_photo,
                                color: Colors.grey, size: 40))
                        : Image.file(_simImageFile!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 20),

                Text("Foto KTP",
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    final file = await _pickImage();
                    if (file != null) setState(() => _ktpImageFile = file);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    height: 150,
                    width: double.infinity,
                    child: _ktpImageFile == null
                        ? const Center(
                            child: Icon(Icons.add_a_photo,
                                color: Colors.grey, size: 40))
                        : Image.file(_ktpImageFile!, fit: BoxFit.cover),
                  ),
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