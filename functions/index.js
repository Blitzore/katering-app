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
  return R * c;
}

/**
 * HELPER: Generate Daily Orders
 * Logika untuk membuat pesanan harian
 */
const generateDailyOrders = async (orderId, orderData) => {
  const batch = db.batch();
  const slots = orderData.items; 
  const userId = orderData.userId;

  // 1. Buat satu dokumen langganan
  const subscriptionRef = db.collection("subscriptions").doc(orderId);
  batch.set(subscriptionRef, {
    ...orderData,
    status: "active",
  });

  // Logika Tanggal
  const startDate = new Date();
  startDate.setDate(startDate.getDate() + 1); // Mulai Besok
  if (new Date().getHours() > 20) {
    startDate.setDate(startDate.getDate() + 1); // Lusa jika malam
  }

  // 3. Loop dan buat dokumen pesanan harian
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
      shippingCost: 0 // Default, nanti diupdate jika perlu
    };
    
    batch.set(dailyOrderRef, dailyOrderData);
  }
  
  await batch.commit();
  console.log(`Berhasil generate pesanan untuk ${orderId}`);
};

/**
 * =================================================================
 * ENDPOINT 1: createTransaction (Midtrans)
 * =================================================================
 */
app.post("/createTransaction", async (req, res) => {
  try {
    const finalPrice = req.body.finalPrice;
    const slots = req.body.slots;
    const userId = req.body.userId;

    if (!userId) throw new Error("User ID tidak ditemukan.");

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
 * ENDPOINT 2: paymentHandler (Webhook Midtrans)
 * =================================================================
 */
app.post("/paymentHandler", async (req, res) => {
  try {
    const notificationJson = req.body;
    const statusResponse = await snap.transaction.notification(notificationJson);
    const orderId = statusResponse.order_id;
    const transactionStatus = statusResponse.transaction_status;
    const fraudStatus = statusResponse.fraud_status;

    const orderRef = db.collection("pending_payments").doc(orderId);
    const orderDoc = await orderRef.get();

    if (!orderDoc.exists) return res.status(404).send("Order tidak ditemukan.");
    
    const orderData = orderDoc.data();

    if (transactionStatus === "capture" || transactionStatus === "settlement") {
      if (fraudStatus === "accept") {
        await orderRef.update({ status: "paid", paymentDetails: statusResponse });
        await generateDailyOrders(orderId, orderData);
      }
    } else if (
      transactionStatus === "cancel" ||
      transactionStatus === "deny" ||
      transactionStatus === "expire"
    ) {
      await orderRef.update({ status: "failed", paymentDetails: statusResponse });
    }

    res.status(200).send("OK");
  } catch (e) {
    console.error("Error webhook:", e);
    res.status(500).send("Error internal.");
  }
});

/**
 * =================================================================
 * ENDPOINT 3: markReadyAndAutoAssign (UPDATE WEEK 8)  * Logika Baru: Batas 4 Pesanan & Radius 5KM
 * =================================================================
 */
app.post("/markReadyAndAutoAssign", async (req, res) => {
  const { orderIds } = req.body;
  
  // KONFIGURASI WEEK 8
  const MAX_ORDERS_PER_DRIVER = 4; // Batas beban kerja
  const MAX_RADIUS_KM = 5.0;       // Batas jarak

  try {
    if (!orderIds || orderIds.length === 0) {
        return res.status(400).json({ error: "Tidak ada Order ID." });
    }

    // 1. Ambil SEMUA Driver Verified
    const driversSnapshot = await db.collection('drivers').where('status', '==', 'verified').get();
    let drivers = [];
    
    // Siapkan data driver (lokasi & slot beban kerja)
    driversSnapshot.forEach(doc => {
        const d = doc.data();
        drivers.push({ 
            id: doc.id, 
            namaLengkap: d.namaLengkap || 'Driver',
            lat: d.latitude || 0, 
            lng: d.longitude || 0,
            currentLoad: 0 // Akan dihitung di bawah
        });
    });

    // 2. Hitung Beban Kerja Driver Saat Ini (Real-time)
    // Cek pesanan yg sedang 'assigned', 'ready_for_pickup', atau 'on_delivery'
    const activeOrdersSnap = await db.collection('daily_orders')
        .where('status', 'in', ['assigned', 'ready_for_pickup', 'on_delivery'])
        .get();
    
    activeOrdersSnap.forEach(doc => {
        const data = doc.data();
        if (data.driverId) {
            const driverIndex = drivers.findIndex(d => d.id === data.driverId);
            if (driverIndex !== -1) {
                drivers[driverIndex].currentLoad += 1;
            }
        }
    });

    let assignedCount = 0;

    // 3. Proses Penugasan per Order
    for (const orderId of orderIds) {
      const orderRef = db.collection('daily_orders').doc(orderId);
      const orderDoc = await orderRef.get();
      
      if (!orderDoc.exists) continue;
      const orderData = orderDoc.data();
      
      // Ambil lokasi Restoran
      const restoSnap = await db.collection('restaurants').doc(orderData.restaurantId).get();
      if (!restoSnap.exists) continue;
      
      const restoData = restoSnap.data();
      const restoLat = restoData.latitude || 0;
      const restoLng = restoData.longitude || 0;

      // 4. Cari Driver Terbaik (Filter: Beban < 4, Jarak < 5KM, Paling Dekat)
      let bestDriver = null;
      let minDistance = 9999; 

      for (const driver of drivers) {
        // FILTER A: Cek Beban (Jangan kasih ke yang sibuk)
        if (driver.currentLoad >= MAX_ORDERS_PER_DRIVER) continue;

        // FILTER B: Hitung Jarak
        const dist = calculateDistance(driver.lat, driver.lng, restoLat, restoLng);
        
        // FILTER C: Radius & Minimum
        if (dist <= MAX_RADIUS_KM && dist < minDistance) {
          minDistance = dist;
          bestDriver = driver;
        }
      }

      if (bestDriver) {
        // Update DB
        await orderRef.update({ 
            status: 'assigned', // Status awal penugasan
            driverId: bestDriver.id,
            driverName: bestDriver.namaLengkap
        });
        
        // Update beban di memori (biar order selanjutnya di loop ini tau dia nambah tugas)
        bestDriver.currentLoad += 1;
        assignedCount++;
      }
    }

    res.status(200).json({ 
        success: true, 
        message: `Berhasil menugaskan ${assignedCount} pesanan.`,
        assignedCount: assignedCount
    });

  } catch (error) {
    console.error("Error Auto Assign:", error);
    res.status(500).json({ error: error.message });
  }
});

// --- ROOT & SERVER ---
app.get("/", (req, res) => {
  res.status(200).send("Backend Katering App is running (Week 8 Version)! 🚀");
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  console.log(`Server katering berjalan di port ${PORT}`);
});

module.exports = app;