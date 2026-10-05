import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/student_listings/student_listings_cubit.dart';
import '../cubits/student_listings/student_listings_state.dart';
import '../repositories/auth_repository.dart';
import '../repositories/listing_repository.dart';
import '../repositories/user_repository.dart';
import '../widgets/listing_grid_card.dart';

/// Destination of the home feed's "Student" banner — every active listing
/// whose owner is a verified student (UserModel.isStudent), for people who
/// only want to trade with fellow students.
class StudentListingsScreen extends StatelessWidget {
  const StudentListingsScreen({super.key});

  static const Color _studentColor = Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthRepository>().currentUser?.uid ?? '';

    return BlocProvider(
      create: (context) => StudentListingsCubit(
        listingRepository: context.read<ListingRepository>(),
        userRepository: context.read<UserRepository>(),
        currentUserId: currentUserId,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black87),
          title: const Text('สินค้าจากนักศึกษา',
              style: TextStyle(
                  color: Color(0xFF004D40), fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: BlocBuilder<StudentListingsCubit, StudentListingsState>(
          builder: (context, state) {
            if (state is StudentListingsLoading) {
              return const Center(
                  child: CircularProgressIndicator(color: _studentColor));
            }
            if (state is StudentListingsError) {
              return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'));
            }
            if (state is StudentListingsLoaded) {
              if (state.items.isEmpty) {
                return const Center(
                    child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'ยังไม่มีสิ่งของจากนักศึกษาที่ยืนยันตัวตนในขณะนี้',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ));
              }

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.62),
                itemCount: state.items.length,
                itemBuilder: (context, index) {
                  final item = state.items[index];
                  final isWishlisted = state.wishlist.contains(item.listingId);
                  return ListingGridCard(
                    item: item,
                    isWishlisted: isWishlisted,
                    accentColor: _studentColor,
                    onToggleWishlist: (item) => context
                        .read<StudentListingsCubit>()
                        .toggleWishlist(item),
                  );
                },
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
