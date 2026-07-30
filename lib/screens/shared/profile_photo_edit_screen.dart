// ====================================================
// ====== شاشة تعديل صورة البروفايل قبل الحفظ ======
// بتفتح فور ما المستخدم يختار صورة (من المعرض أو الكاميرا) وقبل ما تتبعت
// لـ ProfilePhotoValidator. بتسمح له يكبّر/يصغّر ويسحب الصورة جوه دائرة
// القص، وبعدين "حفظ" بيرجّع الصورة النهائية بعد القص كـ Uint8List،
// أو "إلغاء" بيرجّع null (يعني نفضل مستخدمين الصورة القديمة/محدش اتغيّر) ======
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/theme/theme_extensions.dart';

class ProfilePhotoEditScreen extends StatefulWidget {
  final Uint8List imageBytes;

  const ProfilePhotoEditScreen({super.key, required this.imageBytes});

  @override
  State<ProfilePhotoEditScreen> createState() =>
      _ProfilePhotoEditScreenState();
}

class _ProfilePhotoEditScreenState extends State<ProfilePhotoEditScreen> {
  // ====== حجم دائرة القص على الشاشة (بالـ logical pixels) ======
  static const double _cropSize = 280;

  final TransformationController _transformationController =
      TransformationController();
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  bool _isSaving = false;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  // ====== نحوّل اللي ظاهر جوه دائرة القص بس (مش الصورة كلها) لـ PNG bytes
  // عن طريق تصوير الـ RepaintBoundary اللي لافّة منطقة القص ======
  Future<void> _saveCroppedImage() async {
    setState(() => _isSaving = true);
    try {
      final boundary = _repaintBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) Navigator.of(context).pop(null);
        return;
      }
      // ====== دقة أعلى من حجم العرض الفعلي عشان الصورة النهائية متكونش
      // مبكسلة لو المستخدم فتحها بحجم أكبر بعدين ======
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        if (mounted) Navigator.of(context).pop(null);
        return;
      }
      final bytes = byteData.buffer.asUint8List();
      if (mounted) Navigator.of(context).pop(bytes);
    } catch (e) {
      debugPrint('❌ خطأ في قص الصورة: $e');
      if (mounted) Navigator.of(context).pop(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(l10n.editPhotoTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(null),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 24),
          Text(
            l10n.editPhotoHint,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: ClipRect(
                child: RepaintBoundary(
                  key: _repaintBoundaryKey,
                  child: ClipOval(
                    child: SizedBox(
                      width: _cropSize,
                      height: _cropSize,
                      child: InteractiveViewer(
                        transformationController: _transformationController,
                        // ====== نسيبه يكبّر لغاية 4 أضعاف، ونمنع إنه يصغّر
                        // الصورة لحد ما تبقى أصغر من دائرة القص وتسيب فراغ ======
                        minScale: 1,
                        maxScale: 4,
                        boundaryMargin: const EdgeInsets.all(0),
                        child: Image.memory(
                          widget.imageBytes,
                          width: _cropSize,
                          height: _cropSize,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(null),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                    ),
                    child: Text(l10n.cancel),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveCroppedImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TayarColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(l10n.saveButton),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
