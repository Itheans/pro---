import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:myproject/Admin/NotificationService.dart';

class BookingCleanupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // ตรวจสอบและลบคิวการจองที่ไม่ได้รับการยืนยันเกินเวลาที่กำหนด
  Future<void> cleanupPendingBookings({int timeoutMinutes = 30}) async {
    try {
      // คำนวณเวลาที่เกินกำหนด
      DateTime timeoutThreshold =
          DateTime.now().subtract(Duration(minutes: timeoutMinutes));
      Timestamp timestampThreshold = Timestamp.fromDate(timeoutThreshold);

      // ค้นหาการจองที่มีสถานะ pending และสร้างมานานเกินกว่าเวลาที่กำหนด
      QuerySnapshot pendingBookings = await _firestore
          .collection('bookings')
          .where('status', isEqualTo: 'pending')
          .where('createdAt', isLessThan: timestampThreshold)
          .get();

      print('Found ${pendingBookings.docs.length} expired pending bookings');

      // ลบการจองที่เกินเวลาและส่งการแจ้งเตือน
      for (var doc in pendingBookings.docs) {
        Map<String, dynamic> bookingData = doc.data() as Map<String, dynamic>;
        String bookingId = doc.id;

        // อัพเดทสถานะเป็นยกเลิก
        await _firestore.collection('bookings').doc(bookingId).update({
          'status': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
          'cancellationReason':
              'ระบบยกเลิกอัตโนมัติเนื่องจากไม่ได้รับการยืนยันภายใน $timeoutMinutes นาที',
        });

        // ส่งการแจ้งเตือนไปยังผู้ใช้
        if (bookingData.containsKey('userId')) {
          await _notificationService.sendBookingStatusNotification(
            userId: bookingData['userId'],
            bookingId: bookingId,
            status: 'auto_cancelled',
            message:
                'การจองของคุณถูกยกเลิกอัตโนมัติเนื่องจากไม่ได้รับการยืนยันภายใน $timeoutMinutes นาที',
          );
        }

        // ส่งการแจ้งเตือนไปยังพี่เลี้ยง
        if (bookingData.containsKey('sitterId')) {
          await _notificationService.sendBookingStatusNotification(
            userId: bookingData['sitterId'],
            bookingId: bookingId,
            status: 'auto_cancelled',
            message:
                'การจองถูกยกเลิกอัตโนมัติเนื่องจากไม่ได้รับการยืนยันภายใน $timeoutMinutes นาที',
          );
        }

        print('Auto-cancelled booking: $bookingId');
      }
    } catch (e) {
      print('Error cleaning up bookings: $e');
    }
  }

// เพิ่มฟังก์ชันใหม่หลังจากฟังก์ชัน cleanupOldBookings
  Future<void> cleanupExpiredBookings() async {
    try {
      // คำนวณเวลาปัจจุบัน
      DateTime now = DateTime.now();
      Timestamp nowTimestamp = Timestamp.fromDate(now);

      // ค้นหาการจองที่มีเวลาหมดอายุน้อยกว่าเวลาปัจจุบัน และยังมีสถานะ pending
      QuerySnapshot expiredBookingsSnapshot = await _firestore
          .collection('bookings')
          .where('status', isEqualTo: 'pending')
          .where('expirationTime', isLessThan: nowTimestamp)
          .get();

      print('Found ${expiredBookingsSnapshot.docs.length} expired bookings');

      // อัพเดทสถานะการจองที่หมดอายุเป็น cancelled
      for (var doc in expiredBookingsSnapshot.docs) {
        Map<String, dynamic> bookingData = doc.data() as Map<String, dynamic>;
        String bookingId = doc.id;

        // อัพเดทสถานะเป็นยกเลิก
        await _firestore.collection('bookings').doc(bookingId).update({
          'status': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
          'cancellationReason': 'ระบบยกเลิกอัตโนมัติเนื่องจากคำขอหมดเวลา',
        });

        // สร้างการแจ้งเตือนสำหรับแอดมิน
        await _firestore.collection('admin_notifications').add({
          'type': 'booking_expired',
          'bookingId': bookingId,
          'message': 'การจองรหัส $bookingId หมดเวลาและถูกยกเลิกอัตโนมัติ',
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });

        // ส่งการแจ้งเตือนไปยังผู้ใช้
        if (bookingData.containsKey('userId')) {
          await _notificationService.sendBookingStatusNotification(
            userId: bookingData['userId'],
            bookingId: bookingId,
            status: 'auto_cancelled',
            message: 'การจองของคุณหมดเวลาและถูกยกเลิกอัตโนมัติ',
          );
        }

        // ส่งการแจ้งเตือนไปยังพี่เลี้ยง
        if (bookingData.containsKey('sitterId')) {
          await _notificationService.sendBookingStatusNotification(
            userId: bookingData['sitterId'],
            bookingId: bookingId,
            status: 'auto_cancelled',
            message: 'การจองหมดเวลาและถูกยกเลิกอัตโนมัติ',
          );
        }

        print('Auto-cancelled expired booking: $bookingId');
      }
    } catch (e) {
      print('Error cleaning up expired bookings: $e');
    }
  }

// แก้ไขฟังก์ชัน runCleanupTasks เพื่อเรียกใช้ฟังก์ชันใหม่
  Future<void> runCleanupTasks() async {
    try {
      print('Starting cleanup tasks...');

      // Check expired bookings immediately
      await checkExpiredBookingsImmediately();

      // Run all cleanup tasks
      await cleanupPendingBookings();
      await cleanupExpiredBookings();
      await cleanupOldBookings();

      print('All cleanup tasks completed successfully');
    } catch (e) {
      print('Error running cleanup tasks: $e');
      throw e; // Re-throw to allow error handling by caller
    }
  }

// เพิ่มฟังก์ชันตรวจสอบทันทีเมื่อเปิดแอป
  Future<void> checkExpiredBookingsImmediately() async {
    print('Checking expired bookings immediately...');
    await cleanupExpiredBookings();
    print('Immediate expired bookings check completed');
  }

  // ตรวจสอบและลบคิวการจองเก่าที่เสร็จสิ้นหรือยกเลิกไปแล้วเกินกว่าระยะเวลาที่กำหนด
  Future<void> cleanupOldBookings({int daysToKeep = 90}) async {
    try {
      // คำนวณเวลาที่เกินกำหนด
      DateTime cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      Timestamp cutoffTimestamp = Timestamp.fromDate(cutoffDate);

      // ค้นหาการจองเก่าที่มีสถานะ completed หรือ cancelled
      QuerySnapshot oldBookings = await _firestore
          .collection('bookings')
          .where('status', whereIn: ['completed', 'cancelled'])
          .where('updatedAt', isLessThan: cutoffTimestamp)
          .get();

      print('Found ${oldBookings.docs.length} old bookings to clean up');

      // ลบการจองเก่า
      for (var doc in oldBookings.docs) {
        String bookingId = doc.id;
        await _firestore.collection('bookings').doc(bookingId).delete();

        print('Deleted old booking: $bookingId');
      }
    } catch (e) {
      print('Error cleaning up old bookings: $e');
    }
  }
}
