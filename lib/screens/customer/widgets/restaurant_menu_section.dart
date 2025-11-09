// File: lib/screens/customer/widgets/restaurant_menu_section.dart
import 'package:flutter/material.dart';
import '../../../models/menu_model.dart';
import '../../../models/restaurant_model.dart';
import '../../../services/customer_service.dart';
import '../restaurant_detail_screen.dart'; // Import halaman detail baru
import 'menu_card.dart'; 

/// Widget untuk menampilkan satu baris restoran
/// beserta daftar menu horizontalnya.
class RestaurantMenuSection extends StatefulWidget {
  final RestaurantModel restaurant;
  const RestaurantMenuSection({Key? key, required this.restaurant})
      : super(key: key);

  @override
  _RestaurantMenuSectionState createState() => _RestaurantMenuSectionState();
}

class _RestaurantMenuSectionState extends State<RestaurantMenuSection> {
  final CustomerService _customerService = CustomerService();
  late Future<List<MenuModel>> _menusFuture;

  @override
  void initState() {
    super.initState();
    // Ambil data menu saat widget pertama kali dibuat
    _menusFuture = _customerService.getMenusForRestaurant(widget.restaurant.id);
  }

  /// Navigasi ke halaman detail restoran
  void _navigateToDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            RestaurantDetailScreen(restaurant: widget.restaurant),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Judul Restoran (Dibuat bisa diklik)
          InkWell(
            onTap: () => _navigateToDetail(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.restaurant.namaToko,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        'Lihat semua',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontSize: 14,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).primaryColor,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.restaurant.alamat,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2. Daftar Menu Horizontal
          FutureBuilder<List<MenuModel>>(
            future: _menusFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                // Tampilkan container kosong selagi loading
                return Container(
                  height: 220,
                  child: const Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Container(
                  height: 220,
                  child: const Center(child: Text('Gagal memuat menu')),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Container(
                  height: 100, // Lebih kecil jika tidak ada menu
                  child: const Center(child: Text('Tidak ada menu tersedia')),
                );
              }

              final menus = snapshot.data!;

              // ListView horizontal
              return Container(
                height: 220, // Tentukan tinggi untuk list horizontal
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: menus.length,
                  itemBuilder: (context, index) {
                    // Beri margin agar tidak menempel
                    return Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: SizedBox(
                        width: 160, // Tentukan lebar untuk menu card
                        child: MenuCard(menu: menus[index]),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}