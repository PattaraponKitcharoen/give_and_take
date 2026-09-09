import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/auth_repository.dart';
import '../cubits/chat_list/chat_list_cubit.dart';
import '../cubits/chat_list/chat_list_state.dart';
import '../repositories/chat_repository.dart';
import '../models/chat_room_model.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  String get currentUserId => context.read<AuthRepository>().currentUser?.uid ?? '';
  final Color tealColor = const Color(0xFF008080);
  
  String _selectedFilter = 'All'; // ตัวกรองสถานะแชท

  String _formatTimestamp(DateTime? date) {
    if (date == null) return '';
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
    return BlocProvider(
      create: (context) => ChatListCubit(repository: context.read<ChatRepository>())..listenToChatRooms(currentUserId),
      child: Scaffold(
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
              child: BlocBuilder<ChatListCubit, ChatListState>(
                builder: (context, state) {
                  if (state is ChatListInitial || state is ChatListLoading) {
                    return Center(child: CircularProgressIndicator(color: tealColor));
                  }
                  if (state is ChatListError) {
                    return Center(child: Text('เกิดข้อผิดพลาด:\n${state.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)));
                  }
                  if (state is ChatListLoaded) {
                    List<ChatListItem> items = state.items;

                    if (_selectedFilter == 'Unread') {
                      items = items.where((item) => item.isUnread).toList();
                    } else if (_selectedFilter == 'Completed') {
                      items = items.where((item) => item.status == 'completed').toList();
                    } else if (_selectedFilter == 'Active Trades') {
                      items = items.where((item) => item.status != 'completed' && item.status != 'rejected' && item.status != 'cancelled' && item.status.isNotEmpty).toList();
                    }

                    if (items.isEmpty) return const Center(child: Text('ไม่พบแชทในหมวดหมู่นี้', style: TextStyle(color: Colors.grey)));

                    return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final String roomId = item.room.id;
                        final String? offerId = item.room.activeOfferId;
                        
                        final String lastMessage = item.room.lastMessageText.isEmpty ? 'เริ่มการสนทนาได้เลย' : item.room.lastMessageText;
                        final String timeString = _formatTimestamp(item.room.updatedAt);
                        final String title = item.title;
                        final String status = item.status;
                        final String thumbnail = item.thumbnail;
                        final bool isUnread = item.isUnread;

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
                            final cubit = context.read<ChatListCubit>();
                            bool canDelete = await cubit.canDeleteChatRoom(offerId, currentUserId);
                            
                            if (!canDelete) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: const Text('ไม่สามารถลบห้องสนทนานี้ได้'), behavior: SnackBarBehavior.floating, margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16), backgroundColor: Colors.orange.shade800)
                                );
                              }
                              return false;
                            }
                            
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
                            ) ?? false;

                            return confirmDelete; 
                          },
                          onDismissed: (direction) async {
                            context.read<ChatListCubit>().removeMember(roomId, currentUserId);
                          },
                          child: InkWell(
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
                          ),
                        );
                      },
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
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