import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final Color tealColor = const Color(0xFF006666); 
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  
  String _selectedFilter = 'All';
  // 🟢 1. เปลี่ยนชื่อหมวดหมู่ตามที่คุณต้องการ
  final List<String> _filters = ['All', 'Pending', 'Accepted', 'Rejected', 'Cancelled'];

  Future<String> _getChatRoomName(String? offerId) async {
    if (offerId == null || offerId.isEmpty) return 'การแลกเปลี่ยน';
    try {
      final offerDoc = await FirebaseFirestore.instance.collection('offers').doc(offerId).get();
      if (!offerDoc.exists) return 'การแลกเปลี่ยน';

      final targetItemId = offerDoc.data()?['target_listing_id'];
      if (targetItemId == null) return 'การแลกเปลี่ยน';

      final itemDoc = await FirebaseFirestore.instance.collection('listings').doc(targetItemId).get();
      if (!itemDoc.exists) return 'สิ่งของถูกลบไปแล้ว';

      return itemDoc.data()?['title'] ?? 'การแลกเปลี่ยนสิ่งของ';
    } catch (e) {
      return 'การแลกเปลี่ยน';
    }
  }

  Future<void> _markAllAsRead(BuildContext context) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('chat_rooms')
          .where('participants', arrayContains: currentUserId)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      bool hasUpdates = false;

      for (var doc in querySnapshot.docs) {
        final room = doc.data() as Map<String, dynamic>;
        final List readBy = room['read_by'] ?? [];
        final String msgType = room['last_message_type'] ?? 'text';
        
        if (msgType != 'text' && !readBy.contains(currentUserId)) {
          batch.update(doc.reference, {
            'read_by': FieldValue.arrayUnion([currentUserId])
          });
          hasUpdates = true;
        }
      }

      if (hasUpdates) {
        await batch.commit(); 
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('อ่านการแจ้งเตือนทั้งหมดแล้ว'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: tealColor,
              margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  String _getTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final duration = DateTime.now().difference(timestamp.toDate());
    if (duration.inMinutes < 1) return 'Just now';
    if (duration.inMinutes < 60) return '${duration.inMinutes}m ago';
    if (duration.inHours < 24) return '${duration.inHours}h ago';
    if (duration.inDays < 7) return '${duration.inDays}d ago';
    return '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}';
  }

  // 🟢 2. เพิ่มสไตล์ให้ครอบคลุมสถานะ Rejected
  Map<String, dynamic> _getNotificationStyle(String type) {
    switch (type) {
      case 'system_offer':
        return {'icon': Icons.description_outlined, 'color': Colors.orange.shade400, 'title': 'Offer Pending', 'btn': 'Review Offer'};
      case 'system_counter':
        return {'icon': Icons.sync, 'color': Colors.blue.shade400, 'title': 'Counter Offer', 'btn': 'Review'};
      case 'system_accept': // 🟢 2. ปรับสไตล์ให้เข้ากับคำว่า Accepted
      case 'system_confirm':
        return {'icon': Icons.check_circle_outline, 'color': tealColor, 'title': 'Trade Accepted!', 'btn': 'View Details'};
      case 'system_reject':
        return {'icon': Icons.thumb_down_outlined, 'color': Colors.red.shade400, 'title': 'Offer Rejected', 'btn': 'View Details'};
      case 'system_cancel':
        return {'icon': Icons.cancel_outlined, 'color': Colors.grey.shade600, 'title': 'Deal Cancelled', 'btn': 'View Details'};
      default:
        return {'icon': Icons.notifications_outlined, 'color': Colors.grey, 'title': 'System Update', 'btn': 'View'};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), 
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF004D40), fontSize: 22)),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF004D40)),
        actions: [
          TextButton(
            onPressed: () => _markAllAsRead(context),
            child: const Text('Mark all as read', style: TextStyle(color: Color(0xFF006666), fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  bool isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedFilter = filter),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? tealColor : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? tealColor : Colors.grey.shade300),
                        ),
                        child: Text(
                          filter,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chat_rooms')
                  .where('participants', arrayContains: currentUserId)
                  .orderBy('updated_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล', style: TextStyle(color: Colors.red)));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                final rawDocs = snapshot.data!.docs;
                
                final notiDocs = rawDocs.where((doc) {
                  final room = doc.data() as Map<String, dynamic>;
                  final List readBy = room['read_by'] ?? [];
                  final String msgType = room['last_message_type'] ?? 'text'; 
                  
                  final bool isUnread = !readBy.contains(currentUserId);
                  
                  // 🟢 3. ถ้าอ่านแล้ว (ไม่เป็น Unread) ให้ซ่อนทิ้งไปเลย! (หายไปจากลิสต์)
                  if (!isUnread) return false; 
                  
                  if (msgType == 'text') return false; 
                  
                  if (_selectedFilter != 'All') {
                    if (_selectedFilter == 'Pending' && !(msgType == 'system_offer' || msgType == 'system_counter')) return false;
                    if (_selectedFilter == 'Accepted' && !(msgType == 'system_accept' || msgType == 'system_confirm')) return false;
                    if (_selectedFilter == 'Rejected' && msgType != 'system_reject') return false;
                    if (_selectedFilter == 'Cancelled' && msgType != 'system_cancel') return false;
                  }

                  return true; 
                }).toList();

                if (notiDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No notifications', style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notiDocs.length,
                  itemBuilder: (context, index) {
                    final room = notiDocs[index].data() as Map<String, dynamic>;
                    final String roomId = notiDocs[index].id;
                    final String lastMessage = room['last_message_text'] ?? 'มีการอัปเดตใหม่ในดีลนี้';
                    final String msgType = room['last_message_type'] ?? 'system_offer';
                    final Timestamp? time = room['updated_at'];
                    
                    final List readBy = room['read_by'] ?? [];
                    final bool isUnread = !readBy.contains(currentUserId);

                    final styleData = _getNotificationStyle(msgType);

                    return FutureBuilder<String>(
                      future: _getChatRoomName(room['active_offer_id']),
                      builder: (context, nameSnapshot) {
                        String itemName = nameSnapshot.data ?? '...';

                        return GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(roomId: roomId))),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isUnread ? Colors.white : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: isUnread ? [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))] : [],
                            ),
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    width: 4,
                                    decoration: BoxDecoration(
                                      color: isUnread ? styleData['color'] : Colors.transparent,
                                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16))
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: (styleData['color'] as Color).withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(styleData['icon'], color: styleData['color'], size: 24),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        styleData['title'],
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF004D40)),
                                                      ),
                                                    ),
                                                    Row(
                                                      children: [
                                                        Text(_getTimeAgo(time), style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                                        if (isUnread) ...[
                                                          const SizedBox(width: 6),
                                                          Container(width: 8, height: 8, decoration: BoxDecoration(color: tealColor, shape: BoxShape.circle)),
                                                        ]
                                                      ],
                                                    )
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'สำหรับสิ่งของ: $itemName\n$lastMessage',
                                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.4),
                                                  maxLines: 2, overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 12),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: (styleData['color'] as Color).withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8)
                                                  ),
                                                  child: Text(
                                                    styleData['btn'], 
                                                    style: TextStyle(color: styleData['color'], fontWeight: FontWeight.bold, fontSize: 12)
                                                  ),
                                                )
                                              ],
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}