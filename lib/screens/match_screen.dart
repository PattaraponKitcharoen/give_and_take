import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/match/match_cubit.dart';
import '../cubits/match/match_state.dart';
import '../models/listing_model.dart';
import '../models/match_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/match_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/primary_button.dart';
import 'item_detail_screen.dart';

/// "แลกตามความต้องการ": the user lists what they want, and the server looks
/// in the background for people who have it AND want something back.
class MatchScreen extends StatelessWidget {
  const MatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthRepository>().currentUser?.uid ?? '';
    return BlocProvider(
      create: (context) => MatchCubit(
        matchRepository: context.read<MatchRepository>(),
        userId: userId,
      ),
      child: const _MatchView(),
    );
  }
}

class _MatchView extends StatelessWidget {
  const _MatchView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MatchCubit, MatchState>(
      listenWhen: (prev, next) =>
          next.message != null && next.message != prev.message,
      listener: (context, state) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(state.message!))),
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            title: const Text('แลกตามความต้องการ', style: AppText.title),
            centerTitle: false,
          ),
          body: state.loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => context.read<MatchCubit>().rescan(),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(AppSpace.page, 4,
                        AppSpace.page, 32 + MediaQuery.paddingOf(context).bottom),
                    children: [
                      _buildSwitchCard(context, state),
                      _sectionHeader(
                        'สิ่งที่ฉันอยากได้',
                        '${state.wants.length}/${MatchRepository.maxWants}',
                        action: state.wants.length < MatchRepository.maxWants
                            ? TextButton.icon(
                                onPressed: () => _showAddWant(context),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('เพิ่ม'),
                                style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primary),
                              )
                            : null,
                      ),
                      _buildWants(context, state),
                      _sectionHeader(
                        'แมตช์ที่เจอ',
                        state.matches.isEmpty ? '' : '${state.matches.length}',
                        action: state.rescanning
                            ? const Padding(
                                padding: EdgeInsets.all(8),
                                child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                              )
                            : null,
                      ),
                      ..._buildMatches(context, state),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildSwitchCard(BuildContext context, MatchState state) {
    final on = state.enabled;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.raised,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: on ? AppGradients.primary : null,
              color: on ? null : AppColors.surfaceMuted,
              boxShadow: on ? AppShadows.glow(AppColors.primary) : null,
            ),
            child: Icon(Icons.sync_alt_rounded,
                color: on ? Colors.white : AppColors.inkTertiary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(on ? 'กำลังหาคู่แลกให้อยู่' : 'หยุดหาไว้ชั่วคราว',
                    style: AppText.label.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                    on
                        ? 'เจอคนที่มีของที่คุณอยากได้ และอยากได้ของของคุณเมื่อไหร่ จะแจ้งเตือนทันที'
                        : 'เปิดอีกครั้งเมื่อต้องการให้ระบบหาคู่แลกต่อ',
                    style: AppText.caption),
              ],
            ),
          ),
          Switch.adaptive(
            value: on,
            activeColor: AppColors.primary,
            onChanged: (v) => context.read<MatchCubit>().setEnabled(v),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String count, {Widget? action}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 24, 0, 8),
      child: SizedBox(
        height: 36,
        child: Row(
          children: [
            Text(title, style: AppText.subtitle),
            if (count.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(count,
                  style: AppText.caption.copyWith(color: AppColors.inkTertiary)),
            ],
            const Spacer(),
            if (action != null) action,
          ],
        ),
      ),
    );
  }

  Widget _buildWants(BuildContext context, MatchState state) {
    if (state.wants.isEmpty) {
      return GestureDetector(
        onTap: () => _showAddWant(context),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            children: [
              const Icon(Icons.add_circle_outline_rounded,
                  color: AppColors.primary, size: 28),
              const SizedBox(height: 8),
              const Text('บอกเราว่าอยากได้อะไร', style: AppText.label),
              const SizedBox(height: 2),
              Text('เช่น "หูฟังบลูทูธ ใช้ออกกำลังกาย" หรือ "หนังสือเตรียมสอบ TOEIC"',
                  style: AppText.caption, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        children: [
          for (var i = 0; i < state.wants.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: 48, color: AppColors.hairline),
            _buildWantRow(context, state.wants[i], state),
          ],
        ],
      ),
    );
  }

  Widget _buildWantRow(BuildContext context, WantModel want, MatchState state) {
    final found =
        state.matches.where((m) => m.myWantText == want.text).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      child: Row(
        children: [
          const Icon(Icons.favorite_border_rounded,
              size: 20, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(want.text,
                    style: AppText.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                Text(found > 0 ? 'เจอ $found แมตช์' : 'กำลังหา…',
                    style: AppText.caption.copyWith(
                        fontSize: 11.5,
                        color: found > 0
                            ? AppColors.primary
                            : AppColors.inkTertiary)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'ลบ',
            icon: const Icon(Icons.close_rounded,
                size: 18, color: AppColors.inkTertiary),
            onPressed: () => context.read<MatchCubit>().deleteWant(want.id),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMatches(BuildContext context, MatchState state) {
    if (state.matches.isEmpty) {
      final String text;
      if (!state.enabled) {
        text = 'ระบบหยุดหาไว้อยู่ เปิดสวิตช์ด้านบนเพื่อหาต่อ';
      } else if (state.wants.isEmpty) {
        text = 'เพิ่มสิ่งที่อยากได้ แล้วระบบจะหาคู่แลกให้';
      } else {
        text =
            'ยังไม่เจอคู่แลก ระบบจะหาต่อเบื้องหลังและแจ้งเตือนเมื่อเจอ\nอย่าลืมลงประกาศของที่อยากเอามาแลกด้วยนะ';
      }
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
          child: Text(text,
              textAlign: TextAlign.center,
              style: AppText.bodySecondary.copyWith(height: 1.5)),
        ),
      ];
    }
    return state.matches.map((m) => _MatchCard(match: m)).toList();
  }

  void _showAddWant(BuildContext context) {
    final cubit = context.read<MatchCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (_) => _AddWantSheet(cubit: cubit),
    );
  }
}

// Owns its text controller so it is disposed only after the sheet has left
// the tree. Disposing it in showModalBottomSheet().whenComplete ran while
// the closing animation still showed the TextField and crashed the app.
class _AddWantSheet extends StatefulWidget {
  final MatchCubit cubit;
  const _AddWantSheet({required this.cubit});

  @override
  State<_AddWantSheet> createState() => _AddWantSheetState();
}

class _AddWantSheetState extends State<_AddWantSheet> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || _controller.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final ok = await widget.cubit.addWant(_controller.text);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpace.page, 20, AppSpace.page,
          20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('อยากได้อะไร', style: AppText.title),
          const SizedBox(height: 4),
          const Text(
              'พิมพ์สั้นๆ ว่าเป็นของอะไร ใส่รุ่นหรือการใช้งานได้ ระบบจะหาของที่ใกล้เคียงให้',
              style: AppText.caption),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 120,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration:
                const InputDecoration(hintText: 'หูฟังบลูทูธ ใช้ออกกำลังกาย'),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              onPressed: _submit,
              isLoading: _saving,
              child: const Text('เพิ่ม'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final MatchModel match;
  const _MatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final theirs = match.theirListing!;
    final mine = match.myListing!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.raised,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ItemDetailScreen(
                listing: theirs,
                preselectedOfferListingId: match.myListingId,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _thumb(theirs),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(Icons.sync_alt_rounded,
                          color: AppColors.primary, size: 22),
                    ),
                    _thumb(mine),
                    const Spacer(),
                    if (!match.seen)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: const Text('ใหม่',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _line('ของเขา', theirs.title, theirs.estimatedCoins),
                const SizedBox(height: 4),
                _line('ของคุณ', mine.title, mine.estimatedCoins),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'ตรงกับที่คุณอยากได้ '),
                      TextSpan(
                          text: '"${match.myWantText}"',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const TextSpan(text: '\nและเขาก็อยากได้ '),
                      TextSpan(
                          text: '"${match.theirWantText}"',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ]),
                    style: AppText.caption.copyWith(
                        color: AppColors.primaryDark, height: 1.45),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text('${theirs.ownerName} · ดูของและยื่นข้อเสนอ',
                          style: AppText.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        size: 20, color: AppColors.inkTertiary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumb(ListingModel l) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: 64,
        height: 64,
        color: AppColors.surfaceMuted,
        child: l.thumbnailUrl.isNotEmpty
            ? Image.network(l.thumbnailUrl, fit: BoxFit.cover)
            : const Icon(Icons.image_outlined, color: AppColors.inkTertiary),
      ),
    );
  }

  Widget _line(String label, String title, int coins) {
    return Row(
      children: [
        SizedBox(
            width: 46,
            child: Text(label,
                style: AppText.caption.copyWith(color: AppColors.inkTertiary))),
        Expanded(
          child: Text(title,
              style: AppText.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.toll_rounded, size: 13, color: AppColors.primaryDark),
        const SizedBox(width: 3),
        Text('$coins',
            style: AppText.caption.copyWith(
                color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
