// File: functions/index.js

const admin = require("firebase-admin");
const midtransClient = require("midtrans-client");
const express = require("express");
const cors = require("cors");

// Inisialisasi Express
const app = express();
app.use(cors({origin: true}));
app.use(express.json());

// --- Inisialisasi Firebase Admin ---
const serviceAccountString = process.env.FIREBASE_SERVICE_ACCOUNT;
if (!serviceAccountString) {
  console.error("Variabel FIREBASE_SERVICE_ACCOUNT tidak ditemukan.");
}
const serviceAccount = JSON.parse(serviceAccountString);
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();
// --- Akhir Inisialisasi Firebase ---

// Inisialisasi Midtrans Snap client
const snap = new midtransClient.Snap({
  isProduction: false,
  serverKey: process.env.MIDTRANS_SERVER_KEY,
  clientKey: process.env.MIDTRANS_CLIENT_KEY,
});

/**
 * =================================================================
 * FUNGSI BARU: generateDailyOrders
 * =================================================================
 * Logika untuk membuat pesanan harian (Tugas Minggu ke-6)
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

  // 2. Tentukan tanggal mulai (hari ini/besok, tergantung jam)
  const startDate = new Date();
  // (Logika sederhana: jika pesan sebelum jam 5 sore, mulai besok)
  if (startDate.getHours() > 17) {
    startDate.setDate(startDate.getDate() + 1);
  }

  // 3. Loop dan buat dokumen pesanan harian (daily_orders)
  // Kita asumsikan 1 slot = 1 hari
  for (let i = 0; i < slots.length; i++) {
    const slot = slots[i];
    const menu = slot.selectedMenu; // (Asumsi dari Flutter)

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
      day: slot.day, // Misal: 1
      mealTime: slot.mealTime, // Misal: "Makan Siang"
      
      // Info Menu & Resto
      menuId: menu.menuId,
      namaMenu: menu.namaMenu,
      harga: menu.harga,
      fotoUrl: menu.fotoUrl,
      restaurantId: menu.restaurantId, // <-- Ini SANGAT PENTING
      
      // Status & Tanggal
      deliveryDate: admin.firestore.Timestamp.fromDate(deliveryDate),
      status: "confirmed", // Status awal (menunggu disiapkan resto)
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
 * ENDPOINT 1: createTransaction (Tidak Berubah)
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
    
    // Kita gunakan User ID + timestamp untuk Order ID
    const orderId = `${userId}-${Date.now()}`;

    // 1. Buat order di Firestore (sebagai 'pending_payment')
    // Kita ganti nama koleksi agar lebih jelas
    const orderRef = db.collection("pending_payments").doc(orderId);
    
    const orderPayload = {
      userId: userId,
      status: "pending",
      totalPrice: finalPrice,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      // 'items' sekarang berisi data menu lengkap
      items: slots.map((slot) => ({
        day: slot.day,
        mealTime: slot.mealTime,
        selectedMenu: {
          menuId: slot.selectedMenu.menuId,
          namaMenu: slot.selectedMenu.namaMenu,
          harga: slot.selectedMenu.harga,
          fotoUrl: slot.selectedMenu.fotoUrl,
          restaurantId: slot.selectedMenu.restaurantId,
        },
      })),
    };
    await orderRef.set(orderPayload);

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
    await orderRef.update({
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
 * ENDPOINT 2: paymentHandler (WEBHOOK - Dimodifikasi)
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
      throw new Error(`Dokumen order ${orderId} tidak ditemukan.`);
    }
    
    const orderData = orderDoc.data();

    // Cek status transaksi
    if (transactionStatus === "capture" || transactionStatus === "settlement") {
      if (fraudStatus === "accept") {
        
        // --- [LOGIKA MINGGU 6 DIMULAI DI SINI] ---
        
        // 1. Update status order 'pending_payments' menjadi 'paid'
        await orderRef.update({
          status: "paid",
          paymentDetails: statusResponse,
        });

        // 2. Panggil fungsi baru untuk generate pesanan harian
        await generateDailyOrders(orderId, orderData);
        
        // --- [LOGIKA MINGGU 6 SELESAI] ---

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

// ---
// Menjalankan server Express
// ---
const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  console.log(`Server katering berjalan di port ${PORT}`);
});

module.exports = app;