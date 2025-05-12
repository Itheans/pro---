const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

// ตรวจสอบว่ากำลังรันบน emulator หรือไม่
const isEmulator = process.env.FUNCTIONS_EMULATOR === 'true';
console.log("functions has pubsub:", Boolean(functions.pubsub));
const { onSchedule } = require("firebase-functions/v2/scheduler");

// แก้ไขส่วนของ scheduled function (ตรวจสอบให้แน่ใจว่ามีการเปิดใช้งาน billing สำหรับโปรเจค)
if (functions.pubsub) {
  exports.checkExpiredBookings = functions.pubsub
    .schedule('every 5 minutes')
    .onRun(async (context) => {
      try {
        await checkExpiredBookingsLogic();
        return null;
      } catch (error) {
        console.error("Error checking expired bookings:", error);
        return null;
      }
    });}

// ฟังก์ชันหลักสำหรับการตรวจสอบการจองที่หมดอายุ
const checkExpiredBookingsLogic = async () => {
  console.log("Checking for expired booking requests...");
  
  const now = admin.firestore.Timestamp.now();
  
  // ค้นหาคำขอที่หมดเวลาและยังอยู่ในสถานะ pending
  const expiredRequestsSnapshot = await admin.firestore()
      .collection("booking_requests")
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
      message: 
          `คำขอการจอง ${bookingId} ได้หมดเวลาแล้วและถูกยกเลิกโดยอัตโนมัติ`,
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
  return { success: true, processedCount: expiredRequestsSnapshot.size };
};

// สร้างฟังก์ชัน HTTP สำหรับการทดสอบบน emulator
exports.checkExpiredBookingsHttp = functions.https.onRequest(async (req, res) => {
  try {
    const result = await checkExpiredBookingsLogic();
    res.status(200).send(`Successfully updated expired bookings. Processed: ${result.processedCount} items`);
  } catch (error) {
    console.error("Error checking expired bookings:", error);
    res.status(500).send("Error checking expired bookings: " + error.message);
  }
});

// สร้างฟังก์ชัน scheduled สำหรับการใช้งานจริง
exports.checkExpiredBookings = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    try {
      await checkExpiredBookingsLogic();
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
// ใช้ Cloud Function scheduled trigger ในรูปแบบ อื่น (อาจทำงานได้กับเวอร์ชันเก่า)
exports.checkExpiredBookingsCron = functions.pubsub
  .topic('firebase-schedule-checkExpiredBookings')
  .onPublish(async (message) => {
    try {
      await checkExpiredBookingsLogic();
      return null;
    } catch (error) {
      console.error("Error checking expired bookings:", error);
      return null;
    }
  });
  // ใช้ Firestore trigger แทน
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
  // ใช้ V2 API สำหรับ scheduled function
exports.checkExpiredBookingsScheduled = onSchedule({
  schedule: "every 5 minutes"
}, async (context) => {
  try {
    await checkExpiredBookingsLogic();
    return null;
  } catch (error) {
    console.error("Error checking expired bookings:", error);
    return null;
  }
});