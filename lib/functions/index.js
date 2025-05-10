// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// ฟังก์ชันที่ทำงานทุก 5 นาที
exports.checkExpiredBookings = functions.pubsub.schedule('every 5 minutes').onRun(async (context) => {
  try {
    console.log('Checking for expired booking requests...');
    
    const now = admin.firestore.Timestamp.now();
    
    // ค้นหาคำขอที่หมดเวลาและยังอยู่ในสถานะ pending
    const expiredRequestsSnapshot = await admin.firestore()
      .collection('booking_requests')
      .where('status', '==', 'pending')
      .where('expirationTime', '<', now)
      .get();
    
    console.log(`Found ${expiredRequestsSnapshot.size} expired requests`);
    
    const batch = admin.firestore().batch();
    const promises = [];
    
    expiredRequestsSnapshot.forEach(doc => {
      const bookingId = doc.id;
      const data = doc.data();
      const userId = data.userId;
      const sitterId = data.sitterId;
      
      console.log(`Processing expired booking: ${bookingId}`);
      
      // อัพเดตสถานะคำขอเป็น expired
      batch.update(doc.ref, {
        status: 'expired',
        cancelReason: 'คำขอหมดเวลาอัตโนมัติหลังจาก 15 นาที',
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // สร้างการแจ้งเตือนให้ผู้ใช้
      const userNotification = {
        title: 'คำขอการจองหมดเวลา',
        message: 'คำขอการจองของคุณได้หมดเวลาแล้ว กรุณาทำรายการใหม่อีกครั้ง',
        type: 'booking_expired',
        bookingId: bookingId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false
      };
      
      // สร้างการแจ้งเตือนให้ผู้รับเลี้ยง
      const sitterNotification = {
        title: 'คำขอการจองหมดเวลา',
        message: 'คำขอการจองได้หมดเวลาแล้ว',
        type: 'booking_expired',
        bookingId: bookingId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false
      };
      
      // สร้างการแจ้งเตือนให้แอดมิน
      const adminNotification = {
        title: 'คำขอการจองหมดเวลา',
        message: `คำขอการจอง ${bookingId} ได้หมดเวลาแล้วและถูกยกเลิกโดยอัตโนมัติ`,
        type: 'booking_expired',
        bookingId: bookingId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false
      };
      
      // เพิ่มการแจ้งเตือนใน batch
      const userNotifRef = admin.firestore().collection('users').doc(userId).collection('notifications').doc();
      batch.set(userNotifRef, userNotification);
      
      const sitterNotifRef = admin.firestore().collection('users').doc(sitterId).collection('notifications').doc();
      batch.set(sitterNotifRef, sitterNotification);
      
      const adminNotifRef = admin.firestore().collection('admin_notifications').doc();
      batch.set(adminNotifRef, adminNotification);
      
      // ส่ง push notification (ถ้ามี FCM token)
      promises.push(sendPushNotifications(userId, sitterId, bookingId));
    });
    
    // ดำเนินการทั้งหมดพร้อมกัน
    await batch.commit();
    await Promise.all(promises);
    
    console.log('Successfully updated expired bookings');
    return null;
  } catch (error) {
    console.error('Error checking expired bookings:', error);
    return null;
  }
});

// ฟังก์ชันส่ง push notification
async function sendPushNotifications(userId, sitterId, bookingId) {
  try {
    // ดึง FCM token ของผู้ใช้และผู้รับเลี้ยง
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    const sitterDoc = await admin.firestore().collection('users').doc(sitterId).get();
    
    const userData = userDoc.data();
    const sitterData = sitterDoc.data();
    
    // ถ้ามี FCM token ให้ส่งการแจ้งเตือน
    if (userData && userData.fcmToken) {
      await admin.messaging().send({
        token: userData.fcmToken,
        notification: {
          title: 'คำขอการจองหมดเวลา',
          body: 'คำขอการจองของคุณได้หมดเวลาแล้ว กรุณาทำรายการใหม่อีกครั้ง'
        },
        data: {
          type: 'booking_expired',
          bookingId: bookingId
        }
      });
    }
    
    if (sitterData && sitterData.fcmToken) {
      await admin.messaging().send({
        token: sitterData.fcmToken,
        notification: {
          title: 'คำขอการจองหมดเวลา',
          body: 'คำขอการจองได้หมดเวลาแล้ว'
        },
        data: {
          type: 'booking_expired',
          bookingId: bookingId
        }
      });
    }
  } catch (error) {
    console.error('Error sending push notifications:', error);
  }
}