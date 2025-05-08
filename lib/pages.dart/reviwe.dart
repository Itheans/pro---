import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class Review {
  final String id;
  final String userId;
  final double rating;
  final String comment;
  final DateTime timestamp;
  final String userName; // เพิ่มฟิลด์ userName
  final String userPhoto; // เพิ่มฟิลด์ userPhoto

  Review({
    required this.id,
    required this.userId,
    required this.rating,
    required this.comment,
    required this.timestamp,
    this.userName = '', // กำหนดค่าเริ่มต้น
    this.userPhoto = '', // กำหนดค่าเริ่มต้น
  });

  factory Review.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    if (data.isEmpty) {
      return Review(
        id: doc.id,
        userId: '',
        rating: 0.0,
        comment: 'ไม่มีข้อมูล',
        timestamp: DateTime.now(),
      );
    }

    DateTime timestamp = DateTime.now();
    try {
      if (data['timestamp'] is Timestamp) {
        timestamp = (data['timestamp'] as Timestamp).toDate();
      }
    } catch (e) {
      print('Error parsing timestamp: $e');
    }

    return Review(
      id: doc.id,
      userId: data['userId'] ?? '',
      rating:
          (data['rating'] is num) ? (data['rating'] as num).toDouble() : 0.0,
      comment: data['comment'] ?? '',
      timestamp: timestamp,
      userName: data['userName'] ?? '', // ดึงข้อมูล userName
      userPhoto: data['userPhoto'] ?? '', // ดึงข้อมูล userPhoto
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'rating': rating,
      'comment': comment,
      'timestamp': FieldValue.serverTimestamp(),
      'userName': userName, // เพิ่ม userName
      'userPhoto': userPhoto, // เพิ่ม userPhoto
    };
  }
}

class ReviewConstants {
  static const String collectionName = 'reviews';
  static const int pageSize = 10;
  static const double minRating = 1.0;
  static const int maxCommentLength = 500;
}

class ReviewsPage extends StatefulWidget {
  final String? itemId;
  String? sitterId;

  ReviewsPage({
    Key? key,
    this.itemId,
    this.sitterId,
  }) : super(key: key);

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  double _rating = 0;
  bool _isLoading = false;
  DocumentSnapshot? _lastDocument;
  List<Review> _reviews = [];
  double _averageRating = 0;
  String sitterName = '';
  String sitterPhoto = '';
  bool _hasFoundSitter = false;
  String? _currentItemId;
  bool _loadingReviews = false;

  @override
  void initState() {
    super.initState();
    _currentItemId = widget.itemId;

    if (widget.sitterId != null && widget.sitterId!.isNotEmpty) {
      _loadSitterData().then((_) {
        _initializeData();
        _setupScrollListener();
      });
    } else {
      _loadMatchedSitter().then((_) {
        if (_hasFoundSitter) {
          _initializeData();
          _setupScrollListener();
        }
      });
    }
  }

  Future<void> _loadReviews() async {
    try {
      setState(() => _loadingReviews = true);

      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection(ReviewConstants.collectionName)
          .where('sitterId', isEqualTo: widget.sitterId)
          .get();

      final reviews = snapshot.docs
          .map((doc) => Review.fromFirestore(doc))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (snapshot.docs.isNotEmpty) {
        final totalRating = snapshot.docs
            .map((doc) => (doc.get('rating') as num).toDouble())
            .fold<double>(0, (sum, rating) => sum + rating);

        setState(() {
          _reviews = reviews;
          _averageRating = totalRating / snapshot.docs.length;
          _loadingReviews = false;
        });
      } else {
        setState(() {
          _reviews = [];
          _averageRating = 0.0;
          _loadingReviews = false;
        });
      }
    } catch (e) {
      print('Error loading reviews: $e');
      setState(() => _loadingReviews = false);
    }
  }

  Future<void> _loadMatchedSitter() async {
    try {
      setState(() => _isLoading = true);

      // ดึงข้อมูลผู้ใช้ปัจจุบัน
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showErrorSnackBar('กรุณาเข้าสู่ระบบก่อนเข้าถึงหน้ารีวิว');
        setState(() => _isLoading = false);
        return;
      }

      // ค้นหาการจองทั้งหมดของผู้ใช้ (ไม่เรียงลำดับหรือมีเงื่อนไขซับซ้อน)
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      // จัดเรียงข้อมูลหลังจากได้รับมาแล้ว
      final completedBookings = bookingsSnapshot.docs
          .where((doc) =>
              (doc.data() as Map<String, dynamic>)['status'] == 'completed')
          .toList();

      completedBookings.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;

        final aTime = aData['createdAt'] as Timestamp?;
        final bTime = bData['createdAt'] as Timestamp?;

        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;

        return bTime.compareTo(aTime); // เรียงจากใหม่ไปเก่า
      });

      // หากพบการจองที่เสร็จสิ้น
      if (completedBookings.isNotEmpty) {
        final bookingData =
            completedBookings.first.data() as Map<String, dynamic>;
        if (bookingData.containsKey('sitterId') &&
            bookingData['sitterId'] != null &&
            bookingData['sitterId'].toString().isNotEmpty) {
          setState(() {
            widget.sitterId = bookingData['sitterId'];
            if (_currentItemId == null) {
              _currentItemId = completedBookings.first.id;
            }
            _hasFoundSitter = true;
          });
          await _loadSitterData();
          return;
        }
      }

      // ถ้าไม่พบในคอลเลกชัน bookings ให้ตรวจสอบใน booking_requests แบบเดียวกัน
      final requestsSnapshot = await FirebaseFirestore.instance
          .collection('booking_requests')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      // ประมวลผลเช่นเดียวกัน...
      final completedRequests = requestsSnapshot.docs
          .where((doc) =>
              (doc.data() as Map<String, dynamic>)['status'] == 'completed')
          .toList();

      completedRequests.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;

        final aTime = aData['createdAt'] as Timestamp?;
        final bTime = bData['createdAt'] as Timestamp?;

        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;

        return bTime.compareTo(aTime);
      });

      if (completedRequests.isEmpty) {
        _showErrorSnackBar(
            'ไม่พบประวัติการฝากเลี้ยง กรุณาใช้บริการฝากเลี้ยงแมวก่อนเขียนรีวิว');
        setState(() => _isLoading = false);
        return;
      }

      // ดึง sitterId จากการจอง
      final requestData =
          completedRequests.first.data() as Map<String, dynamic>;
      if (requestData.containsKey('sitterId') &&
          requestData['sitterId'] != null &&
          requestData['sitterId'].toString().isNotEmpty) {
        setState(() {
          widget.sitterId = requestData['sitterId'];
          if (_currentItemId == null) {
            _currentItemId = completedRequests.first.id;
          }
          _hasFoundSitter = true;
        });
        await _loadSitterData();
      } else {
        _showErrorSnackBar('ไม่พบข้อมูลผู้รับเลี้ยง');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading matched sitter: $e');
      _showErrorSnackBar('เกิดข้อผิดพลาดในการโหลดข้อมูลผู้รับเลี้ยง: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSitterData() async {
    try {
      if (widget.sitterId == null || widget.sitterId!.isEmpty) {
        setState(() {
          sitterName = 'ไม่พบข้อมูลผู้รับเลี้ยง';
          _isLoading = false;
        });
        return;
      }

      final sitterDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.sitterId)
          .get();

      if (sitterDoc.exists) {
        final sitterData = sitterDoc.data();
        if (sitterData != null) {
          setState(() {
            sitterName = sitterData['name'] ?? 'ไม่ระบุชื่อ';
            sitterPhoto = sitterData['photo'] ?? '';
            _isLoading = false;
            _hasFoundSitter = true;
          });

          _initializeData();
        } else {
          setState(() {
            sitterName = 'ข้อมูลผู้รับเลี้ยงไม่สมบูรณ์';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          sitterName = 'ไม่พบข้อมูลผู้รับเลี้ยง';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading sitter data: $e');
      setState(() {
        sitterName = 'เกิดข้อผิดพลาดในการโหลดข้อมูล';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        _loadMoreReviews();
      }
    });
  }

  Future<void> _loadMoreReviews() async {
    if (_isLoading || _lastDocument == null) return;
    if (widget.sitterId == null || widget.sitterId!.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      // ใช้การค้นหาเรียบง่าย
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection(ReviewConstants.collectionName)
          .where('sitterId', isEqualTo: widget.sitterId)
          .get();

      // จัดเรียงและเลือกเฉพาะข้อมูลที่ต้องการ (ที่มาหลัง lastDocument)
      final allReviews =
          snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList();
      allReviews.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // ค้นหาตำแหน่งของข้อมูลล่าสุดที่โหลดไปแล้ว
      int lastIndex = -1;
      for (int i = 0; i < allReviews.length; i++) {
        if (allReviews[i].id == _lastDocument!.id) {
          lastIndex = i;
          break;
        }
      }

      if (lastIndex != -1 && lastIndex + 1 < allReviews.length) {
        // เลือกข้อมูลเพิ่มเติม
        final nextReviews = allReviews
            .sublist(lastIndex + 1)
            .take(ReviewConstants.pageSize)
            .toList();

        setState(() {
          _reviews.addAll(nextReviews);
          if (nextReviews.isNotEmpty) {
            // หาและเก็บข้อมูล document สุดท้าย
            final lastReviewId = nextReviews.last.id;
            _lastDocument =
                snapshot.docs.firstWhere((doc) => doc.id == lastReviewId);
          }
        });
      }
    } catch (e) {
      print('Error loading more reviews: $e');
      _showErrorSnackBar('เกิดข้อผิดพลาดในการโหลดรีวิวเพิ่มเติม: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initializeData() async {
    try {
      await Future.wait([
        _loadInitialReviews(),
        _calculateAverageRating(),
      ]);
    } catch (e) {
      _showErrorSnackBar('Error loading reviews: $e');
    }
  }

  Future<void> _loadInitialReviews() async {
    setState(() => _isLoading = true);
    try {
      // ตรวจสอบว่ามี sitterId หรือไม่
      if (widget.sitterId == null || widget.sitterId!.isEmpty) {
        setState(() {
          _isLoading = false;
          _reviews = [];
        });
        return;
      }

      // ใช้เพียง where เดียวเพื่อหลีกเลี่ยงปัญหา index
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection(ReviewConstants.collectionName)
          .where('sitterId', isEqualTo: widget.sitterId)
          .get();

      // จัดเรียงและจำกัดจำนวนหลังจากได้รับข้อมูลแล้ว
      final allReviews =
          snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList();
      allReviews.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      final limitedReviews = allReviews.take(ReviewConstants.pageSize).toList();

      setState(() {
        _reviews = limitedReviews;
        if (snapshot.docs.isNotEmpty) {
          _lastDocument = snapshot.docs[limitedReviews.length - 1];
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading reviews: $e');
      _showErrorSnackBar('เกิดข้อผิดพลาดในการโหลดรีวิว: $e');
      setState(() => _isLoading = false);
    }
  }

  void _processQuerySnapshot(QuerySnapshot snapshot) {
    final newReviews =
        snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList();

    setState(() {
      _reviews.addAll(newReviews);
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }
    });
  }

  Future<void> _calculateAverageRating() async {
    try {
      if (widget.sitterId == null || widget.sitterId!.isEmpty) {
        setState(() => _averageRating = 0);
        return;
      }

      // ใช้การค้นหาอย่างง่าย
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection(ReviewConstants.collectionName)
          .where('sitterId', isEqualTo: widget.sitterId)
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() => _averageRating = 0);
        return;
      }

      double totalRating = 0;
      int validRatings = 0;

      // คำนวณคะแนนเฉลี่ยด้วยตัวเอง
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          if (data.containsKey('rating') && data['rating'] is num) {
            totalRating += (data['rating'] as num).toDouble();
            validRatings++;
          }
        } catch (e) {
          print('Error processing rating: $e');
        }
      }

      setState(() {
        _averageRating = validRatings > 0 ? totalRating / validRatings : 0;
      });
    } catch (e) {
      print('Error calculating average rating: $e');
      setState(() => _averageRating = 0);
    }
  }

  Future<void> _addReview() async {
    if (!_validateReview()) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showErrorSnackBar('กรุณาเข้าสู่ระบบเพื่อเขียนรีวิว');
        return;
      }

      if (widget.sitterId == null || widget.sitterId!.isEmpty) {
        _showErrorSnackBar('ไม่พบข้อมูลผู้รับเลี้ยง');
        return;
      }

      setState(() => _isLoading = true);

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('ไม่พบข้อมูลผู้ใช้');
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final userName = userData['name'] ?? 'ผู้ใช้งาน';
      final userPhoto = userData['photo'] ?? '';

      final newReview = {
        'userId': currentUser.uid,
        'userName': userName, // บันทึกชื่อผู้ใช้
        'userPhoto': userPhoto, // บันทึกรูปโปรไฟล์ผู้ใช้
        'sitterId': widget.sitterId,
        'rating': _rating,
        'comment': _commentController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (_currentItemId != null && _currentItemId!.isNotEmpty) {
        newReview['bookingId'] = _currentItemId;
      }

      final docRef = await FirebaseFirestore.instance
          .collection(ReviewConstants.collectionName)
          .add(newReview);

      if (_currentItemId != null && _currentItemId!.isNotEmpty) {
        final bookingDoc = await FirebaseFirestore.instance
            .collection('bookings')
            .doc(_currentItemId)
            .get();

        if (bookingDoc.exists) {
          await FirebaseFirestore.instance
              .collection('bookings')
              .doc(_currentItemId)
              .update({'reviewed': true});
        } else {
          final requestDoc = await FirebaseFirestore.instance
              .collection('booking_requests')
              .doc(_currentItemId)
              .get();

          if (requestDoc.exists) {
            await FirebaseFirestore.instance
                .collection('booking_requests')
                .doc(_currentItemId)
                .update({'reviewed': true});
          }
        }
      }

      _resetForm();
      await _initializeData();
      _showSuccessSnackBar('เพิ่มรีวิวเรียบร้อยแล้ว');
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการเพิ่มรีวิว: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _validateReview() {
    if (_rating < ReviewConstants.minRating) {
      _showErrorSnackBar('กรุณาให้คะแนน');
      return false;
    }

    final comment = _commentController.text.trim();
    if (comment.isEmpty) {
      _showErrorSnackBar('กรุณาเขียนความคิดเห็น');
      return false;
    }

    if (comment.length > ReviewConstants.maxCommentLength) {
      _showErrorSnackBar('ความคิดเห็นยาวเกินไป');
      return false;
    }

    return true;
  }

  void _resetForm() {
    setState(() {
      _rating = 0;
      _commentController.clear();
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'รีวิวบริการ',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.orange,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _initializeData,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.orange.shade50, Colors.white],
            ),
          ),
          child: _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.orange),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'กำลังโหลดข้อมูล...',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : !_hasFoundSitter
                  ? _buildNoSitterFoundWidget()
                  : ListView(
                      children: [
                        _buildSitterInfo(),
                        _buildAverageRatingCard(),
                        _loadingReviews
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : (_reviews.isEmpty
                                ? _buildEmptyReviewsWidget()
                                : Column(
                                    children: _reviews
                                        .map((review) =>
                                            _buildReviewCard(review))
                                        .toList(),
                                  )),
                        if (_hasFoundSitter) _buildAddReviewForm(),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildNoSitterFoundWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'ไม่พบข้อมูลผู้รับเลี้ยงแมว',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'กรุณาเลือกผู้รับเลี้ยงแมวจากหน้าประวัติการฝากเลี้ยง',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back),
            label: Text('กลับไปหน้าก่อนหน้า'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSitterInfo() {
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: widget.sitterId == null || widget.sitterId!.isEmpty
            ? Center(
                child: Text(
                  'ไม่พบข้อมูลผู้รับเลี้ยง',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.orange.shade100,
                        backgroundImage: sitterPhoto.isNotEmpty
                            ? NetworkImage(sitterPhoto)
                            : null,
                        child: sitterPhoto.isEmpty
                            ? const Icon(Icons.person,
                                size: 30, color: Colors.orange)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sitterName.isEmpty ? 'ไม่ระบุชื่อ' : sitterName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ผู้รับเลี้ยงแมว',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyReviewsWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.rate_review_outlined,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'ยังไม่มีรีวิว\nเป็นคนแรกที่รีวิวผู้รับเลี้ยงคนนี้!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAverageRatingCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'คะแนนเฉลี่ย',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _averageRating.isNaN
                      ? '0.0'
                      : _averageRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.star,
                  color: Colors.amber,
                  size: 36,
                ),
              ],
            ),
            Text(
              '(${_reviews.length} รีวิว)',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _reviews.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _reviews.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            ),
          );
        }

        final review = _reviews[index];
        return _buildReviewCard(review);
      },
    );
  }

  Widget _buildReviewCard(Review review) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // แสดงรูปโปรไฟล์ผู้ใช้
                CircleAvatar(
                  backgroundColor: Colors.orange.shade100,
                  backgroundImage: review.userPhoto.isNotEmpty
                      ? NetworkImage(review.userPhoto)
                      : null,
                  child: review.userPhoto.isEmpty
                      ? const Icon(Icons.person, color: Colors.orange)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // แสดงชื่อผู้ใช้ หรือ ID บางส่วนถ้าไม่มีชื่อ
                        review.userName.isNotEmpty
                            ? review.userName
                            : 'ผู้ใช้ ${review.userId.length > 5 ? review.userId.substring(0, 5) : review.userId}...',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      RatingBarIndicator(
                        rating: review.rating,
                        itemBuilder: (context, _) => const Icon(
                          Icons.star,
                          color: Colors.amber,
                        ),
                        itemCount: 5,
                        itemSize: 20,
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatDate(review.timestamp),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                review.comment,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddReviewForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'เขียนรีวิว',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: RatingBar.builder(
              initialRating: _rating,
              minRating: ReviewConstants.minRating,
              direction: Axis.horizontal,
              itemCount: 5,
              itemBuilder: (context, _) => const Icon(
                Icons.star,
                color: Colors.amber,
              ),
              onRatingUpdate: (rating) {
                setState(() {
                  _rating = rating;
                });
              },
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            decoration: InputDecoration(
              hintText: 'แชร์ประสบการณ์ของคุณ...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.orange, width: 2),
              ),
              counterText:
                  '${_commentController.text.length}/${ReviewConstants.maxCommentLength}',
            ),
            maxLines: 3,
            maxLength: ReviewConstants.maxCommentLength,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _addReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'ส่งรีวิว',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} นาทีที่แล้ว';
      }
      return '${difference.inHours} ชั่วโมงที่แล้ว';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} วันที่แล้ว';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
