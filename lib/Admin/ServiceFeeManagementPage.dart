import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ServiceFeeManagementPage extends StatefulWidget {
  const ServiceFeeManagementPage({Key? key}) : super(key: key);

  @override
  _ServiceFeeManagementPageState createState() =>
      _ServiceFeeManagementPageState();
}

class _ServiceFeeManagementPageState extends State<ServiceFeeManagementPage> {
  bool _isLoading = true;

  // ตัวแปรสำหรับเก็บข้อมูลค่าบริการ
  Map<String, dynamic> _serviceFees = {};

  // ตัวควบคุมสำหรับฟิลด์ input
  final TextEditingController _platformFeeController = TextEditingController();
  final TextEditingController _minServiceRateController =
      TextEditingController();
  final TextEditingController _maxServiceRateController =
      TextEditingController();
  final TextEditingController _defaultServiceRateController =
      TextEditingController();
  final TextEditingController _taxRateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadServiceFees();
  }

  @override
  void dispose() {
    _platformFeeController.dispose();
    _minServiceRateController.dispose();
    _maxServiceRateController.dispose();
    _defaultServiceRateController.dispose();
    _taxRateController.dispose();
    super.dispose();
  }

  // โหลดข้อมูลค่าบริการจาก Firestore
  Future<void> _loadServiceFees() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // โหลดการตั้งค่าจาก Firestore
      DocumentSnapshot feeDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('serviceFees')
          .get();

      if (feeDoc.exists) {
        Map<String, dynamic> data = feeDoc.data() as Map<String, dynamic>;
        setState(() {
          _serviceFees = data;
        });

        // กำหนดค่าเริ่มต้นให้ controller
        _platformFeeController.text =
            (_serviceFees['platformFee'] ?? 0.0).toString();
        _minServiceRateController.text =
            (_serviceFees['minServiceRate'] ?? 0.0).toString();
        _maxServiceRateController.text =
            (_serviceFees['maxServiceRate'] ?? 0.0).toString();
        _defaultServiceRateController.text =
            (_serviceFees['defaultServiceRate'] ?? 0.0).toString();
        _taxRateController.text = (_serviceFees['taxRate'] ?? 0.0).toString();
      } else {
        // ถ้ายังไม่มีข้อมูล ให้สร้างข้อมูลเริ่มต้น
        await _createDefaultServiceFees();
      }
    } catch (e) {
      print('Error loading service fees: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูลค่าบริการ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // สร้างข้อมูลค่าบริการเริ่มต้น
  Future<void> _createDefaultServiceFees() async {
    try {
      Map<String, dynamic> defaultFees = {
        'platformFee': 10.0, // ค่าธรรมเนียมแพลตฟอร์ม (%)
        'minServiceRate': 100.0, // ค่าบริการขั้นต่ำ (บาท)
        'maxServiceRate': 1000.0, // ค่าบริการสูงสุด (บาท)
        'defaultServiceRate': 300.0, // ค่าบริการเริ่มต้น (บาท)
        'taxRate': 7.0, // อัตราภาษี (%)
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('settings')
          .doc('serviceFees')
          .set(defaultFees);

      setState(() {
        _serviceFees = defaultFees;
        _platformFeeController.text = defaultFees['platformFee'].toString();
        _minServiceRateController.text =
            defaultFees['minServiceRate'].toString();
        _maxServiceRateController.text =
            defaultFees['maxServiceRate'].toString();
        _defaultServiceRateController.text =
            defaultFees['defaultServiceRate'].toString();
        _taxRateController.text = defaultFees['taxRate'].toString();
      });
    } catch (e) {
      print('Error creating default service fees: $e');
      throw e;
    }
  }

  // บันทึกการเปลี่ยนแปลงค่าบริการ
  Future<void> _saveServiceFees() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // แปลง string เป็น double
      double platformFee = double.tryParse(_platformFeeController.text) ?? 0.0;
      double minServiceRate =
          double.tryParse(_minServiceRateController.text) ?? 0.0;
      double maxServiceRate =
          double.tryParse(_maxServiceRateController.text) ?? 0.0;
      double defaultServiceRate =
          double.tryParse(_defaultServiceRateController.text) ?? 0.0;
      double taxRate = double.tryParse(_taxRateController.text) ?? 0.0;

      // ตรวจสอบความถูกต้องของข้อมูล
      if (platformFee < 0 || platformFee > 100) {
        throw Exception('ค่าธรรมเนียมแพลตฟอร์มต้องอยู่ระหว่าง 0-100%');
      }

      if (minServiceRate < 0) {
        throw Exception('ค่าบริการขั้นต่ำต้องไม่ต่ำกว่า 0 บาท');
      }

      if (maxServiceRate <= minServiceRate) {
        throw Exception('ค่าบริการสูงสุดต้องมากกว่าค่าบริการขั้นต่ำ');
      }

      if (defaultServiceRate < minServiceRate ||
          defaultServiceRate > maxServiceRate) {
        throw Exception(
            'ค่าบริการเริ่มต้นต้องอยู่ระหว่างค่าบริการขั้นต่ำและสูงสุด');
      }

      if (taxRate < 0 || taxRate > 100) {
        throw Exception('อัตราภาษีต้องอยู่ระหว่าง 0-100%');
      }

      // สร้างข้อมูลใหม่
      Map<String, dynamic> updatedFees = {
        'platformFee': platformFee,
        'minServiceRate': minServiceRate,
        'maxServiceRate': maxServiceRate,
        'defaultServiceRate': defaultServiceRate,
        'taxRate': taxRate,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // บันทึกข้อมูลลง Firestore
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('serviceFees')
          .update(updatedFees);

      setState(() {
        _serviceFees = updatedFees;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('บันทึกการเปลี่ยนแปลงค่าบริการเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error saving service fees: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('จัดการค่าบริการ'),
        backgroundColor: Colors.deepOrange,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // หัวข้อค่าบริการพื้นฐาน
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.monetization_on,
                                  color: Colors.deepOrange),
                              SizedBox(width: 8),
                              Text(
                                'ค่าบริการพื้นฐาน',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),

                          // ค่าธรรมเนียมแพลตฟอร์ม
                          Text(
                            'ค่าธรรมเนียมแพลตฟอร์ม (%)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          TextField(
                            controller: _platformFeeController,
                            decoration: InputDecoration(
                              hintText: 'ระบุเปอร์เซ็นต์ (0-100)',
                              border: OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: Colors.deepOrange, width: 2),
                              ),
                              suffixText: '%',
                            ),
                            keyboardType:
                                TextInputType.numberWithOptions(decimal: true),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'ส่วนแบ่งรายได้ที่ระบบจะได้รับจากค่าบริการทั้งหมด',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),

                          SizedBox(height: 16),

                          // อัตราภาษี
                          Text(
                            'อัตราภาษี (%)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          TextField(
                            controller: _taxRateController,
                            decoration: InputDecoration(
                              hintText: 'ระบุเปอร์เซ็นต์ (0-100)',
                              border: OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: Colors.deepOrange, width: 2),
                              ),
                              suffixText: '%',
                            ),
                            keyboardType:
                                TextInputType.numberWithOptions(decimal: true),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'อัตราภาษีที่จะนำไปคำนวณในใบเสร็จ',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  // การตั้งค่าพี่เลี้ยงแมว
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.pets, color: Colors.deepOrange),
                              SizedBox(width: 8),
                              Text(
                                'ค่าบริการพี่เลี้ยงแมว',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),

                          // ค่าบริการขั้นต่ำ
                          Text(
                            'ค่าบริการขั้นต่ำ (บาท/วัน)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          TextField(
                            controller: _minServiceRateController,
                            decoration: InputDecoration(
                              hintText: 'ระบุจำนวนเงิน',
                              border: OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: Colors.deepOrange, width: 2),
                              ),
                              suffixText: 'บาท',
                            ),
                            keyboardType:
                                TextInputType.numberWithOptions(decimal: true),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'ค่าบริการขั้นต่ำที่พี่เลี้ยงแมวสามารถตั้งได้',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),

                          SizedBox(height: 16),

                          // ค่าบริการสูงสุด
                          Text(
                            'ค่าบริการสูงสุด (บาท/วัน)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          TextField(
                            controller: _maxServiceRateController,
                            decoration: InputDecoration(
                              hintText: 'ระบุจำนวนเงิน',
                              border: OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: Colors.deepOrange, width: 2),
                              ),
                              suffixText: 'บาท',
                            ),
                            keyboardType:
                                TextInputType.numberWithOptions(decimal: true),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'ค่าบริการสูงสุดที่พี่เลี้ยงแมวสามารถตั้งได้',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),

                          SizedBox(height: 16),

                          // ค่าบริการเริ่มต้น
                          Text(
                            'ค่าบริการเริ่มต้น (บาท/วัน)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          TextField(
                            controller: _defaultServiceRateController,
                            decoration: InputDecoration(
                              hintText: 'ระบุจำนวนเงิน',
                              border: OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: Colors.deepOrange, width: 2),
                              ),
                              suffixText: 'บาท',
                            ),
                            keyboardType:
                                TextInputType.numberWithOptions(decimal: true),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'ค่าบริการเริ่มต้นสำหรับพี่เลี้ยงแมวรายใหม่',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 30),

                  // ปุ่มบันทึก
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveServiceFees,
                      icon: Icon(Icons.save),
                      label: Text('บันทึกการเปลี่ยนแปลง'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  // ปุ่มรีเซ็ตเป็นค่าเริ่มต้น
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () async {
                        bool confirm = await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('ยืนยันการรีเซ็ต'),
                            content: Text(
                                'คุณแน่ใจหรือไม่ว่าต้องการรีเซ็ตค่าบริการเป็นค่าเริ่มต้น?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text('ยกเลิก'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: Text('รีเซ็ต'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          // ลบข้อมูลเดิมและสร้างใหม่
                          await FirebaseFirestore.instance
                              .collection('settings')
                              .doc('serviceFees')
                              .delete();

                          await _createDefaultServiceFees();

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'รีเซ็ตค่าบริการเป็นค่าเริ่มต้นเรียบร้อยแล้ว'),
                              backgroundColor: Colors.blue,
                            ),
                          );
                        }
                      },
                      icon: Icon(Icons.refresh),
                      label: Text('รีเซ็ตเป็นค่าเริ่มต้น'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
