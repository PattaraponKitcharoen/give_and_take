import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/auth_repository.dart';
import '../repositories/listing_repository.dart';
import '../models/listing_model.dart';
import 'edit_listing_screen.dart';
import '../theme/app_theme.dart';

class MyListingScreen extends StatefulWidget {
  const MyListingScreen({super.key});

  @override
  State<MyListingScreen> createState() => _MyListingScreenState();
}

class _MyListingScreenState extends State<MyListingScreen> {
  String get currentUserId =>
      context.read<AuthRepository>().currentUser?.uid ?? '';
  final Color tealColor = AppColors.primary;
  final Color bgColor = AppColors.background;

  // ตัวแปรเก็บสถานะแท็บที่เลือก
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('My Listings', style: AppText.title),
        centerTitle: false, // จัดซ้ายตามภาพ
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppColors.ink),
            onPressed: () {}, // สำหรับตั้งค่า Filter เพิ่มเติมในอนาคต
          ),
        ],
      ),
      body: StreamBuilder<List<ListingModel>>(
        stream:
            context.read<ListingRepository>().getUserListings(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const Center(child: Text('เกิดข้อผิดพลาดในการดึงข้อมูล'));
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data ?? [];

          final validDocs = docs.where((doc) {
            final status = doc.status;
            return status == 'active' ||
                status == 'in_progress' ||
                status == 'banned';
          }).toList();

          int total = validDocs.where((d) => d.status != 'banned').length;
          int activeCount = validDocs.where((d) => d.status == 'active').length;
          int inDealCount =
              validDocs.where((d) => d.status == 'in_progress').length;

          var filteredDocs = validDocs.where((doc) {
            final status = doc.status;
            if (_selectedFilter == 'Active' && status != 'active') return false;
            if (_selectedFilter == 'In Progress' && status != 'in_progress')
              return false;
            return true;
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryRow(total, activeCount, inDealCount),
              _buildFilterTabs(),
              Expanded(
                child: filteredDocs.isEmpty
                    ? const Center(
                        child: Text('ไม่พบสิ่งของในหมวดหมู่นี้',
                            style: TextStyle(color: AppColors.inkTertiary)))
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                            AppSpace.page,
                            8,
                            AppSpace.page,
                            16 + MediaQuery.paddingOf(context).bottom),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final item = filteredDocs[index];
                          return _buildItemCard(context, item);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 🟢 1. แถบสรุปยอดด้านบน (Summary Pills)
  Widget _buildSummaryRow(int total, int active, int inDeal) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpace.page, vertical: 8),
      child: Row(
        children: [
          _buildSummaryChip(
              '$total Total', AppColors.primarySoft, AppColors.primaryDark),
          const SizedBox(width: 8),
          _buildSummaryChip(
              '$active Active', AppColors.successSoft, AppColors.success,
              icon: Icons.check_circle),
          const SizedBox(width: 8),
          _buildSummaryChip(
              '$inDeal In Deal', AppColors.surfaceMuted, AppColors.inkSecondary,
              icon: Icons.handshake),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String label, Color bgColor, Color textColor,
      {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4)
          ],
          if (icon == null) ...[
            Icon(Icons.layers_rounded, size: 14, color: textColor),
            const SizedBox(width: 4)
          ],
          Text(label,
              style: AppText.label.copyWith(color: textColor, fontSize: 12.5)),
        ],
      ),
    );
  }

  // 🟢 2. แถบแท็บฟิลเตอร์ (Filter Tabs)
  Widget _buildFilterTabs() {
    // 🟢 เอา 'Draft' ออกจากลิสต์
    final filters = ['All', 'Active', 'In Progress'];
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
              child: Row(
                children: [
                  Icon(
                      // 🟢 เอาเงื่อนไขไอคอน Draft ออก
                      filter == 'All'
                          ? Icons.grid_view_rounded
                          : filter == 'Active'
                              ? Icons.check_circle
                              : Icons.handshake,
                      size: 14,
                      color:
                          isSelected ? Colors.white : AppColors.inkSecondary),
                  const SizedBox(width: 6),
                  Text(filter,
                      style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.inkSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // 🟢 3. การ์ดแสดงสินค้า (Item Card)
  Widget _buildItemCard(BuildContext context, ListingModel item) {
    final String title = item.title.isEmpty ? 'ไม่มีชื่อสินค้า' : item.title;
    final int coins = item.estimatedCoins;
    final String status = item.status;
    final String thumbnail = item.thumbnailUrl;

    // ตั้งค่าสีและข้อความของ Status Badge
    Color statusBgColor = AppColors.surfaceMuted;
    Color statusTextColor = AppColors.inkSecondary;
    String statusText = 'Draft';
    IconData statusIcon = Icons.insert_drive_file;

    if (status == 'active') {
      statusBgColor = AppColors.successSoft;
      statusTextColor = AppColors.success;
      statusText = 'Active';
      statusIcon = Icons.check_circle;
    } else if (status == 'in_progress') {
      statusBgColor = AppColors.surfaceMuted;
      statusTextColor = AppColors.inkSecondary;
      statusText = 'In Progress';
      statusIcon = Icons.handshake;
    } else if (status == 'banned') {
      statusBgColor = AppColors.dangerSoft;
      statusTextColor = AppColors.danger;
      statusText = 'ถูกระงับ';
      statusIcon = Icons.block_rounded;
    }
    // Why it's suspended, shown under the badge.
    final String? banNote = status != 'banned'
        ? null
        : item.hiddenByUserBan
            ? 'ซ่อนไว้ระหว่างที่บัญชีของคุณถูกระงับ'
            : (item.banReason.isNotEmpty
                ? 'เหตุผล: ${item.banReason}'
                : 'ถูกระงับโดยผู้ดูแลระบบ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.hairline.withOpacity(0.6)),
        boxShadow: AppShadows.raised,
      ),
      child: Row(
        children: [
          // รูปภาพ
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.md)),
            child: thumbnail.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Image.network(thumbnail, fit: BoxFit.cover))
                : const Center(
                    child: Icon(Icons.image,
                        color: AppColors.inkTertiary, size: 30)),
          ),
          const SizedBox(width: 16),
          // รายละเอียด
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppText.subtitle.copyWith(fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                // ป้ายสถานะ
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(AppRadius.pill)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusTextColor),
                      const SizedBox(width: 4),
                      Text(statusText,
                          style: TextStyle(
                              color: statusTextColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                if (banNote != null) ...[
                  const SizedBox(height: 4),
                  Text(banNote,
                      style: AppText.caption
                          .copyWith(color: AppColors.danger, fontSize: 11.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 6),
                // ป้ายราคาเหรียญ
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          gradient: AppGradients.primary,
                          borderRadius: BorderRadius.circular(AppRadius.pill)),
                      child: Row(
                        children: [
                          const Icon(Icons.toll_rounded,
                              color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text('$coins',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('TradeCoins',
                        style: TextStyle(
                            color: AppColors.inkSecondary, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          // ปุ่มจัดการ (Edit / Delete). Not while a deal is in progress: the
          // other side agreed to this item as it is, and the rules refuse
          // deleting it until the deal is finished or cancelled.
          if (status == 'in_progress')
            const Tooltip(
              message: 'อยู่ระหว่างแลกเปลี่ยน แก้ไขหรือลบไม่ได้',
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.lock_outline_rounded,
                    color: AppColors.inkTertiary, size: 18),
              ),
            )
          else
            Column(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                EditListingScreen(itemData: item)));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                        color: AppColors.surfaceMuted, shape: BoxShape.circle),
                    child: const Icon(Icons.edit_outlined,
                        color: AppColors.ink, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _showDeleteConfirmDialog(
                      context, item.listingId, tealColor),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: AppColors.dangerSoft, shape: BoxShape.circle),
                    child: Icon(Icons.delete_outline,
                        color: AppColors.danger, size: 18),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(
      BuildContext context, String itemId, Color tealColor) {
    showDialog(
      context: context,
      builder: (contextDialog) {
        return AlertDialog(
          title: const Text('ยืนยันการลบ'),
          content: const Text(
              'คุณแน่ใจหรือไม่ที่จะลบสิ่งของชิ้นนี้?\nข้อเสนอที่เกี่ยวข้องทั้งหมดจะถูกยกเลิกด้วย'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(contextDialog),
                child: const Text('ยกเลิก',
                    style: TextStyle(color: AppColors.inkSecondary))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  minimumSize: const Size(0, 44)),
              onPressed: () async {
                Navigator.pop(contextDialog);
                try {
                  await context
                      .read<ListingRepository>()
                      .deleteListingAndRelatedData(itemId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                            'ลบสิ่งของและยกเลิกข้อเสนอที่เกี่ยวข้องเรียบร้อย'),
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.only(
                            bottom: 20, left: 16, right: 16),
                        backgroundColor: tealColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('เกิดข้อผิดพลาด: $e'),
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.only(
                            bottom: 20, left: 16, right: 16),
                        backgroundColor: AppColors.danger,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                }
              },
              child: const Text('ลบสิ่งของ',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
