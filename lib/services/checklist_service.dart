import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:myproject/models/checklist_model.dart';

class ChecklistService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Stream<List<ChecklistItem>> getTasksForBooking(String bookingId) {
    return _firestore
        .collection('checklists')
        .where('bookingId', isEqualTo: bookingId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                ChecklistItem.fromJson(doc.data() as Map<String, dynamic>))
            .toList());
  }

  // สร้างรายการเช็คลิสต์พื้นฐานเมื่อยืนยันการจอง
  Future<void> createDefaultChecklist(String bookingId, String userId,
      String sitterId, List<String> catIds) async {
    // รายการกิจกรรมมาตรฐานที่ต้องทำ
    List<String> standardActivities = [
      'ให้อาหาร',
      'เปลี่ยนน้ำ',
      'ทำความสะอาดกระบะทราย',
      'เล่นกับแมว',
      'แปรงขน',
      'ตรวจสอบสุขภาพทั่วไป'
    ];

    // สร้างเช็คลิสต์สำหรับแมวแต่ละตัว
    for (String catId in catIds) {
      for (String activity in standardActivities) {
        String id = Uuid().v4();
        ChecklistItem item = ChecklistItem(
          id: id,
          bookingId: bookingId,
          sitterId: sitterId,
          userId: userId,
          catId: catId,
          description: activity,
          timestamp: DateTime.now(),
          isCompleted: false,
        );

        await _firestore.collection('checklists').doc(id).set(item.toJson());
      }
    }
  }

  // อัปโหลดรูปภาพและอัปเดตเช็คลิสต์
  Future<String?> uploadImageAndUpdateChecklist(
      String checklistId, File imageFile, String note, bool isCompleted) async {
    try {
      // อัปโหลดรูปภาพไปที่ Firebase Storage
      String fileName =
          'checklist_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = _storage.ref().child('checklist_images/$fileName');

      await storageRef.putFile(imageFile);
      String downloadUrl = await storageRef.getDownloadURL();

      // อัปเดตเช็คลิสต์ใน Firestore
      await _firestore.collection('checklists').doc(checklistId).update({
        'imageUrl': downloadUrl,
        'note': note,
        'isCompleted': isCompleted,
        'timestamp': FieldValue.serverTimestamp(),
      });

      return downloadUrl;
    } catch (e) {
      print('Error uploading image and updating checklist: $e');
      return null;
    }
  }

  // อัปเดตรายการเช็คลิสต์
  Future<void> updateChecklistItem(String checklistId, bool isCompleted,
      {String? note}) async {
    try {
      Map<String, dynamic> updateData = {
        'isCompleted': isCompleted,
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (note != null) {
        updateData['note'] = note;
      }

      await _firestore
          .collection('checklists')
          .doc(checklistId)
          .update(updateData);
    } catch (e) {
      print('Error updating checklist item: $e');
      throw e;
    }
  }

  // ดึงรายการเช็คลิสต์ตามการจอง
  Future<List<ChecklistItem>> getChecklistByBooking(String bookingId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('checklists')
          .where('bookingId', isEqualTo: bookingId)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) =>
              ChecklistItem.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting checklist by booking: $e');
      return [];
    }
  }

  // ดึงรายการเช็คลิสต์ตามแมว
  Future<List<ChecklistItem>> getChecklistByCat(
      String catId, String bookingId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('checklists')
          .where('catId', isEqualTo: catId)
          .where('bookingId', isEqualTo: bookingId)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) =>
              ChecklistItem.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting checklist by cat: $e');
      return [];
    }
  }

  // ดึงรายชื่อแมวสำหรับการจอง
  Future<List<Map<String, dynamic>>> getCatsForBooking(String bookingId) async {
    try {
      // ดึงข้อมูลการจอง
      DocumentSnapshot bookingDoc =
          await _firestore.collection('bookings').doc(bookingId).get();
      if (!bookingDoc.exists) {
        return [];
      }

      Map<String, dynamic> bookingData =
          bookingDoc.data() as Map<String, dynamic>;
      String userId = bookingData['userId'];
      List<String> catIds = List<String>.from(bookingData['catIds'] ?? []);

      List<Map<String, dynamic>> cats = [];
      for (String catId in catIds) {
        DocumentSnapshot catDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('cats')
            .doc(catId)
            .get();

        if (catDoc.exists) {
          Map<String, dynamic> catData = catDoc.data() as Map<String, dynamic>;
          catData['id'] = catId;
          cats.add(catData);
        }
      }

      return cats;
    } catch (e) {
      print('Error getting cats for booking: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getChecklistStatistics() async {
    try {
      // ดึงข้อมูลเช็คลิสต์ทั้งหมด
      QuerySnapshot allChecklistsSnapshot =
          await _firestore.collection('checklists').get();
      int totalChecklists = allChecklistsSnapshot.docs.length;

      // ดึงข้อมูลเช็คลิสต์ที่เสร็จแล้ว
      QuerySnapshot completedChecklistsSnapshot = await _firestore
          .collection('checklists')
          .where('isCompleted', isEqualTo: true)
          .get();
      int completedItems = completedChecklistsSnapshot.docs.length;

      // ดึงข้อมูลการจองทั้งหมด
      QuerySnapshot bookingSnapshot =
          await _firestore.collection('bookings').get();
      int totalBookings = bookingSnapshot.docs.length;

      // ดึงจำนวนการจองที่มีเช็คลิสต์ (เช่น มีรายการใน collection checklist ที่ bookingId ตรงกัน)
      Set<String> bookingIdsWithChecklist = allChecklistsSnapshot.docs
          .map((doc) =>
              (doc.data() as Map<String, dynamic>)['bookingId'] as String)
          .toSet();
      int bookingsWithChecklist = bookingIdsWithChecklist.length;

      // คำนวณเปอร์เซ็นต์
      double completionRate =
          totalChecklists > 0 ? completedItems / totalChecklists : 0.0;
      double bookingCompletionRate =
          totalBookings > 0 ? bookingsWithChecklist / totalBookings : 0.0;

      return {
        'totalChecklists': totalChecklists,
        'completedItems': completedItems,
        'completionRate': completionRate,
        'totalBookings': totalBookings,
        'bookingCompletionRate': bookingCompletionRate,
      };
    } catch (e) {
      print('Error getting checklist statistics: $e');
      return {
        'totalChecklists': 0,
        'completedChecklists': 0,
        'totalBookings': 0,
        'bookingsWithChecklists': 0,
        'error': e.toString()
      };
    }
  }
}
