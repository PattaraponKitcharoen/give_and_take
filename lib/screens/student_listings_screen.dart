import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/student_listings/student_listings_cubit.dart';
import '../cubits/student_listings/student_listings_state.dart';
import '../repositories/auth_repository.dart';
import '../repositories/listing_repository.dart';
import '../repositories/user_repository.dart';
import '../widgets/listing_grid_card.dart';
import '../theme/app_theme.dart';

/// Destination of the home feed's "Student" banner — every active listing
/// whose owner is a verified student (UserModel.isStudent), for people who
/// only want to trade with fellow students.
class StudentListingsScreen extends StatelessWidget {
  const StudentListingsScreen({super.key});

  static const Color _studentColor = AppColors.student;

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
        appBar: AppBar(
          title: const Text('สินค้าจากนักศึกษา'),
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
                    style: AppText.bodySecondary,
                  ),
                ));
              }

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.64),
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
