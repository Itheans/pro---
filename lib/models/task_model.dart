// lib/models/task_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String id;
  final String bookingId;
  final String title;
  final String description;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;
  final String? assignedTo;
  final String? createdBy;
  final String? photoUrl;
  final String? notes; // Added notes field

  TaskModel({
    required this.id,
    required this.bookingId,
    required this.title,
    required this.description,
    required this.isCompleted,
    this.completedAt,
    required this.createdAt,
    this.assignedTo,
    this.createdBy,
    this.photoUrl, // Optional field
    this.notes, // Added to constructor
  });

  // Convert a map to a TaskModel
  factory TaskModel.fromMap(Map<String, dynamic> map, String documentId) {
    return TaskModel(
      id: documentId,
      bookingId: map['bookingId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      completedAt: map['completedAt'] != null
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      assignedTo: map['assignedTo'],
      createdBy: map['createdBy'],
      photoUrl: map['photoUrl'], // Add this field to the factory constructor
      notes: map['notes'], // Added to fromMap
    );
  }

  // Convert a TaskModel to a map
  Map<String, dynamic> toMap() {
    return {
      'bookingId': bookingId,
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'assignedTo': assignedTo,
      'createdBy': createdBy,
      'photoUrl': photoUrl, // Add this field to the map
      'notes': notes, // Added to toMap
    };
  }
}
