import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // ส่งการแจ้งเตือนเมื่อสถานะการจองเปลี่ยนแปลง
  Future<void> sendBookingStatusNotification({
    required String userId,
    required String bookingId,
    required String status,
    required String message,
  }) async {
    try {
      // สร้างข้อมูลการแจ้งเตือน
      Map<String, dynamic> notificationData = {
        'userId': userId,
        'bookingId': bookingId,
        'status': status,
        'message': message,
        'isRead': false,
        'type': bookingId.isNotEmpty ? 'booking' : 'system',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // บันทึกลงใน Firestore
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add(notificationData);

      // ดึง FCM token สำหรับการส่งแจ้งเตือนแบบ push notification
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final fcmToken = userData['fcmToken'];

        if (fcmToken != null && fcmToken.toString().isNotEmpty) {
          await _sendPushNotification(
            token: fcmToken,
            title: _getNotificationTitle(status),
            body: message,
            data: {
              'type': bookingId.isNotEmpty ? 'booking' : 'system',
              'bookingId': bookingId,
              'status': status,
            },
          );
        }
      }

      print(
          'Notification sent successfully to user $userId about booking $bookingId');
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // ส่ง Push Notification
  Future<void> _sendPushNotification({
    required String token,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      // Convert dynamic map to String map
      Map<String, String> stringData = data.map(
        (key, value) => MapEntry(key, value.toString()),
      );

      await _firebaseMessaging.sendMessage(
        to: token,
        data: stringData, // Use the converted map
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        messageType: 'notification',
        collapseKey: 'meow_sitter_app',
        ttl: 24 * 60 * 60, // 1 day
      );
    } catch (e) {
      print('Error sending push notification: $e');
    }
  }

  // แปลงสถานะเป็นหัวข้อการแจ้งเตือน
  String _getNotificationTitle(String status) {
    switch (status) {
      case 'pending':
        return 'การจองใหม่';
      case 'confirmed':
        return 'การจองได้รับการยืนยัน';
      case 'in_progress':
        return 'การดูแลแมวเริ่มแล้ว';
      case 'completed':
        return 'การบริการเสร็จสิ้น';
      case 'cancelled':
        return 'การจองถูกยกเลิก';
      case 'auto_cancelled':
        return 'การจองถูกยกเลิกอัตโนมัติ';
      case 'deleted':
        return 'การจองถูกลบโดยแอดมิน';
      case 'approval':
        return 'คำขอเป็นพี่เลี้ยงได้รับการอนุมัติ';
      case 'rejection':
        return 'คำขอเป็นพี่เลี้ยงถูกปฏิเสธ';
      default:
        return 'การแจ้งเตือนใหม่';
    }
  }

  // ดึงรายการแจ้งเตือนทั้งหมดของผู้ใช้
  Stream<QuerySnapshot> getUserNotifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // อัพเดตสถานะว่าอ่านแล้ว
  Future<void> markNotificationAsRead(
      String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // ลบการแจ้งเตือน
  Future<void> deleteNotification(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }
}
