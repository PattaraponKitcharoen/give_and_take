import 'package:flutter/material.dart';

import 'package:geolocator/geolocator.dart'; 
import 'package:geocoding/geocoding.dart';   
import 'package:flutter_bloc/flutter_bloc.dart'; // 🟢 เพิ่ม BLoC
import 'item_detail_screen.dart';
import 'item_search_delegate.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';
import '../cubits/home/home_cubit.dart';
import '../cubits/home/home_state.dart';
import '../repositories/listing_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/chat_repository.dart';
import '../models/user_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Color tealColor = const Color(0xFF008080);
  final Color bgColor = const Color(0xFFF4F6F8); 

  String? get currentUserId => context.read<AuthRepository>().currentUser?.uid;

  // 🟢 เพิ่มตัวแปรสำหรับระบบ Location
  String _currentLocation = 'หาดใหญ่, สงขลา'; 
  bool _isLoadingLocation = false;

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

  // 🟢 ฟังก์ชันหลักสำหรับขอสิทธิ์และดึงตำแหน่ง
  Future<void> _updateLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar('กรุณาเปิดบริการตำแหน่ง (GPS) ในเครื่องของคุณ');
        setState(() => _isLoadingLocation = false);
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('ไม่สามารถอัปเดตได้เนื่องจากคุณปฏิเสธการเข้าถึงตำแหน่ง');
          setState(() => _isLoadingLocation = false);
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('การเข้าถึงตำแหน่งถูกปฏิเสธถาวร กรุณาไปเปิดในการตั้งค่าของเครื่อง');
        setState(() => _isLoadingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude, 
        position.longitude
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        
        String district = place.subAdministrativeArea ?? '';
        String province = place.administrativeArea ?? '';

        district = district.replaceAll('อำเภอ', '').replaceAll('เขต', '').trim();
        province = province.replaceAll('จังหวัด', '').trim();

        String newLocationInfo = '$district, $province';

        if (!mounted) return;
        setState(() {
          _currentLocation = newLocationInfo;
          _isLoadingLocation = false;
        });

        await _saveLocationToDatabase(position.latitude, position.longitude, district, province);
        
        _showSnackBar('อัปเดตตำแหน่งของคุณเป็น $newLocationInfo เรียบร้อยแล้ว');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingLocation = false);
      _showSnackBar('เกิดข้อผิดพลาดในการค้นหาตำแหน่ง: $e');
    }
  }

  Future<void> _saveLocationToDatabase(double lat, double lng, String district, String province) async {
    final uid = currentUserId;
    if (uid != null) {
      await context.read<UserRepository>().updateUserLocation(uid, lat, lng, district, province);
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating, 
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10), 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showSortOptions(BuildContext parentContext) {
    final cubit = parentContext.read<HomeCubit>();
    showModalBottomSheet(
      context: parentContext,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return BlocProvider.value(
          value: cubit,
          child: BlocBuilder<HomeCubit, HomeState>(
            builder: (context, state) {
              final sortBy = state is HomeLoaded ? state.sortBy : 'newest';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('จัดเรียงตาม', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.access_time),
                      title: const Text('โพสต์ล่าสุด'),
                      trailing: sortBy == 'newest' ? Icon(Icons.check, color: tealColor) : null,
                      onTap: () { cubit.updateSort('newest'); Navigator.pop(context); },
                    ),
                    ListTile(
                      leading: const Icon(Icons.arrow_upward),
                      title: const Text('ราคาประเมิน: น้อยไปมาก'),
                      trailing: sortBy == 'coins_asc' ? Icon(Icons.check, color: tealColor) : null,
                      onTap: () { cubit.updateSort('coins_asc'); Navigator.pop(context); },
                    ),
                    ListTile(
                      leading: const Icon(Icons.arrow_downward),
                      title: const Text('ราคาประเมิน: มากไปน้อย'),
                      trailing: sortBy == 'coins_desc' ? Icon(Icons.check, color: tealColor) : null,
                      onTap: () { cubit.updateSort('coins_desc'); Navigator.pop(context); },
                    ),
                  ],
                ),
              );
            }
          ),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return BlocProvider.value(
          value: cubit,
          child: BlocBuilder<HomeCubit, HomeState>(
            builder: (context, state) {
              final selectedCategories = state is HomeLoaded ? state.selectedCategories : ['All'];
              return Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('เลือกหมวดหมู่ทั้งหมด', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Icon(Icons.close, color: Colors.grey.shade600),
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
                              labelPadding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 0.0),
                              visualDensity: const VisualDensity(horizontal: -2.0, vertical: -2.0),
                              selectedColor: tealColor,
                              backgroundColor: Colors.white,
                              labelStyle: TextStyle(
                                color: isActive ? Colors.white : Colors.black87,
                                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: isActive ? tealColor : Colors.grey.shade300)
                              ),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('ตกลง', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              );
            }
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HomeCubit(
        listingRepository: context.read<ListingRepository>(),
        currentUserId: currentUserId ?? '',
      )..fetchItems(),
      child: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: bgColor,
            appBar: AppBar(
              backgroundColor: bgColor, 
              elevation: 0,
              title: Row(
                children: [
                  Image.asset('assets/logo.png', width: 40, height: 40, fit: BoxFit.contain),
                  const SizedBox(width: 4),
                  Text('Give & Take', style: TextStyle(color: tealColor, fontWeight: FontWeight.bold, fontSize: 22)),
                ],
              ),
              actions: [
                StreamBuilder<bool>(
                  stream: currentUserId != null ? context.read<ChatRepository>().hasUnreadNotifications(currentUserId!) : Stream.value(false),
                  builder: (context, snapshot) {
                    bool hasUnreadNoti = snapshot.data ?? false;

                    return Container(
                      margin: const EdgeInsets.only(right: 12), width: 40, height: 40,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: Colors.grey.shade300)),
                      child: Stack(
                        alignment: Alignment.center, clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                            icon: const Icon(Icons.notifications_none, color: Colors.black87, size: 22),
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationScreen())),
                          ),
                          if (hasUnreadNoti) Positioned(right: 0, top: 0, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
                        ],
                      ),
                    );
                  },
                ),
                
                StreamBuilder<UserModel>(
                  stream: currentUserId != null ? context.read<UserRepository>().getUserStream(currentUserId!) : const Stream.empty(),
                  builder: (context, snapshot) {
                    String profileImg = '';
                    if (snapshot.hasData) {
                      profileImg = snapshot.data!.profileImgUrl;
                    }
                    return GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
                      child: Container(
                        margin: const EdgeInsets.only(right: 16), width: 40, height: 40,
                        child: CircleAvatar(
                          radius: 18, backgroundColor: Colors.grey.shade300, 
                          backgroundImage: profileImg.isNotEmpty ? NetworkImage(profileImg) : null,
                          child: profileImg.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 20) : null,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(context),
                  _buildLocationBar(),
                  _buildHeroBanner(),
                  _buildSectionHeader('Categories', 'See all', onTrailingTap: () => _showAllCategoriesPopup(context)),
                  _buildCategoryChips(context),
                  _buildSectionHeader('Near You', 'อัปเดตใหม่วันนี้', isTrailingGreen: true),
                  _buildProductGrid(context),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => showSearch(context: context, delegate: ItemSearchDelegate()),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade300)),
                child: Row(children: [Icon(Icons.search, color: Colors.grey.shade500, size: 20), const SizedBox(width: 8), Text('ค้นหาสิ่งของ...', style: TextStyle(color: Colors.grey.shade500, fontSize: 14))]),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _showSortOptions(context),
            child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300)), child: const Icon(Icons.tune, color: Colors.black87, size: 20)),
          )
        ],
      ),
    );
  }

  Widget _buildLocationBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _isLoadingLocation ? null : _updateLocation, 
            child: Row(
              children: [
                Icon(Icons.location_on, color: tealColor, size: 18), 
                const SizedBox(width: 4), 
                _isLoadingLocation 
                  ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : Text(_currentLocation, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)), 
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 18)
              ],
            ),
          ),
          Text('ใกล้ฉัน', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24), height: 160,
      decoration: BoxDecoration(gradient: LinearGradient(colors: [tealColor, const Color(0xFF20B2AA)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity( 0.2), borderRadius: BorderRadius.circular(8)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_circle, color: Colors.white, size: 12), SizedBox(width: 4), Text('Verified Traders Only', style: TextStyle(color: Colors.white, fontSize: 10))])),
          const SizedBox(height: 12),
          const Text('Trade what you have.\nGet what you need.', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.2)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String trailing, {bool isTrailingGreen = false, VoidCallback? onTrailingTap}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          GestureDetector(
            onTap: onTrailingTap,
            child: Row(
              children: [
                if (isTrailingGreen) Icon(Icons.add_circle, color: tealColor, size: 14),
                if (isTrailingGreen) const SizedBox(width: 4),
                Text(trailing, style: TextStyle(color: isTrailingGreen ? tealColor : Colors.grey.shade600, fontSize: 13, fontWeight: isTrailingGreen ? FontWeight.bold : FontWeight.normal)),
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
        final selectedCategories = state is HomeLoaded ? state.selectedCategories : ['All'];
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: displayCategories.map((cat) {
              bool isActive = selectedCategories.contains(cat); 
              return GestureDetector(
                onTap: () => context.read<HomeCubit>().toggleCategory(cat), 
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: isActive ? tealColor : Colors.white,
                    border: Border.all(color: isActive ? tealColor : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        cat == 'All' ? Icons.grid_view_rounded : _getCategoryIcon(cat), 
                        size: 16, color: isActive ? Colors.white : tealColor
                      ),
                      const SizedBox(width: 8),
                      Text(cat, style: TextStyle(color: isActive ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)),
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
      case 'Wishlists': return Icons.favorite;
      case 'อุปกรณ์ไอที & แก็ดเจ็ต': return Icons.devices_rounded;
      case 'แฟชั่น & เครื่องแต่งกาย': return Icons.checkroom_rounded;
      case 'เกม & ของเล่น': return Icons.sports_esports_rounded;
      case 'ของใช้ในบ้าน & เฟอร์นิเจอร์': return Icons.chair_rounded;
      case 'หนังสือ & เครื่องเขียน': return Icons.menu_book_rounded;
      case 'กีฬา & กิจกรรมกลางแจ้ง': return Icons.sports_basketball_rounded;
      case 'สุขภาพ & ความงาม': return Icons.health_and_safety_rounded;
      case 'ดนตรี & ศิลปะ': return Icons.music_note_rounded;
      case 'อุปกรณ์สัตว์เลี้ยง': return Icons.pets_rounded;
      case 'ยานพาหนะ & อะไหล่': return Icons.two_wheeler_rounded;
      case 'อื่นๆ (Miscellaneous)': return Icons.category_rounded;
      default: return Icons.category_outlined;
    }
  }

  Widget _buildProductGrid(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          if (state is HomeLoading) {
            return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
          }
          if (state is HomeError) {
            return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'));
          }
          if (state is HomeLoaded) {
            final filteredDocs = state.filteredItems;

            if (state.allItems.isEmpty) {
              return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('ยังไม่มีสิ่งของให้แลกเปลี่ยนในขณะนี้', style: TextStyle(color: Colors.grey))));
            }
            if (filteredDocs.isEmpty) {
              return const Center(child: Padding(padding: EdgeInsets.all(40.0), child: Text('ไม่พบสิ่งของในหมวดหมู่นี้', style: TextStyle(color: Colors.grey))));
            }

            return GridView.builder(
              physics: const NeverScrollableScrollPhysics(), shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.52),
              itemCount: filteredDocs.length,
              itemBuilder: (context, index) {
                final item = filteredDocs[index];
                
                final title = item.title;
                final coins = item.estimatedCoins;
                final thumbnail = item.thumbnailUrl;

                final ownerName = item.ownerName.trim().isEmpty ? 'ผู้ใช้งาน' : item.ownerName;
                final profileImg = item.ownerProfileImg;
                final ratingScore = item.ownerRatingScores;
                
                return InkWell( 
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailScreen(listing: item)));
                  },
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity( 0.03), blurRadius: 10, offset: const Offset(0, 4))]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              Container(
                                width: double.infinity, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
                                child: thumbnail.isNotEmpty ? ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), child: Image.network(thumbnail, fit: BoxFit.cover)) : const Center(child: Icon(Icons.image, size: 40, color: Colors.black12)),
                              ),
                              Positioned(
                                top: 8, left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: tealColor, borderRadius: BorderRadius.circular(12)),
                                  child: Row(children: [const Icon(Icons.monetization_on, color: Colors.white, size: 12), const SizedBox(width: 4), Text('$coins', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))]),
                                ),
                              ),
                              Positioned(
                                top: 8, right: 8,
                                child: GestureDetector(
                                  onTap: () => context.read<HomeCubit>().toggleLike(item),
                                  child: CircleAvatar(
                                    radius: 14, backgroundColor: Colors.white,
                                    child: Icon(item.likedBy.contains(currentUserId) ? Icons.favorite : Icons.favorite_border, size: 16, color: item.likedBy.contains(currentUserId) ? Colors.red : Colors.grey.shade400),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        CircleAvatar(radius: 8, backgroundColor: Colors.grey.shade300, backgroundImage: profileImg.isNotEmpty ? NetworkImage(profileImg) : null, child: profileImg.isEmpty ? const Icon(Icons.person, size: 10, color: Colors.white) : null),
                                        const SizedBox(width: 6),
                                        Expanded(child: Text(ownerName, style: TextStyle(fontSize: 11, color: Colors.grey.shade700), overflow: TextOverflow.ellipsis)),
                                      ],
                                    ),
                                  ),
                                  Row(children: [const Icon(Icons.star, size: 12, color: Colors.amber), const SizedBox(width: 2), Text(ratingScore > 0 ? ratingScore.toStringAsFixed(1) : 'New', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade800))]),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: tealColor, borderRadius: BorderRadius.circular(8)),
                                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.swap_horiz, color: Colors.white, size: 16), SizedBox(width: 4), Text('Swap', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))]),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}