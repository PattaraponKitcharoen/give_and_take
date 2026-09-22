import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

/// One entry in a [MultiImagePickerWidget]'s image list — either a photo
/// already uploaded to Storage ([NetworkPickedImage]) or one picked on this
/// screen and not yet uploaded ([LocalPickedImage]). Both carry
/// [isFromCamera] so the "Camera" badge renders the same way regardless of
/// whether the photo is a fresh pick or one loaded back from Firestore.
sealed class PickedImageEntry {
  const PickedImageEntry();
  bool get isFromCamera;
}

class LocalPickedImage extends PickedImageEntry {
  final File file;
  @override
  final bool isFromCamera;
  const LocalPickedImage(this.file, {this.isFromCamera = false});
}

class NetworkPickedImage extends PickedImageEntry {
  final String url;
  @override
  final bool isFromCamera;
  const NetworkPickedImage(this.url, {this.isFromCamera = false});
}

/// A horizontal, reorderable, up-to-[maxImages] photo picker: pick from
/// Gallery/Camera, crop to a square, long-press to drag-reorder, tap "X" to
/// remove. The first image acts as the cover photo.
///
/// This widget is stateless/controlled — the caller owns the `images` list
/// (in its own State) and gets the updated list back via [onChanged], the
/// same way a [TextField] is driven by a [TextEditingController] owner.
class MultiImagePickerWidget extends StatelessWidget {
  final List<PickedImageEntry> images;
  final ValueChanged<List<PickedImageEntry>> onChanged;
  final Color primaryColor;
  final int maxImages;
  final double thumbSize;

  const MultiImagePickerWidget({
    super.key,
    required this.images,
    required this.onChanged,
    required this.primaryColor,
    this.maxImages = 6,
    this.thumbSize = 130,
  });

  bool get _canAddMore => images.length < maxImages;

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    if (!_canAddMore) return;

    try {
      final XFile? picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (picked == null) return;

      final CroppedFile? cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 85,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'ครอปรูปภาพ',
            toolbarColor: primaryColor,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: primaryColor,
            backgroundColor: Colors.black,
            initAspectRatio: CropAspectRatioPreset.square,
            aspectRatioPresets: const [CropAspectRatioPreset.square],
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'ครอปรูปภาพ',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
            aspectRatioPresets: const [CropAspectRatioPreset.square],
          ),
        ],
      );

      // cropped == null means the user cancelled the crop screen — leave the
      // list untouched instead of crashing.
      if (cropped == null || !context.mounted) return;

      // Guard against the list having filled up while the picker/cropper
      // sheet was open (e.g. a rebuild from elsewhere added images).
      if (!_canAddMore) return;

      final updated = List<PickedImageEntry>.from(images)
        ..add(LocalPickedImage(File(cropped.path), isFromCamera: source == ImageSource.camera));
      onChanged(updated);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('ไม่สามารถเลือกรูปภาพได้'), backgroundColor: Colors.red.shade600, behavior: SnackBarBehavior.floating));
      }
    }
  }

  void _removeAt(int index) {
    final updated = List<PickedImageEntry>.from(images)..removeAt(index);
    onChanged(updated);
  }

  void _reorder(int oldIndex, int newIndex) {
    final updated = List<PickedImageEntry>.from(images);
    if (newIndex >= updated.length) newIndex = updated.length - 1;
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    onChanged(updated);
  }

  void _showImageSourceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: primaryColor),
                title: const Text('เลือกจากคลังภาพ'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage(context, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_outlined, color: primaryColor),
                title: const Text('ถ่ายรูป'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage(context, ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        images.isEmpty ? _buildEmptyState(context) : _buildImagesRow(context),
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'อัปโหลดได้สูงสุด $maxImages รูป · กดค้างที่รูปเพื่อลากจัดเรียง · รูปแรกจะเป็นรูปหน้าปก',
              maxLines: 1,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.camera_alt, color: primaryColor, size: 28),
          ),
          const SizedBox(height: 12),
          const Text('Cover Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
          const SizedBox(height: 4),
          Text('แตะเพื่ออัปโหลดหรือถ่ายรูป', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(onPressed: () => _pickImage(context, ImageSource.gallery), icon: Icon(Icons.photo_library_outlined, size: 16, color: Colors.grey.shade700), label: Text('Gallery', style: TextStyle(color: Colors.grey.shade700))),
              const SizedBox(width: 16),
              TextButton.icon(onPressed: () => _pickImage(context, ImageSource.camera), icon: Icon(Icons.camera_alt_outlined, size: 16, color: Colors.grey.shade700), label: Text('Camera', style: TextStyle(color: Colors.grey.shade700))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String label, Color backgroundColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildThumbImage(PickedImageEntry entry) {
    return switch (entry) {
      LocalPickedImage(:final file) => Image.file(file, width: thumbSize, height: thumbSize, fit: BoxFit.cover),
      NetworkPickedImage(:final url) => Image.network(
          url,
          width: thumbSize,
          height: thumbSize,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              width: thumbSize,
              height: thumbSize,
              color: Colors.grey.shade200,
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
          errorBuilder: (context, error, stackTrace) => Container(
            width: thumbSize,
            height: thumbSize,
            color: Colors.grey.shade200,
            child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
          ),
        ),
    };
  }

  Widget _buildThumb(BuildContext context, int index) {
    final entry = images[index];
    final isFromCamera = entry.isFromCamera;
    final entryKey = switch (entry) {
      LocalPickedImage(:final file) => 'local:${file.path}',
      NetworkPickedImage(:final url) => 'network:$url',
    };

    return ReorderableDelayedDragStartListener(
      key: ValueKey(entryKey),
      index: index,
      child: Padding(
        // top inset gives the overflowing delete button (Positioned top:-6)
        // room to render without being clipped by the list's viewport edge.
        padding: const EdgeInsets.only(top: 8, right: 10),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(14), child: _buildThumbImage(entry)),
            if (isFromCamera)
              Positioned(top: 6, left: 6, child: _buildBadge(Icons.camera_alt, 'Camera', Colors.black.withOpacity(0.6))),
            if (index == 0)
              Positioned(
                bottom: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(6)),
                  child: const Text('Cover', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
            Positioned(
              top: -6,
              right: -6,
              child: GestureDetector(
                onTap: () => _removeAt(index),
                child: const CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddTile(BuildContext context) {
    return Padding(
      key: const ValueKey('add_image_tile'),
      padding: const EdgeInsets.only(top: 8, right: 10),
      child: Opacity(
        opacity: _canAddMore ? 1 : 0.4,
        child: GestureDetector(
          onTap: _canAddMore ? () => _showImageSourceSheet(context) : null,
          child: Container(
            width: thumbSize,
            height: thumbSize,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: primaryColor.withOpacity(0.3), width: 1.5),
            ),
            child: Icon(Icons.add_photo_alternate_outlined, color: primaryColor, size: 28),
          ),
        ),
      ),
    );
  }

  Widget _buildImagesRow(BuildContext context) {
    return SizedBox(
      // + 16 (not the image's own +8) leaves headroom both above (for the
      // delete button overflow) and below the thumbnails.
      height: thumbSize + 16,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: false,
        itemCount: images.length + 1,
        onReorderItem: (oldIndex, newIndex) {
          // The trailing add tile has no drag listener, so it can never be
          // the one being dragged — this guard is just defensive.
          if (oldIndex >= images.length) return;
          _reorder(oldIndex, newIndex);
        },
        itemBuilder: (context, index) {
          if (index == images.length) return _buildAddTile(context);
          return _buildThumb(context, index);
        },
      ),
    );
  }
}
