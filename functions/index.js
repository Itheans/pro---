// functions/index.js
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

// ตรวจสอบว่ากำลังรันบน emulator หรือไม่
const isEmulator = process.env.FUNCTIONS_EMULATOR === 'true';
console.log("functions has pubsub:", Boolean(functions.pubsub));

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
      cancelReason: "คำขอหมดเวลาอัตโนมัติหลังจาก 15 นาที",
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

console.log("Creating admin notification:", adminNotification);

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
  return { success: true, processedCount: expiredRequestsSnapshot.size };
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
async function sendPushNotifications(userId, sitterId, bookingId) {
  try {
    // ดึง FCM token ของผู้ใช้และผู้รับเลี้ยง
    const userDoc = await admin.firestore()
        .collection("users")
        .doc(userId)
        .get();
    const sitterDoc = await admin.firestore()
        .collection("users")
        .doc(sitterId)
        .get();
    
    const userData = userDoc.data();
    const sitterData = sitterDoc.data();
    
    // ถ้ามี FCM token ให้ส่งการแจ้งเตือน
    if (userData && userData.fcmToken) {
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
    }
    
    if (sitterData && sitterData.fcmToken) {
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
    }
  } catch (error) {
    console.error("Error sending push notifications:", error);
  }
}
// ใช้ Firestore trigger แทน HTTP trigger
exports.checkExpiredBookingsByFirestore = functions.firestore
  .document('triggers/checkExpiredBookings')
  .onUpdate(async (change, context) => {
    try {
      await checkExpiredBookingsLogic();
      return null;
    } catch (error) {
      console.error("Error checking expired bookings:", error);
      return null;
    }
  });