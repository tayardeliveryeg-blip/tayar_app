import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';

import 'package:tayay_app/theme/theme_extensions.dart';
import 'package:tayay_app/widgets/tayar_toast.dart';

// ====== صف "البيت" و"الشغل": بيسمعوا على users/{uid}.savedAddresses على
// فيرستور لايف. لو المكان لسه مش محفوظ، دوسة عليه بتفتح شاشة اختيار
// العنوان وتحفظه. لو محفوظ فعلًا، دوسة عادية بتستخدمه كوجهة على طول،
// وضغطة مطوّلة (long press) بتفتح شاشة الاختيار تاني عشان يتغيّر ======
class SavedPlacesRow extends StatelessWidget {
  final void Function(LatLng location, String address) onUseAddress;
  final void Function(String key, String screenTitle) onSaveAddress;
  final VoidCallback onAddTap;
  final String addLabel;

  const SavedPlacesRow({
    super.key,
    required this.onUseAddress,
    required this.onSaveAddress,
    required this.onAddTap,
    required this.addLabel,
  });

  void _handleTap(
    String key,
    Map<String, dynamic>? savedData,
    String screenTitle,
  ) {
    final lat = (savedData?['lat'] as num?)?.toDouble();
    final lng = (savedData?['lng'] as num?)?.toDouble();
    final address = savedData?['address'] as String?;

    if (lat == null || lng == null || address == null) {
      // مفيش عنوان محفوظ لسه: افتح شاشة الاختيار واحفظه
      onSaveAddress(key, screenTitle);
    } else {
      // العنوان محفوظ: استخدمه كوجهة على طول
      onUseAddress(LatLng(lat, lng), address);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Row(
        children: [
          Expanded(
            child: SavedPlaceChip(
              icon: Icons.home_outlined,
              label: loc.savedPlaceHome,
              onTap: () => onSaveAddress('home', loc.selectHomeAddressTitle),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: SavedPlaceChip(
              icon: Icons.work_outline,
              label: loc.savedPlaceWork,
              onTap: () => onSaveAddress('work', loc.selectWorkAddressTitle),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: SavedPlaceChip(
              icon: Icons.add,
              label: addLabel,
              onTap: onAddTap,
            ),
          ),
        ],
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final savedAddresses =
            snapshot.data?.data()?['savedAddresses'] as Map<String, dynamic>?;
        final home = savedAddresses?['home'] as Map<String, dynamic>?;
        final work = savedAddresses?['work'] as Map<String, dynamic>?;

        // ====== أي مفتاح تاني غير home/work هو مكان مخصّص اتضاف من زرار
        // "+ إضافة" (مفاتيحه بالشكل custom_<timestamp>)، فبيترتبوا
        // زمنيًا تلقائيًا من غير ما نحتاج نخزّن حقل ترتيب منفصل ======
        final customEntries =
            (savedAddresses?.entries.where(
                      (e) => e.key != 'home' && e.key != 'work',
                    ) ??
                    const <MapEntry<String, dynamic>>[])
                .toList()
              ..sort((a, b) => a.key.compareTo(b.key));

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SizedBox(
                width: 96,
                child: SavedPlaceChip(
                  icon: Icons.home_outlined,
                  label: loc.savedPlaceHome,
                  onTap: () => _handleTap('home', home, loc.savedPlaceHome),
                  onLongPress: () =>
                      onSaveAddress('home', loc.selectHomeAddressTitle),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 96,
                child: SavedPlaceChip(
                  icon: Icons.work_outline,
                  label: loc.savedPlaceWork,
                  onTap: () => _handleTap('work', work, loc.savedPlaceWork),
                  onLongPress: () =>
                      onSaveAddress('work', loc.selectWorkAddressTitle),
                ),
              ),
              for (final entry in customEntries) ...[
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 96,
                  child: SavedPlaceChip(
                    icon: Icons.star_outline,
                    label:
                        (entry.value as Map<String, dynamic>)['label']
                            as String? ??
                        (entry.value as Map<String, dynamic>)['address']
                            as String? ??
                        loc.savedPlaceAdd,
                    onTap: () {
                      final data = entry.value as Map<String, dynamic>;
                      final lat = (data['lat'] as num?)?.toDouble();
                      final lng = (data['lng'] as num?)?.toDouble();
                      final address = data['address'] as String?;
                      if (lat == null || lng == null || address == null) {
                        return;
                      }
                      onUseAddress(LatLng(lat, lng), address);
                    },
                    onLongPress: () =>
                        _confirmAndDeleteCustomPlace(context, uid, entry.key),
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 96,
                child: SavedPlaceChip(
                  icon: Icons.add,
                  label: addLabel,
                  onTap: onAddTap,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ====== حذف مكان محفوظ مخصّص: بيسأل تأكيد الأول، وبعدين بيمسح المفتاح
  // بتاعه من users/{uid}.savedAddresses باستخدام dot-notation مع
  // .update() (ده بيشتغل صح كمسار متداخل بعكس .set(merge:true)) ======
  Future<void> _confirmAndDeleteCustomPlace(
    BuildContext context,
    String uid,
    String key,
  ) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.bgColor,
        title: Text(
          loc.removeSavedPlaceTitle,
          style: TextStyle(color: context.textColor),
        ),
        content: Text(
          loc.removeSavedPlaceMessage,
          style: TextStyle(color: context.textGreyColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              loc.removeSavedPlaceButton,
              style: const TextStyle(color: TayarColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'savedAddresses.$key': FieldValue.delete(),
      });
      if (!context.mounted) return;
      TayarToast.show(context, loc.savedPlaceRemovedConfirmation, type: ToastType.success);
    } catch (e) {
      debugPrint('❌ خطأ في حذف مكان محفوظ مخصص ($key): $e');
    }
  }
}

// ====== شريحة مكان محفوظ (البيت / الشغل / إضافة) ======
class SavedPlaceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const SavedPlaceChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: TayarColors.primary, size: 15),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
