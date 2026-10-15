import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/location/location_cubit.dart';
import '../widgets/pickup_location_tile.dart';
import '../cubits/add_post/add_post_cubit.dart';
import '../cubits/add_post/add_post_state.dart';
import '../cubits/listing_estimate/listing_estimate_cubit.dart';
import '../cubits/listing_estimate/listing_estimate_state.dart';
import '../models/listing_estimate.dart';
import '../repositories/ai_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/listing_repository.dart';
import '../widgets/multi_image_picker.dart';
import '../widgets/email_verification_dialog.dart';
import '../widgets/ui/primary_button.dart';
import '../theme/app_theme.dart';

class AddPostScreen extends StatelessWidget {
  const AddPostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => AddPostCubit(
            listingRepository: context.read<ListingRepository>(),
            userRepository: context.read<UserRepository>(),
          ),
        ),
        BlocProvider(
          create: (context) => ListingEstimateCubit(
            aiRepository: context.read<AiRepository>(),
          ),
        ),
      ],
      child: const _AddPostView(),
    );
  }
}

class _AddPostView extends StatefulWidget {
  const _AddPostView();

  @override
  State<_AddPostView> createState() => _AddPostViewState();
}

class _AddPostViewState extends State<_AddPostView> {
  final Color primaryTeal = AppColors.primary;
  final Color bgColor = AppColors.background;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _coinsController = TextEditingController();

  String _selectedCategory = 'อุปกรณ์ไอที & แก็ดเจ็ต';
  final List<Map<String, dynamic>> _categories = [
    {'name': 'อุปกรณ์ไอที & แก็ดเจ็ต', 'icon': Icons.devices_rounded},
    {'name': 'แฟชั่น & เครื่องแต่งกาย', 'icon': Icons.checkroom_rounded},
    {'name': 'เกม & ของเล่น', 'icon': Icons.sports_esports_rounded},
    {'name': 'ของใช้ในบ้าน & เฟอร์นิเจอร์', 'icon': Icons.chair_rounded},
    {'name': 'หนังสือ & เครื่องเขียน', 'icon': Icons.menu_book_rounded},
    {'name': 'กีฬา & กิจกรรมกลางแจ้ง', 'icon': Icons.sports_basketball_rounded},
    {'name': 'สุขภาพ & ความงาม', 'icon': Icons.health_and_safety_rounded},
    {'name': 'ดนตรี & ศิลปะ', 'icon': Icons.music_note_rounded},
    {'name': 'อุปกรณ์สัตว์เลี้ยง', 'icon': Icons.pets_rounded},
    {'name': 'ยานพาหนะ & อะไหล่', 'icon': Icons.two_wheeler_rounded},
    {'name': 'อื่นๆ (Miscellaneous)', 'icon': Icons.category_rounded},
  ];

  String _selectedCondition = 'มือสองสภาพดี';
  final List<String> _conditions = [
    'มือหนึ่ง',
    'มือสองสภาพนางฟ้า',
    'มือสองสภาพดี',
    'มือสองเสียหายเล็กน้อย'
  ];

  List<PickedImageEntry> _pickedImages = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _coinsController.dispose();
    super.dispose();
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.hairline,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text('เลือกหมวดหมู่', style: AppText.title),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat['name'];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            gradient: isSelected ? AppGradients.primary : null,
                            color: isSelected ? null : AppColors.primarySoft,
                            shape: BoxShape.circle),
                        child: Icon(cat['icon'],
                            color: isSelected ? Colors.white : primaryTeal,
                            size: 22),
                      ),
                      title: Text(
                        cat['name'],
                        style: AppText.body.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? primaryTeal : AppColors.ink,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle_rounded, color: primaryTeal)
                          : null,
                      onTap: () {
                        setState(() => _selectedCategory = cat['name']);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitPost() async {
    bool isVerified = await context.read<AuthRepository>().isEmailVerified();
    if (!mounted) return;

    if (!isVerified) {
      showEmailVerificationDialog(
        context,
        message:
            'คุณต้องยืนยันอีเมลก่อนจึงจะสามารถลงประกาศสิ่งของได้ กรุณาตรวจสอบกล่องจดหมายของคุณ',
        themeColor: primaryTeal,
      );
      return;
    }

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final coinsText = _coinsController.text.trim();

    if (title.isEmpty || description.isEmpty || coinsText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('กรุณากรอกข้อมูลให้ครบถ้วน'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating));
      return;
    }

    final int? coins = int.tryParse(coinsText);
    if (coins == null || coins <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('กรุณากรอกราคาประเมินเป็นตัวเลข'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating));
      return;
    }

    final User? firebaseUser = context.read<AuthRepository>().currentUser;
    if (firebaseUser == null) return;

    // All post images are freshly picked here (never an existing Storage
    // URL), so every entry maps to a NewListingImage — order preserved, so
    // index 0 stays the cover photo.
    final imageInputs = _pickedImages
        .whereType<LocalPickedImage>()
        .map<ListingImageInput>((entry) =>
            NewListingImage(entry.file, isFromCamera: entry.isFromCamera))
        .toList();

    context.read<AddPostCubit>().submitPost(
          ownerId: firebaseUser.uid,
          category: _selectedCategory,
          title: title,
          description: description,
          condition: _selectedCondition,
          estimatedCoins: coins,
          images: imageInputs,
          // Pickup point = where the user is now (already ~1 km coarse).
          location: context.read<LocationCubit>().state.location,
        );
  }

  List<File> get _localImageFiles => _pickedImages
      .whereType<LocalPickedImage>()
      .map((entry) => entry.file)
      .toList();

  void _requestEstimate() {
    FocusScope.of(context).unfocus();
    // Whatever the owner already typed (brand, age, defects) helps the AI.
    final hint = [
      _titleController.text.trim(),
      _descriptionController.text.trim()
    ].where((t) => t.isNotEmpty).join(' — ');
    context.read<ListingEstimateCubit>().estimate(_localImageFiles, hint: hint);
  }

  /// Fill the form from the AI suggestion. Text the owner already typed is
  /// kept; everything stays editable before posting.
  void _applyEstimate(ListingEstimate estimate) {
    if (_titleController.text.trim().isEmpty && estimate.title.isNotEmpty) {
      _titleController.text = estimate.title;
    }
    if (_descriptionController.text.trim().isEmpty &&
        estimate.description.isNotEmpty) {
      _descriptionController.text = estimate.description;
    }
    if (estimate.hasPrice) {
      _coinsController.text = estimate.coinsSuggested.toString();
    }
    setState(() {
      if (_categories.any((cat) => cat['name'] == estimate.category)) {
        _selectedCategory = estimate.category;
      }
      if (_conditions.contains(estimate.condition)) {
        _selectedCondition = estimate.condition;
      }
    });
  }

  Widget _buildAiAssist() {
    return BlocConsumer<ListingEstimateCubit, ListingEstimateState>(
      listener: (context, state) {
        if (state is ListingEstimateSuccess) {
          _applyEstimate(state.estimate);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text(
                  'AI กรอกข้อมูลให้แล้ว ตรวจสอบและแก้ไขได้ก่อนโพสต์'),
              backgroundColor: primaryTeal,
              behavior: SnackBarBehavior.floating));
        } else if (state is ListingEstimateError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating));
        }
      },
      builder: (context, state) {
        const aiColor = AppColors.student;
        final aiDecoration = BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF3F0FB), Color(0xFFE9F5F3)],
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: Colors.white),
          boxShadow: AppShadows.raised,
        );
        if (state is ListingEstimateLoading) {
          return Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(16),
            decoration: aiDecoration,
            child: const Row(children: [
              SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: aiColor)),
              SizedBox(width: 12),
              Expanded(
                  child: Text(
                      'AI กำลังดูรูปและประเมินมูลค่า… อาจใช้เวลาสักครู่',
                      style: TextStyle(
                          color: aiColor,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500))),
            ]),
          );
        }
        if (state is ListingEstimateSuccess) {
          final e = state.estimate;
          final confidence = switch (e.confidence) {
            'high' => 'มั่นใจสูง',
            'medium' => 'มั่นใจปานกลาง',
            _ => 'มั่นใจต่ำ ควรตรวจสอบ',
          };
          return Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(16),
            decoration: aiDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: AppGradients.of(aiColor),
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.glow(aiColor),
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: Colors.white, size: 14),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                        e.hasPrice
                            ? 'AI แนะนำ ${e.coinsSuggested} เหรียญ (ช่วง ${e.coinsMin}–${e.coinsMax})'
                            : 'AI ประเมินมูลค่าไม่ได้',
                        style: AppText.label
                            .copyWith(color: aiColor, fontSize: 14.5)),
                  ),
                ]),
                if (e.reason.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(e.reason,
                      style: AppText.caption.copyWith(
                          color: AppColors.inkSecondary, fontSize: 12.5)),
                ],
                const SizedBox(height: 8),
                Row(children: [
                  Text(confidence,
                      style: AppText.caption.copyWith(
                          color: AppColors.inkTertiary, fontSize: 11.5)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _requestEstimate,
                    icon: const Icon(Icons.refresh, size: 16, color: aiColor),
                    label: const Text('ประเมินใหม่',
                        style: TextStyle(color: aiColor, fontSize: 12)),
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32)),
                  ),
                ]),
              ],
            ),
          );
        }
        final hasImages = _localImageFiles.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: OutlinedButton.icon(
            onPressed: hasImages ? _requestEstimate : null,
            icon: Icon(Icons.auto_awesome,
                size: 18, color: hasImages ? aiColor : AppColors.inkTertiary),
            label: Text(
                hasImages
                    ? 'ให้ AI ช่วยกรอกข้อมูลและประเมินมูลค่า'
                    : 'เพิ่มรูปเพื่อให้ AI ช่วยกรอกข้อมูล',
                style: AppText.label.copyWith(
                    fontSize: 14,
                    color: hasImages ? aiColor : AppColors.inkTertiary)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              backgroundColor:
                  hasImages ? AppColors.studentSoft : AppColors.surface,
              side: BorderSide(
                  color: hasImages
                      ? aiColor.withOpacity(0.35)
                      : AppColors.hairline),
            ),
          ),
        );
      },
    );
  }

  void _resetForm() {
    _titleController.clear();
    _descriptionController.clear();
    _coinsController.clear();
    setState(() {
      _selectedCategory = 'อุปกรณ์ไอที & แก็ดเจ็ต';
      _selectedCondition = 'มือสองสภาพดี';
      _pickedImages = [];
    });
    context.read<ListingEstimateCubit>().reset();
  }

  InputDecoration _buildInputDecoration(String hintText, IconData icon) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(icon, color: AppColors.inkSecondary, size: 20),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 24),
      child: Text(
        title.toUpperCase(),
        style: AppText.overline,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🟢 3. ครอบ Scaffold ด้วย GestureDetector เพื่อดักจับการแตะพื้นที่ว่าง
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // เมื่อแตะพื้นที่ว่าง ให้ยกเลิกการโฟกัส (ปิดคีย์บอร์ด)
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          centerTitle: true,
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.hairline),
              ),
              child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: AppColors.ink),
                  onPressed: () => Navigator.pop(context)),
            ),
          ),
          title: const Text('Add Item', style: AppText.subtitle),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle('Photos'),
              MultiImagePickerWidget(
                images: _pickedImages,
                onChanged: (updated) {
                  setState(() => _pickedImages = updated);
                  context.read<ListingEstimateCubit>().reset();
                },
                primaryColor: primaryTeal,
              ),
              _buildAiAssist(),
              _buildSectionTitle('Item Details'),
              TextField(
                  controller: _titleController,
                  decoration: _buildInputDecoration(
                      'ชื่อสิ่งของ', Icons.edit_outlined)),
              const SizedBox(height: 12),
              TextField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: _buildInputDecoration(
                      'อธิบายสิ่งของของคุณ เช่น แบรนด์, อายุการใช้งาน, ตำหนิ...',
                      Icons.description_outlined)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _showCategoryPicker,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Row(
                    children: [
                      Icon(
                          _categories.firstWhere((cat) =>
                              cat['name'] == _selectedCategory)['icon'],
                          color: primaryTeal,
                          size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(
                        _selectedCategory,
                        style: AppText.body,
                      )),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppColors.inkTertiary),
                    ],
                  ),
                ),
              ),
              _buildSectionTitle('Condition'),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _conditions.map((condition) {
                  bool isSelected = _selectedCondition == condition;
                  return ChoiceChip(
                    label: Text(condition), selected: isSelected,
                    onSelected: (selected) {
                      if (selected)
                        setState(() => _selectedCondition = condition);
                    },
                    selectedColor: AppColors.ink,
                    backgroundColor: AppColors.surface,
                    labelStyle: AppText.label.copyWith(
                        color:
                            isSelected ? Colors.white : AppColors.inkSecondary,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500),
                    showCheckmark: false,
                    // 🟢 2. เอา avatar: ที่วาดรูปติ๊กถูกออกไปแล้ว Layout จะได้ไม่ยืดหด
                    shape: StadiumBorder(
                        side: BorderSide(
                            color: isSelected
                                ? AppColors.ink
                                : AppColors.hairline)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16, color: primaryTeal),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            'การระบุสภาพตามจริงจะช่วยให้การแลกเปลี่ยนเป็นไปอย่างราบรื่น',
                            style: AppText.caption
                                .copyWith(color: AppColors.primaryDark))),
                  ],
                ),
              ),
              _buildSectionTitle('Estimated Value'),
              TextField(
                controller: _coinsController,
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration(
                    'ราคาประเมิน (Coins)', Icons.monetization_on_outlined),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8, left: 4),
                child: Text(
                    'ช่วยให้ผู้อื่นคำนวณการใช้เหรียญเพื่อชดเชยส่วนต่างได้',
                    style: AppText.caption),
              ),
              _buildSectionTitle('Pickup Location'),
              BlocBuilder<LocationCubit, LocationState>(
                builder: (context, loc) => PickupLocationTile(
                  location: loc.location,
                  loading: loc.loading,
                  actionLabel: loc.location == null ? 'ใช้ตำแหน่ง' : 'อัปเดต',
                  onUseCurrent: () => context
                      .read<LocationCubit>()
                      .refresh(askPermission: true),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.only(left: 20, right: 20, bottom: 16, top: 8),
            child: BlocConsumer<AddPostCubit, AddPostState>(
              listener: (context, state) {
                if (state is AddPostSuccess) {
                  _resetForm();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text('โพสต์สิ่งของสำเร็จ!'),
                      backgroundColor: primaryTeal,
                      behavior: SnackBarBehavior.floating));
                  Navigator.pop(context);
                } else if (state is AddPostError) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(state.message),
                      backgroundColor: AppColors.danger,
                      behavior: SnackBarBehavior.floating));
                }
              },
              builder: (context, state) {
                final isSubmitting = state is AddPostSubmitting;
                return PrimaryButton(
                  onPressed: _submitPost,
                  isLoading: isSubmitting,
                  icon: Icons.send_rounded,
                  height: 56,
                  child: const Text('Post Item'),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
