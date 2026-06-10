import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final Color tealColor = const Color(0xFF008080);
  
  String _selectedFilter = 'All'; // ตัวกรองสถานะแชท

  // 🟢 เพิ่มฟังก์ชันกรองข้อมูลแชทตามแท็บที่เลือก
  Future<List<DocumentSnapshot>> _filterDocs(List<DocumentSnapshot> rawDocs) async {
    if (_selectedFilter == 'All') return rawDocs;

    // กรองแท็บ Unread
    if (_selectedFilter == 'Unread') {
      return rawDocs.where((doc) {
        final room = doc.data() as Map<String, dynamic>;
        final List readBy = room['read_by'] ?? [];
        return !readBy.contains(currentUserId) && room['last_message_text'] != null;
      }).toList();
    }

    // กรองแท็บ Active Trades และ Completed
    List<DocumentSnapshot> filtered = [];
    for (var doc in rawDocs) {
      final room = doc.data() as Map<String, dynamic>;
      final String? offerId = room['active_offer_id'];
      
      String status = '';
      if (offerId != null && offerId.isNotEmpty) {
        try {
          final offerDoc = await FirebaseFirestore.instance.collection('offers').doc(offerId).get();
          if (offerDoc.exists) status = offerDoc.data()?['status'] ?? '';
        } catch (e) {
          debugPrint('Error fetching offer status: $e');
        }
      }

      if (_selectedFilter == 'Completed') {
        if (status == 'completed') filtered.add(doc);
      } else if (_selectedFilter == 'Active Trades') {
        // Active คือสถานะที่ยังไม่จบ (ไม่ใช่ completed, rejected, cancelled)
        if (status != 'completed' && status != 'rejected' && status != 'cancelled') {
          filtered.add(doc);
        }
      }
    }
    return filtered;
  }

  Future<Map<String, dynamic>> _getRoomDetails(String? offerId) async {
    Map<String, dynamic> result = {
      'title': 'ห้องแชทส่วนตัว',
      'status': '',
      'thumbnail': ''
    };

    if (offerId == null || offerId.isEmpty) return result;

    try {
      final offerDoc = await FirebaseFirestore.instance.collection('offers').doc(offerId).get();
      if (!offerDoc.exists) {
        result['title'] = 'ห้องแชท (ไม่พบข้อเสนอ)';
        return result;
      }

      final data = offerDoc.data()!;
      result['status'] = data['status'] ?? '';
      
      String targetId = data['target_listing_id'] ?? '';
      String offeredId = data['offered_listing_id'] ?? '';
      String senderId = data['sender_id'] ?? '';
      
      // 🟢 สลับการดึงข้อมูลสิ่งของให้แสดง "ของฝ่ายตรงข้าม"
      String itemToShowId = (currentUserId == senderId) ? targetId : offeredId;
      if (itemToShowId.isEmpty) itemToShowId = targetId;
      
      if (itemToShowId.isNotEmpty) {
        final itemDoc = await FirebaseFirestore.instance.collection('listings').doc(itemToShowId).get();
        if (itemDoc.exists) {
          result['title'] = itemDoc.data()?['title'] ?? 'ไม่มีชื่อสิ่งของ';
          result['thumbnail'] = itemDoc.data()?['thumbnail_url'] ?? '';
        } else {
          result['title'] = 'สิ่งของถูกลบไปแล้ว';
        }
      }
    } catch (e) {
      result['title'] = 'ห้องแชท';
    }
    return result;
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0 && date.day == now.day) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1 || (diff.inDays == 0 && date.day != now.day)) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Messages', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          _buildFilterTabs(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('ACTIVE NEGOTIATIONS', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chat_rooms')
                  .where('participants', arrayContains: currentUserId)
                  .orderBy('updated_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('เกิดข้อผิดพลาด:\n${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)));
                if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: tealColor));

                final rawDocs = snapshot.data!.docs;
                if (rawDocs.isEmpty) return const Center(child: Text('ยังไม่มีรายการสนทนา', style: TextStyle(color: Colors.grey)));

                // 🟢 ใช้ FutureBuilder มารอผลการกรองข้อมูลก่อนวาด ListView
                return FutureBuilder<List<DocumentSnapshot>>(
                  future: _filterDocs(rawDocs),
                  builder: (context, filterSnap) {
                    if (filterSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final filteredDocs = filterSnap.data ?? [];
                    if (filteredDocs.isEmpty) return const Center(child: Text('ไม่พบแชทในหมวดหมู่นี้', style: TextStyle(color: Colors.grey)));

                    return ListView.builder(
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final room = filteredDocs[index].data() as Map<String, dynamic>;
                        final String roomId = filteredDocs[index].id;
                        final String? offerId = room['active_offer_id'];
                        
                        final String lastMessage = room['last_message_text'] ?? 'เริ่มการสนทนาได้เลย';
                        final List readBy = room['read_by'] ?? [];
                        final bool isUnread = !readBy.contains(currentUserId) && room['last_message_text'] != null;
                        final String timeString = _formatTimestamp(room['updated_at'] as Timestamp?);

                        return Dismissible(
                          key: Key(roomId),
                          direction: DismissDirection.endToStart, 
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red.shade400,
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          confirmDismiss: (direction) async {
                            // 1. เช็กเงื่อนไขก่อนว่า "สถานะของแชทนี้อนุญาตให้ลบได้ไหม"
                            if (offerId != null && offerId.isNotEmpty) {
                              try {
                                final offerDoc = await FirebaseFirestore.instance.collection('offers').doc(offerId).get();
                                
                                if (offerDoc.exists) {
                                  final status = offerDoc.data()?['status'] ?? '';
                                  if (status == 'completed') {
                                    bool hasReviewed = false;
                                    final txSnap = await FirebaseFirestore.instance.collection('transactions').where('offer_id', isEqualTo: offerId).limit(1).get();
                                    if (txSnap.docs.isNotEmpty) {
                                      final txId = txSnap.docs.first.id;
                                      final reviewSnap = await FirebaseFirestore.instance.collection('reviews')
                                          .where('transaction_id', isEqualTo: txId)
                                          .where('reviewer_id', isEqualTo: currentUserId)
                                          .get();
                                      if (reviewSnap.docs.isNotEmpty) hasReviewed = true;
                                    } else {
                                      final reviewSnap = await FirebaseFirestore.instance.collection('reviews')
                                          .where('offer_id', isEqualTo: offerId)
                                          .where('reviewer_id', isEqualTo: currentUserId)
                                          .get();
                                      if (reviewSnap.docs.isNotEmpty) hasReviewed = true;
                                    }

                                    if (!hasReviewed) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: const Text('คุณยังไม่ได้รีวิวการแลกเปลี่ยนนี้'), behavior: SnackBarBehavior.floating, margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16), backgroundColor: Colors.orange.shade800)
                                        );
                                      }
                                      return false; // ไม่ให้ลบ
                                    }
                                  } else if (status != 'rejected' && status != 'cancelled') {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: const Text('การแลกเปลี่ยนยังไม่สมบูรณ์'), behavior: SnackBarBehavior.floating, margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16), backgroundColor: Colors.red)
                                      );
                                    }
                                    return false; // ไม่ให้ลบ
                                  }
                                }
                              } catch (e) { 
                                return false; // ถ้ามี Error ดักไว้ไม่ให้เผลอลบ
                              }
                            }
                            
                            // 2. ถ้าผ่านด่านด้านบนมาได้ (อนุญาตให้ลบได้) ให้เปิด Popup ถามยืนยัน
                            if (!context.mounted) return false;
                            
                            bool confirmDelete = await showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('ยืนยันการลบแชท', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                  content: const Text('คุณแน่ใจหรือไม่ว่าต้องการลบห้องสนทนานี้?\nข้อมูลทั้งหมดจะหายไปและไม่สามารถกู้คืนได้'),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      child: const Text('ลบทิ้ง', style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                );
                              },
                            ) ?? false; // ถ้ากดข้างนอกถือว่ายกเลิก

                            return confirmDelete; 
                          },
                          onDismissed: (direction) async {
                            await FirebaseFirestore.instance.collection('chat_rooms').doc(roomId).update({
                              'participants': FieldValue.arrayRemove([currentUserId])
                            });
                          },
                          child: FutureBuilder<Map<String, dynamic>>(
                            future: _getRoomDetails(offerId),
                            builder: (context, detailsSnap) {
                              String title = 'กำลังโหลด...';
                              String status = '';
                              String thumbnail = '';

                              if (detailsSnap.hasData) {
                                title = detailsSnap.data!['title'];
                                status = detailsSnap.data!['status'];
                                thumbnail = detailsSnap.data!['thumbnail'];
                              }

                              return InkWell(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(roomId: roomId))),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 50, height: 50,
                                        decoration: BoxDecoration(
                                          color: tealColor,
                                          shape: BoxShape.circle,
                                          image: thumbnail.isNotEmpty ? DecorationImage(image: NetworkImage(thumbnail), fit: BoxFit.cover) : null,
                                        ),
                                        child: thumbnail.isEmpty ? const Icon(Icons.inventory, color: Colors.white) : null,
                                      ),
                                      const SizedBox(width: 12),
                                      
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(title, style: TextStyle(fontWeight: isUnread ? FontWeight.bold : FontWeight.w600, fontSize: 16, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            const SizedBox(height: 4),
                                            Text(lastMessage, style: TextStyle(color: isUnread ? Colors.black87 : Colors.grey.shade600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            const SizedBox(height: 8),
                                            if (status.isNotEmpty) _buildStatusBadge(status),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(timeString, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                          const SizedBox(height: 8),
                                          if (isUnread)
                                            Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))
                                          else
                                            Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade400),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              );
                            }
                          ),
                        );
                      },
                    );
                  }
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(24)),
        child: TextField(
          decoration: InputDecoration(
            icon: Icon(Icons.search, color: Colors.grey.shade500),
            hintText: 'Search conversations...',
            hintStyle: TextStyle(color: Colors.grey.shade500),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    final filters = ['All', 'Unread', 'Active Trades', 'Completed'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: filters.map((filter) {
          bool isSelected = _selectedFilter == filter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? tealColor : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? tealColor : Colors.grey.shade300),
              ),
              child: Text(
                filter, 
                style: TextStyle(color: isSelected ? Colors.white : Colors.blueGrey, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontSize: 13)
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    IconData icon;
    String text;

    if (status == 'completed') {
      bgColor = Colors.green.shade50; textColor = Colors.green.shade700; icon = Icons.check_circle; text = 'Trade Accepted';
    } else if (status == 'in_negotiation') {
      bgColor = Colors.blueGrey.shade50; textColor = Colors.blueGrey.shade700; icon = Icons.access_time; text = 'Negotiating';
    } else {
      bgColor = Colors.teal.shade50; textColor = tealColor; icon = Icons.swap_horiz; text = 'Offer Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}