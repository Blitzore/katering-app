// File: lib/screens/customer/checkout_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'package:provider/provider.dart'; 
import 'package:intl/intl.dart'; 

import '../../models/subscription_slot.dart'; 
import '../../services/customer_service.dart';
import '../maps/location_picker_screen.dart';
import '../../utils/location_utils.dart';
import '../../providers/cart_provider.dart';

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
  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  
  // Variabel Lokasi & Ongkir
  LatLng? _userLocation;
  
  // Mapping ID Restoran ke Lokasi (untuk Multi-Restoran)
  Map<String, LatLng> _restoLocations = {}; 
  
  double _maxDistanceKm = 0.0; // Jarak terjauh (untuk info UI)
  int _shippingCost = 0;
  String? _errorMsg;

  // Variabel Harga
  int _totalFoodPrice = 0;

  @override
  void initState() {
    super.initState();
    _calculateTotalPrice();
    _fetchAllRestaurantLocations(); // Ambil lokasi semua restoran yang terlibat
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

  // --- 1. MENGAMBIL LOKASI SEMUA RESTORAN ---
  Future<void> _fetchAllRestaurantLocations() async {
    if (widget.slots.isEmpty) return;
    
    // Kumpulkan semua ID Restoran unik dari keranjang
    final Set<String> restoIds = widget.slots
        .where((slot) => slot.selectedMenu != null)
        .map((slot) => slot.selectedMenu!.restaurantId)
        .toSet();

    if (restoIds.isEmpty) {
        setState(() => _errorMsg = "Keranjang kosong atau data menu tidak valid.");
        return;
    }
    
    Map<String, LatLng> locations = {};
    String? failedRestoId;

    // Loop setiap ID restoran untuk ambil datanya
    for (String id in restoIds) {
        final resto = await _customerService.getRestaurantById(id);
        
        // Cek validitas lokasi restoran
        if (resto == null || (resto.latitude == 0 && resto.longitude == 0)) {
            failedRestoId = id;
            break; 
        }
        locations[id] = LatLng(resto.latitude, resto.longitude);
    }
    
    if (mounted) {
      if (failedRestoId != null) {
        setState(() => _errorMsg = "Restoran (ID: $failedRestoId) belum mengatur lokasi. Tidak bisa dipesan.");
      } else {
        setState(() {
          _restoLocations = locations;
          _errorMsg = null;
        });
      }
    }
  }

  void _pickLocation() async {
    if (_restoLocations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Menunggu data lokasi restoran dimuat...'))
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationPickerScreen()),
    );

    if (result != null && result is LatLng) {
      _calculateMultiRestoShipping(result);
    }
  }

  // --- 2. LOGIKA ONGKIR MULTI-RESTORAN (TIERED BARU) ---
  void _calculateMultiRestoShipping(LatLng userLoc) {
    if (_restoLocations.isEmpty) return;
    
    // Kelompokkan slot berdasarkan ID Restoran
    // Agar kita bisa hitung ongkir per restoran (karena jaraknya beda-beda)
    Map<String, List<SubscriptionSlot>> groupedSlots = {};
    for (var slot in widget.slots) {
        if (slot.selectedMenu != null) {
          final restoId = slot.selectedMenu!.restaurantId;
          groupedSlots.putIfAbsent(restoId, () => []).add(slot);
        }
    }

    int totalShippingCost = 0;
    double tempMaxDistance = 0.0;
    String? tempError;

    // Loop setiap restoran untuk hitung biayanya sendiri
    for (var entry in groupedSlots.entries) {
        final String restoId = entry.key;
        final List<SubscriptionSlot> slots = entry.value;
        final LatLng restoLoc = _restoLocations[restoId]!;
        
        // A. Hitung Jarak
        double dist = LocationUtils.calculateDistance(
          restoLoc.latitude, restoLoc.longitude, 
          userLoc.latitude, userLoc.longitude
        );

        // B. Cek Batas Maksimal 5 KM
        if (dist > 5.0) {
          tempError = "Salah satu restoran berjarak ${dist.toStringAsFixed(1)} KM (Max 5 KM). Pesanan ditolak.";
          break; // Stop perhitungan jika ada yang melanggar
        }

        if (dist > tempMaxDistance) {
            tempMaxDistance = dist;
        }

        // C. Tentukan Durasi Langganan (Max Day) untuk grup ini
        int maxDay = 0;
        if (slots.isNotEmpty) {
           maxDay = slots.map((s) => s.day).reduce((a, b) => a > b ? a : b);
        }

        // D. Tentukan Harga Per Trip (Tiered Pricing Baru)
        // Biaya Gaji Riil = Rp 5.000/titik
        double costPerTrip = 0.0;
        
        if (dist < 2.0) { 
            // Jarak < 2 KM
            if (maxDay >= 30) {
                costPerTrip = 4000;
            } else if (maxDay >= 14) {
                costPerTrip = 5000;
            } else { 
                costPerTrip = 6000; // 7 hari
            }
        } else if (dist >= 2.0 && dist < 3.0) { 
            // Jarak 2 - 3 KM
            if (maxDay >= 30) {
                costPerTrip = 5000;
            } else if (maxDay >= 14) {
                costPerTrip = 7000;
            } else { 
                costPerTrip = 8000; // 7 hari
            }
        } else { 
            // Jarak 3 - 5 KM
            if (maxDay >= 30) {
                costPerTrip = 7000;
            } else if (maxDay >= 14) {
                costPerTrip = 9000;
            } else { 
                costPerTrip = 10000; // 7 hari
            }
        }

        // E. Total Ongkir Restoran Ini = Harga Per Trip * Jumlah Menu
        int totalTrips = slots.length;
        int restoShippingCost = (costPerTrip * totalTrips).ceil();
        
        totalShippingCost += restoShippingCost;
    }
    
    // Update State UI
    setState(() {
      if (tempError != null) {
        _userLocation = null;
        _shippingCost = 0;
        _errorMsg = tempError;
      } else {
        _userLocation = userLoc;
        _maxDistanceKm = tempMaxDistance;
        _shippingCost = totalShippingCost;
        _errorMsg = null;
      }
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

      // Kirim Data ke Backend
      // Backend akan menerima 'shippingCost' total dan membaginya rata ke daily_orders
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'finalPrice': finalTotal,
          'userId': user.uid,
          'slots': slotsData,
          'shippingCost': _shippingCost, // Ongkir Total Gabungan
          'userLat': _userLocation!.latitude,
          'userLng': _userLocation!.longitude,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Hapus Keranjang setelah sukses request
        if (mounted) {
           Provider.of<CartProvider>(context, listen: false).clearCart(); 
        }

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
    int maxDay = widget.slots.isNotEmpty ? widget.slots.last.day : 1;
    
    // Tampilan Ongkir rata-rata per hari (untuk info saja)
    double ongkirPerDay = maxDay > 0 ? _shippingCost / maxDay : 0; 

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
                trailing: Text(currencyFormatter.format(slot.selectedMenu?.harga ?? 0)),
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
                  ? 'Jarak Terjauh: ${_maxDistanceKm.toStringAsFixed(1)} KM' 
                  : 'Wajib set lokasi untuk hitung ongkir'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: _pickLocation,
            ),
          ),

          const SizedBox(height: 24),

          // --- RINGKASAN BIAYA ---
          _buildSummaryRow('Total Makanan', currencyFormatter.format(_totalFoodPrice)),
          
          const Divider(height: 30),

          // --- TAMPILAN ONGKIR (Tiered Pricing) ---
          if (_shippingCost > 0) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Ongkir Rata-rata / Hari", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      Text(
                        currencyFormatter.format(ongkirPerDay), 
                        style: TextStyle(
                          color: Colors.green[800], 
                          fontSize: 20, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "*Harga bervariasi tergantung jarak per restoran & durasi langganan",
                    style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  "Total Ongkir ${maxDay} Hari: ${currencyFormatter.format(_shippingCost)}",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          _buildSummaryRow('Total Bayar', currencyFormatter.format(grandTotal), isBold: true, fontSize: 18),
          
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