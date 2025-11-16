// File: functions/index.js

// JANGAN gunakan 'firebase-functions' lagi
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

    const orderId = `KATERING-${userId}-${Date.now()}`;

    // 1. Buat order di Firestore
    const orderPayload = {
      userId: userId,
      status: "pending",
      totalPrice: finalPrice,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      items: slots,
    };
    await db.collection("orders").doc(orderId).set(orderPayload);

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
    await db.collection("orders").doc(orderId).update({
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

    const orderRef = db.collection("orders").doc(orderId);

    if (transactionStatus === "capture" || transactionStatus === "settlement") {
      if (fraudStatus === "accept") {
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

// ---
// Menjalankan server Express
// ---
const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  console.log(`Server katering berjalan di port ${PORT}`);
});

// Kita export 'app' agar Vercel bisa menggunakannya
module.exports = app;