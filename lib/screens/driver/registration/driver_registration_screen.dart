import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart' show TayarColors, TayarThemeColors;
import 'package:tayay_app/screens/driver/driver_home_screen.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';

import 'package:tayay_app/screens/driver/registration/personal_info_screen.dart';
import 'package:tayay_app/screens/driver/registration/driving_license_screen.dart';
import 'package:tayay_app/screens/driver/registration/personal_documents_screen.dart';
import 'package:tayay_app/screens/driver/registration/bike_info_screen.dart';
class DriverRegistrationScreen extends StatefulWidget {
  const DriverRegistrationScreen({super.key});

  @override
  State<DriverRegistrationScreen> createState() =>
      _Dr9yMnTm4NSzvG9rrwjM2ec8xZgh1cafXH8();
}

class _Dr9yMnTm4NSzvG9rrwjM2ec8xZgh1cafXH8
    extends State<DriverRegistrationScreen> {
  Map<String, dynamic>? _driverData;
  bool _isLoading = true;
  bool _isSubmitting = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  Future<void> _loadDriverData() async {
    if (_uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(_uid)
          .get();
      setState(() {
        _driverData = doc.data();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ خطأ في تحميل بيانات الطيار: $e');
      setState(() => _isLoading = false);
    }
  }

  bool _isSectionComplete(String key) {
    return _driverData?[key]?['complete'] == true;
  }

  Future<void> _openSection(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _loadDriverData(); // نحدث حالة الأقسام بعد الرجوع
  }

  bool get _allSectionsComplete =>
      _isSectionComplete('personalInfo') &&
      _isSectionComplete('drivingLicense') &&
      _isSectionComplete('personalDocuments') &&
      _isSectionComplete('bikeInfo');

  Future<void> _submitRegistration() async {
    if (_uid == null || !_allSectionsComplete) return;
    setState(() => _isSubmitting = true);
    try {
      await FirebaseFirestore.instance.collection('drivers').doc(_uid).set({
        'status': 'pending_review', // pending_review → approved → rejected
        'submittedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      final loc = AppLocalizations.of(context)!;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: context.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Column(
            children: [
              const Icon(
                Icons.hourglass_top,
                color: TayarColors.primary,
                size: 56,
              ),
              const SizedBox(height: 12),
              Text(
                loc.submitApplicationSuccessTitle,
                style: TextStyle(color: context.textColor),
              ),
            ],
          ),
          content: Text(
            loc.submitApplicationSuccessBody,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textGreyColor),
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // يقفل الـ dialog
                  Navigator.of(context).pop(); // يرجع لشاشة الراكب
                },
                child: Text(
                  loc.ok,
                  style: const TextStyle(color: TayarColors.primary),
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('❌ خطأ في إرسال طلب التسجيل: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.submitFailedError),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // لو الطيار مسجل بالفعل ومقبول، نوديه على طول لشاشة الطلبات
    final status = _driverData?['status'];
    if (!_isLoading && status == 'approved') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
        );
      });
    }

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        title: Text(
          AppLocalizations.of(context)!.driverRegistrationTitle,
          style: TextStyle(color: context.textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context)!.closeButton,
              style: TextStyle(color: context.textGreyColor),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: TayarColors.primary),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (status == 'pending_review')
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: TayarColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: TayarColors.primary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(
                          context,
                        )!.applicationUnderReviewBanner,
                        style: TextStyle(color: context.textColor),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Text(
                      AppLocalizations.of(context)!.registrationIntroText,
                      style: TextStyle(
                        color: context.textGreyColor,
                        fontSize: 14,
                      ),
                    ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView(
                      children: [
                        _SectionTile(
                          title: AppLocalizations.of(
                            context,
                          )!.sectionPersonalInfo,
                          isComplete: _isSectionComplete('personalInfo'),
                          onTap: () => _openSection(const PersonalInfoScreen()),
                        ),
                        _SectionTile(
                          title: AppLocalizations.of(
                            context,
                          )!.sectionDrivingLicense,
                          isComplete: _isSectionComplete('drivingLicense'),
                          onTap: () =>
                              _openSection(const DrivingLicenseScreen()),
                        ),
                        _SectionTile(
                          title: AppLocalizations.of(
                            context,
                          )!.sectionPersonalDocuments,
                          isComplete: _isSectionComplete('personalDocuments'),
                          onTap: () =>
                              _openSection(const PersonalDocumentsScreen()),
                        ),
                        _SectionTile(
                          title: AppLocalizations.of(context)!.sectionBikeInfo,
                          isComplete: _isSectionComplete('bikeInfo'),
                          onTap: () => _openSection(const BikeInfoScreen()),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed:
                          (_allSectionsComplete &&
                              !_isSubmitting &&
                              status != 'pending_review')
                          ? _submitRegistration
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TayarColors.primary,
                        disabledBackgroundColor: context.cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSubmitting
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: context.textColor,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              status == 'pending_review'
                                  ? AppLocalizations.of(
                                      context,
                                    )!.applicationUnderReviewButton
                                  : AppLocalizations.of(
                                      context,
                                    )!.continueButton,
                              style: TextStyle(
                                color: context.textColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}


class _SectionTile extends StatelessWidget {
  final String title;
  final bool isComplete;
  final VoidCallback onTap;

  const _SectionTile({
    required this.title,
    required this.isComplete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      title: Text(
        title,
        style: TextStyle(color: context.textColor, fontSize: 16),
      ),
      subtitle: Text(
        isComplete
            ? AppLocalizations.of(context)!.sectionCompleteLabel
            : AppLocalizations.of(context)!.sectionIncompleteLabel,
        style: TextStyle(
          color: isComplete ? TayarColors.primary : context.textGreyColor,
          fontSize: 14,
        ),
      ),
      leading: CircleAvatar(
        backgroundColor: isComplete
            ? TayarColors.primary.withValues(alpha: 0.15)
            : context.cardColor,
        child: Icon(
          isComplete ? Icons.check : Icons.description_outlined,
          color: isComplete ? TayarColors.primary : context.textGreyColor,
        ),
      ),
      trailing: Icon(Icons.chevron_left, color: context.textGreyColor),
    );
  }
}

// ====================================================
// ====== أدوات مشتركة: حقل نص + مربع رفع صورة ======
// ====================================================
