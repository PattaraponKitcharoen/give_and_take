import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';

class StudentVerificationDialog extends StatefulWidget {
  final UserModel user;

  const StudentVerificationDialog({super.key, required this.user});

  @override
  State<StudentVerificationDialog> createState() => _StudentVerificationDialogState();
}

class _StudentVerificationDialogState extends State<StudentVerificationDialog> {
  final Color tealColor = const Color(0xFF10B981);
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

  final List<String> _academicYears = const ['ปี 1', 'ปี 2', 'ปี 3', 'ปี 4', 'ปี 5+'];

  @override
  void initState() {
    super.initState();
    _selectedFaculty = widget.user.faculty;
    _selectedAcademicYear = widget.user.academicYear;
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      bool isStudent = (_selectedFaculty != null && _selectedFaculty!.isNotEmpty &&
          _selectedAcademicYear != null && _selectedAcademicYear!.isNotEmpty);

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
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            value: (value != null && items.contains(value)) ? value : null,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            ),
            items: items.map((item) {
              return DropdownMenuItem(
                value: item,
                child: Text(
                  item,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: onChanged,
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade400),
            dropdownColor: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        children: [
          Icon(Icons.school, size: 48, color: tealColor),
          const SizedBox(height: 16),
          const Text(
            'Student Verification',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tell us more about your studies to unlock student features!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.blueGrey),
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
              label: 'ACADEMIC YEAR',
              value: _selectedAcademicYear,
              hintText: 'Select your academic year',
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
            foregroundColor: Colors.grey.shade600,
          ),
          child: const Text('Skip for now'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: tealColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
