// File: lib/screens/restaurant/add_edit_menu_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/menu_model.dart';
import '../../services/restaurant_service.dart';

/// Halaman Form untuk menambah atau mengedit menu.
class AddEditMenuScreen extends StatefulWidget {
  /// ID restoran (diperlukan untuk service)
  final String restoId;
  /// Jika [menu] tidak null, berarti ini mode Edit.
  /// Jika [menu] null, berarti ini mode Tambah.
  final MenuModel? menu;

  const AddEditMenuScreen({
    Key? key,
    required this.restoId,
    this.menu,
  }) : super(key: key);

  @override
  _AddEditMenuScreenState createState() => _AddEditMenuScreenState();
}

class _AddEditMenuScreenState extends State<AddEditMenuScreen> {
  final _formKey = GlobalKey<FormState>();
  final _restaurantService = RestaurantService();
  final _picker = ImagePicker();

  late TextEditingController _namaController;
  late TextEditingController _hargaController;
  late bool _isAvailable;
  
  File? _imageFile; // Untuk gambar baru yang dipilih
  String? _existingImageUrl; // Untuk gambar lama (mode edit)
  bool _isLoading = false;

  /// Cek apakah ini mode Edit
  bool get _isEditMode => widget.menu != null;

  @override
  void initState() {
    super.initState();
    // Inisialisasi controller dengan data yang ada (jika mode Edit)
    _namaController = TextEditingController(text: widget.menu?.namaMenu);
    _hargaController =
        TextEditingController(text: widget.menu?.harga.toString());
    _isAvailable = widget.menu?.isAvailable ?? true;
    _existingImageUrl = widget.menu?.fotoUrl;
  }

  @override
  void dispose() {
    _namaController.dispose();
    _hargaController.dispose();
    super.dispose();
  }

  /// Helper untuk memilih gambar dari galeri
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 1080,
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _existingImageUrl = null; // Hapus gambar lama jika gambar baru dipilih
      });
    }
  }

  /// Menangani logika submit form
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validasi gambar
    if (_imageFile == null && !_isEditMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto menu wajib diisi')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final namaMenu = _namaController.text;
      final harga = int.parse(_hargaController.text);
      
      if (_isEditMode) {
        // --- LOGIKA UPDATE ---
        await _restaurantService.updateMenu(
          restoId: widget.restoId,
          menuId: widget.menu!.menuId,
          namaMenu: namaMenu,
          harga: harga,
          isAvailable: _isAvailable,
          existingFotoUrl: widget.menu!.fotoUrl,
          newImageFile: _imageFile,
          statusResto: widget.menu!.statusResto, // Kirim status lama
        );
        
      } else {
        // --- LOGIKA ADD ---
        await _restaurantService.addMenu(
          restoId: widget.restoId,
          namaMenu: namaMenu,
          harga: harga,
          isAvailable: _isAvailable,
          imageFile: _imageFile!, // Wajib ada di mode Tambah
        );
      }
      
      scaffoldMessenger.showSnackBar(
         SnackBar(
          content: Text('Menu berhasil ${ _isEditMode ? 'diperbarui' : 'ditambahkan'}!'),
          backgroundColor: Colors.green,
        ),
      );
      
      navigator.pop(); // Kembali ke halaman list
      
    } catch (e) {
       scaffoldMessenger.showSnackBar(
         SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Menu' : 'Tambah Menu Baru'),
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Pemilih Gambar
                  _buildImagePicker(),
                  const SizedBox(height: 24),
                  
                  // 2. Form Nama Menu
                  TextFormField(
                    controller: _namaController,
                    decoration: const InputDecoration(labelText: 'Nama Makanan'),
                    validator: (v) => v!.isEmpty ? 'Nama wajib diisi' : null,
                  ),
                  const SizedBox(height: 20),
                  
                  // 3. Form Harga
                  TextFormField(
                    controller: _hargaController,
                    decoration: const InputDecoration(labelText: 'Harga (Rp)'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => v!.isEmpty ? 'Harga wajib diisi' : null,
                  ),
                  const SizedBox(height: 10),

                  // 4. Switch Ketersediaan
                  SwitchListTile(
                    title: const Text('Tersedia'),
                    value: _isAvailable,
                    onChanged: (val) {
                      setState(() => _isAvailable = val);
                    },
                    activeColor: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 30),
                  
                  // 5. Tombol Submit
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    child: Text(_isEditMode ? 'Simpan Perubahan' : 'Simpan Menu'),
                  ),
                ],
              ),
            ),
          ),
          // Indikator Loading
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  /// Widget helper untuk pemilih gambar
  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(10),
        ),
        child: _imageFile != null
            ? Image.file(_imageFile!, fit: BoxFit.cover)
            : (_existingImageUrl != null
                ? Image.network(_existingImageUrl!, fit: BoxFit.cover)
                : const Center(
                    child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                      Text('Pilih Foto Menu',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ))),
      ),
    );
  }
}