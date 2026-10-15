import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/edit_listing/edit_listing_cubit.dart';
import '../cubits/edit_listing/edit_listing_state.dart';
import '../cubits/location/location_cubit.dart';
import '../models/place_location.dart';
import '../widgets/pickup_location_tile.dart';
import '../repositories/listing_repository.dart';
import '../models/listing_model.dart';
import '../widgets/multi_image_picker.dart';
import '../widgets/ui/primary_button.dart';
import '../theme/app_theme.dart';

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
  // Pickup point; only changes when the owner taps "ย้ายมาตำแหน่งปัจจุบัน".
  PlaceLocation? _pickup;
  bool _locating = false;

  final Color tealColor = AppColors.primary;

  // 🟢 รายการตัวเลือก (สามารถปรับเปลี่ยนให้ตรงกับหน้า Add Item ได้)
  final List<String> _categories = [
    'อุปกรณ์ไอที & แก็ดเจ็ต',
    'แฟชั่น & เครื่องแต่งกาย',
    'เกม & ของเล่น',
    'ของใช้ในบ้าน & เฟอร์นิเจอร์',
    'หนังสือ & เครื่องเขียน',
    'กีฬา & กิจกรรมกลางแจ้ง',
    'สุขภาพ & ความงาม',
    'ดนตรี & ศิลปะ',
    'อุปกรณ์สัตว์เลี้ยง',
    'ยานพาหนะ & อะไหล่',
    'อื่นๆ (Miscellaneous)',
    'ทั่วไป'
  ];

  final List<String> _conditions = [
    'มือหนึ่ง',
    'มือสองสภาพนางฟ้า',
    'มือสองสภาพดี',
    'มือสองเสียหายเล็กน้อย'
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.itemData.title);
    _descController = TextEditingController(text: widget.itemData.description);
    _coinsController =
        TextEditingController(text: widget.itemData.estimatedCoins.toString());

    _pickup = widget.itemData.location;
    _selectedCategory = widget.itemData.category;
    if (!_categories.contains(_selectedCategory))
      _categories.add(_selectedCategory);

    _selectedCondition = widget.itemData.condition;
    if (!_conditions.contains(_selectedCondition))
      _conditions.add(_selectedCondition);

    // Prefer the full images array; fall back to the legacy single
    // thumbnailUrl for listings saved before multi-image upload existed
    // (no camera metadata available for that legacy path).
    _images = widget.itemData.images.isNotEmpty
        ? widget.itemData.images
            .map<PickedImageEntry>((img) =>
                NetworkPickedImage(img.url, isFromCamera: img.isFromCamera))
            .toList()
        : (widget.itemData.thumbnailUrl.isNotEmpty
            ? [NetworkPickedImage(widget.itemData.thumbnailUrl)]
            : []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _coinsController.dispose();
    super.dispose();
  }

  Future<void> _moveToCurrentLocation() async {
    final cubit = context.read<LocationCubit>();
    setState(() => _locating = true);
    await cubit.refresh(askPermission: true);
    if (!mounted) return;
    final here = cubit.state.location;
    setState(() {
      _locating = false;
      if (here != null) _pickup = here;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(here != null
          ? 'ย้ายจุดรับของเป็น ${here.displayName.isNotEmpty ? here.displayName : 'ตำแหน่งปัจจุบัน'} แล้ว กดบันทึกเพื่อยืนยัน'
          : 'หาตำแหน่งไม่สำเร็จ ตรวจสอบว่าเปิด GPS และอนุญาตการเข้าถึงตำแหน่ง'),
      behavior: SnackBarBehavior.floating,
    ));
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
          location: _pickup,
        );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () =>
          FocusScope.of(context).unfocus(), // พับคีย์บอร์ดเมื่อกดพื้นที่ว่าง
      child: Scaffold(
        appBar: AppBar(
          title: const Text('แก้ไขสิ่งของ'),
          centerTitle: true,
        ),
        body: BlocListener<EditListingCubit, EditListingState>(
          listener: (context, state) {
            if (state is EditListingSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('บันทึกข้อมูลเรียบร้อย'),
                behavior: SnackBarBehavior.floating, // สั่งให้ลอยทับ UI
                margin: const EdgeInsets.only(
                    bottom: 20,
                    left: 20,
                    right: 20), // เพิ่มระยะห่างขอบให้ดูสวยขึ้น
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)), // ลบมุมขอบให้มนๆ
                backgroundColor: tealColor,
              ));
              Navigator.pop(context);
            } else if (state is EditListingError) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('เกิดข้อผิดพลาด: ${state.message}'),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
                backgroundColor: AppColors.danger,
              ));
            }
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🟢 SECTION: จัดการรูปภาพ
                Text('รูปภาพ',
                    style:
                        AppText.label.copyWith(color: AppColors.inkSecondary)),
                const SizedBox(height: 12),
                MultiImagePickerWidget(
                  images: _images,
                  onChanged: (updated) => setState(() => _images = updated),
                  primaryColor: tealColor,
                ),
                const SizedBox(height: 24),

                // 🟢 SECTION: ข้อมูลพื้นฐาน
                Text('ชื่อสิ่งของ',
                    style:
                        AppText.label.copyWith(color: AppColors.inkSecondary)),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  style: AppText.body,
                  decoration: const InputDecoration(),
                ),
                const SizedBox(height: 20),

                Text('รายละเอียด',
                    style:
                        AppText.label.copyWith(color: AppColors.inkSecondary)),
                const SizedBox(height: 8),
                TextField(
                  controller: _descController,
                  maxLines: 4,
                  style: AppText.body,
                  decoration: const InputDecoration(),
                ),
                const SizedBox(height: 20),

                // 🟢 SECTION: หมวดหมู่และสภาพ
                Text('หมวดหมู่ (Category)',
                    style:
                        AppText.label.copyWith(color: AppColors.inkSecondary)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategory,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppColors.inkTertiary),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      dropdownColor: AppColors.surface,
                      items: _categories.map((String cat) {
                        return DropdownMenuItem<String>(
                            value: cat, child: Text(cat, style: AppText.body));
                      }).toList(),
                      onChanged: (newValue) {
                        if (newValue != null)
                          setState(() => _selectedCategory = newValue);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Text('สภาพสิ่งของ',
                    style:
                        AppText.label.copyWith(color: AppColors.inkSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _conditions.map((condition) {
                    bool isSelected = _selectedCondition == condition;
                    return ChoiceChip(
                      label: Text(condition),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected)
                          setState(() => _selectedCondition = condition);
                      },
                      selectedColor: AppColors.ink,
                      backgroundColor: AppColors.surface,
                      labelStyle: AppText.label.copyWith(
                          color: isSelected
                              ? Colors.white
                              : AppColors.inkSecondary,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500),
                      showCheckmark: false,
                      shape: StadiumBorder(
                          side: BorderSide(
                              color: isSelected
                                  ? AppColors.ink
                                  : AppColors.hairline)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // 🟢 SECTION: ราคา
                Text('ราคาประเมิน (Coins)',
                    style:
                        AppText.label.copyWith(color: AppColors.inkSecondary)),
                const SizedBox(height: 8),
                TextField(
                  controller: _coinsController,
                  keyboardType: TextInputType.number,
                  style: AppText.body,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.toll_rounded, color: AppColors.gold),
                  ),
                ),
                const SizedBox(height: 20),

                Text('จุดรับของ',
                    style:
                        AppText.label.copyWith(color: AppColors.inkSecondary)),
                const SizedBox(height: 8),
                PickupLocationTile(
                  location: _pickup,
                  loading: _locating,
                  actionLabel: 'ย้ายมาที่\nตำแหน่งปัจจุบัน',
                  onUseCurrent: _moveToCurrentLocation,
                ),
                const SizedBox(height: 40),

                BlocBuilder<EditListingCubit, EditListingState>(
                  builder: (context, state) {
                    final isSubmitting = state is EditListingSubmitting;
                    return PrimaryButton(
                      onPressed: _updateListing,
                      isLoading: isSubmitting,
                      height: 56,
                      child: const Text('บันทึกการแก้ไข'),
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
