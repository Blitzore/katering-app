// File: lib/screens/customer/widgets/menu_card.dart
import 'package:flutter/material.dart';
import '../../../models/menu_model.dart';

/// Widget Card UI untuk menampilkan satu item menu.
class MenuCard extends StatelessWidget {
  final MenuModel menu;

  const MenuCard({Key? key, required this.menu}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias, // Untuk membulatkan gambar
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          /// Gambar Menu
          Expanded(
            child: Image.network(
              menu.fotoUrl,
              fit: BoxFit.cover,
              // Loading builder untuk gambar
              loadingBuilder: (context, child, progress) {
                return progress == null
                    ? child
                    : const Center(child: CircularProgressIndicator(strokeWidth: 2));
              },
              // Error builder jika gambar gagal dimuat
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                );
              },
            ),
          ),
          
          /// Detail Teks
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Nama Menu
                Text(
                  menu.namaMenu,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                /// Harga
                Text(
                  'Rp ${menu.harga}',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                // TODO: Tampilkan Nama Restoran (Memerlukan query tambahan)
                // Text(
                //   'Nama Resto',
                //   style: Theme.of(context).textTheme.bodySmall,
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}