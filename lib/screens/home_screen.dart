import 'dart:async';
import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart'; // 🟢 เพิ่ม BLoC
import 'item_search_delegate.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';
import 'student_listings_screen.dart';
import 'match_screen.dart';
import '../cubits/match/match_badge_cubit.dart';
import '../repositories/match_repository.dart';
import '../cubits/home/home_cubit.dart';
import '../cubits/location/location_cubit.dart';
import '../models/place_location.dart';
import '../repositories/location_repository.dart';
import '../cubits/home/home_state.dart';
import '../repositories/listing_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/chat_repository.dart';
import '../models/user_model.dart';
import '../widgets/listing_grid_card.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Color tealColor = AppColors.primary;
  final Color bgColor = AppColors.background;

  String? get currentUserId => context.read<AuthRepository>().currentUser?.uid;


  final PageController _bannerPageController = PageController();
  int _currentBannerPage = 0;
  static const int _bannerCount = 2;
  // Auto-advances the banner carousel; restarted whenever the page changes
  // so a manual swipe gets a full 5 s before the next automatic move.
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _restartBannerTimer();
  }

  void _restartBannerTimer() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_bannerPageController.hasClients) return;
      _bannerPageController.animateToPage(
        (_currentBannerPage + 1) % _bannerCount,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerPageController.dispose();
    super.dispose();
  }

  final List<String> _allCategories = [
    'Wishlists',
    'อุปกรณ์ไอที & แก็ดเจ็ต',
    'แฟชั่น & เครื่องแต่งกาย',
    'เกม & ของเล่น',
    'ของใช้ในบ้าน & เฟอร์นิเจอร์',
    'ดนตรี & ศิลปะ',
    'หนังสือ & เครื่องเขียน',
    'กีฬา & กิจกรรมกลางแจ้ง',
    'สุขภาพ & ความงาม',
    'อุปกรณ์สัตว์เลี้ยง',
    'ยานพาหนะ & อะไหล่',
    'อื่นๆ (Miscellaneous)'
  ];

  /// Tapping the location bar: ask again (shows the system prompt if the
  /// user hasn't decided yet) and explain what's wrong if it still fails.
  Future<void> _refreshLocation() async {
    final cubit = context.read<LocationCubit>();
    await cubit.refresh(askPermission: true);
    if (!mounted) return;
    final issue = cubit.state.issue;
    if (issue == null) return;
    _showSnackBar(switch (issue) {
      LocationIssue.serviceOff => 'กรุณาเปิดบริการตำแหน่ง (GPS) ในเครื่องของคุณ',
      LocationIssue.denied =>
        'ไม่สามารถอัปเดตได้เนื่องจากคุณปฏิเสธการเข้าถึงตำแหน่ง',
      LocationIssue.deniedForever =>
        'การเข้าถึงตำแหน่งถูกปฏิเสธถาวร กรุณาไปเปิดในการตั้งค่าของเครื่อง',
      LocationIssue.failed => 'หาตำแหน่งไม่สำเร็จ ลองใหม่อีกครั้ง',
    });
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showSortOptions(BuildContext parentContext) {
    final cubit = parentContext.read<HomeCubit>();
    showModalBottomSheet(
      context: parentContext,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return BlocProvider.value(
          value: cubit,
          child: BlocBuilder<HomeCubit, HomeState>(builder: (context, state) {
            final sortBy = state is HomeLoaded ? state.sortBy : 'newest';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('จัดเรียงตาม',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('โพสต์ล่าสุด'),
                    trailing: sortBy == 'newest'
                        ? Icon(Icons.check, color: tealColor)
                        : null,
                    onTap: () {
                      cubit.updateSort('newest');
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.near_me_outlined),
                    title: const Text('ใกล้ฉันที่สุด'),
                    subtitle: state is HomeLoaded && state.userLocation == null
                        ? const Text('ต้องเปิดตำแหน่งก่อน')
                        : null,
                    trailing: sortBy == 'nearest'
                        ? Icon(Icons.check, color: tealColor)
                        : null,
                    onTap: () {
                      cubit.updateSort('nearest');
                      Navigator.pop(context);
                      if (context.read<LocationCubit>().state.location ==
                          null) {
                        _refreshLocation();
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.arrow_upward),
                    title: const Text('ราคาประเมิน: น้อยไปมาก'),
                    trailing: sortBy == 'coins_asc'
                        ? Icon(Icons.check, color: tealColor)
                        : null,
                    onTap: () {
                      cubit.updateSort('coins_asc');
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.arrow_downward),
                    title: const Text('ราคาประเมิน: มากไปน้อย'),
                    trailing: sortBy == 'coins_desc'
                        ? Icon(Icons.check, color: tealColor)
                        : null,
                    onTap: () {
                      cubit.updateSort('coins_desc');
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  void _showAllCategoriesPopup(BuildContext parentContext) {
    final cubit = parentContext.read<HomeCubit>();
    showModalBottomSheet(
        context: parentContext,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (context) {
          return BlocProvider.value(
            value: cubit,
            child: BlocBuilder<HomeCubit, HomeState>(builder: (context, state) {
              final selectedCategories =
                  state is HomeLoaded ? state.selectedCategories : ['All'];
              return Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.75),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: AppColors.hairline,
                            borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('เลือกหมวดหมู่ทั้งหมด',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.ink)),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Icon(Icons.close, color: AppColors.inkSecondary),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 8,
                          children: ['All', ..._allCategories].map((cat) {
                            bool isActive = selectedCategories.contains(cat);
                            return ChoiceChip(
                              label: Text(cat),
                              selected: isActive,
                              onSelected: (selected) {
                                cubit.toggleCategory(cat);
                              },
                              labelPadding: const EdgeInsets.symmetric(
                                  horizontal: 4.0, vertical: 0.0),
                              visualDensity: const VisualDensity(
                                  horizontal: -2.0, vertical: -2.0),
                              selectedColor: tealColor,
                              backgroundColor: Colors.white,
                              labelStyle: TextStyle(
                                  color:
                                      isActive ? Colors.white : AppColors.ink,
                                  fontWeight: isActive
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                      color: isActive
                                          ? tealColor
                                          : AppColors.hairline)),
                              showCheckmark: false,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tealColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('ตกลง',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              );
            }),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => HomeCubit(
            listingRepository: context.read<ListingRepository>(),
            userRepository: context.read<UserRepository>(),
            currentUserId: currentUserId ?? '',
          )
            ..setUserLocation(context.read<LocationCubit>().state.location)
            ..fetchItems(),
        ),
        BlocProvider(
          create: (context) => MatchBadgeCubit(
            matchRepository: context.read<MatchRepository>(),
            userId: currentUserId ?? '',
          ),
        ),
      ],
      child: Builder(builder: (context) {
        return BlocListener<LocationCubit, LocationState>(
          listenWhen: (a, b) => a.location != b.location,
          listener: (context, loc) =>
              context.read<HomeCubit>().setUserLocation(loc.location),
          child: Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: bgColor,
            elevation: 0,
            titleSpacing: AppSpace.page,
            title: Row(
              children: [
                Image.asset('assets/logo.png',
                    width: 34, height: 34, fit: BoxFit.contain),
                const SizedBox(width: 8),
                const Text('Give & Take',
                    style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        fontSize: 21)),
              ],
            ),
            actions: [
              StreamBuilder<bool>(
                stream: currentUserId != null
                    ? context
                        .read<ChatRepository>()
                        .hasUnreadNotifications(currentUserId!)
                    : Stream.value(false),
                builder: (context, snapshot) {
                  bool hasUnreadNoti = snapshot.data ?? false;

                  return Container(
                    margin: const EdgeInsets.only(right: 10),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.hairline)),
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.notifications_none_rounded,
                              color: AppColors.ink, size: 22),
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const NotificationScreen())),
                        ),
                        if (hasUnreadNoti)
                          Positioned(
                              right: 9,
                              top: 9,
                              child: Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                      color: AppColors.danger,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 1.5)))),
                      ],
                    ),
                  );
                },
              ),
              StreamBuilder<UserModel>(
                stream: currentUserId != null
                    ? context
                        .read<UserRepository>()
                        .getUserStream(currentUserId!)
                    : const Stream.empty(),
                builder: (context, snapshot) {
                  String profileImg = '';
                  if (snapshot.hasData) {
                    profileImg = snapshot.data!.profileImgUrl;
                  }
                  return GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ProfileScreen())),
                    child: Container(
                      margin: const EdgeInsets.only(right: AppSpace.page),
                      width: 42,
                      height: 42,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.hairline)),
                      child: CircleAvatar(
                        backgroundColor: AppColors.surfaceMuted,
                        backgroundImage: profileImg.isNotEmpty
                            ? NetworkImage(profileImg)
                            : null,
                        child: profileImg.isEmpty
                            ? const Icon(Icons.person,
                                color: AppColors.inkTertiary, size: 20)
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          // CustomScrollView + slivers instead of a SingleChildScrollView
          // wrapping a Column: the product grid below is a SliverGrid, so
          // only items actually scrolled into view get built, instead of
          // every item in the feed being laid out up front (which is what
          // GridView.builder's `shrinkWrap: true` was forcing to make it
          // fit inside a box-constrained Column/ScrollView).
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchBar(context),
                    _buildLocationBar(),
                    _buildBannerCarousel(),
                    _buildSectionHeader('Categories', 'See all',
                        onTrailingTap: () => _showAllCategoriesPopup(context)),
                    _buildCategoryChips(context),
                    _buildSectionHeader('Near You', 'อัปเดตใหม่วันนี้',
                        isTrailingGreen: true),
                  ],
                ),
              ),
              _buildProductGrid(context),
              // 30 + room for the floating glass nav bar.
              SliverToBoxAdapter(
                  child: SizedBox(
                      height: 30 + MediaQuery.paddingOf(context).bottom)),
            ],
          ),
          ),
        );
      }),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.page, 8, AppSpace.page, 4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () =>
                  showSearch(context: context, delegate: ItemSearchDelegate()),
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.hairline)),
                child: Row(children: [
                  const Icon(Icons.search_rounded,
                      color: AppColors.inkSecondary, size: 21),
                  const SizedBox(width: 10),
                  Text('ค้นหาสิ่งของ...',
                      style: AppText.bodySecondary
                          .copyWith(color: AppColors.inkTertiary))
                ]),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _showSortOptions(context),
            child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(AppRadius.md)),
                child: const Icon(Icons.tune_rounded,
                    color: Colors.white, size: 21)),
          )
        ],
      ),
    );
  }

  Widget _buildLocationBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.page, 12, AppSpace.page, 4),
      child: Row(
        children: [
          BlocBuilder<LocationCubit, LocationState>(
            builder: (context, loc) {
              final name = loc.location?.displayName ?? '';
              return GestureDetector(
                onTap: loc.loading ? null : _refreshLocation,
                child: Row(
                  children: [
                    const Icon(Icons.place_outlined,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 6),
                    loc.loading && loc.location == null
                        ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(
                            name.isNotEmpty
                                ? name
                                : (loc.location != null
                                    ? 'ตำแหน่งปัจจุบัน'
                                    : 'แตะเพื่อใช้ตำแหน่งของคุณ'),
                            style: AppText.label),
                    const SizedBox(width: 2),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.inkSecondary, size: 18)
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Shared look for both carousel banners: solid deep colour, a fine
  // highlight in the corner, small overline chip and a large headline.
  Widget _bannerShell(
      {required Color color,
      required IconData chipIcon,
      required String chip,
      required String headline,
      Widget? footer}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.page),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Colors.white, 0.16)!,
            color,
            Color.lerp(color, Colors.black, 0.12)!
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.22),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
                decoration: BoxDecoration(gradient: AppGradients.gloss)),
          ),
          Positioned(
            right: -40,
            top: -50,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withOpacity(0.10), width: 22),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(AppRadius.pill)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(chipIcon, color: Colors.white, size: 12),
                      const SizedBox(width: 5),
                      Text(chip,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4))
                    ])),
                const SizedBox(height: 12),
                Text(headline,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        height: 1.25)),
                if (footer != null) ...[const SizedBox(height: 10), footer],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Entry to "แลกตามความต้องการ" (want-based matching). Shows how many
  // matches the user hasn't opened yet.
  Widget _buildMatchBanner() {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (context) => const MatchScreen())),
      child: BlocBuilder<MatchBadgeCubit, int>(
        builder: (context, unseen) => Stack(
          children: [
            Positioned.fill(
              child: _bannerShell(
                color: AppColors.primary,
                chipIcon: Icons.sync_alt_rounded,
                chip: 'Match',
                headline: 'แลกตามความต้องการ\nบอกสิ่งที่อยากได้ เราหาคู่แลกให้',
                footer: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(unseen > 0 ? 'ดูแมตช์' : 'เริ่มเลย',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 15),
                ]),
              ),
            ),
            if (unseen > 0)
              Positioned(
                top: 14,
                right: AppSpace.page + 14,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: AppShadows.glow(AppColors.danger),
                  ),
                  child: Text('$unseen แมตช์ใหม่',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Muted plum to read as clearly distinct from the brand-teal "everyone"
  // banner — this one filters down to student-owned listings only.
  Widget _buildStudentBanner() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const StudentListingsScreen()));
      },
      child: _bannerShell(
        color: AppColors.student,
        chipIcon: Icons.school_rounded,
        chip: 'Student',
        headline: 'ตลาดนักศึกษา\nแลกเปลี่ยนกับเพื่อนนักศึกษาเท่านั้น',
        footer: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('ดูทั้งหมด',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward_rounded,
              color: Colors.white, size: 15),
        ]),
      ),
    );
  }

  Widget _buildBannerCarousel() {
    final banners = [
      _buildMatchBanner(),
      _buildStudentBanner(),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        children: [
          // 168 banner + room above/below so its glow shadow isn't cut off
          // by the PageView's clip.
          SizedBox(
            height: 208,
            child: PageView.builder(
              controller: _bannerPageController,
              itemCount: banners.length,
              onPageChanged: (index) {
                setState(() => _currentBannerPage = index);
                _restartBannerTimer();
              },
              itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 30),
                  child: banners[index]),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(banners.length, (index) {
              final isActive = index == _currentBannerPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.ink : AppColors.hairline,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String trailing,
      {bool isTrailingGreen = false, VoidCallback? onTrailingTap}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.page, 28, AppSpace.page, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(title, style: AppText.title),
          GestureDetector(
            onTap: onTrailingTap,
            child: Row(
              children: [
                if (isTrailingGreen)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: const BoxDecoration(
                        color: AppColors.success, shape: BoxShape.circle),
                  ),
                Text(trailing,
                    style: AppText.caption.copyWith(
                        color: isTrailingGreen
                            ? AppColors.success
                            : AppColors.inkSecondary,
                        fontWeight: FontWeight.w600)),
                if (!isTrailingGreen && onTrailingTap != null)
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: AppColors.inkSecondary),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCategoryChips(BuildContext context) {
    final displayCategories = ['All', ..._allCategories];
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        final selectedCategories =
            state is HomeLoaded ? state.selectedCategories : ['All'];
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
          child: Row(
            children: displayCategories.map((cat) {
              bool isActive = selectedCategories.contains(cat);
              return GestureDetector(
                onTap: () => context.read<HomeCubit>().toggleCategory(cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.ink : AppColors.surface,
                    border: Border.all(
                        color: isActive ? AppColors.ink : AppColors.hairline),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    children: [
                      Icon(
                          cat == 'All'
                              ? Icons.grid_view_rounded
                              : _getCategoryIcon(cat),
                          size: 15,
                          color: isActive ? Colors.white : AppColors.ink),
                      const SizedBox(width: 7),
                      Text(cat,
                          style: AppText.label.copyWith(
                              color: isActive ? Colors.white : AppColors.ink,
                              fontWeight: isActive
                                  ? FontWeight.w600
                                  : FontWeight.w500)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Wishlists':
        return Icons.favorite;
      case 'อุปกรณ์ไอที & แก็ดเจ็ต':
        return Icons.devices_rounded;
      case 'แฟชั่น & เครื่องแต่งกาย':
        return Icons.checkroom_rounded;
      case 'เกม & ของเล่น':
        return Icons.sports_esports_rounded;
      case 'ของใช้ในบ้าน & เฟอร์นิเจอร์':
        return Icons.chair_rounded;
      case 'หนังสือ & เครื่องเขียน':
        return Icons.menu_book_rounded;
      case 'กีฬา & กิจกรรมกลางแจ้ง':
        return Icons.sports_basketball_rounded;
      case 'สุขภาพ & ความงาม':
        return Icons.health_and_safety_rounded;
      case 'ดนตรี & ศิลปะ':
        return Icons.music_note_rounded;
      case 'อุปกรณ์สัตว์เลี้ยง':
        return Icons.pets_rounded;
      case 'ยานพาหนะ & อะไหล่':
        return Icons.two_wheeler_rounded;
      case 'อื่นๆ (Miscellaneous)':
        return Icons.category_rounded;
      default:
        return Icons.category_outlined;
    }
  }

  // Returns a sliver (not a box widget) — this is placed directly inside
  // the CustomScrollView's `slivers:` list in build(), so SliverGrid.builder
  // below only builds the item cards actually scrolled near the viewport,
  // instead of every item up front (which is what GridView.builder's
  // `shrinkWrap: true` forced when this lived inside a boxed Column).
  Widget _buildProductGrid(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
      sliver: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          if (state is HomeLoading) {
            return const SliverToBoxAdapter(
                child: Center(
                    child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator())));
          }
          if (state is HomeError) {
            return const SliverToBoxAdapter(
                child: Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล')));
          }
          if (state is HomeLoaded) {
            final filteredDocs = state.filteredItems;

            if (state.allItems.isEmpty) {
              return const SliverToBoxAdapter(
                  child: Center(
                      child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('ยังไม่มีสิ่งของให้แลกเปลี่ยนในขณะนี้',
                              style: TextStyle(color: AppColors.inkTertiary)))));
            }
            if (filteredDocs.isEmpty) {
              return const SliverToBoxAdapter(
                  child: Center(
                      child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: Text('ไม่พบสิ่งของในหมวดหมู่นี้',
                              style: TextStyle(color: AppColors.inkTertiary)))));
            }

            return SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.64),
              itemCount: filteredDocs.length,
              itemBuilder: (context, index) {
                final item = filteredDocs[index];
                final isWishlisted = state.wishlist.contains(item.listingId);

                final here = state.userLocation;
                final there = item.location;
                return ListingGridCard(
                  item: item,
                  isWishlisted: isWishlisted,
                  accentColor: tealColor,
                  distanceLabel: here != null && there != null
                      ? PlaceLocation.formatDistance(there.distanceKmTo(here))
                      : null,
                  onToggleWishlist: (item) =>
                      context.read<HomeCubit>().toggleWishlist(item),
                );
              },
            );
          }
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        },
      ),
    );
  }
}
