// functions/index.js
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

console.log("Environment:", process.env.NODE_ENV || "production");
console.log("Firebase Functions initialized");

// ฟังก์ชันหลักสำหรับการตรวจสอบการจองที่หมดอายุ
const checkExpiredBookingsLogic = async () => {
  console.log("Checking for expired booking requests...");
  
  const now = admin.firestore.Timestamp.now();
  console.log("Current time:", now.toDate());
  
  // ค้นหาคำขอที่หมดเวลา
  const expiredRequestsSnapshot = await admin.firestore()
    .collection("bookings")
    .where("status", "==", "pending")
    .where("expirationTime", "<", now)
    .get();
  
  console.log(`Found ${expiredRequestsSnapshot.size} expired requests`);
  
  const batch = admin.firestore().batch();
  
  expiredRequestsSnapshot.forEach((doc) => {
    const bookingId = doc.id;
    const data = doc.data();
    const userId = data.userId;
    const sitterId = data.sitterId;
    
    console.log(`Processing expired booking: ${bookingId}`);
    
    // อัพเดตสถานะคำขอเป็น expired
    batch.update(doc.ref, {
      status: "expired",
      cancelReason: "คำขอหมดเวลาอัตโนมัติหลังจาก 15 นาที",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // สร้างการแจ้งเตือนให้ผู้ใช้
    if (userId) {
      const userNotification = {
        title: "คำขอการจองหมดเวลา",
        message: "คำขอการจองของคุณได้หมดเวลาแล้ว กรุณาทำรายการใหม่อีกครั้ง",
        type: "booking_expired",
        bookingId: bookingId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
      };
      
      const userNotifRef = admin.firestore()
          .collection("users")
          .doc(userId)
          .collection("notifications")
          .doc();
      batch.set(userNotifRef, userNotification);
    }
    
    // สร้างการแจ้งเตือนให้ผู้รับเลี้ยง
    if (sitterId) {
      const sitterNotification = {
        title: "คำขอการจองหมดเวลา",
        message: "คำขอการจองได้หมดเวลาแล้ว",
        type: "booking_expired",
        bookingId: bookingId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
      };
      
      const sitterNotifRef = admin.firestore()
          .collection("users")
          .doc(sitterId)
          .collection("notifications")
          .doc();
      batch.set(sitterNotifRef, sitterNotification);
    }
    
    // สร้างการแจ้งเตือนให้แอดมิน
    const adminNotification = {
      title: "คำขอการจองหมดเวลา",
      message: `คำขอการจอง ${bookingId} ได้หมดเวลาแล้วและถูกยกเลิกโดยอัตโนมัติ`,
      type: "booking_expired",
      bookingId: bookingId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    };

    console.log("Creating admin notification:", adminNotification);

    const adminNotifRef = admin.firestore()
        .collection("admin_notifications")
        .doc();
    batch.set(adminNotifRef, adminNotification);
  });
  
  // ดำเนินการทั้งหมดพร้อมกัน
  if (expiredRequestsSnapshot.size > 0) {
    await batch.commit();
    console.log("Successfully updated expired bookings");
  } else {
    console.log("No expired bookings to update");
  }
  
  return { 
    success: true, 
    processedCount: expiredRequestsSnapshot.size,
    message: `Successfully processed ${expiredRequestsSnapshot.size} expired booking requests.`
  };
};

// เหลือเฉพาะ HTTP function อย่างเดียว
exports.checkExpiredBookingsHttp = functions.https.onRequest(async (req, res) => {
  try {
    console.log("HTTP request for expired bookings check...");
    const result = await checkExpiredBookingsLogic();
    res.status(200).json(result);
  } catch (error) {
    console.error("Error checking expired bookings:", error);
    res.status(500).json({ error: error.message });
  }
});

// อีกหนึ่ง HTTP function สำหรับเรียกใช้จากแอพโดยตรง
exports.checkExpiredBookings = functions.https.onRequest(async (req, res) => {
  try {
    console.log("HTTP request for expired bookings check...");
    const result = await checkExpiredBookingsLogic();
    res.status(200).json(result);
  } catch (error) {
    console.error("Error checking expired bookings:", error);
    res.status(500).json({ error: error.message });
  }
});