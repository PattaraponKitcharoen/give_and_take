import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/listing_model.dart';
import '../models/offer_model.dart';
import '../repositories/listing_repository.dart';
import '../repositories/offer_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_repository.dart';
import '../cubits/offer/offer_cubit.dart';
import '../cubits/offer/offer_state.dart';
import 'chat_screen.dart';
import 'user_profile_screen.dart';

class ItemDetailScreen extends StatelessWidget {
  final ListingModel listing;

  const ItemDetailScreen({super.key, required this.listing});

  @override
  Widget build(BuildContext context) {
    // 🟢 แก้รหัสสีให้ตรงกับหน้า Add Item (0xFF008080)
    const Color tealColor = Color(0xFF008080); 
    const Color lightTeal = Color(0xFFE0F2F1);
    const Color coinGreen = Color(0xFF00C853);
    
    final String listingId = listing.listingId;
    final String title = listing.title;
    final String description = listing.description;
    final String category = listing.category;
    final int coins = listing.estimatedCoins;
    
    final String condition = listing.condition.isEmpty ? 'ไม่ระบุสภาพ' : listing.condition;
    final String ownerId = listing.ownerId; 
    final String thumbnail = listing.thumbnailUrl;

    // 🟢 แก้ไขการแสดงเวลาให้เป็นภาษาไทย
    String listedText = 'โพสต์เมื่อไม่นานมานี้';
    if (listing.createdAt != null) {
      final int days = DateTime.now().difference(listing.createdAt!).inDays;
      if (days == 0) {
        listedText = 'โพสต์วันนี้';
      } else {
        listedText = 'โพสต์เมื่อ $days วันที่แล้ว';
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 320, 
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    image: thumbnail.isNotEmpty 
                        ? DecorationImage(image: NetworkImage(thumbnail), fit: BoxFit.cover) 
                        : null,
                  ),
                  child: thumbnail.isEmpty ? const Icon(Icons.image, size: 80, color: Colors.black12) : null,
                ),
                Container(
                  height: 320,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.4), Colors.transparent, Colors.black.withOpacity(0.4)],
                      stops: const [0.0, 0.5, 1.0],
                    )
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildFloatingIcon(Icons.arrow_back_ios_new_rounded, () => Navigator.pop(context)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16, right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(20)),
                    child: const Text('1 / 1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                Positioned(
                  bottom: 24, left: 0, right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildDot(true), _buildDot(false), _buildDot(false),
                    ],
                  ),
                )
              ],
            ),
            
            Padding(
              padding: const EdgeInsets.all(16.0), 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildBadge(Icons.laptop_mac, category, lightTeal, tealColor),
                      _buildBadge(Icons.star, condition, lightTeal, tealColor),
                    ],
                  ),
                  const SizedBox(height: 12), 

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.2)),
                            const SizedBox(height: 6),
                            Text(listedText, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(color: coinGreen, borderRadius: BorderRadius.circular(20)),
                            child: Row(
                              children: [
                                const Icon(Icons.layers, color: Colors.white, size: 16),
                                const SizedBox(width: 4),
                                Text('$coins', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('Coin Value', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 16), 

                  _buildOwnerProfileCard(context, listing, tealColor),

                  const SizedBox(height: 16), 

                  const Text('About This Item', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tealColor)),
                  const SizedBox(height: 8), 
                  Text(
                    description,
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade800, height: 1.6),
                  ),
                  const SizedBox(height: 80), 
                ],
              ),
            ),
          ],
        ),
      ),
      
      // 🟢 ดักจับกรณีที่แอปยังโหลด ID ไม่ทัน เพื่อไม่ให้ StreamBuilder พัง
      bottomNavigationBar: listingId.isEmpty 
        ? const SizedBox.shrink() 
        : StreamBuilder<ListingModel?>(
            stream: context.read<ListingRepository>().getListingStream(listingId),
            builder: (context, snapshot) {
              bool isActive = false;
              bool isLiked = false; 
              
              final currentUser = context.read<AuthRepository>().currentUser;
              final currentUserId = currentUser?.uid ?? '';

              if (snapshot.hasData && snapshot.data != null) {
                final latestData = snapshot.data!;
                if (latestData.status == 'active') {
                  isActive = true;
                }
                
                final List<String> likedBy = latestData.likedBy;
                isLiked = likedBy.contains(currentUserId);
              }

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
                ),
                child: SafeArea(
                  top: false, 
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), 
                    child: Row(
                      children: [
                        Container(
                          height: 52, width: 52, 
                          decoration: BoxDecoration(
                            color: isLiked ? Colors.red.shade50 : lightTeal,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isLiked ? Colors.red.shade200 : tealColor.withOpacity(0.3)),
                          ),
                          child: IconButton(
                            icon: Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              color: isLiked ? Colors.red : tealColor, 
                            ),
                            onPressed: () async {
                              if (currentUserId.isEmpty) return;
                              
                              await context.read<ListingRepository>().toggleLike(listingId, currentUserId, isLiked);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          // 🟢 เพิ่ม Container ห่อปุ่มไว้เพื่อทำเอฟเฟกต์เงาแบบเดียวกับหน้า Add Item
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: isActive ? [
                                BoxShadow(
                                  color: tealColor.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ] : [],
                            ),
                            child: ElevatedButton(
                              onPressed: isActive ? () async {
                                bool isVerified = await context.read<AuthRepository>().isEmailVerified();
                                if (!isVerified) {
                                  if (context.mounted) _showVerificationDialog(context, tealColor);
                                  return;
                                }

                                if (currentUserId.isEmpty) return;

                                if (currentUserId == ownerId) {
                                  if (context.mounted) {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        title: const Text('แจ้งเตือน', style: TextStyle(color: tealColor, fontWeight: FontWeight.bold)),
                                        content: const Text('คุณไม่สามารถยื่นข้อเสนอให้กับสิ่งของของตัวเองได้ครับ'),
                                        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('เข้าใจแล้ว', style: TextStyle(color: tealColor, fontWeight: FontWeight.bold)))],
                                      ),
                                    );
                                  }
                                  return;
                                }
                                if (context.mounted) _showOfferBottomSheet(context, tealColor, currentUserId, listing);
                              } : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: tealColor,
                                disabledBackgroundColor: Colors.grey.shade400,
                                minimumSize: const Size(double.infinity, 52), 
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0, // ปิด elevation เดิมทิ้ง เพราะเราใช้ BoxShadow จาก Container แทนแล้ว
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.swap_horiz, color: isActive ? Colors.white : Colors.white70),
                                  const SizedBox(width: 8),
                                  Text(isActive ? 'Make an Offer' : 'Item Unavailable', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isActive ? Colors.white : Colors.white70)),
                                ],
                              )
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
      ),
    );
  }

  void _showVerificationDialog(BuildContext context, Color tealColor) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('ยืนยันอีเมลของคุณ', style: TextStyle(fontWeight: FontWeight.bold, color: tealColor)),
          content: const Text('คุณต้องยืนยันอีเมลก่อนจึงจะสามารถยื่นข้อเสนอได้ กรุณาตรวจสอบกล่องจดหมายของคุณ'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ปิด', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await context.read<AuthRepository>().sendEmailVerification();
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: const Text('ส่งอีเมลยืนยันใหม่อีกครั้งแล้ว'), backgroundColor: tealColor, behavior: SnackBarBehavior.floating)
                    );
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString()), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating)
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: tealColor),
              child: const Text('ส่งอีเมลอีกครั้ง', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFloatingIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildDot(bool isActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 16 : 6, height: 6,
      decoration: BoxDecoration(color: isActive ? Colors.white : Colors.white54, borderRadius: BorderRadius.circular(4)),
    );
  }

  Widget _buildBadge(IconData icon, String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: textColor.withOpacity(0.3))),
      child: Row(
        mainAxisSize: MainAxisSize.min, 
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildOwnerProfileCard(BuildContext context, ListingModel listing, Color tealColor) {
    if (listing.ownerId.isEmpty) return const SizedBox(); 

    String ownerName = listing.ownerName.trim().isEmpty ? 'ผู้ใช้งาน' : listing.ownerName;
    double ratingScore = listing.ownerRatingScores;
    String profileImg = listing.ownerProfileImg;

    return Container(
      padding: const EdgeInsets.all(12), 
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46, height: 46, 
                decoration: BoxDecoration(
                  color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12),
                  image: profileImg.isNotEmpty ? DecorationImage(image: NetworkImage(profileImg), fit: BoxFit.cover) : null,
                ),
                child: profileImg.isEmpty ? const Icon(Icons.person, color: Colors.grey) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ownerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2), 
                    
                    FutureBuilder<int>(
                      future: context.read<OfferRepository>().getSuccessfulTradesCount(listing.ownerId),
                      builder: (context, tradeSnap) {
                        int tradeCount = tradeSnap.data ?? 0;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$tradeCount successful trades', style: TextStyle(color: Colors.grey.shade500, fontSize: 11, height: 1.2)),
                          ],
                        );
                      }
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.orange, size: 14),
                    const SizedBox(width: 4),
                    Text(ratingScore > 0 ? ratingScore.toStringAsFixed(1) : 'New', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 12), 
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfileScreen(userId: listing.ownerId))),
              icon: Icon(Icons.person_outline, size: 16, color: tealColor),
              label: Text('View Profile', style: TextStyle(color: tealColor, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: tealColor.withOpacity(0.05),
                side: BorderSide(color: tealColor.withOpacity(0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
            ),
          )
        ],
      ),
    );
  }

  void _showOfferBottomSheet(BuildContext context, Color tealColor, String currentUserId, ListingModel listing) {
    String? selectedMyItemId;
    Map<String, dynamic>? selectedMyItemData; 
    int coinOffset = 0;
    String offerType = 'none'; 

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  FocusScope.of(context).unfocus(); 
                },
                child: SingleChildScrollView(
                  child: Container(
                    margin: const EdgeInsets.only(top: 80), 
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 5)
                      ]
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                        const SizedBox(height: 24),
                        
                        const Center(
                          child: Column(
                            children: [
                              Text('Make an Offer', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF004D40))),
                              SizedBox(height: 4),
                              Text('Propose a fair trade for this item', style: TextStyle(fontSize: 14, color: Colors.black54)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        const Text('YOUR OFFER ITEM', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.blueGrey, letterSpacing: 0.5)),
                        const SizedBox(height: 12),
                        
                        FutureBuilder<List<ListingModel>>(
                          future: context.read<ListingRepository>().getUserActiveListings(currentUserId),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                            var items = snapshot.data!;
                            
                            if (items.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                                child: const Center(child: Text('คุณยังไม่มีสิ่งของให้แลก', style: TextStyle(color: Colors.black54))),
                              );
                            }
                            
                          if (selectedMyItemId == null && items.isNotEmpty) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setModalState(() {
                                selectedMyItemId = items.first.listingId;
                                selectedMyItemData = items.first.toJson();
                                selectedMyItemData!['listing_id'] = items.first.listingId;
                              });
                            });
                          }

                            return GestureDetector(
                              onTap: () {},
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF00C853).withOpacity(0.5), width: 1.5),
                                  boxShadow: [BoxShadow(color: const Color(0xFF00C853).withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 50, height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8),
                                        image: selectedMyItemData?['thumbnail_url'] != null && selectedMyItemData!['thumbnail_url'].isNotEmpty
                                            ? DecorationImage(image: NetworkImage(selectedMyItemData!['thumbnail_url']), fit: BoxFit.cover)
                                            : null,
                                      ),
                                      child: selectedMyItemData?['thumbnail_url'] == null || selectedMyItemData!['thumbnail_url'].isEmpty
                                          ? const Icon(Icons.image, color: Colors.grey) : null,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(selectedMyItemData?['title'] ?? 'ไม่ระบุชื่อ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: const Color(0xFF00C853).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.layers, size: 10, color: Color(0xFF00C853)),
                                                    const SizedBox(width: 4),
                                                    Text('~${selectedMyItemData?['estimated_coins'] ?? 0} Coins', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00C853))),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  value: selectedMyItemId,
                                                  icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                                                  style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
                                                  isDense: true,
                                                  items: items.map((item) => DropdownMenuItem(value: item.listingId, child: Text(item.title))).toList(),
                                                  onChanged: (val) {
                                                    setModalState(() {
                                                      selectedMyItemId = val;
                                                      var selectedItem = items.firstWhere((item) => item.listingId == val);
                                                      selectedMyItemData = selectedItem.toJson();
                                                      selectedMyItemData!['listing_id'] = selectedItem.listingId;
                                                    });
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        const Text('BALANCE THE TRADE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.blueGrey, letterSpacing: 0.5)),
                        const SizedBox(height: 12),
                        
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setModalState(() => offerType = 'give'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: offerType == 'give' ? const Color(0xFF00C853) : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.arrow_upward, size: 18, color: offerType == 'give' ? Colors.white : Colors.grey.shade500),
                                      const SizedBox(height: 4),
                                      Text('แถมเหรียญ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: offerType == 'give' ? Colors.white : Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setModalState(() { offerType = 'none'; coinOffset = 0; }), 
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: offerType == 'none' ? const Color(0xFF008080) : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.sync_alt, size: 18, color: offerType == 'none' ? Colors.white : Colors.grey.shade500),
                                      const SizedBox(height: 4),
                                      Text('แลกของเท่านั้น', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: offerType == 'none' ? Colors.white : Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setModalState(() => offerType = 'ask'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: offerType == 'ask' ? const Color(0xFFFF5252) : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.arrow_downward, size: 18, color: offerType == 'ask' ? Colors.white : Colors.grey.shade500),
                                      const SizedBox(height: 4),
                                      Text('ขอเหรียญเพิ่ม', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: offerType == 'ask' ? Colors.white : Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        if (offerType != 'none')
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200)
                            ),
                            child: TextField(
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                              decoration: InputDecoration(
                                hintText: '0',
                                hintStyle: TextStyle(color: Colors.grey.shade400),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.only(left: 20, right: 10),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: Colors.amber, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.4), blurRadius: 4)]),
                                    child: const Icon(Icons.layers, size: 16, color: Colors.white),
                                  ),
                                ),
                                suffixIcon: const Padding(
                                  padding: EdgeInsets.only(right: 20, top: 12),
                                  child: Text('coins', style: TextStyle(fontSize: 14, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                                )
                              ),
                              onChanged: (val) => coinOffset = int.tryParse(val) ?? 0,
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text('ใช้สิ่งของแลกเปลี่ยนกันโดยตรง ไม่มีการใช้เหรียญ', style: TextStyle(color: Colors.grey.shade500, fontSize: 13))
                            ),
                          ),
                          
                        const SizedBox(height: 32),

                        BlocConsumer<OfferCubit, OfferState>(
                          listener: (context, state) {
                            if (state is OfferSuccess && state.message != 'ส่งข้อเสนอเรียบร้อยแล้ว' && state.message != 'ตกลงรับข้อเสนอเรียบร้อยแล้ว!') {
                              final navigator = Navigator.of(context);
                              if (context.mounted) {
                                navigator.pop();
                                navigator.push(MaterialPageRoute(builder: (context) => ChatScreen(roomId: state.message)));
                              }
                            } else if (state is OfferError) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
                            }
                          },
                          builder: (context, state) {
                            bool isSubmitting = state is OfferSubmitting;
                            return ElevatedButton.icon(
                              onPressed: isSubmitting ? null : () async {
                                bool isVerified = await context.read<AuthRepository>().isEmailVerified();
                                if (!isVerified) {
                                  if (context.mounted) _showVerificationDialog(context, tealColor);
                                  return;
                                }

                                if (selectedMyItemId == null) {
                                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาเลือกสิ่งของของคุณก่อนยื่นข้อเสนอครับ'), behavior: SnackBarBehavior.floating));
                                   return;
                                }

                                String coinText = "";
                                int finalCoinOffset = 0;
                                
                                if (offerType != 'none' && coinOffset > 0) {
                                  finalCoinOffset = offerType == 'ask' ? -coinOffset : coinOffset;
                                  coinText = " และยินดี${offerType == 'ask' ? 'ขอรับเหรียญเพิ่ม' : 'แถมเหรียญให้'} $coinOffset Coins";
                                }
                                
                                final offer = OfferModel(
                                  offerId: '',
                                  senderId: currentUserId,
                                  targetUserId: listing.ownerId,
                                  targetListingId: listing.listingId,
                                  offeredListingId: selectedMyItemId!,
                                  coinOffset: finalCoinOffset,
                                  status: 'pending',
                                );

                                context.read<OfferCubit>().submitNewOffer(
                                  offer: offer, 
                                  targetItemData: listing.toJson(), 
                                  offeredItemData: selectedMyItemData!, 
                                  coinText: coinText
                                );
                              },
                              icon: isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.chat_bubble, color: Colors.white, size: 20),
                              label: Text(isSubmitting ? 'กำลังส่งข้อเสนอ...' : 'Confirm & Start Chat', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF008080), 
                                minimumSize: const Size(double.infinity, 56), 
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 4,
                                shadowColor: const Color(0xFF008080).withOpacity(0.5)
                              ),
                            );
                          }
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}