// File: lib/screens/customer/checkout_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'package:provider/provider.dart'; 

import '../../models/subscription_slot.dart'; 
import '../../services/customer_service.dart';
import '../maps/location_picker_screen.dart';
import '../../utils/location_utils.dart';
import '../../providers/cart_provider.dart'; // Import CartProvider

class CheckoutScreen extends StatefulWidget {
  final List<SubscriptionSlot> slots;

  const CheckoutScreen({
    Key? key,
    required this.slots,
  }) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final CustomerService _customerService = CustomerService();
  bool _isLoading = false;
  
  // Variabel Lokasi & Ongkir
  LatLng? _userLocation;
  double? _restoLat;
  double? _restoLng;
  double _distanceKm = 0.0;
  int _shippingCost = 0;
  String? _errorMsg;

  // Variabel Harga
  int _totalFoodPrice = 0;

  @override
  void initState() {
    super.initState();
    _calculateTotalPrice();
    _fetchRestaurantLocation();
  }

  void _calculateTotalPrice() {
    int total = 0;
    for (var slot in widget.slots) {
      if (slot.selectedMenu != null) {
        total += slot.selectedMenu!.harga;
      }
    }
    setState(() {
      _totalFoodPrice = total;
    });
  }

  Future<void> _fetchRestaurantLocation() async {
    if (widget.slots.isEmpty) return;
    
    final firstSlot = widget.slots.first;
    if (firstSlot.selectedMenu == null) return;

    final String restoId = firstSlot.selectedMenu!.restaurantId;
    if (restoId.isEmpty) {
      setState(() => _errorMsg = "ERROR DATA: ID Restoran Kosong. Hapus keranjang & pesan ulang.");
      return;
    }
    
    final resto = await _customerService.getRestaurantById(restoId);
    
    if (resto == null) {
      setState(() => _errorMsg = "Data restoran hilang dari server.");
      return;
    }

    if (mounted) {
      if (resto.latitude != 0 && resto.longitude != 0) {
        setState(() {
          _restoLat = resto.latitude;
          _restoLng = resto.longitude;
        });
      } else {
        setState(() => _errorMsg = "Restoran belum mengatur lokasi (Lat/Lng masih 0).");
      }
    }
  }

  void _pickLocation() async {
    if (_restoLat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data lokasi restoran tidak valid.'))
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationPickerScreen()),
    );

    if (result != null && result is LatLng) {
      _calculateShipping(result);
    }
  }

  void _calculateShipping(LatLng userLoc) {
    if (_restoLat == null || _restoLng == null) return;

    double dist = LocationUtils.calculateDistance(
      _restoLat!, _restoLng!, 
      userLoc.latitude, userLoc.longitude
    );

    if (dist > 5.0) {
      setState(() {
        _userLocation = null;
        _distanceKm = 0;
        _shippingCost = 0;
        _errorMsg = "Kejauhan (${dist.toStringAsFixed(1)} KM). Max 5 KM.";
      });
      return;
    }

    int maxDay = 0;
    if (widget.slots.isNotEmpty) {
      for (var slot in widget.slots) {
        if (slot.day > maxDay) maxDay = slot.day;
      }
    }
    
    int mealsPerDay = 1;
    if (maxDay > 0) {
      mealsPerDay = (widget.slots.length / maxDay).ceil();
    }

    double payableDist = dist < 1.0 ? 1.0 : dist;
    double baseCostPerTrip = payableDist * 4000; 

    double durationMultiplier = 1.0;
    if (maxDay <= 7) {
      durationMultiplier = 1.0;      
    } else if (maxDay <= 14) {
      durationMultiplier = 1.5;      
    } else {
      durationMultiplier = 2.0;      
    }

    double totalCost = (baseCostPerTrip * durationMultiplier) * mealsPerDay;
    int fixedCost = totalCost.ceil();

    setState(() {
      _userLocation = userLoc;
      _distanceKm = dist;
      _shippingCost = fixedCost;
      _errorMsg = null; 
    });
  }

  Future<void> _processPayment() async {
    if (_userLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih lokasi pengiriman dahulu!')));
      return;
    }

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final int finalTotal = _totalFoodPrice + _shippingCost;
      
      // Pastikan URL Backend Anda benar
      final url = Uri.parse('https://katering-app.vercel.app/createTransaction'); 

      final List<Map<String, dynamic>> slotsData = widget.slots.map((slot) {
        return {
          'day': slot.day,
          'mealTime': slot.mealTime,
          'selectedMenu': {
            'menuId': slot.selectedMenu!.menuId,
            'namaMenu': slot.selectedMenu!.namaMenu,
            'harga': slot.selectedMenu!.harga,
            'fotoUrl': slot.selectedMenu!.fotoUrl,
            'restaurantId': slot.selectedMenu!.restaurantId,
          }
        };
      }).toList();

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'finalPrice': finalTotal,
          'userId': user.uid,
          'slots': slotsData,
          'shippingCost': _shippingCost,
          'userLat': _userLocation!.latitude,
          'userLng': _userLocation!.longitude,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        
        // --- [PERBAIKAN: Gunakan clearCart()] ---
        if (mounted) {
           // Panggil fungsi sesuai nama di cart_provider.dart Anda
           Provider.of<CartProvider>(context, listen: false).clearCart(); 
        }
        // ----------------------------------------

        if (mounted) {
           Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentWebViewScreen(paymentUrl: responseData['paymentUrl']),
            ),
          );
        }
      } else {
        throw Exception('Gagal: ${responseData['error']}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    int grandTotal = _totalFoodPrice + _shippingCost;
    bool isLocationSelected = _userLocation != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Konfirmasi Langganan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Rincian Paket Menu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          
          ListView.builder(
            shrinkWrap: true, 
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.slots.length,
            itemBuilder: (context, index) {
              final slot = widget.slots[index];
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.restaurant, size: 20, color: Colors.grey),
                title: Text('Hari ${slot.day} - ${slot.mealTime}'),
                subtitle: Text(slot.selectedMenu?.namaMenu ?? '-'),
                trailing: Text('Rp ${slot.selectedMenu?.harga ?? 0}'),
              );
            },
          ),
          const Divider(),
          
          const SizedBox(height: 16),
          const Text('Lokasi Pengiriman', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          
          if (_errorMsg != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.red[50],
              child: Text(_errorMsg!, style: const TextStyle(color: Colors.red)),
            ),

          Card(
            elevation: 1,
            color: Colors.blue[50],
            child: ListTile(
              leading: Icon(Icons.location_on, color: isLocationSelected ? Colors.green : Colors.orange),
              title: Text(isLocationSelected ? 'Lokasi Terpilih' : 'Pilih Lokasi Antar'),
              subtitle: Text(isLocationSelected 
                  ? 'Jarak: ${_distanceKm.toStringAsFixed(1)} KM' 
                  : 'Wajib set lokasi untuk ongkir'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: _pickLocation,
            ),
          ),

          const SizedBox(height: 24),

          _buildSummaryRow('Total Makanan', 'Rp $_totalFoodPrice'),
          _buildSummaryRow('Ongkos Kirim', 'Rp $_shippingCost', color: Colors.green[700]),
          const Divider(thickness: 1.5),
          _buildSummaryRow('Total Bayar', 'Rp $grandTotal', isBold: true, fontSize: 18),
          
          const SizedBox(height: 30),
          
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: (isLocationSelected && _errorMsg == null) ? Theme.of(context).primaryColor : Colors.grey,
              ),
              onPressed: (isLocationSelected && _errorMsg == null && !_isLoading) 
                  ? _processPayment 
                  : null,
              child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('BAYAR LANGGANAN', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? color, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }
}

class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  const PaymentWebViewScreen({Key? key, required this.paymentUrl}) : super(key: key);

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
            if (url.contains('payment-success') || url.contains('status_code=200')) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pembayaran Berhasil!'), backgroundColor: Colors.green));
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}