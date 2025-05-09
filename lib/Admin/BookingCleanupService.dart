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
      DateTime timeoutThreshold = DateTime.now().subtract(Duration(minutes: timeoutMinutes));
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
        await _firestore
            .collection('bookings')
            .doc(bookingId)
            .update({
              'status': 'cancelled',
              'updatedAt': FieldValue.serverTimestamp(),
              'cancellationReason': 'ระบบยกเลิกอัตโนมัติเนื่องจากไม่ได้รับการยืนยันภายใน $timeoutMinutes นาที',
            });

        // ส่งการแจ้งเตือนไปยังผู้ใช้
        if (bookingData.containsKey('userId')) {
          await _notificationService.sendBookingStatusNotification(
            userId: bookingData['userId'],
            bookingId: bookingId,
            status: 'auto_cancelled',
            message: 'การจองของคุณถูกยกเลิกอัตโนมัติเนื่องจากไม่ได้รับการยืนยันภายใน $timeoutMinutes นาที',
          );
        }

        // ส่งการแจ้งเตือนไปยังพี่เลี้ยง
        if (bookingData.containsKey('sitterId')) {
          await _notificationService.sendBookingStatusNotification(
            userId: bookingData['sitterId'],
            bookingId: bookingId,
            status: 'auto_cancelled',
            message: 'การจองถูกยกเลิกอัตโนมัติเนื่องจากไม่ได้รับการยืนยันภายใน $timeoutMinutes นาที',
          );
        }

        print('Auto-cancelled booking: $bookingId');
      }
    } catch (e) {
      print('Error cleaning up bookings: $e');
    }
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
        await _firestore
            .collection('bookings')
            .doc(bookingId)
            .delete();

        print('Deleted old booking: $bookingId');
      }
    } catch (e) {
      print('Error cleaning up old bookings: $e');
    }
  }

  // รันระบบทำความสะอาดทั้งหมด
  Future<void> runCleanupTasks() async {
    await cleanupPendingBookings();
    await cleanupOldBookings();
  }
}