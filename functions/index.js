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

    const orderId = `${userId}-${Date.now()}`;

    // 1. Buat order di Firestore
    const orderPayload = {
      userId: userId,
      status: "pending",
      totalPrice: finalPrice,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      
      // --- [PERBAIKAN DI SINI] ---
      // 'slots' dari req.body sudah memiliki format yang benar
      // (karena Flutter mengirim `slot.selectedMenu!.toJson()`)
      // Kita tidak perlu me-mapping-nya lagi.
      items: slots,
      // --- [AKHIR PERBAIKAN] ---
    };
    
    // Ganti 'orders' menjadi 'pending_payments' agar sesuai dengan logika webhook
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
      throw new Error(`Dokumen order ${orderId} tidak ditemukan.`);
    }
    
    const orderData = orderDoc.data();

    if (transactionStatus === "capture" || transactionStatus === "settlement") {
      if (fraudStatus === "accept") {
        
        // --- [LOGIKA MINGGU 6 DIMULAI DI SINI] ---
        await generateDailyOrders(orderId, orderData); // Panggil fungsi baru
        
        await orderRef.update({
          status: "paid",
          paymentDetails: statusResponse,
        });

      }
    } else if (
      transactionStatus === "cancel" ||
      transactionStatus === "deny" ||
      transactionStatus === "expire"
    ) {
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
 * FUNGSI BARU: generateDailyOrders
 * =================================================================
 */
const generateDailyOrders = async (orderId, orderData) => {
  const batch = db.batch();
  const slots = orderData.items; 
  const userId = orderData.userId;

  // 1. Buat satu dokumen langganan (subscription)
  const subscriptionRef = db.collection("subscriptions").doc(orderId);
  batch.set(subscriptionRef, {
    ...orderData,
    status: "active", 
  });

  // 2. Tentukan tanggal mulai (hari ini/besok, tergantung jam)
  const startDate = new Date();
  if (startDate.getHours() > 17) {
    startDate.setDate(startDate.getDate() + 1);
  }

  // 3. Loop dan buat dokumen pesanan harian (daily_orders)
  for (let i = 0; i < slots.length; i++) {
    const slot = slots[i];
    
    // [PERBAIKAN] Akses 'selectedMenu' dari 'slot'
    const menu = slot.selectedMenu; 

    if (!menu || !menu.menuId) {
      console.error("Data menu tidak lengkap di slot:", slot);
      // Lompati slot ini jika data menu tidak ada
      continue; 
    }

    // Hitung tanggal pengiriman
    const deliveryDate = new Date(startDate);
    deliveryDate.setDate(deliveryDate.getDate() + i);

    const dailyOrderId = `${orderId}_day${i + 1}`;
    const dailyOrderRef = db.collection("daily_orders").doc(dailyOrderId);

    const dailyOrderData = {
      subscriptionId: orderId,
      userId: userId,
      day: slot.day, 
      mealTime: slot.mealTime, 
      
      menuId: menu.menuId,
      namaMenu: menu.namaMenu,
      harga: menu.harga,
      fotoUrl: menu.fotoUrl,
      restaurantId: menu.restaurantId,
      
      deliveryDate: admin.firestore.Timestamp.fromDate(deliveryDate),
      status: "confirmed",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    
    batch.set(dailyOrderRef, dailyOrderData);
  }
  
  // 4. Commit semua operasi database sekaligus
  await batch.commit();
  console.log(`Berhasil generate ${slots.length} pesanan untuk ${orderId}`);
};


// ---
// Menjalankan server Express
// ---
const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  console.log(`Server katering berjalan di port ${PORT}`);
});

module.exports = app;