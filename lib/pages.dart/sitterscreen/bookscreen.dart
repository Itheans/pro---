import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:myproject/pages.dart/buttomnav.dart';
import 'package:myproject/pages.dart/sitterscreen/bookingService.dart';
import 'package:myproject/services/shared_pref.dart';

class BookingScreen extends StatefulWidget {
  final String sitterId;
  final List<String> catIds;
  final List<DateTime> selectedDates;
  final double pricePerDay;
  final String? bookingRef; // เพิ่ม parameter นี้

  const BookingScreen({
    Key? key,
    required this.sitterId,
    required this.selectedDates,
    required this.pricePerDay,
    required this.catIds,
    this.bookingRef, // เพิ่ม optional parameter
  }) : super(key: key);

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance; // Add this line
  final TextEditingController _notesController = TextEditingController();
  final BookingService _bookingService = BookingService();
  bool _isLoading = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // ฟังก์ชันสำหรับการยืนยันการจอง
  // ตำแหน่งที่ต้องแก้: ฟังก์ชัน _confirmBooking() ใน class _BookingScreenState
// แก้ไขทั้งฟังก์ชันเป็น:
  // ตำแหน่งที่ต้องแก้: ฟังก์ชัน _confirmBooking() ใน class _BookingScreenState
// เพิ่มโค้ดด้านล่างนี้เพื่อดีบักปัญหาและทำให้การตรวจสอบยอดเงินถูกต้อง:

  Future<void> _confirmBooking() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("กรุณาเข้าสู่ระบบ");

      // คำนวณค่าบริการทั้งหมด
      final totalPrice = widget.pricePerDay * widget.selectedDates.length;

      // ดีบัก: แสดงค่าบริการที่จะชำระ
      print("ค่าบริการที่ต้องชำระ: $totalPrice");
      print("Booking Reference: ${widget.bookingRef}");

      // ถ้ามี bookingRef ให้นำ catIds จาก booking_request มาใช้
      List<String> catIds = widget.catIds;
      if (widget.bookingRef != null) {
        try {
          final bookingDoc = await _firestore
              .collection('booking_requests')
              .doc(widget.bookingRef)
              .get();

          if (bookingDoc.exists) {
            final bookingData = bookingDoc.data();
            if (bookingData != null && bookingData.containsKey('catIds')) {
              catIds = List<String>.from(bookingData['catIds']);
              print("Using catIds from booking_request: $catIds");
            }
          }
        } catch (e) {
          print("Error fetching booking_request data: $e");
        }
      }

      // ดึงข้อมูลแมวที่มีสถานะ isForSitting เป็น true (ถ้า catIds ว่าง)
      if (catIds.isEmpty) {
        final catsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('cats')
            .where('isForSitting', isEqualTo: true)
            .get();

        catIds = catsSnapshot.docs.map((doc) => doc.id).toList();
        print("Using catIds from isForSitting: $catIds");
      }

      if (catIds.isEmpty) {
        throw Exception("กรุณาเลือกแมวที่ต้องการฝากเลี้ยง");
      }

      // ตรวจสอบยอดเงินในกระเป๋าเงินของผู้ใช้ - ทั้งจาก SharedPreferences และ Firestore
      double walletFromPrefs = 0;
      String? walletStrFromPrefs =
          await SharedPreferenceHelper().getUserWallet();
      if (walletStrFromPrefs != null && walletStrFromPrefs.isNotEmpty) {
        walletFromPrefs = double.tryParse(walletStrFromPrefs) ?? 0;
      }

      // ดีบัก: แสดงยอดเงินจาก SharedPreferences
      print("ยอดเงินจาก SharedPreferences: $walletFromPrefs");

      // ดึงข้อมูลจาก Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        // ถ้าไม่มีข้อมูลใน Firestore ให้ใช้ค่าจาก SharedPreferences
        if (walletFromPrefs < totalPrice) {
          throw Exception(
              "ยอดเงินในกระเป๋าไม่เพียงพอ กรุณาเติมเงิน (ยอดในกระเป๋า: $walletFromPrefs, ค่าบริการ: $totalPrice)");
        }

        // สร้างข้อมูล wallet ใน Firestore ถ้ายังไม่มี
        await _firestore.collection('users').doc(user.uid).set(
            {'wallet': walletFromPrefs.toStringAsFixed(0)},
            SetOptions(merge: true));

        // ใช้ค่าจาก SharedPreferences เป็นยอดปัจจุบัน
        double currentWallet = walletFromPrefs;
        double newWallet = currentWallet - totalPrice;
        String newWalletStr = newWallet.toStringAsFixed(0);

        // Using the BookingService to handle the transaction
        final bookingId = await _bookingService.createBooking(
            sitterId: widget.sitterId,
            dates: widget.selectedDates,
            totalPrice: totalPrice,
            notes: _notesController.text.trim(),
            catIds: catIds,
            currentWallet: currentWallet,
            newWallet: newWallet);

        // อัพเดตค่า wallet ใน SharedPreferences
        await SharedPreferenceHelper().saveUserWallet(newWalletStr);

        if (!mounted) return;

// Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'จองสำเร็จ หักเงินจากกระเป๋าเงินแล้ว ฿$totalPrice บาท (เหลือ ฿$newWalletStr)')),
        );

// Navigate to home screen instead of just popping
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => BottomNav()),
          (route) => false,
        );

        return;
      }

      // มีข้อมูลใน Firestore
      final userData = userDoc.data();
      String walletStr = userData?['wallet'] ?? "0";
      double walletFromFirestore = double.tryParse(walletStr) ?? 0;

      // ดีบัก: แสดงยอดเงินจาก Firestore
      print("ยอดเงินจาก Firestore: $walletFromFirestore");

      // ใช้ยอดเงินที่มากกว่าระหว่าง SharedPreferences และ Firestore
      // เพื่อป้องกันการสูญเสียเงินจากการซิงค์ข้อมูลผิดพลาด
      double currentWallet = walletFromFirestore > walletFromPrefs
          ? walletFromFirestore
          : walletFromPrefs;

      // ดีบัก: แสดงยอดเงินที่จะใช้
      print("ยอดเงินที่จะใช้ในการตรวจสอบ: $currentWallet");

      // ตรวจสอบว่ามีเงินเพียงพอหรือไม่
      if (currentWallet < totalPrice) {
        throw Exception(
            "ยอดเงินในกระเป๋าไม่เพียงพอ กรุณาเติมเงิน (ยอดในกระเป๋า: $currentWallet, ค่าบริการ: $totalPrice)");
      }

      // คำนวณยอดเงินใหม่หลังหักค่าบริการ
      double newWallet = currentWallet - totalPrice;
      String newWalletStr = newWallet.toStringAsFixed(0);

      // ดีบัก: แสดงยอดเงินคงเหลือหลังหักค่าบริการ
      print("ยอดเงินคงเหลือหลังหักค่าบริการ: $newWallet");

      // Using the BookingService to handle the transaction
      final bookingId = await _bookingService.createBooking(
          sitterId: widget.sitterId,
          dates: widget.selectedDates,
          totalPrice: totalPrice,
          notes: _notesController.text.trim(),
          catIds: catIds,
          currentWallet: currentWallet,
          newWallet: newWallet);

      // อัพเดตค่า wallet ใน SharedPreferences
      await SharedPreferenceHelper().saveUserWallet(newWalletStr);

      if (!mounted) return;

      // Show success message and navigate back
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'จองสำเร็จ หักเงินจากกระเป๋าเงินแล้ว ฿$totalPrice บาท (เหลือ ฿$newWalletStr)')),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => BottomNav()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ตรวจสอบว่าวันที่เลือกยังว่างอยู่
  Future<bool> _checkDateAvailability() async {
    try {
      final bookingSnapshot = await _firestore
          .collection('bookings')
          .where('sitterId', isEqualTo: widget.sitterId)
          .where('status', whereIn: ['pending', 'confirmed']).get();

      // ตรวจสอบการซ้ำซ้อนของวันที่
      for (var booking in bookingSnapshot.docs) {
        List<Timestamp> bookedDates = List<Timestamp>.from(booking['dates']);
        for (var bookedDate in bookedDates) {
          if (widget.selectedDates
              .any((date) => isSameDay(date, bookedDate.toDate()))) {
            return false;
          }
        }
      }
      return true;
    } catch (e) {
      print('Error checking availability: $e');
      return false;
    }
  }

  // เปรียบเทียบวันที่
  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Booking Details'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected Dates:',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8),
            // Display selected dates
            ...widget.selectedDates.map(
              (date) => Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(DateFormat('yyyy-MM-dd').format(date)),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Price per Day: \$${widget.pricePerDay}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Additional Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),

            SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _confirmBooking,
                child: _isLoading
                    ? CircularProgressIndicator()
                    : Text('Confirm Booking'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createBooking({
    required String sitterId,
    required List<DateTime> dates,
    required double totalPrice,
    required String notes,
    required List<String> catIds,
    required double currentWallet,
    required double newWallet,
  }) async {
    // Create a reference to a new document with auto-generated ID
    final bookingRef = _firestore.collection('bookings').doc();

    await bookingRef.set({
      'sitterId': sitterId,
      'dates': dates.map((date) => Timestamp.fromDate(date)).toList(),
      'totalPrice': totalPrice,
      'notes': notes,
      'catIds': catIds,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return bookingRef.id;
  }
}
