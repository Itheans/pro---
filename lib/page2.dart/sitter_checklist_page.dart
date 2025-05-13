import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:myproject/models/checklist_model.dart';
import 'package:myproject/services/checklist_service.dart';

class SitterChecklistPage extends StatefulWidget {
  final String bookingId;

  const SitterChecklistPage({
    Key? key,
    required this.bookingId,
  }) : super(key: key);

  @override
  _SitterChecklistPageState createState() => _SitterChecklistPageState();
}

class _SitterChecklistPageState extends State<SitterChecklistPage> {
  final ChecklistService _checklistService = ChecklistService();
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = true;
  List<Map<String, dynamic>> _cats = [];
  List<ChecklistItem> _checklistItems = [];
  String? _selectedCatId;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // โหลดข้อมูลแมวสำหรับการจอง
      List<Map<String, dynamic>> cats = await _checklistService.getCatsForBooking(widget.bookingId);
      
      // โหลดเช็คลิสต์สำหรับการจอง
      List<ChecklistItem> checklistItems = await _checklistService.getChecklistByBooking(widget.bookingId);
      
      setState(() {
        _cats = cats;
        _checklistItems = checklistItems;
        if (cats.isNotEmpty && _selectedCatId == null) {
          _selectedCatId = cats.first['id'];
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e')),
      );
    }
  }
  
  Future<void> _pickImageAndUpdateChecklist(ChecklistItem item) async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image == null) return;
      
      // แสดงป๊อปอัพให้กรอกโน้ต
      String? note = await _showNoteDialog();
      if (note == null) return;
      
      setState(() {
        _isLoading = true;
      });
      
      // อัปโหลดรูปภาพและอัปเดตเช็คลิสต์
      await _checklistService.uploadImageAndUpdateChecklist(
        item.id, 
        File(image.path), 
        note, 
        true
      );
      
      // โหลดข้อมูลใหม่
      await _loadData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('อัปเดตเช็คลิสต์เรียบร้อยแล้ว')),
      );
    } catch (e) {
      print('Error picking image and updating checklist: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<String?> _showNoteDialog() async {
    TextEditingController noteController = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('เพิ่มโน้ต'),
        content: TextField(
          controller: noteController,
          decoration: InputDecoration(
            hintText: 'เช่น "แมวกินอาหารหมดจาน", "เล่นเป็นเวลา 30 นาที"',
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
            onPressed: () => Navigator.pop(context, noteController.text),
            child: Text('บันทึก'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
            ),
          ),
        ],
      ),
    );
  }
  
  void _updateChecklistStatus(ChecklistItem item, bool isCompleted) async {
    try {
      if (isCompleted) {
        // ถ้ากำลังจะทำเครื่องหมายว่าเสร็จแล้ว ให้ถ่ายรูปและเพิ่มโน้ต
        await _pickImageAndUpdateChecklist(item);
      } else {
        // ถ้ากำลังจะยกเลิกเครื่องหมาย
        await _checklistService.updateChecklistItem(item.id, isCompleted);
        await _loadData();
      }
    } catch (e) {
      print('Error updating checklist status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการอัปเดตสถานะ: $e')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('เช็คลิสต์การดูแลแมว'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'รีเฟรชข้อมูล',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ส่วนเลือกแมว
                _buildCatSelector(),
                
                // ส่วนแสดงเช็คลิสต์
                Expanded(
                  child: _selectedCatId != null
                      ? _buildChecklistForCat(_selectedCatId!)
                      : Center(
                          child: Text('กรุณาเลือกแมว'),
                        ),
                ),
              ],
            ),
    );
  }
  
  Widget _buildCatSelector() {
    return Container(
      height: 100,
      padding: EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _cats.length,
        itemBuilder: (context, index) {
          final cat = _cats[index];
          final isSelected = cat['id'] == _selectedCatId;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCatId = cat['id'];
              });
            },
            child: Container(
              width: 80,
              margin: EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: isSelected ? Colors.teal : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundImage: cat['imagePath'] != null && cat['imagePath'].isNotEmpty
                        ? NetworkImage(cat['imagePath'])
                        : null,
                    child: cat['imagePath'] == null || cat['imagePath'].isEmpty
                        ? Icon(Icons.pets, color: Colors.grey)
                        : null,
                  ),
                  SizedBox(height: 8),
                  Text(
                    cat['name'] ?? 'แมว',
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildChecklistForCat(String catId) {
    // กรองรายการเฉพาะแมวที่เลือก
    List<ChecklistItem> filteredItems = _checklistItems
        .where((item) => item.catId == catId)
        .toList();
    
    if (filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.format_list_bulleted,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'ไม่พบรายการเช็คลิสต์สำหรับแมวตัวนี้',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        
        return Card(
          margin: EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () {
              if (item.isCompleted) {
                // ถ้าทำแล้ว ให้แสดงรายละเอียด
                _showCompletedItemDetails(item);
              } else {
                // ถ้ายังไม่ได้ทำ ให้ทำเครื่องหมายว่าเสร็จแล้ว
                _updateChecklistStatus(item, true);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  // ไอคอนสถานะ
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: item.isCompleted ? Colors.green.shade100 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      item.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                      color: item.isCompleted ? Colors.green : Colors.grey,
                    ),
                  ),
                  SizedBox(width: 16),
                  
                  // รายละเอียดรายการ
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.description,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                            color: item.isCompleted ? Colors.grey : Colors.black,
                          ),
                        ),
                        if (item.isCompleted && item.note != null && item.note!.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              item.note!,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (item.isCompleted)
                          Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'เสร็จเมื่อ: ${DateFormat('dd/MM/yyyy HH:mm').format(item.timestamp)}',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // ปุ่มกล้องหรือปุ่มแสดงรูป
                  if (item.isCompleted && item.imageUrl != null)
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(item.imageUrl!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  else if (!item.isCompleted)
                    IconButton(
                      icon: Icon(Icons.camera_alt, color: Colors.teal),
                      onPressed: () => _updateChecklistStatus(item, true),
                      tooltip: 'ถ่ายรูปและทำเครื่องหมายว่าเสร็จแล้ว',
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  void _showCompletedItemDetails(ChecklistItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.description),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.imageUrl != null)
                Container(
                  width: double.infinity,
                  height: 200,
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: NetworkImage(item.imageUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              Text(
                'บันทึกเมื่อ: ${DateFormat('dd/MM/yyyy HH:mm').format(item.timestamp)}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 12),
              if (item.note != null && item.note!.isNotEmpty) ...[
                Text(
                  'โน้ต:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(item.note!),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ปิด'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateChecklistStatus(item, false);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text('ยกเลิกการทำเครื่องหมาย'),
          ),
        ],
      ),
    );
  }
}