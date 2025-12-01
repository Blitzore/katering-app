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

// Inisialisasi Midtrans Snap client
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
  const slots = orderData.items; 
  const userId = orderData.userId;

  const subscriptionRef = db.collection("subscriptions").doc(orderId);
  batch.set(subscriptionRef, {
    ...orderData,
    status: "active", 
  });

  const startDate = new Date();
  startDate.setDate(startDate.getDate() + 1); // Mulai besok
  if (new Date().getHours() > 20) {
    startDate.setDate(startDate.getDate() + 1); 
  }

  for (let i = 0; i < slots.length; i++) {
    const slot = slots[i];
    const menu = slot.selectedMenu; 

    if (!menu || !menu.menuId) continue;

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
  
  await batch.commit();
  console.log(`Berhasil generate ${slots.length} pesanan untuk ${orderId}`);
};

/**
 * =================================================================
 * ENDPOINT 1: createTransaction
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

    const orderPayload = {
      userId: userId,
      status: "pending",
      totalPrice: finalPrice,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      items: slots, 
    };
    await db.collection("pending_payments").doc(orderId).set(orderPayload);

    const parameter = {
      transaction_details: {
        order_id: orderId,
        gross_amount: finalPrice,
      },
      callbacks: {
        finish: "https://katering-app.com/payment-success",
      },
    };

    const transaction = await snap.createTransaction(parameter);
    const paymentUrl = transaction.redirect_url;

    await db.collection("pending_payments").doc(orderId).update({
      paymentUrl: paymentUrl,
    });

    res.status(200).send({paymentUrl: paymentUrl});
  } catch (e) {
    console.error(e);
    res.status(500).send({error: e.message});
  }
});

/**
 * =================================================================
 * ENDPOINT 2: paymentHandler (Webhook)
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

    const orderRef = db.collection("pending_payments").doc(orderId);
    const orderDoc = await orderRef.get();

    if (!orderDoc.exists) {
      console.warn(`Dokumen order ${orderId} tidak ditemukan.`);
      return res.status(404).send("Order tidak ditemukan.");
    }
    
    const orderData = orderDoc.data();

    if (transactionStatus === "capture" || transactionStatus === "settlement") {
      if (fraudStatus === "accept") {
        await orderRef.update({
          status: "paid",
          paymentDetails: statusResponse,
        });
        await generateDailyOrders(orderId, orderData);
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
    console.error("Error menangani notifikasi:", e);
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

// --- Menjalankan server ---
const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  console.log(`Server katering berjalan di port ${PORT}`);
});

module.exports = app;