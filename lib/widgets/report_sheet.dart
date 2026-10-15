import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/report/report_cubit.dart';
import '../repositories/auth_repository.dart';
import '../repositories/report_repository.dart';
import '../theme/app_theme.dart';
import 'ui/primary_button.dart';

const _reasons = {
  ReportTarget.listing: [
    'ของผิดกฎหมายหรือต้องห้าม',
    'ของปลอม / ละเมิดลิขสิทธิ์',
    'รูปหรือรายละเอียดไม่ตรงกับของจริง',
    'หลอกลวง / ชวนโอนเงินนอกแอป',
    'สแปม / ลงซ้ำ',
    'อื่นๆ',
  ],
  ReportTarget.user: [
    'โกง / หลอกลวง',
    'ไม่มาตามนัดหรือเบี้ยวดีล',
    'คุกคาม / ใช้คำหยาบ',
    'บัญชีปลอม / แอบอ้างเป็นคนอื่น',
    'อื่นๆ',
  ],
  ReportTarget.chat: [
    'คุกคาม / ใช้คำหยาบ',
    'ชวนโอนเงินหรือทำธุรกรรมนอกแอป',
    'ส่งเนื้อหาไม่เหมาะสม',
    'สแปม',
    'อื่นๆ',
  ],
};

const _titles = {
  ReportTarget.listing: 'รายงานประกาศนี้',
  ReportTarget.user: 'รายงานผู้ใช้นี้',
  ReportTarget.chat: 'รายงานแชทนี้',
};

/// Opens the report sheet for a listing, user or chat room.
void showReportSheet(BuildContext context,
    {required ReportTarget type, required String targetId}) {
  final reporterId = context.read<AuthRepository>().currentUser?.uid;
  if (reporterId == null) return;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
    builder: (_) => BlocProvider(
      create: (_) => ReportCubit(
        repository: context.read<ReportRepository>(),
        reporterId: reporterId,
        type: type,
        targetId: targetId,
      ),
      child: _ReportSheet(type: type),
    ),
  );
}

class _ReportSheet extends StatefulWidget {
  final ReportTarget type;
  const _ReportSheet({required this.type});

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _detail = TextEditingController();
  String? _reason;

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpace.page, 20, AppSpace.page,
          20 + MediaQuery.viewInsetsOf(context).bottom),
      child: BlocConsumer<ReportCubit, ReportState>(
        listener: (context, state) {
          if (state.step == ReportStep.failed) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('ส่งรายงานไม่สำเร็จ ลองใหม่อีกครั้ง')));
          }
        },
        builder: (context, state) {
          switch (state.step) {
            case ReportStep.checking:
              return const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()));
            case ReportStep.alreadyReported:
              return _done('คุณรายงานไปแล้ว',
                  'ทีมงานกำลังตรวจสอบ จะแจ้งให้ทราบเมื่อตรวจสอบเสร็จ');
            case ReportStep.sent:
              return _done('ส่งรายงานแล้ว',
                  'ขอบคุณที่ช่วยให้ Give & Take ปลอดภัยขึ้น ทีมงานจะตรวจสอบและแจ้งให้ทราบ');
            default:
              return _form(context, state.step == ReportStep.submitting);
          }
        },
      ),
    );
  }

  Widget _form(BuildContext context, bool submitting) {
    final reasons = _reasons[widget.type]!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_titles[widget.type]!, style: AppText.title),
        const SizedBox(height: 4),
        const Text('ผู้ถูกรายงานจะไม่รู้ว่าใครเป็นคนรายงาน',
            style: AppText.caption),
        const SizedBox(height: 12),
        for (final r in reasons)
          RadioListTile<String>(
            value: r,
            groupValue: _reason,
            onChanged: submitting ? null : (v) => setState(() => _reason = v),
            title: Text(r, style: AppText.body),
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
          ),
        const SizedBox(height: 4),
        TextField(
          controller: _detail,
          maxLength: 500,
          maxLines: 3,
          minLines: 1,
          enabled: !submitting,
          decoration: const InputDecoration(
              hintText: 'รายละเอียดเพิ่มเติม (ไม่บังคับ)'),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: PrimaryButton(
            color: AppColors.danger,
            isLoading: submitting,
            onPressed: _reason == null
                ? null
                : () => context
                    .read<ReportCubit>()
                    .submit(_reason!, _detail.text),
            child: const Text('ส่งรายงาน'),
          ),
        ),
      ],
    );
  }

  Widget _done(String title, String body) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        const Icon(Icons.check_circle_rounded,
            color: AppColors.success, size: 48),
        const SizedBox(height: 12),
        Text(title, style: AppText.title),
        const SizedBox(height: 6),
        Text(body, style: AppText.bodySecondary, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.hairline),
            ),
            child: const Text('ปิด'),
          ),
        ),
      ],
    );
  }
}
