// File: functions/index.js

const admin = require("firebase-admin");
const midtransClient = require("midtrans-client");
const express = require("express");
const cors = require("cors");

// Inisialisasi Express
const app = express();
app.use(cors({origin: true}));
app.use(express.json());

// --- 1. INISIALISASI FIREBASE ADMIN ---
const serviceAccountString = process.env.FIREBASE_SERVICE_ACCOUNT;
if (!serviceAccountString) {
  console.error("ERROR: Variabel FIREBASE_SERVICE_ACCOUNT tidak ditemukan.");
}
const serviceAccount = JSON.parse(serviceAccountString);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();

// --- 2. INISIALISASI MIDTRANS ---
const snap = new midtransClient.Snap({
  isProduction: false,
  serverKey: process.env.MIDTRANS_SERVER_KEY,
  clientKey: process.env.MIDTRANS_CLIENT_KEY,
});

/**
 * ============================================================
 * HELPER 1: HITUNG JARAK (Haversine Formula)
 * ============================================================
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
 * ============================================================
 * HELPER 2: LOGIKA PENCARIAN DRIVER (AUTO ASSIGN)
 * Mencari driver verified, radius 5KM, max 5 order.
 * ============================================================
 */
async function findAndAssignDriver(orderIds) {
  const MAX_ORDERS_PER_DRIVER = 5; // <--- UPDATE: Kapasitas 5
  const MAX_RADIUS_KM = 5.0;       // Batas jarak

  console.log(`Mulai mencari driver untuk ${orderIds.length} pesanan...`);

  try {
    // A. Ambil Data Restoran (Koordinat)
    const firstOrderDoc = await db.collection('daily_orders').doc(orderIds[0]).get();
    if (!firstOrderDoc.exists) {
        console.error("Order tidak ditemukan saat mencari driver.");
        return { success: false, message: "Order not found" };
    }
    const orderData = firstOrderDoc.data();
    const restoId = orderData.restaurantId;
    
    // Ambil Koordinat Resto
    const restoSnap = await db.collection('restaurants').doc(restoId).get();
    if (!restoSnap.exists) {
        return { success: false, message: "Resto not found" };
    }
    const restoLat = restoSnap.data().latitude || 0;
    const restoLng = restoSnap.data().longitude || 0;

    // B. Ambil SEMUA Driver Verified
    const driversSnapshot = await db.collection('drivers').where('status', '==', 'verified').get();
    let drivers = [];
    
    driversSnapshot.forEach(doc => {
        const d = doc.data();
        drivers.push({ 
            id: doc.id, 
            namaLengkap: d.namaLengkap || 'Driver',
            lat: d.latitude || 0, 
            lng: d.longitude || 0,
            currentLoad: 0 
        });
    });

    // C. Hitung Beban Kerja Driver Saat Ini (Real-time)
    const activeOrdersSnap = await db.collection('daily_orders')
        .where('status', 'in', ['assigned', 'ready_for_pickup', 'on_delivery'])
        .get();
    
    activeOrdersSnap.forEach(doc => {
        const data = doc.data();
        if (data.driverId) {
            const idx = drivers.findIndex(d => d.id === data.driverId);
            if (idx !== -1) {
                drivers[idx].currentLoad += 1;
            }
        }
    });

    let assignedCount = 0;
    const batch = db.batch();

    // D. Loop setiap Order dan Cari Driver Terbaik
    for (const orderId of orderIds) {
      let bestDriver = null;
      let minDistance = 9999; 

      for (const driver of drivers) {
        // FILTER 1: Cek Beban (Max 5)
        if (driver.currentLoad >= MAX_ORDERS_PER_DRIVER) continue;

        // FILTER 2: Hitung Jarak
        const dist = calculateDistance(driver.lat, driver.lng, restoLat, restoLng);
        
        // FILTER 3: Radius Max 5KM & Cari yang Terdekat
        if (dist <= MAX_RADIUS_KM && dist < minDistance) {
          minDistance = dist;
          bestDriver = driver;
        }
      }

      if (bestDriver) {
        // KETEMU! Update Data Order
        const ref = db.collection('daily_orders').doc(orderId);
        batch.update(ref, { 
            status: 'assigned', // Status langsung assigned (sudah dapat driver)
            driverId: bestDriver.id,
            driverName: bestDriver.namaLengkap
        });
        
        // Update beban di memori
        bestDriver.currentLoad += 1;
        assignedCount++;
      }
    }

    // E. Commit perubahan ke Database
    if (assignedCount > 0) {
        await batch.commit();
        console.log(`SUKSES: ${assignedCount} pesanan berhasil dapat driver.`);
    } else {
        console.log("GAGAL: Tidak ada driver yang cocok/available saat ini.");
    }
    
    return { success: true, assignedCount };

  } catch (e) {
      console.error("AUTO-ASSIGN ERROR:", e);
      return { success: false, error: e.message };
  }
}

/**
 * ============================================================
 * HELPER 3: GENERATE DAILY ORDERS (FIX ONGKIR)
 * Membuat dokumen harian setelah pembayaran lunas
 * ============================================================
 */
const generateDailyOrders = async (orderId, orderData) => {
  const batch = db.batch();
  const slots = orderData.items; 
  const userId = orderData.userId;
  
  // Array untuk menyimpan ID pesanan yang baru dibuat
  let createdIds = []; 

  // --- LOGIKA ONGKIR BARU ---
  const totalShippingCost = orderData.shippingCost || 0; // Ambil total ongkir dari pending_payments
  const totalItems = slots.length;
  // Hitung ongkir per pesanan (pembulatan ke bawah)
  const shippingPerItem = totalItems > 0 ? Math.floor(totalShippingCost / totalItems) : 0;
  // --------------------------

  // 1. Simpan dokumen langganan
  const subscriptionRef = db.collection("subscriptions").doc(orderId);
  batch.set(subscriptionRef, {
    ...orderData,
    status: "active",
  });

  // 2. Logika Tanggal (H+1 atau H+2 jika malam)
  const startDate = new Date();
  startDate.setDate(startDate.getDate() + 1);
  if (new Date().getHours() > 20) {
    startDate.setDate(startDate.getDate() + 1); 
  }

  // 3. Loop Item & Buat Dokumen
  for (let i = 0; i < slots.length; i++) {
    const slot = slots[i];
    const menu = slot.selectedMenu; 

    if (!menu || !menu.menuId) continue; 

    const deliveryDate = new Date(startDate);
    deliveryDate.setDate(deliveryDate.getDate() + i);

    const dailyOrderId = `${orderId}_day${i + 1}`;
    createdIds.push(dailyOrderId);

    const dailyOrderRef = db.collection("daily_orders").doc(dailyOrderId);

    const dailyOrderData = {
      subscriptionId: orderId,
      userId: userId,
      day: slot.day, 
      mealTime: slot.mealTime, 
      
      // Info Menu
      menuId: menu.menuId,
      namaMenu: menu.namaMenu,
      harga: menu.harga,
      fotoUrl: menu.fotoUrl,
      restaurantId: menu.restaurantId,
      
      // Status & Tanggal
      deliveryDate: admin.firestore.Timestamp.fromDate(deliveryDate),
      status: "confirmed", 
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      
      // --- UPDATE PENTING: SIMPAN ONGKIR PER ITEM ---
      shippingCost: shippingPerItem 
    };
    
    batch.set(dailyOrderRef, dailyOrderData);
  }
  
  await batch.commit();
  console.log(`Berhasil generate ${createdIds.length} pesanan dengan Ongkir @${shippingPerItem}`);
  
  return createdIds; 
};

/**
 * ============================================================
 * ENDPOINT 1: createTransaction (Dipanggil Flutter)
 * ============================================================
 */
app.post("/createTransaction", async (req, res) => {
  try {
    // --- UPDATE: Terima shippingCost dari body ---
    const { finalPrice, slots, userId, shippingCost } = req.body; 
    
    // Validasi
    if (!userId) throw new Error("User ID tidak ditemukan.");

    const orderId = `${userId}-${Date.now()}`;

    // Simpan data sementara (Pending)
    await db.collection("pending_payments").doc(orderId).set({
      userId: userId,
      status: "pending",
      totalPrice: finalPrice,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      items: slots, 
      shippingCost: shippingCost || 0, // <--- UPDATE: Simpan Ongkir
    });

    // Request ke Midtrans
    const transaction = await snap.createTransaction({
      transaction_details: {
        order_id: orderId,
        gross_amount: finalPrice,
      },
      callbacks: {
        finish: "https://katering-app.com/payment-success",
      },
    });

    // Update URL pembayaran
    await db.collection("pending_payments").doc(orderId).update({
      paymentUrl: transaction.redirect_url,
    });

    res.status(200).send({paymentUrl: transaction.redirect_url});
  } catch (e) {
    console.error(e);
    res.status(500).send({error: e.message});
  }
});

/**
 * ============================================================
 * ENDPOINT 2: paymentHandler (WEBHOOK MIDTRANS)
 * ============================================================
 */
app.post("/paymentHandler", async (req, res) => {
  try {
    const notif = req.body;
    const statusResponse = await snap.transaction.notification(notif);
    const orderId = statusResponse.order_id;
    const transactionStatus = statusResponse.transaction_status;
    const fraudStatus = statusResponse.fraud_status;

    const orderRef = db.collection("pending_payments").doc(orderId);
    const orderDoc = await orderRef.get();

    if (!orderDoc.exists) return res.status(404).send("Order not found");

    // Jika Pembayaran Sukses (Settlement / Capture)
    if (transactionStatus === "capture" || transactionStatus === "settlement") {
      if (fraudStatus === "accept") {
        
        // 1. Update Status Pembayaran jadi Paid
        await orderRef.update({ status: "paid", paymentDetails: statusResponse });
        
        // 2. GENERATE DAILY ORDERS (Membuat rincian H+1 dst)
        const orderData = orderDoc.data();
        const newOrderIds = await generateDailyOrders(orderId, orderData);
        
        // 3. AUTO ASSIGN DRIVER!
        if (newOrderIds.length > 0) {
            await findAndAssignDriver(newOrderIds);
        }
      }
    } else if (
      transactionStatus === "cancel" ||
      transactionStatus === "deny" ||
      transactionStatus === "expire"
    ) {
      await orderRef.update({ status: "failed" });
    }

    res.status(200).send("OK");
  } catch (e) {
    console.error("Error Webhook:", e);
    res.status(500).send("Error Internal Server");
  }
});

/**
 * ============================================================
 * ENDPOINT 3: Manual Retry (markReadyAndAutoAssign)
 * ============================================================
 */
app.post("/markReadyAndAutoAssign", async (req, res) => {
  const { orderIds } = req.body;
  
  const result = await findAndAssignDriver(orderIds);
  
  if (result.success) {
      res.status(200).json(result);
  } else {
      res.status(500).json(result);
  }
});

// --- ROOT & PORT ---
app.get("/", (req, res) => {
  res.status(200).send("Backend Katering App is running (Full Version)!");
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  console.log(`Server katering berjalan di port ${PORT}`);
});

module.exports = app;