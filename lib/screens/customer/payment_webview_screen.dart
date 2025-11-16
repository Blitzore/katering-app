// File: lib/screens/customer/payment_webview_screen.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Halaman WebView untuk memproses pembayaran.
class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;

  const PaymentWebViewScreen({Key? key, required this.paymentUrl})
      : super(key: key);

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {},
          onPageFinished: (String url) {},
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
            
            // --- INI ADALAH LOGIKA PENTING ---
            // Saat Midtrans/Xendit selesai, mereka akan redirect ke
            // URL 'finish' yang Anda atur di backend (Cloud Function).
            // Kita harus menangkapnya di sini.
            
            // Ganti URL ini dengan URL 'finish' Anda
            const String finishUrl = 'https://katering-app.com/payment-success';

            if (request.url.startsWith(finishUrl)) {
              print('Pembayaran selesai, navigasi ke halaman sukses...');
              
              // Navigasi ke halaman sukses dan hapus tumpukan checkout
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/payment_success',
                (route) => route.isFirst, // Hapus sampai ke AuthWrapper
              );
              
              // Hentikan WebView agar tidak menavigasi ke URL 'finish'
              return NavigationDecision.prevent; 
            }
            
            // Izinkan navigasi lainnya di dalam WebView (misal: pilih bank)
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proses Pembayaran'),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}