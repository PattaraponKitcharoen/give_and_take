import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/auth_repository.dart';
import '../repositories/chat_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/listing_repository.dart';
import '../cubits/location/location_cubit.dart';
import '../cubits/profile/profile_cubit.dart';
import '../cubits/profile/profile_state.dart';
import '../models/user_model.dart';
import '../widgets/student_verification_dialog.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/glass.dart';
import 'banned_screen.dart';
import 'home_screen.dart';
import 'my_listing_screen.dart';
import 'add_post_screen.dart';
import 'chat_list_screen.dart';
import 'profile_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  // Sliding selection pill: animates from the previous tab to the new one,
  // swelling into a glass "lens" mid-way (iOS 26 tab bar feel).
  int _fromIndex = 0;
  late final AnimationController _pillController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: 1,
  );
  static const double _addGap = 72; // space left for the raised + button
  static const double _barPadding = 6;

  @override
  void dispose() {
    _pillController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (index == _currentIndex) return;
    // Start from wherever the pill is right now (it may still be moving).
    setState(() {
      _fromIndex = _currentIndex;
      _currentIndex = index;
    });
    _pillController.forward(from: 0);
  }

  double _slotCenter(int index, double slotWidth) =>
      slotWidth * index + slotWidth / 2 + (index >= 2 ? _addGap : 0);

  Widget _buildSlidingPill(double barWidth) {
    final slotWidth = (barWidth - _addGap) / 4;
    return AnimatedBuilder(
      animation: _pillController,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_pillController.value);
        // 0 at rest, 1 at the middle of the move.
        final lift = math.sin(math.pi * _pillController.value);
        final x = lerpDouble(_slotCenter(_fromIndex, slotWidth),
            _slotCenter(_currentIndex, slotWidth), t)!;
        final width = 58 + 22 * lift;
        final height = 40 + 12 * lift;
        return Positioned(
          left: x - width / 2,
          top: (_barHeight - height) / 2,
          width: width,
          height: height,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                // Grey pill at rest → bright glass lens while travelling.
                // Both ends are light colours so the blend never passes
                // through a dark grey (lerping from translucent ink did).
                color: Color.lerp(const Color(0xFFE8E8E5),
                    Colors.white.withOpacity(0.92), lift),
                border: Border.all(
                    color: Colors.white.withOpacity(0.9 * lift), width: 1),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.ink.withOpacity(0.14 * lift),
                      blurRadius: 18,
                      offset: Offset(0, 6 * lift)),
                  BoxShadow(
                      color: AppColors.primary.withOpacity(0.12 * lift),
                      blurRadius: 10,
                      spreadRadius: -2),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    // Signed in from here on: start following the user's coarse position.
    context.read<LocationCubit>().start();
  }

  bool _hasShownStudentDialog = false;
  final Color activeColor = AppColors.ink;
  final Color inactiveColor = AppColors.inkTertiary;
  static const double _barHeight = 56;
  static const double _fabRise = 18;

  Widget _buildNavItem(
      IconData icon, IconData activeIcon, String label, int index,
      {bool isChat = false}) {
    bool isSelected = _currentIndex == index;
    final color = isSelected ? activeColor : inactiveColor;

    Widget iconWidget =
        Icon(isSelected ? activeIcon : icon, color: color, size: 24);

    if (isChat) {
      final currentUserId = context.read<AuthRepository>().currentUser?.uid;
      iconWidget = StreamBuilder<bool>(
        stream: currentUserId != null
            ? context
                .read<ChatRepository>()
                .hasUnreadNotifications(currentUserId)
            : Stream.value(false),
        builder: (context, snapshot) {
          bool hasUnreadChat = snapshot.data ?? false;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(isSelected ? activeIcon : icon, color: color, size: 24),
              if (hasUnreadChat)
                Positioned(
                  right: -3,
                  top: -2,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          );
        },
      );
    }

    return Expanded(
      child: GestureDetector(
        onTap: () => _selectTab(index),
        behavior: HitTestBehavior.opaque,
        // Icon-only bar; the label stays for screen readers.
        child: Semantics(
          label: label,
          button: true,
          selected: isSelected,
          child: Center(child: iconWidget),
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddPostScreen()),
        );
      },
      child: Container(
        height: 62,
        width: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Light mint at the top deepening to dark teal, with a wide soft
          // halo so the edge melts into the bar instead of a hard rim.
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(AppColors.primary, Colors.white, 0.28)!,
              AppColors.primary,
              AppColors.primaryDark,
            ],
            stops: const [0, 0.5, 1],
          ),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withOpacity(0.30),
                blurRadius: 26,
                spreadRadius: 2,
                offset: const Offset(0, 8)),
            BoxShadow(
                color: AppColors.primary.withOpacity(0.18),
                blurRadius: 10,
                spreadRadius: 1),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final authRepo = context.read<AuthRepository>();
        return ProfileCubit(
          userRepository: context.read<UserRepository>(),
          listingRepository: context.read<ListingRepository>(),
          authRepository: authRepo,
          userId: authRepo.currentUser?.uid ?? '',
        );
      },
      // A banned account sees only the ban notice; the live user stream
      // switches back to the app as soon as the ban is lifted.
      child: BlocBuilder<ProfileCubit, ProfileState>(
        buildWhen: (prev, next) => _bannedUser(prev) != _bannedUser(next),
        builder: (context, state) {
          final banned = _bannedUser(state);
          return banned != null
              ? BannedScreen(user: banned)
              : _buildTabs(context);
        },
      ),
    );
  }

  UserModel? _bannedUser(ProfileState state) =>
      state is ProfileLoaded && state.user.isBanned ? state.user : null;

  Widget _buildTabs(BuildContext context) {
    return Scaffold(
      body: BlocListener<ProfileCubit, ProfileState>(
          listener: (context, state) {
            if (state is ProfileLoaded &&
                !state.user.isBanned &&
                !_hasShownStudentDialog) {
              if (state.user.isStudent != true) {
                _hasShownStudentDialog = true;
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) =>
                      StudentVerificationDialog(user: state.user),
                );
              }
            }
          },
          child: IndexedStack(
            index: _currentIndex,
            children: const [
              HomeScreen(),
              MyListingScreen(),
              ChatListScreen(),
              ProfileScreen(),
            ],
          ),
        ),
      // The bar floats over the content (extendBody) so lists scroll under
      // the frosted glass; MediaQuery bottom padding grows by the bar's
      // height, which the tab screens add to their scroll padding.
      extendBody: true,
      bottomNavigationBar: Stack(
        children: [
          // Progressive blur + fade behind the bar: content dissolves into
          // the page colour as it scrolls toward the bottom edge, instead of
          // staying sharp around the floating pill.
          Positioned.fill(
            child: IgnorePointer(
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black, Colors.black],
                  stops: [0, 0.45, 1],
                ).createShader(rect),
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.background.withOpacity(0.55),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            // Sits closer to the bottom edge than the full safe-area inset,
            // just clear of the home indicator.
            padding: EdgeInsets.fromLTRB(20, 10, 20,
                math.max(MediaQuery.viewPaddingOf(context).bottom - 14, 10)),
            child: SizedBox(
              // Bar (56) + room for the + button rising 18 above it, kept
              // inside the Stack so its top half still receives taps.
              height: _barHeight + _fabRise,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: _barHeight,
                    child: Glass(
                      borderRadius: BorderRadius.circular(_barHeight / 2),
                      shadows: AppShadows.raised,
                      padding:
                          const EdgeInsets.symmetric(horizontal: _barPadding),
                      child: LayoutBuilder(
                        builder: (context, constraints) => Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildSlidingPill(constraints.maxWidth),
                            Row(
                              children: [
                                _buildNavItem(Icons.home_outlined,
                                    Icons.home_rounded, 'หน้าหลัก', 0),
                                _buildNavItem(Icons.grid_view_outlined,
                                    Icons.grid_view_rounded, 'ของฉัน', 1),
                                const SizedBox(width: _addGap),
                                _buildNavItem(Icons.chat_bubble_outline_rounded,
                                    Icons.chat_bubble_rounded, 'แชท', 2,
                                    isChat: true),
                                _buildNavItem(Icons.person_outline_rounded,
                                    Icons.person_rounded, 'โปรไฟล์', 3),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Center(child: _buildAddButton()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
