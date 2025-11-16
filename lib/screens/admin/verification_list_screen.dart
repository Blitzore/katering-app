// File: lib/screens/admin/verification_list_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'verification_detail_screen.dart'; // Import halaman detail

/// Menampilkan daftar mitra (restoran & driver) yang statusnya 'pending'.
class VerificationListScreen extends StatelessWidget {
  const VerificationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Daftar Verifikasi Mitra'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Restoran', icon: Icon(Icons.storefront)),
              Tab(text: 'Driver', icon: Icon(Icons.delivery_dining)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            // Tab untuk Restoran
            _PartnerList(collectionName: 'restaurants'),
            // Tab untuk Driver
            _PartnerList(collectionName: 'drivers'),
          ],
        ),
      ),
    );
  }
}

/// Widget internal untuk mengambil dan menampilkan daftar mitra 'pending'.
class _PartnerList extends StatelessWidget {
  final String collectionName;

  const _PartnerList({super.key, required this.collectionName});

  @override
  Widget build(BuildContext context) {
    /// Query untuk mengambil data yang statusnya 'pending'
    final query = FirebaseFirestore.instance
        .collection(collectionName)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'Tidak ada pendaftar baru.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            // Menentukan data yang akan ditampilkan
            final String title;
            final String subtitle;
            IconData icon;

            if (collectionName == 'restaurants') {
              title = data['namaToko'] ?? 'Data Restoran Tidak Lengkap';
              subtitle = data['alamat'] ?? data['email'] ?? 'Info tidak ada';
              icon = Icons.storefront;
            } else {
              title = data['namaLengkap'] ?? 'Data Driver Tidak Lengkap';
              subtitle = data['noPolisi'] ?? data['email'] ?? 'Info tidak ada';
              icon = Icons.delivery_dining;
            }

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: Icon(icon, color: Theme.of(context).primaryColor),
                title: Text(title),
                subtitle: Text(subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Navigasi ke halaman detail
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VerificationDetailScreen(
                        collection: collectionName,
                        uid: doc.id,
                        data: data,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}