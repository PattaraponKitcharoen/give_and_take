import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/edit_listing/edit_listing_cubit.dart';
import '../cubits/edit_listing/edit_listing_state.dart';
import '../repositories/listing_repository.dart';
import '../models/listing_model.dart';
import '../widgets/multi_image_picker.dart';

class EditListingScreen extends StatelessWidget {
  final ListingModel itemData;

  const EditListingScreen({
    super.key,
    required this.itemData,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => EditListingCubit(
        listingRepository: context.read<ListingRepository>(),
      ),
      child: _EditListingView(itemData: itemData),
    );
  }
}

class _EditListingView extends StatefulWidget {
  final ListingModel itemData;

  const _EditListingView({required this.itemData});

  @override
  State<_EditListingView> createState() => _EditListingViewState();
}

class _EditListingViewState extends State<_EditListingView> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _coinsController;

  // 🟢 เพิ่มตัวแปรสำหรับรับค่าอื่นๆ
  late String _selectedCategory;
  late String _selectedCondition;
  List<PickedImageEntry> _images = [];

  final Color tealColor = const Color(0xFF008080);

  // 🟢 รายการตัวเลือก (สามารถปรับเปลี่ยนให้ตรงกับหน้า Add Item ได้)
  final List<String> _categories = [
    'อุปกรณ์ไอที & แก็ดเจ็ต', 'แฟชั่น & เครื่องแต่งกาย', 'เกม & ของเล่น',
    'ของใช้ในบ้าน & เฟอร์นิเจอร์', 'หนังสือ & เครื่องเขียน', 'กีฬา & กิจกรรมกลางแจ้ง',
    'สุขภาพ & ความงาม', 'ดนตรี & ศิลปะ', 'อุปกรณ์สัตว์เลี้ยง', 'ยานพาหนะ & อะไหล่', 'อื่นๆ (Miscellaneous)', 'ทั่วไป'
  ];

  final List<String> _conditions = [
    'มือหนึ่ง', 'มือสองสภาพนางฟ้า', 'มือสองสภาพดี', 'มือสองเสียหายเล็กน้อย'
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.itemData.title);
    _descController = TextEditingController(text: widget.itemData.description);
    _coinsController = TextEditingController(text: widget.itemData.estimatedCoins.toString());

    _selectedCategory = widget.itemData.category;
    if (!_categories.contains(_selectedCategory)) _categories.add(_selectedCategory);

    _selectedCondition = widget.itemData.condition;
    if (!_conditions.contains(_selectedCondition)) _conditions.add(_selectedCondition);

    // Prefer the full images array; fall back to the legacy single
    // thumbnailUrl for listings saved before multi-image upload existed
    // (no camera metadata available for that legacy path).
    _images = widget.itemData.images.isNotEmpty
        ? widget.itemData.images
            .map<PickedImageEntry>((img) => NetworkPickedImage(img.url, isFromCamera: img.isFromCamera))
            .toList()
        : (widget.itemData.thumbnailUrl.isNotEmpty ? [NetworkPickedImage(widget.itemData.thumbnailUrl)] : []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _coinsController.dispose();
    super.dispose();
  }

  void _updateListing() {
    final imageInputs = _images
        .map<ListingImageInput>((entry) => switch (entry) {
              LocalPickedImage(:final file, :final isFromCamera) =>
                NewListingImage(file, isFromCamera: isFromCamera),
              NetworkPickedImage(:final url, :final isFromCamera) =>
                ExistingListingImage(url, isFromCamera: isFromCamera),
            })
        .toList();

    context.read<EditListingCubit>().updateListing(
      originalListing: widget.itemData,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      category: _selectedCategory,
      condition: _selectedCondition,
      estimatedCoins: int.tryParse(_coinsController.text.trim()) ?? 0,
      images: imageInputs,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(), // พับคีย์บอร์ดเมื่อกดพื้นที่ว่าง
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('แก้ไขสิ่งของ', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0.5,
          iconTheme: const IconThemeData(color: Colors.black87),
        ),
        body: BlocListener<EditListingCubit, EditListingState>(
          listener: (context, state) {
            if (state is EditListingSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('บันทึกข้อมูลเรียบร้อย'),
                  behavior: SnackBarBehavior.floating, // สั่งให้ลอยทับ UI
                  margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20), // เพิ่มระยะห่างขอบให้ดูสวยขึ้น
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // ลบมุมขอบให้มนๆ
                  backgroundColor: tealColor,
                )
              );
              Navigator.pop(context);
            } else if (state is EditListingError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('เกิดข้อผิดพลาด: ${state.message}'),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
                  backgroundColor: Colors.red.shade600,
                )
              );
            }
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🟢 SECTION: จัดการรูปภาพ
                const Text('รูปภาพ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 12),
                MultiImagePickerWidget(
                  images: _images,
                  onChanged: (updated) => setState(() => _images = updated),
                  primaryColor: tealColor,
                ),
                const SizedBox(height: 24),

                // 🟢 SECTION: ข้อมูลพื้นฐาน
                const Text('ชื่อสิ่งของ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                  ),
                ),
                const SizedBox(height: 20),

                const Text('รายละเอียด', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 8),
                TextField(
                  controller: _descController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                  ),
                ),
                const SizedBox(height: 20),

                // 🟢 SECTION: หมวดหมู่และสภาพ
                const Text('หมวดหมู่ (Category)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategory,
                      isExpanded: true,
                      icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
                      items: _categories.map((String cat) {
                        return DropdownMenuItem<String>(value: cat, child: Text(cat, style: const TextStyle(fontSize: 14)));
                      }).toList(),
                      onChanged: (newValue) {
                        if (newValue != null) setState(() => _selectedCategory = newValue);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const Text('สภาพสิ่งของ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0, runSpacing: 8.0,
                  children: _conditions.map((condition) {
                    bool isSelected = _selectedCondition == condition;
                    return ChoiceChip(
                      label: Text(condition),
                      selected: isSelected,
                      onSelected: (selected) { if (selected) setState(() => _selectedCondition = condition); },
                      selectedColor: tealColor,
                      backgroundColor: Colors.grey.shade100,
                      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade700, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13),
                      showCheckmark: false,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? tealColor : Colors.grey.shade300)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // 🟢 SECTION: ราคา
                const Text('ราคาประเมิน (Coins)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 8),
                TextField(
                  controller: _coinsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.monetization_on_outlined, color: Colors.orange),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                  ),
                ),
                const SizedBox(height: 40),

                BlocBuilder<EditListingCubit, EditListingState>(
                  builder: (context, state) {
                    final isSubmitting = state is EditListingSubmitting;
                    return SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : _updateListing,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tealColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: isSubmitting
                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('บันทึกการแก้ไข', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
