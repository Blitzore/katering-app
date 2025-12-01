// File: functions/index.js

const admin = require("firebase-admin");
const midtransClient = require("midtrans-client");
const express = require("express");
const cors = require("cors");

// Inisialisasi Express
const app = express();
app.use(cors({origin: true}));
app.use(express.json());

// --- Inisialisasi Firebase Admin (WAJIB) ---
// 1. Ambil string JSON dari Environment Variable Vercel
const serviceAccountString = process.env.FIREBASE_SERVICE_ACCOUNT;

if (!serviceAccountString) {
  console.error("Variabel FIREBASE_SERVICE_ACCOUNT tidak ditemukan.");
}

// 2. Ubah string JSON kembali menjadi objek
const serviceAccount = JSON.parse(serviceAccountString);

// 3. Inisialisasi Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();
// --- Akhir Inisialisasi Firebase ---

// Inisialisasi Midtrans Snap client (Baca dari Environment Variables Vercel)
const snap = new midtransClient.Snap({
  isProduction: false,
  serverKey: process.env.MIDTRANS_SERVER_KEY,
  clientKey: process.env.MIDTRANS_CLIENT_KEY,
});

/**
 * HELPER: Hitung Jarak (Haversine Formula)
 * Mengembalikan jarak dalam Kilometer (KM)
 */
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Radius bumi dalam km
  const dLat = (lat2 - lat1) * (Math.PI / 180);
  const dLon = (lon2 - lon1) * (Math.PI / 180);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * (Math.PI / 180)) *
      Math.cos(lat2 * (Math.PI / 180)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const d = R * c;
  return d;
}

/**
 * HELPER: Generate Daily Orders
 * Logika untuk membuat pesanan harian (Minggu 6)
 */
const generateDailyOrders = async (orderId, orderData) => {
  const batch = db.batch();
  const slots = orderData.items; // Array slot dari order
  const userId = orderData.userId;

  // 1. Buat satu dokumen langganan (subscription)
  const subscriptionRef = db.collection("subscriptions").doc(orderId);
  batch.set(subscriptionRef, {
    ...orderData,
    status: "active", // Status langganan aktif
  });

  // --- [LOGIKA TANGGAL H+1] ---
  const startDate = new Date();
  
  // Selalu mulai BESOK (H+1) sebagai default
  startDate.setDate(startDate.getDate() + 1);

  // Jika pesan sudah terlalu malam (misal > jam 20.00), 
  // mungkin restoran butuh waktu lebih, jadi mulai LUSA (H+2)
  if (new Date().getHours() > 20) {
    startDate.setDate(startDate.getDate() + 1); 
  }
  // --- [AKHIR LOGIKA] ---

  // 3. Loop dan buat dokumen pesanan harian (daily_orders)
  for (let i = 0; i < slots.length; i++) {
    const slot = slots[i];
    
    // Pastikan selectedMenu ada
    const menu = slot.selectedMenu; 

    if (!menu || !menu.menuId) {
      console.error("Data menu tidak lengkap di slot:", slot);
      continue; 
    }

    // Hitung tanggal pengiriman
    const deliveryDate = new Date(startDate);
    deliveryDate.setDate(deliveryDate.getDate() + i);

    // Buat ID unik untuk pesanan harian
    const dailyOrderId = `${orderId}_day${i + 1}`;
    const dailyOrderRef = db.collection("daily_orders").doc(dailyOrderId);

    // Data untuk dokumen pesanan harian
    const dailyOrderData = {
      subscriptionId: orderId,
      userId: userId,
      day: slot.day, 
      mealTime: slot.mealTime, 
      
      // Info Menu & Resto
      menuId: menu.menuId,
      namaMenu: menu.namaMenu,
      harga: menu.harga,
      fotoUrl: menu.fotoUrl,
      restaurantId: menu.restaurantId, // Penting untuk query Resto
      
      // Status & Tanggal
      deliveryDate: admin.firestore.Timestamp.fromDate(deliveryDate),
      status: "confirmed", // Status awal
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    
    batch.set(dailyOrderRef, dailyOrderData);
  }
  
  // 4. Commit semua operasi database sekaligus
  await batch.commit();
  console.log(`Berhasil generate ${slots.length} pesanan untuk ${orderId}`);
};

/**
 * =================================================================
 * ENDPOINT 1: createTransaction (Dipanggil oleh Flutter)
 * =================================================================
 */
app.post("/createTransaction", async (req, res) => {
  try {
    const finalPrice = req.body.finalPrice;
    const slots = req.body.slots;
    const userId = req.body.userId;

    if (!userId) {
      throw new Error("User ID tidak ditemukan di request body.");
    }

    // Perpendek Order ID agar lolos validasi Midtrans
    const orderId = `${userId}-${Date.now()}`;

    // 1. Buat order di Firestore (sebagai 'pending_payments')
    const orderPayload = {
      userId: userId,
      status: "pending",
      totalPrice: finalPrice,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      items: slots, // Data slot sudah lengkap dari Flutter
    };
    await db.collection("pending_payments").doc(orderId).set(orderPayload);

    // 2. Siapkan parameter Midtrans
    const parameter = {
      transaction_details: {
        order_id: orderId,
        gross_amount: finalPrice,
      },
      callbacks: {
        finish: "https://katering-app.com/payment-success",
      },
    };

    // 3. Buat transaksi Midtrans
    const transaction = await snap.createTransaction(parameter);
    const paymentUrl = transaction.redirect_url;

    // 4. Update order di Firestore
    await db.collection("pending_payments").doc(orderId).update({
      paymentUrl: paymentUrl,
    });

    // 5. Kembalikan URL ke Flutter
    res.status(200).send({paymentUrl: paymentUrl});
  } catch (e) {
    console.error(e);
    res.status(500).send({error: e.message});
  }
});

/**
 * =================================================================
 * ENDPOINT 2: paymentHandler (WEBHOOK - Dipanggil oleh Midtrans)
 * =================================================================
 */
app.post("/paymentHandler", async (req, res) => {
  try {
    const notificationJson = req.body;
    const statusResponse = await snap.transaction.notification(
      notificationJson,
    );

    const orderId = statusResponse.order_id;
    const transactionStatus = statusResponse.transaction_status;
    const fraudStatus = statusResponse.fraud_status;

    console.log(
      `Notifikasi untuk Order ID: ${orderId}, Status: ${transactionStatus}`,
    );

    // Ambil referensi order dari 'pending_payments'
    const orderRef = db.collection("pending_payments").doc(orderId);
    const orderDoc = await orderRef.get();

    if (!orderDoc.exists) {
      // Jika order tidak ditemukan, mungkin ini order lama atau salah ID
      console.warn(`Dokumen order ${orderId} tidak ditemukan.`);
      return res.status(404).send("Order tidak ditemukan.");
    }
    
    const orderData = orderDoc.data();

    // Cek status transaksi
    if (transactionStatus === "capture" || transactionStatus === "settlement") {
      if (fraudStatus === "accept") {
        
        // 1. Update status pembayaran menjadi 'paid'
        await orderRef.update({
          status: "paid",
          paymentDetails: statusResponse,
        });

        // 2. Generate pesanan harian (Daily Orders) untuk Restoran
        await generateDailyOrders(orderId, orderData);

      }
    } else if (
      transactionStatus === "cancel" ||
      transactionStatus === "deny" ||
      transactionStatus === "expire"
    ) {
      // Pembayaran gagal atau dibatalkan
      await orderRef.update({
        status: "failed",
        paymentDetails: statusResponse,
      });
    }

    res.status(200).send("Notifikasi berhasil diterima.");
  } catch (e) {
    console.error(
      "Error menangani notifikasi:",
      e,
    );
    res.status(500).send("Error internal.");
  }
});

/**
 * =================================================================
 * ENDPOINT 3: markReadyAndAutoAssign (BARU - Minggu 7)
 * Dipanggil oleh RESTORAN saat klik "Siap Diambil"
 * =================================================================
 */
app.post("/markReadyAndAutoAssign", async (req, res) => {
  try {
    const { orderIds } = req.body; // Array ID pesanan
    if (!orderIds || orderIds.length === 0) {
      return res.status(400).send("Tidak ada Order ID.");
    }

    // 1. Ambil data salah satu order untuk tahu Lokasi Restoran
    const firstOrderDoc = await db.collection("daily_orders").doc(orderIds[0]).get();
    if (!firstOrderDoc.exists) {
        return res.status(404).send("Order tidak ditemukan.");
    }
    const orderData = firstOrderDoc.data();
    const restoId = orderData.restaurantId;

    // 2. Ambil data Lokasi Restoran
    const restoDoc = await db.collection("restaurants").doc(restoId).get();
    if (!restoDoc.exists) {
        return res.status(404).send("Restoran tidak ditemukan.");
    }
    
    // Default lokasi 0,0 jika belum diset
    const restoLat = restoDoc.data().latitude || 0.0;
    const restoLng = restoDoc.data().longitude || 0.0;

    // 3. Ambil SEMUA Driver yang Verified
    const driversSnapshot = await db.collection("drivers")
        .where("status", "==", "verified")
        .get();

    let selectedDriverId = null;
    let selectedDriverName = "";

    // 4. Cari Driver dalam Radius 5KM
    for (const doc of driversSnapshot.docs) {
      const driver = doc.data();
      const drvLat = driver.latitude || 0.0;
      const drvLng = driver.longitude || 0.0;

      const distance = calculateDistance(restoLat, restoLng, drvLat, drvLng);

      if (distance <= 5.0) {
        // Driver ditemukan!
        selectedDriverId = doc.id;
        selectedDriverName = driver.namaLengkap;
        break; // Ambil driver pertama yang ketemu
      }
    }

    if (!selectedDriverId) {
      return res.status(404).send("Tidak ada driver dalam radius 5KM.");
    }

    // 5. Update Status Order -> 'assigned' & Simpan Driver ID
    const batch = db.batch();
    for (const id of orderIds) {
      const ref = db.collection("daily_orders").doc(id);
      batch.update(ref, {
        status: "assigned", // Status baru untuk Driver
        driverId: selectedDriverId,
        driverName: selectedDriverName,
      });
    }
    await batch.commit();

    res.status(200).send({
      status: "success",
      message: `Berhasil ditugaskan ke ${selectedDriverName}`,
      driverId: selectedDriverId,
    });

  } catch (e) {
    console.error(e);
    res.status(500).send(e.message);
  }
});

// --- [ENDPOINT ROOT] ---
app.get("/", (req, res) => {
  res.status(200).send("Backend Katering App is running and healthy! 🚀");
});

// --- Menjalankan server ---
const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  console.log(`Server katering berjalan di port ${PORT}`);
});

module.exports = app;