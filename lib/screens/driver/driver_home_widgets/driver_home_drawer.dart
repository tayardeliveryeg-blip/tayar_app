import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart'
    show PassengerHomeScreen, TayarSocialLinks, launchSocialUrl;
import 'package:tayay_app/screens/shared/notifications_screen.dart';
import 'package:tayay_app/screens/shared/security_screen.dart';
import 'package:tayay_app/screens/shared/settings_screen.dart';
import 'package:tayay_app/screens/shared/help_screen.dart';
import 'package:tayay_app/screens/shared/support_screen.dart';
import 'package:tayay_app/screens/driver/driver_profile_screen.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/theme/theme_extensions.dart';
import 'package:tayay_app/screens/driver/driver_home_widgets/driver_drawer_item.dart';
import 'package:tayay_app/widgets/app_primary_button.dart';

// ====== القايمة الجانبية (Drawer) لشاشة الطيار الرئيسية ======
// (كانت جوه driver_home_screen.dart واتقسمت في ملف منفصل زي ما حصل مع
// تقسيم passenger_home.dart في السيشن اللي فات)
class DriverHomeDrawer extends StatelessWidget {
  final int selectedTab;
  final bool isOnline;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onLogout;

  const DriverHomeDrawer({
    super.key,
    required this.selectedTab,
    required this.isOnline,
    required this.onTabSelected,
    required this.onLogout,
  });

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  Future<void> _saveLastMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastMode', mode);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: context.bgColor,
      child: SafeArea(
        child: Column(
          children: [
            InkWell(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DriverProfileScreen(),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _currentUser == null
                      ? null
                      : FirebaseFirestore.instance
                            .collection('drivers')
                            .doc(_currentUser!.uid)
                            .snapshots(),
                  builder: (context, snapshot) {
                    final personalInfo =
                        snapshot.data?.data()?['personalInfo']
                            as Map<String, dynamic>?;

                    final photoBase64 = personalInfo?['photoBase64'] as String?;
                    ImageProvider? photo;
                    if (photoBase64 != null && photoBase64.isNotEmpty) {
                      try {
                        photo = MemoryImage(base64Decode(photoBase64));
                      } catch (_) {
                        photo = null;
                      }
                    }

                    // ====== اسم السائق الحقيقي: من بيانات Firestore أولًا
                    // (firstName + lastName اللي السائق كتبهم في البروفايل)،
                    // وإلا اسم حساب Google المسجل بيه، وإلا اسم افتراضي
                    // كـ fallback أخير — بنفس منطق شاشة الراكب بالظبط ======
                    final firstName = (personalInfo?['firstName'] as String?)
                        ?.trim();
                    final lastName = (personalInfo?['lastName'] as String?)
                        ?.trim();
                    final firestoreName = [
                      firstName,
                      lastName,
                    ].where((s) => s != null && s.isNotEmpty).join(' ');
                    final googleName = _currentUser?.displayName?.trim();
                    final displayName = firestoreName.isNotEmpty
                        ? firestoreName
                        : (googleName != null && googleName.isNotEmpty)
                        ? googleName
                        : AppLocalizations.of(context)!.defaultDriverName;

                    return Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: TayarColors.primary,
                          backgroundImage: photo,
                          child: photo == null
                              ? Icon(
                                  Icons.two_wheeler,
                                  color: context.onPrimaryColor,
                                  size: 30,
                                )
                              : null,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: TextStyle(
                                  color: context.textColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                isOnline
                                    ? AppLocalizations.of(
                                        context,
                                      )!.statusAvailable
                                    : AppLocalizations.of(
                                        context,
                                      )!.statusUnavailable,
                                style: TextStyle(
                                  color: isOnline
                                      ? TayarColors.primary
                                      : context.textGreyColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: context.textGreyColor),
                      ],
                    );
                  },
                ),
              ),
            ),
            Divider(color: context.dividerColor2, height: 1),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DriverDrawerItem(
                    icon: Icons.list_alt,
                    label: AppLocalizations.of(context)!.tabRequests,
                    selected: selectedTab == 0,
                    onTap: () {
                      onTabSelected(0);
                      Navigator.pop(context);
                    },
                  ),
                  DriverDrawerItem(
                    icon: Icons.payments_outlined,
                    label: AppLocalizations.of(context)!.navIncome,
                    selected: selectedTab == 1,
                    onTap: () {
                      onTabSelected(1);
                      Navigator.pop(context);
                    },
                  ),
                  DriverDrawerItem(
                    icon: Icons.star_outline,
                    label: AppLocalizations.of(context)!.navRatings,
                    selected: selectedTab == 2,
                    onTap: () {
                      onTabSelected(2);
                      Navigator.pop(context);
                    },
                  ),
                  DriverDrawerItem(
                    icon: Icons.account_balance_wallet_outlined,
                    label: AppLocalizations.of(context)!.navWallet,
                    selected: selectedTab == 3,
                    onTap: () {
                      onTabSelected(3);
                      Navigator.pop(context);
                    },
                  ),
                  Divider(color: context.dividerColor2, height: 24),
                  DriverDrawerItem(
                    icon: Icons.notifications_none,
                    label: AppLocalizations.of(context)!.navNotifications,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                    },
                  ),
                  DriverDrawerItem(
                    icon: Icons.shield_outlined,
                    label: AppLocalizations.of(context)!.navSecurity,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SecurityScreen(isDriver: true),
                        ),
                      );
                    },
                  ),
                  DriverDrawerItem(
                    icon: Icons.settings_outlined,
                    label: AppLocalizations.of(context)!.navSettings,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  DriverDrawerItem(
                    icon: Icons.info_outline,
                    label: AppLocalizations.of(context)!.navHelp,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HelpScreen()),
                      );
                    },
                  ),
                  DriverDrawerItem(
                    icon: Icons.support_agent,
                    label: AppLocalizations.of(context)!.navSupport,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SupportScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(color: context.dividerColor2, height: 24),
                  DriverDrawerItem(
                    icon: Icons.logout,
                    label: AppLocalizations.of(context)!.logout,
                    isDestructive: true,
                    onTap: onLogout,
                  ),
                ],
              ),
            ),

            // ====== زرار الرجوع لوضع الركاب ======
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                child: AppPrimaryButton(
                  onPressed: () async {
                    // ====== نحفظ إن آخر وضع بقى "راكب" عشان يفتح عليه المرة الجاية ======
                    await _saveLastMode('passenger');
                    if (!context.mounted) return;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PassengerHomeScreen(),
                      ),
                    );
                  },
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.medium,
                  child: Text(
                    AppLocalizations.of(context)!.backToPassengerModeButton,
                    style: TextStyle(
                      color: context.onPrimaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            // ====== أيقونات السوشيال ميديا ======
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DriverSocialIcon(
                    icon: Icon(
                      Icons.facebook,
                      color: context.textColor,
                      size: 20,
                    ),
                    onTap: () =>
                        launchSocialUrl(context, TayarSocialLinks.facebook),
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  DriverSocialIcon(
                    icon: Icon(
                      Icons.camera_alt_outlined,
                      color: context.textColor,
                      size: 20,
                    ), // إنستجرام
                    onTap: () =>
                        launchSocialUrl(context, TayarSocialLinks.instagram),
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  DriverSocialIcon(
                    icon: FaIcon(
                      FontAwesomeIcons.whatsapp,
                      color: context.textColor,
                      size: 20,
                    ), // واتساب
                    onTap: () =>
                        launchSocialUrl(context, TayarSocialLinks.whatsapp),
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  DriverSocialIcon(
                    icon: FaIcon(
                      FontAwesomeIcons.tiktok,
                      color: context.textColor,
                      size: 20,
                    ),
                    onTap: () =>
                        launchSocialUrl(context, TayarSocialLinks.tiktok),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
