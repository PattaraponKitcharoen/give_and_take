import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/user_profile_screen.dart'; 

class ChatBubbleWidget extends StatefulWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  final String timeStr;
  final bool showTimeByDefault;
  final bool showAvatar;
  final bool isLatestRead;

  const ChatBubbleWidget({
    super.key, required this.msg, required this.isMe, required this.timeStr,
    required this.showTimeByDefault, required this.showAvatar, required this.isLatestRead,
  });

  @override
  State<ChatBubbleWidget> createState() => _ChatBubbleWidgetState();
}

class _ChatBubbleWidgetState extends State<ChatBubbleWidget> {
  bool _isTapped = false; 

  @override
  Widget build(BuildContext context) {
    bool showTime = widget.showTimeByDefault || _isTapped;
    
    if (widget.isMe) {
      return Padding(
        padding: EdgeInsets.only(right: 16, left: 60, top: 2, bottom: widget.showTimeByDefault ? 8 : 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: () => setState(() => _isTapped = !_isTapped),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF008080),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                    bottomLeft: const Radius.circular(16), bottomRight: Radius.circular(widget.showTimeByDefault ? 4 : 16),
                  ),
                ),
                child: Text(widget.msg['content'], style: const TextStyle(color: Colors.white, fontSize: 14)),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (showTime) 
                    Padding(padding: const EdgeInsets.only(top: 4), child: Text(widget.timeStr, style: TextStyle(color: Colors.grey.shade500, fontSize: 10))),
                  
                  if (widget.isLatestRead)
                    Padding(
                      padding: const EdgeInsets.only(top: 2), 
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.done_all, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 2),
                          Text('อ่านแล้ว', style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ),
                ],
              ),
            )
          ]
        )
      );
    } else {
      return Padding(
        padding: EdgeInsets.only(left: 16, right: 60, top: 2, bottom: widget.showTimeByDefault ? 8 : 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (widget.showAvatar) ...[
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfileScreen(userId: widget.msg['sender_id']))),
                child: FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(widget.msg['sender_id']).get(),
                  builder: (context, userSnap) {
                    String profileImg = '';
                    if (userSnap.hasData && userSnap.data!.exists) profileImg = (userSnap.data!.data() as Map<String, dynamic>)['profile_img_url'] ?? '';
                    return CircleAvatar(
                      radius: 14, backgroundColor: Colors.grey.shade300,
                      backgroundImage: profileImg.isNotEmpty ? NetworkImage(profileImg) : null,
                      child: profileImg.isEmpty ? const Icon(Icons.person, size: 14, color: Colors.white) : null,
                    );
                  }
                ),
              ),
            ] else ...[
              const SizedBox(width: 28), 
            ],
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _isTapped = !_isTapped),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100, border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                          bottomRight: const Radius.circular(16), bottomLeft: Radius.circular(widget.showTimeByDefault ? 4 : 16),
                        ),
                      ),
                      child: Text(widget.msg['content'], style: const TextStyle(color: Colors.black87, fontSize: 14)),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: showTime 
                      ? Padding(padding: const EdgeInsets.only(top: 4), child: Text(widget.timeStr, style: TextStyle(color: Colors.grey.shade500, fontSize: 10)))
                      : const SizedBox.shrink(),
                  )
                ]
              )
            )
          ]
        )
      );
    }
  }
}