import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/auth_repository.dart';
import '../cubits/chat_list/chat_list_cubit.dart';
import '../cubits/chat_list/chat_list_state.dart';
import '../repositories/chat_repository.dart';
import '../models/chat_room_model.dart';
import 'chat_screen.dart';
import '../theme/app_theme.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  String get currentUserId =>
      context.read<AuthRepository>().currentUser?.uid ?? '';
  final Color tealColor = AppColors.primary;

  String _selectedFilter = 'All'; // ตัวกรองสถานะแชท

  // Search lives behind the magnifier in the header; tapping it expands a
  // field over the title, closing it clears the query.
  bool _searching = false;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _searching = true);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _searchFocus.requestFocus());
  }

  void _closeSearch() {
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() {
      _searching = false;
      _query = '';
    });
  }

  Widget _buildHeaderTitle() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      // The field grows out from the right, where the magnifier was.
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(
          sizeFactor: animation,
          axis: Axis.horizontal,
          axisAlignment: 1,
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerRight,
        children: [...previous, if (current != null) current],
      ),
      child: _searching
          ? Container(
              key: const ValueKey('search'),
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.hairline),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded,
                      size: 20, color: AppColors.inkSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      style: AppText.body,
                      textInputAction: TextInputAction.search,
                      onChanged: (v) => setState(() => _query = v.trim()),
                      decoration: const InputDecoration(
                        hintText: 'Search conversations...',
                        isDense: true,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const Align(
              key: ValueKey('title'),
              alignment: Alignment.centerLeft,
              child: Text('Messages', style: AppText.title),
            ),
    );
  }

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
      create: (context) =>
          ChatListCubit(repository: context.read<ChatRepository>())
            ..listenToChatRooms(currentUserId),
      child: Scaffold(
        appBar: AppBar(
          title: _buildHeaderTitle(),
          centerTitle: false,
          titleSpacing: AppSpace.page,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                onPressed: _searching ? _closeSearch : _openSearch,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, a) => RotationTransition(
                      turns: Tween(begin: 0.75, end: 1.0).animate(a),
                      child: FadeTransition(opacity: a, child: child)),
                  child: Icon(
                    _searching ? Icons.close_rounded : Icons.search_rounded,
                    key: ValueKey(_searching),
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilterTabs(),
            const Padding(
              padding: EdgeInsets.fromLTRB(AppSpace.page, 16, AppSpace.page, 8),
              child: Text('ACTIVE NEGOTIATIONS', style: AppText.overline),
            ),
            Expanded(
              child: BlocBuilder<ChatListCubit, ChatListState>(
                builder: (context, state) {
                  if (state is ChatListInitial || state is ChatListLoading) {
                    return Center(
                        child: CircularProgressIndicator(color: tealColor));
                  }
                  if (state is ChatListError) {
                    return Center(
                        child: Text('เกิดข้อผิดพลาด:\n${state.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.danger)));
                  }
                  if (state is ChatListLoaded) {
                    List<ChatListItem> items = state.items;

                    if (_selectedFilter == 'Unread') {
                      items = items.where((item) => item.isUnread).toList();
                    } else if (_selectedFilter == 'Completed') {
                      items = items
                          .where((item) => item.status == 'completed')
                          .toList();
                    } else if (_selectedFilter == 'Active Trades') {
                      items = items
                          .where((item) =>
                              item.status != 'completed' &&
                              item.status != 'rejected' &&
                              item.status != 'cancelled' &&
                              item.status.isNotEmpty)
                          .toList();
                    }

                    if (_query.isNotEmpty) {
                      final q = _query.toLowerCase();
                      items = items
                          .where((item) =>
                              item.title.toLowerCase().contains(q) ||
                              item.room.lastMessageText
                                  .toLowerCase()
                                  .contains(q))
                          .toList();
                    }

                    if (items.isEmpty)
                      return const Center(
                          child: Text('ไม่พบแชทในหมวดหมู่นี้',
                              style: TextStyle(color: AppColors.inkTertiary)));

                    return ListView.builder(
                      padding: EdgeInsets.only(
                          top: 4,
                          bottom: 16 + MediaQuery.paddingOf(context).bottom),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final String roomId = item.room.id;
                        final String? offerId = item.room.activeOfferId;

                        final String lastMessage =
                            item.room.lastMessageText.isEmpty
                                ? 'เริ่มการสนทนาได้เลย'
                                : item.room.lastMessageText;
                        final String timeString =
                            _formatTimestamp(item.room.updatedAt);
                        final String title = item.title;
                        final String status = item.status;
                        final String thumbnail = item.thumbnail;
                        final bool isUnread = item.isUnread;

                        return Dismissible(
                          key: Key(roomId),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            color: AppColors.danger,
                            child: const Icon(Icons.delete_outline_rounded,
                                color: Colors.white),
                          ),
                          confirmDismiss: (direction) async {
                            final cubit = context.read<ChatListCubit>();
                            bool canDelete = await cubit.canDeleteChatRoom(
                                offerId, currentUserId);

                            if (!canDelete) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            const Text(
                                                'ไม่สามารถลบห้องสนทนานี้ได้'),
                                        behavior: SnackBarBehavior.floating,
                                        margin: const EdgeInsets.only(
                                            bottom: 20, left: 16, right: 16),
                                        backgroundColor: AppColors.warning));
                              }
                              return false;
                            }

                            if (!context.mounted) return false;

                            bool confirmDelete = await showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text('ยืนยันการลบแชท'),
                                      content: const Text(
                                          'คุณแน่ใจหรือไม่ว่าต้องการลบห้องสนทนานี้?\nข้อมูลทั้งหมดจะหายไปและไม่สามารถกู้คืนได้'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(false),
                                          child: const Text('ยกเลิก',
                                              style: TextStyle(
                                                  color:
                                                      AppColors.inkSecondary)),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.danger,
                                              minimumSize: const Size(0, 44)),
                                          child: const Text('ลบทิ้ง',
                                              style: TextStyle(
                                                  color: Colors.white)),
                                        ),
                                      ],
                                    );
                                  },
                                ) ??
                                false;

                            return confirmDelete;
                          },
                          onDismissed: (direction) async {
                            context
                                .read<ChatListCubit>()
                                .removeMember(roomId, currentUserId);
                          },
                          child: _buildChatRow(
                            roomId: roomId,
                            title: title,
                            lastMessage: lastMessage,
                            timeString: timeString,
                            status: status,
                            thumbnail: thumbnail,
                            isUnread: isUnread,
                            isLast: index == items.length - 1,
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

  Widget _buildFilterTabs() {
    final filters = ['All', 'Unread', 'Active Trades', 'Completed'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpace.page, vertical: 8),
      child: Row(
        children: filters.map((filter) {
          bool isSelected = _selectedFilter == filter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.ink : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                    color: isSelected ? AppColors.ink : AppColors.hairline),
              ),
              child: Text(filter,
                  style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.inkSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Deal status as a small coloured mark in front of the item name:
  /// yellow ⇄ while the deal is open, green ✓ when traded, red ✕ when it
  /// was rejected or cancelled. No mark for rooms without a deal.
  Widget? _statusIcon(String status) {
    final (IconData icon, Color color) = switch (status) {
      '' => (Icons.circle, Colors.transparent),
      'completed' => (Icons.check_rounded, AppColors.success),
      'rejected' || 'cancelled' => (Icons.close_rounded, AppColors.danger),
      _ => (Icons.swap_horiz_rounded, const Color(0xFFE0A100)),
    };
    if (status.isEmpty) return null;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 15, color: color),
    );
  }

  Widget _buildChatRow({
    required String roomId,
    required String title,
    required String lastMessage,
    required String timeString,
    required String status,
    required String thumbnail,
    required bool isUnread,
    required bool isLast,
  }) {
    const double thumbSize = 64;
    final statusIcon = _statusIcon(status);
    return Material(
      color: AppColors.background,
      child: InkWell(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ChatScreen(roomId: roomId))),
        child: Padding(
          padding: const EdgeInsets.only(left: AppSpace.page),
          child: Row(
            children: [
              // Square item photo with the unread dot on its edge.
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      image: thumbnail.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(thumbnail), fit: BoxFit.cover)
                          : null,
                    ),
                    child: thumbnail.isEmpty
                        ? const Icon(Icons.inventory_2_outlined,
                            color: AppColors.primary)
                        : null,
                  ),
                  if (isUnread)
                    Positioned(
                      right: -4,
                      top: thumbSize / 2 - 7,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.background, width: 2.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              // Text column carries the divider, so it starts after the
              // photo like the reference.
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(0, 16, AppSpace.page, 16),
                  decoration: BoxDecoration(
                    border: isLast
                        ? null
                        : const Border(
                            bottom: BorderSide(color: AppColors.hairline)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (statusIcon != null) ...[
                            statusIcon,
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(title,
                                style: AppText.subtitle.copyWith(
                                    fontSize: 17,
                                    fontWeight: isUnread
                                        ? FontWeight.w700
                                        : FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          Text(timeString,
                              style: AppText.caption.copyWith(
                                  color: isUnread
                                      ? AppColors.ink
                                      : AppColors.inkTertiary)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(lastMessage,
                          style: AppText.bodySecondary.copyWith(
                              color: isUnread
                                  ? AppColors.ink
                                  : AppColors.inkSecondary,
                              fontWeight:
                                  isUnread ? FontWeight.w500 : FontWeight.w400),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
