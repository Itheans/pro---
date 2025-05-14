import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myproject/Admin/NotificationService.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // ฟังก์ชันตรวจสอบคำขอที่หมดเวลา (เรียกใช้จาก background task หรือ Cloud Function)
  Future<void> checkExpiredBookings() async {
    try {
      // ดึงคำขอที่มีสถานะ 'pending' และยังไม่ถูกยกเลิก
      final pendingBookings = await _firestore
          .collection('bookings')
          .where('status', isEqualTo: 'pending')
          .get();

      final now = DateTime.now();

      for (var booking in pendingBookings.docs) {
        final data = booking.data();
        final expirationTime = data['expirationTime'] as Timestamp;
        final userId = data['userId'] as String;
        final sitterId = data['sitterId'] as String;

        // ตรวจสอบว่าหมดเวลาหรือยัง
        if (now.isAfter(expirationTime.toDate())) {
          // อัพเดทสถานะเป็น 'auto_cancelled'
          await booking.reference.update({
            'status': 'auto_cancelled',
            'cancelledAt': FieldValue.serverTimestamp(),
            'cancelReason': 'คำขอหมดเวลา (15 นาที)'
          });

          // แจ้งเตือนเจ้าของแมว
          await _notificationService.sendBookingStatusNotification(
            userId: userId,
            bookingId: booking.id,
            status: 'auto_cancelled',
            message: 'คำขอรับเลี้ยงของคุณหมดเวลาแล้ว',
          );

          // แจ้งเตือน sitter
          await _notificationService.sendBookingStatusNotification(
            userId: sitterId,
            bookingId: booking.id,
            status: 'auto_cancelled',
            message: 'คำขอรับเลี้ยงหมดเวลาแล้ว',
          );
        }
      }
    } catch (e) {
      print('Error checking expired bookings: $e');
    }
  }

  // ฟังก์ชันสำหรับ admin หรือ sitter ในการยกเลิกคำขอ
  Future<void> cancelBooking({
    required String bookingId,
    required String cancelledBy,
    required String reason,
  }) async {
    try {
      DocumentSnapshot bookingSnapshot =
          await _firestore.collection('bookings').doc(bookingId).get();

      if (!bookingSnapshot.exists) {
        throw Exception('ไม่พบข้อมูลการจอง');
      }

      Map<String, dynamic> bookingData =
          bookingSnapshot.data() as Map<String, dynamic>;

      // อัพเดทสถานะเป็น 'cancelled'
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': cancelledBy,
        'cancelReason': reason
      });

      // แจ้งเตือนเจ้าของแมว
      await _notificationService.sendBookingStatusNotification(
        userId: bookingData['userId'],
        bookingId: bookingId,
        status: 'cancelled',
        message: 'การจองของคุณถูกยกเลิก: $reason',
      );

      // แจ้งเตือน sitter ถ้าผู้ยกเลิกไม่ใช่ sitter เอง
      if (cancelledBy != bookingData['sitterId']) {
        await _notificationService.sendBookingStatusNotification(
          userId: bookingData['sitterId'],
          bookingId: bookingId,
          status: 'cancelled',
          message: 'การจองถูกยกเลิก: $reason',
        );
      }
    } catch (e) {
      print('Error cancelling booking: $e');
      throw Exception('ไม่สามารถยกเลิกการจองได้: $e');
    }
  }

  // ฟังก์ชันสำหรับรับฟังการเปลี่ยนแปลงของการจองที่ใกล้หมดเวลา
  Stream<QuerySnapshot> getNearExpiringBookings() {
    final now = DateTime.now();
    final inFiveMinutes = now.add(Duration(minutes: 5));

    return _firestore
        .collection('bookings')
        .where('status', isEqualTo: 'pending')
        .where('expirationTime', isGreaterThan: Timestamp.fromDate(now))
        .where('expirationTime', isLessThan: Timestamp.fromDate(inFiveMinutes))
        .snapshots();
  }
}
