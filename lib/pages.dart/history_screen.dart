import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/attendance_record.dart';
import '../services/attendance_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  List<AttendanceRecord> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
    });

    final records = await _attendanceService.getAttendanceRecords();
    // เรียงข้อมูลตามวันที่ล่าสุด
    records.sort((a, b) => b.date.compareTo(a.date));

    setState(() {
      _records = records;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF57C00),
        elevation: 0,
        title: Text(
          'ประวัติการดูแลแมว',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 70,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 20),
                      Text(
                        'ไม่พบประวัติการเช็คอิน/เช็คเอาท์',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : _buildRecordsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadRecords,
        backgroundColor: const Color(0xFFF57C00),
        child: Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildRecordsList() {
    // จัดกลุ่มข้อมูลตามวันที่
    Map<String, List<AttendanceRecord>> groupedRecords = {};

    for (var record in _records) {
      final dateStr = DateFormat('yyyy-MM-dd').format(record.date);
      if (!groupedRecords.containsKey(dateStr)) {
        groupedRecords[dateStr] = [];
      }
      groupedRecords[dateStr]!.add(record);
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: groupedRecords.length,
      itemBuilder: (context, index) {
        final dateStr = groupedRecords.keys.elementAt(index);
        final records = groupedRecords[dateStr]!;
        final date = DateFormat('yyyy-MM-dd').parse(dateStr);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                DateFormat('d MMMM yyyy', 'th_TH').format(date),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFF57C00),
                ),
              ),
            ),
            ...records.map((record) => _buildRecordCard(record)).toList(),
            Divider(thickness: 1),
          ],
        );
      },
    );
  }

  Widget _buildRecordCard(AttendanceRecord record) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // แสดงรูปภาพถ้ามี
            if (record.imagePath != null && record.imagePath!.isNotEmpty)
              GestureDetector(
                onTap: () => _showFullImage(record.imagePath!),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: FileImage(File(record.imagePath!)),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            // แสดงเวลาเช็คอิน/เช็คเอาท์
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'เช็คอิน',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      record.checkInTime.format(context),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'เช็คเอาท์',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      record.checkOutTime?.format(context) ?? '--:--',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: record.checkOutTime != null
                            ? Colors.red
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // แสดงบันทึกถ้ามี
            if (record.note != null && record.note!.isNotEmpty)
              Container(
                margin: EdgeInsets.only(top: 16),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'บันทึก:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      record.note!,
                      style: TextStyle(
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showFullImage(String imagePath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              image: DecorationImage(
                image: FileImage(File(imagePath)),
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }
}
