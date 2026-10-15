import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import '../theme/app_theme.dart';
import 'ui/dialog_header.dart';

class StudentVerificationDialog extends StatefulWidget {
  final UserModel user;

  const StudentVerificationDialog({super.key, required this.user});

  @override
  State<StudentVerificationDialog> createState() =>
      _StudentVerificationDialogState();
}

class _StudentVerificationDialogState extends State<StudentVerificationDialog> {
  final Color tealColor = AppColors.primary;
  String? _selectedFaculty;
  String? _selectedAcademicYear;
  bool _isLoading = false;

  final List<String> _faculties = const [
    'วิศวกรรมศาสตร์',
    'วิทยาศาสตร์',
    'วิทยาการจัดการ',
    'ศิลปศาสตร์',
    'ทรัพยากรธรรมชาติ',
    'เภสัชศาสตร์',
    'แพทยศาสตร์',
    'พยาบาลศาสตร์',
    'ทันตแพทยศาสตร์',
    'อื่นๆ'
  ];

  final List<String> _academicYears = const [
    'ชั้นปีที่ 1',
    'ชั้นปีที่ 2',
    'ชั้นปีที่ 3',
    'ชั้นปีที่ 4',
    'ชั้นปีที่ 5+',
    'ปริญญาโท',
    'ปริญญาเอก',
  ];

  @override
  void initState() {
    super.initState();
    _selectedFaculty = widget.user.faculty;
    _selectedAcademicYear = widget.user.academicYear;
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      bool isStudent = (_selectedFaculty != null &&
          _selectedFaculty!.isNotEmpty &&
          _selectedAcademicYear != null &&
          _selectedAcademicYear!.isNotEmpty);

      final updatedUser = widget.user.copyWith(
        faculty: _selectedFaculty,
        academicYear: _selectedAcademicYear,
        isStudent: isStudent,
        updatedAt: DateTime.now(),
      );

      await context.read<UserRepository>().updateUser(updatedUser);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required String hintText,
    required IconData icon,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(label, style: AppText.overline),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.hairline),
          ),
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            value: (value != null && items.contains(value)) ? value : null,
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: Icon(icon, color: AppColors.inkSecondary, size: 20),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            ),
            items: items.map((item) {
              return DropdownMenuItem(
                value: item,
                child: Text(
                  item,
                  style: AppText.body,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: onChanged,
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.inkTertiary),
            dropdownColor: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Column(
        children: [
          DialogHeader(
              icon: Icons.school_rounded,
              title: 'Student Verification',
              color: AppColors.student),
          SizedBox(height: 8),
          Text(
            'Tell us more about your studies to unlock student features!',
            textAlign: TextAlign.center,
            style: AppText.bodySecondary,
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDropdownField(
              label: 'FACULTY',
              value: _selectedFaculty,
              hintText: 'Select your faculty',
              icon: Icons.school_outlined,
              items: _faculties,
              onChanged: (val) => setState(() => _selectedFaculty = val),
            ),
            _buildDropdownField(
              label: 'ACADEMIC LEVEL',
              value: _selectedAcademicYear,
              hintText: 'Select your year or degree level',
              icon: Icons.calendar_today_outlined,
              items: _academicYears,
              onChanged: (val) => setState(() => _selectedAcademicYear = val),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.inkSecondary,
          ),
          child: const Text('Skip for now'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(minimumSize: const Size(96, 46)),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
