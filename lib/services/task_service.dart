// lib/services/task_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myproject/models/task_model.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get tasks for a specific booking
  Stream<List<TaskModel>> getTasksForBooking(String bookingId) {
    return _firestore
        .collection('bookings')
        .doc(bookingId)
        .collection('tasks')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TaskModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // Create a new task
  Future<String> createTask(
      String bookingId, String title, String description) async {
    try {
      // Get current user
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Create task data
      final taskData = {
        'bookingId': bookingId,
        'title': title,
        'description': description,
        'isCompleted': false,
        'completedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentUser.uid,
        'assignedTo': null, // Can be assigned later
      };

      // Add task to Firestore
      DocumentReference docRef =
          await _firestore.collection('tasks').add(taskData);

      return docRef.id;
    } catch (e) {
      print('Error creating task: $e');
      throw e;
    }
  }

  // Mark a task as completed
  Future<void> completeTask(String taskId) async {
    try {
      await _firestore.collection('tasks').doc(taskId).update({
        'isCompleted': true,
        'completedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error completing task: $e');
      throw e;
    }
  }

  // Mark a task as incomplete
  Future<void> reopenTask(String taskId) async {
    try {
      await _firestore.collection('tasks').doc(taskId).update({
        'isCompleted': false,
        'completedAt': null,
      });
    } catch (e) {
      print('Error reopening task: $e');
      throw e;
    }
  }

  // Delete a task
  Future<void> deleteTask(String taskId) async {
    try {
      await _firestore.collection('tasks').doc(taskId).delete();
    } catch (e) {
      print('Error deleting task: $e');
      throw e;
    }
  }

  // Update a task - แก้ไขส่วนนี้เพื่อแก้ปัญหา type error
  Future<void> updateTask(Map<String, dynamic> task) async {
    try {
      final taskId = task['id'] as String; // ทำการแปลงประเภทที่ชัดเจน
      await _firestore.collection('tasks').doc(taskId).update({
        'title': task['title'],
        'description': task['description'],
        'assignedTo': task['assignedTo'],
      });
    } catch (e) {
      print('Error updating task: $e');
      throw e;
    }
  }

  // Assign a task to a user
  Future<void> assignTask(String taskId, String userId) async {
    try {
      await _firestore.collection('tasks').doc(taskId).update({
        'assignedTo': userId,
      });
    } catch (e) {
      print('Error assigning task: $e');
      throw e;
    }
  }

  // Create multiple tasks at once
  Future<List<String>> createMultipleTasks(
      List<Map<String, dynamic>> tasks) async {
    try {
      final batch = _firestore.batch();
      final List<DocumentReference> refs = [];

      for (var task in tasks) {
        final docRef = _firestore.collection('tasks').doc();
        refs.add(docRef);
        batch.set(docRef, task);
      }

      await batch.commit();
      return refs.map((ref) => ref.id).toList();
    } catch (e) {
      print('Error creating multiple tasks: $e');
      throw e;
    }
  }

  // Bulk update tasks - แก้ไขส่วนนี้เพื่อแก้ปัญหา type error
  Future<void> bulkUpdateTasks(List<Map<String, dynamic>> tasks) async {
    try {
      final batch = _firestore.batch();

      for (var task in tasks) {
        final taskId = task['id'] as String; // ทำการแปลงประเภทที่ชัดเจน
        final docRef = _firestore.collection('tasks').doc(taskId);
        batch.update(docRef, {
          'title': task['title'],
          'description': task['description'],
          'assignedTo': task['assignedTo'],
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error bulk updating tasks: $e');
      throw e;
    }
  }
}
