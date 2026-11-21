import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/account/delete_account_cubit.dart';
import '../repositories/auth_repository.dart';
import '../theme/app_theme.dart';

/// What gets deleted and what stays, then a fresh sign-in (password or
/// Google) and typing the confirm word before the account is deleted.
class DeleteAccountScreen extends StatelessWidget {
  const DeleteAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          DeleteAccountCubit(authRepository: context.read<AuthRepository>()),
      child: const _DeleteAccountView(),
    );
  }
}

const _confirmWord = 'ลบบัญชี';

class _DeleteAccountView extends StatefulWidget {
  const _DeleteAccountView();

  @override
  State<_DeleteAccountView> createState() => _DeleteAccountViewState();
}

class _DeleteAccountViewState extends State<_DeleteAccountView> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void initState() {
    super.initState();
    _password.addListener(_refresh);
    _confirm.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DeleteAccountCubit>();
    final usesPassword = cubit.provider == 'password';
    return BlocConsumer<DeleteAccountCubit, DeleteAccountState>(
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context);
        if (state.step == DeleteAccountStep.failed) {
          messenger.showSnackBar(SnackBar(
              content: Text(state.message ?? 'ลบบัญชีไม่สำเร็จ'),
              behavior: SnackBarBehavior.floating));
        } else if (state.step == DeleteAccountStep.done) {
          // Signed out: the root already shows the login screen underneath.
          Navigator.of(context).popUntil((route) => route.isFirst);
          messenger.showSnackBar(const SnackBar(
              content: Text('ลบบัญชีเรียบร้อยแล้ว'),
              behavior: SnackBarBehavior.floating));
        }
      },
      builder: (context, state) {
        final working = state.step == DeleteAccountStep.working ||
            state.step == DeleteAccountStep.done;
        final ready = _confirm.text.trim() == _confirmWord &&
            (!usesPassword || _password.text.isNotEmpty) &&
            !working;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('ลบบัญชี', style: AppText.title),
            backgroundColor: AppColors.background,
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _card(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  children: const [
                    Row(children: [
                      Icon(Icons.warning_amber_rounded,
                          color: AppColors.danger),
                      SizedBox(width: 8),
                      Expanded(
                          child: Text('การลบบัญชีย้อนกลับไม่ได้',
                              style: TextStyle(
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.w600))),
                    ]),
                  ],
                ),
                const SizedBox(height: 16),
                _card(children: [
                  const Text('สิ่งที่จะถูกลบ', style: AppText.overline),
                  const SizedBox(height: 8),
                  ..._bullets(const [
                    'ข้อมูลส่วนตัว: ชื่อ อีเมล เบอร์โทร รูปโปรไฟล์ และข้อมูลแนะนำตัว',
                    'ประกาศที่ยังไม่ได้แลก พร้อมรูปภาพ',
                    'สิ่งที่อยากได้ และคู่แลกที่ระบบจับให้',
                    'ข้อเสนอที่ยังรอตอบ (ระบบจะยกเลิกและแจ้งอีกฝ่ายในแชท)',
                    'เหรียญคงเหลือทั้งหมด',
                  ]),
                ]),
                const SizedBox(height: 12),
                _card(children: [
                  const Text('สิ่งที่ยังเก็บไว้', style: AppText.overline),
                  const SizedBox(height: 8),
                  ..._bullets(const [
                    'แชท รีวิว และประวัติการแลกที่อีกฝ่ายยังต้องใช้ โดยจะแสดงชื่อคุณเป็น "ผู้ใช้ที่ลบบัญชีแล้ว"',
                  ]),
                ]),
                const SizedBox(height: 12),
                const Text(
                  'ถ้ามีการแลกที่ตกลงแล้วแต่ยังไม่ส่งมอบ ต้องส่งมอบหรือยกเลิกให้เรียบร้อยก่อน\nหากสมัครใหม่ด้วยอีเมลเดิม จะไม่ได้รับเหรียญเริ่มต้นอีก',
                  style: AppText.caption,
                ),
                const SizedBox(height: 24),
                if (usesPassword) ...[
                  TextField(
                    key: const Key('delete-password'),
                    controller: _password,
                    obscureText: true,
                    enabled: !working,
                    decoration:
                        const InputDecoration(labelText: 'รหัสผ่านปัจจุบัน'),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  key: const Key('delete-confirm'),
                  controller: _confirm,
                  enabled: !working,
                  decoration: const InputDecoration(
                      labelText: 'พิมพ์ "$_confirmWord" เพื่อยืนยัน'),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('delete-submit'),
                  onPressed: ready
                      ? () {
                          FocusScope.of(context).unfocus();
                          cubit.delete(
                              password: usesPassword ? _password.text : null);
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  child: working
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : Text(usesPassword
                          ? 'ลบบัญชีถาวร'
                          : 'ยืนยันด้วย Google และลบบัญชี'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _card({required List<Widget> children, Color? color}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color ?? AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: color == null ? AppShadows.raised : null,
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  List<Widget> _bullets(List<String> items) => [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('•  ', style: AppText.body),
              Expanded(child: Text(item, style: AppText.body)),
            ]),
          ),
      ];
}
