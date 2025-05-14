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
  const promises = [];
  
  expiredRequestsSnapshot.forEach((doc) => {
    const bookingId = doc.id;
    const data = doc.data();
    const userId = data.userId;
    const sitterId = data.sitterId;
    
    console.log(`Processing expired booking: ${bookingId}`);
    
    // อัพเดตสถานะคำขอเป็น expired
    batch.update(doc.ref, {
      status: "expired",
      cancelReason: "คำขอหมดเวลาอัตโนมัติหลังจาก 1 นาที",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // สร้างการแจ้งเตือนให้ผู้ใช้
    const userNotification = {
      title: "คำขอการจองหมดเวลา",
      message: "คำขอการจองของคุณได้หมดเวลาแล้ว กรุณาทำรายการใหม่อีกครั้ง",
      type: "booking_expired",
      bookingId: bookingId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    };
    
    // เพิ่มการแจ้งเตือนใน batch
    const userNotifRef = admin.firestore()
        .collection("users")
        .doc(userId)
        .collection("notifications")
        .doc();
    batch.set(userNotifRef, userNotification);
    
    if (sitterId) {
      // สร้างการแจ้งเตือนให้ผู้รับเลี้ยง
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
    
    const adminNotifRef = admin.firestore()
        .collection("admin_notifications")
        .doc();
    batch.set(adminNotifRef, adminNotification);
    
    // ส่ง push notification (ถ้ามี FCM token)
    if (userId && sitterId) {
      promises.push(sendPushNotifications(userId, sitterId, bookingId));
    }
  });
  
  // ดำเนินการทั้งหมดพร้อมกัน
  await batch.commit();
  if (promises.length > 0) {
    await Promise.all(promises);
  }
  
  console.log("Successfully updated expired bookings");
  return { 
    success: true, 
    processedCount: expiredRequestsSnapshot.size 
  };
};

// สร้างฟังก์ชัน HTTP สำหรับการทดสอบบน emulator
exports.checkExpiredBookings = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    try {
      console.log("Starting expired bookings check...");
      const result = await checkExpiredBookingsLogic();
      console.log("Completed expired bookings check. Processed:", result.processedCount);
      return null;
    } catch (error) {
      console.error("Error checking expired bookings:", error);
      return null;
    }
  });
/**
 * ฟังก์ชันส่ง push notification
 * @param {string} userId - ไอดีของผู้ใช้
 * @param {string} sitterId - ไอดีของผู้รับเลี้ยง
 * @param {string} bookingId - ไอดีของการจอง
 * @return {Promise} Promise ของการส่งการแจ้งเตือน
 */
// แก้ไขฟังก์ชัน sendPushNotifications โดยลบโค้ดที่ผิดพลาด
async function sendPushNotifications(userId, sitterId, bookingId) {
  try {
    // ตรวจสอบว่ามีค่า userId และ sitterId หรือไม่
    if (!userId || !sitterId) {
      console.log("Missing userId or sitterId, skipping push notifications");
      return;
    }
    
    // ดึงข้อมูลผู้ใช้
    const userDoc = await admin.firestore()
        .collection("users")
        .doc(userId)
        .get();
    
    // ดึงข้อมูลผู้รับเลี้ยง
    const sitterDoc = await admin.firestore()
        .collection("users")
        .doc(sitterId)
        .get();
    
    // ตรวจสอบว่าเอกสารมีอยู่จริง
    if (!userDoc.exists || !sitterDoc.exists) {
      console.log("User or sitter document not found");
      return;
    }
    
    const userData = userDoc.data();
    const sitterData = sitterDoc.data();
    
    // ส่งการแจ้งเตือนเฉพาะเมื่อมี FCM token
    if (userData && userData.fcmToken) {
      try {
        await admin.messaging().send({
          token: userData.fcmToken,
          notification: {
            title: "คำขอการจองหมดเวลา",
            body: "คำขอการจองของคุณได้หมดเวลาแล้ว กรุณาทำรายการใหม่อีกครั้ง",
          },
          data: {
            type: "booking_expired",
            bookingId: bookingId,
          },
        });
        console.log("Sent notification to user", userId);
      } catch (err) {
        console.error("Failed to send notification to user:", err);
      }
    }
    
    if (sitterData && sitterData.fcmToken) {
      try {
        await admin.messaging().send({
          token: sitterData.fcmToken,
          notification: {
            title: "คำขอการจองหมดเวลา",
            body: "คำขอการจองได้หมดเวลาแล้ว",
          },
          data: {
            type: "booking_expired",
            bookingId: bookingId,
          },
        });
        console.log("Sent notification to sitter", sitterId);
        // ลบโค้ดที่มีปัญหา ไม่ต้องมีการส่งค่ากลับในฟังก์ชันนี้
      } catch (err) {
        console.error("Failed to send notification to sitter:", err);
      }
    }
  } catch (error) {
    console.error("Error in sendPushNotifications:", error);
  }
}ห
// แก้ไขฟังก์ชัน Firestore Trigger
exports.checkExpiredBookingsByFirestore = functions.firestore
  .document('triggers/checkExpiredBookings')
  .onWrite(async (change, context) => {
    try {
      console.log("Firestore trigger activated for expired bookings check");
      const result = await checkExpiredBookingsLogic();
      console.log("Expired bookings check completed:", result);
      
      // อัพเดตเอกสาร trigger เพื่อบันทึกผลลัพธ์
      await admin.firestore()
        .collection('triggers')
        .doc('checkExpiredBookings')
        .update({
          lastRun: admin.firestore.FieldValue.serverTimestamp(),
          lastResult: result,
          processedCount: result.processedCount
        });
      
      return null;
    } catch (error) {
      console.error("Error checking expired bookings:", error);
      
      // บันทึกข้อผิดพลาด
      await admin.firestore()
        .collection('triggers')
        .doc('checkExpiredBookings')
        .update({
          lastRun: admin.firestore.FieldValue.serverTimestamp(),
          lastError: error.message
        });
      
      return null;
    }
  });

  // เพิ่มฟังก์ชันใหม่
exports.initializeBookingTriggers = functions.https.onRequest(async (req, res) => {
  try {
    // ตรวจสอบว่าเอกสารมีอยู่แล้วหรือไม่
    const triggerDoc = await admin.firestore()
      .collection('triggers')
      .doc('checkExpiredBookings')
      .get();
      
    if (!triggerDoc.exists) {
      // ถ้ายังไม่มีเอกสาร ให้สร้างใหม่
      await admin.firestore()
        .collection('triggers')
        .doc('checkExpiredBookings')
        .set({
          lastTriggered: admin.firestore.FieldValue.serverTimestamp(),
          initialized: true
        });
      console.log("Created initial trigger document");
    }
    
    res.status(200).send("Booking triggers initialized successfully");
  } catch (error) {
    console.error("Error initializing booking triggers:", error);
    res.status(500).send("Error initializing booking triggers: " + error.message);
  }
});