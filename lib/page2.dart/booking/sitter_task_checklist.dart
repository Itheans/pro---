import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:myproject/models/task_model.dart';
import 'package:myproject/services/task_service.dart';
import 'package:uuid/uuid.dart';

class SitterTaskChecklistPage extends StatefulWidget {
  final String bookingId;
  final String catName;

  const SitterTaskChecklistPage({
    Key? key,
    required this.bookingId,
    required this.catName,
  }) : super(key: key);

  @override
  _SitterTaskChecklistPageState createState() =>
      _SitterTaskChecklistPageState();
}

class _SitterTaskChecklistPageState extends State<SitterTaskChecklistPage> {
  final TaskService _taskService = TaskService();
  bool _isLoading = true;
  bool _isUploading = false;

  // Controllers for adding new task
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeTasks();
  }

  Future<void> _initializeTasks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Initialize default tasks if necessary
      await _taskService.initializeDefaultTasks(widget.bookingId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String?> _uploadImage(File image) async {
    setState(() {
      _isUploading = true;
    });

    try {
      final imageName = '${Uuid().v4()}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('bookings/${widget.bookingId}/tasks/$imageName');

      await ref.putFile(image);
      final downloadUrl = await ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการอัพโหลดรูปภาพ: $e')),
      );
      return null;
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _getImage(String taskId) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      final imageFile = File(image.path);
      final downloadUrl = await _uploadImage(imageFile);

      if (downloadUrl != null) {
        await _taskService.updateTaskStatus(
          widget.bookingId,
          taskId,
          true,
          photoUrl: downloadUrl,
        );
      }
    }
  }

  void _showAddTaskDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('เพิ่มงานใหม่'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'ชื่องาน',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'รายละเอียด',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_titleController.text.trim().isNotEmpty) {
                await _taskService.addTask(
                  widget.bookingId,
                  _titleController.text.trim(),
                  _descriptionController.text.trim(),
                );
                _titleController.clear();
                _descriptionController.clear();
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('กรุณากรอกชื่องาน')),
                );
              }
            },
            child: Text('เพิ่ม'),
          ),
        ],
      ),
    );
  }

  void _showNotesDialog(TaskModel task) {
    _notesController.text = task.notes ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('เพิ่มบันทึก'),
        content: TextField(
          controller: _notesController,
          decoration: InputDecoration(
            labelText: 'บันทึกเพิ่มเติม',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _taskService.updateTaskStatus(
                widget.bookingId,
                task.id,
                task.isCompleted,
                notes: _notesController.text.trim(),
              );
              Navigator.pop(context);
            },
            child: Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text('รูปภาพ'),
              leading: IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
              automaticallyImplyLeading: false,
            ),
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('เช็คลิสต์งานดูแล ${widget.catName}'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _showAddTaskDialog,
            tooltip: 'เพิ่มงานใหม่',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : StreamBuilder<List<TaskModel>>(
              stream: _taskService.getTasksForBooking(widget.bookingId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'),
                  );
                }

                final tasks = snapshot.data ?? [];

                if (tasks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'ไม่มีรายการงาน',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _showAddTaskDialog,
                          icon: Icon(Icons.add),
                          label: Text('เพิ่มงานใหม่'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CheckboxListTile(
                              title: Text(
                                task.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  decoration: task.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 4),
                                  Text(task.description),
                                  SizedBox(height: 4),
                                  if (task.completedAt != null)
                                    Text(
                                      'เสร็จเมื่อ: ${DateFormat('dd/MM/yyyy HH:mm').format(task.completedAt!)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green,
                                      ),
                                    ),
                                  if (task.notes != null &&
                                      task.notes!.isNotEmpty)
                                    Container(
                                      margin: EdgeInsets.only(top: 8),
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.yellow.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.yellow.shade200,
                                        ),
                                      ),
                                      child: Text(
                                        'บันทึก: ${task.notes}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              value: task.isCompleted,
                              onChanged: _isUploading
                                  ? null
                                  : (value) async {
                                      await _taskService.updateTaskStatus(
                                        widget.bookingId,
                                        task.id,
                                        value ?? false,
                                      );
                                    },
                              activeColor: Colors.teal,
                            ),
                            if (task.photoUrl != null &&
                                task.photoUrl!.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: GestureDetector(
                                  onTap: () => _showImageDialog(task.photoUrl!),
                                  child: Container(
                                    height: 100,
                                    width: double.infinity,
                                    margin: EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      image: DecorationImage(
                                        image: NetworkImage(task.photoUrl!),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (task.isCompleted)
                                    IconButton(
                                      icon: Icon(Icons.edit_note),
                                      color: Colors.blue,
                                      onPressed: () => _showNotesDialog(task),
                                      tooltip: 'เพิ่มบันทึก',
                                    ),
                                  SizedBox(width: 8),
                                  if (!task.isCompleted)
                                    IconButton(
                                      icon: Icon(Icons.camera_alt),
                                      color: Colors.green,
                                      onPressed: () => _getImage(task.id),
                                      tooltip: 'ถ่ายรูป',
                                    ),
                                  SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(Icons.delete),
                                    color: Colors.red,
                                    onPressed: () async {
                                      // Show confirmation dialog
                                      bool confirm = await showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text('ยืนยันการลบ'),
                                          content: Text(
                                              'คุณต้องการลบงานนี้ใช่หรือไม่?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: Text('ยกเลิก'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                              ),
                                              child: Text('ลบ'),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirm) {
                                        await _taskService.deleteTask(
                                          widget.bookingId,
                                          task.id,
                                        );
                                      }
                                    },
                                    tooltip: 'ลบงาน',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> initializeDefaultTasks(String bookingId) async {
    try {
      // Check if tasks already exist
      final existingTasks = await _firestore
          .collection('bookings')
          .doc(bookingId)
          .collection('tasks')
          .get();

      // Only initialize if no tasks exist
      if (existingTasks.docs.isEmpty) {
        final batch = _firestore.batch();

        // Define default tasks
        final defaultTasks = [
          {
            'title': 'ตรวจสอบอาหารและน้ำ',
            'description': 'ตรวจสอบว่ามีอาหารและน้ำเพียงพอ',
            'isCompleted': false,
            'createdAt': FieldValue.serverTimestamp(),
            'order': 1,
          },
          {
            'title': 'ทำความสะอาดกรงทราย',
            'description': 'ทำความสะอาดและเปลี่ยนทรายแมว',
            'isCompleted': false,
            'createdAt': FieldValue.serverTimestamp(),
            'order': 2,
          },
          {
            'title': 'เล่นกับแมว',
            'description': 'ใช้เวลาเล่นและมีปฏิสัมพันธ์กับแมว',
            'isCompleted': false,
            'createdAt': FieldValue.serverTimestamp(),
            'order': 3,
          }
        ];

        // Add tasks in batch
        for (var task in defaultTasks) {
          final docRef = _firestore
              .collection('bookings')
              .doc(bookingId)
              .collection('tasks')
              .doc();
          batch.set(docRef, task);
        }

        await batch.commit();
      }
    } catch (e) {
      print('Error initializing default tasks: $e');
      throw Exception('Failed to initialize default tasks');
    }
  }

  Future<void> updateTaskStatus(
      String bookingId, String taskId, bool isCompleted,
      {String? notes, String? photoUrl} // Added photoUrl parameter
      ) async {
    try {
      final taskRef = _firestore
          .collection('bookings')
          .doc(bookingId)
          .collection('tasks')
          .doc(taskId);

      Map<String, dynamic> updates = {
        'isCompleted': isCompleted,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Include notes if provided
      if (notes != null) {
        updates['notes'] = notes;
      }

      // Include photo URL if provided
      if (photoUrl != null) {
        updates['photoUrl'] = photoUrl;
      }

      // Add completion timestamp if task is being marked as complete
      if (isCompleted) {
        updates['completedAt'] = FieldValue.serverTimestamp();
      }

      await taskRef.update(updates);
    } catch (e) {
      print('Error updating task status: $e');
      throw Exception('Failed to update task status: $e');
    }
  }

  Future<void> deleteTask(String bookingId, String taskId,
      {bool softDelete = false}) async {
    try {
      final taskRef = _firestore
          .collection('bookings')
          .doc(bookingId)
          .collection('tasks')
          .doc(taskId);

      if (softDelete) {
        // Soft delete - mark as deleted but keep the record
        await taskRef.update({
          'isDeleted': true,
          'deletedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Hard delete - remove the document
        await taskRef.delete();
      }
    } catch (e) {
      print('Error deleting task: $e');
      throw Exception('Failed to delete task: $e');
    }
  }

  Future<void> addTask(
    String bookingId,
    String title,
    String description,
  ) async {
    try {
      // Get reference to tasks collection
      final tasksRef =
          _firestore.collection('bookings').doc(bookingId).collection('tasks');

      // Create new task document
      await tasksRef.add({
        'title': title,
        'description': description,
        'isCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'order': await _getNextTaskOrder(tasksRef),
      });
    } catch (e) {
      print('Error adding task: $e');
      throw Exception('Failed to add task');
    }
  }

  Future<int> _getNextTaskOrder(CollectionReference tasksRef) async {
    final QuerySnapshot snapshot =
        await tasksRef.orderBy('order', descending: true).limit(1).get();

    if (snapshot.docs.isEmpty) {
      return 1;
    }

    // Safely access data with null checking
    final data = snapshot.docs.first.data() as Map<String, dynamic>?;
    final highestOrder = data?['order'] ?? 0;
    return highestOrder + 1;
  }

  Stream<List<TaskModel>> getTasksForBooking(String bookingId) {
    try {
      return _firestore
          .collection('bookings')
          .doc(bookingId)
          .collection('tasks')
          .orderBy('order', descending: false) // Sort by task order
          .orderBy('createdAt', descending: false) // Then by creation time
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .where((doc) =>
                !(doc.data()['isDeleted'] ?? false)) // Filter out deleted tasks
            .map((doc) => TaskModel.fromMap(doc.data(), doc.id))
            .toList();
      });
    } catch (e) {
      print('Error setting up tasks stream: $e');
      return Stream.value([]); // Return empty list on error
    }
  }
}
