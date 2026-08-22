// ====== الدرج الجانبي (Drawer) بتاع شاشة الراكب: بيانات البروفايل،
// روابط التنقل لكل الشاشات الفرعية، روابط السوشيال ميديا، وتسجيل
// الخروج. اتفصل من passenger_home.dart عشان الملف الأصلي كان كبير
// جدًا (2600+ سطر) — نفس السلوك بالظبط ======
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';

import 'package:tayay_app/theme/theme_extensions.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart'
    show TayarSocialLinks, launchSocialUrl;
import 'package:tayay_app/screens/passenger/create_delivery_order_screen.dart';
import 'package:tayay_app/screens/driver/registration/driver_registration_screen.dart';
import 'package:tayay_app/screens/auth/login_screen.dart';
import 'package:tayay_app/screens/shared/notifications_screen.dart';
import 'package:tayay_app/screens/passenger/order_history_screen.dart';
import 'package:tayay_app/screens/passenger/scheduled_rides_screen.dart';
import 'package:tayay_app/screens/passenger/passenger_wallet_screen.dart';
import 'package:tayay_app/screens/passenger/vendor_partners_screen.dart';
import 'package:tayay_app/screens/passenger/my_drivers_screen.dart';
import 'package:tayay_app/screens/passenger/passenger_profile_screen.dart';
import 'package:tayay_app/screens/shared/security_screen.dart';
import 'package:tayay_app/screens/shared/settings_screen.dart';
import 'package:tayay_app/screens/shared/help_screen.dart';
import 'package:tayay_app/screens/shared/support_screen.dart';

// ====================================================
// ====================== Drawer =======================
// ====================================================
class TayarDrawer extends StatelessWidget {
  const TayarDrawer({super.key});

  // ====== تأكيد تسجيل الخروج قبل تنفيذه فعليًا ======
  Future<void> _confirmLogout(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Text(loc.logout, style: TextStyle(color: context.textColor)),
        content: Text(
          loc.confirmLogoutMessage,
          style: TextStyle(color: context.textGreyColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              loc.cancel,
              style: TextStyle(color: context.textGreyColor),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              loc.logout,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      // ====== نسجل خروج من Google لو المستخدم داخل بيه، وبعدين من Firebase ======
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
      await FirebaseAuth.instance.signOut();
      // ====== نمسح آخر وضع محفوظ عشان أي حساب تاني يسجل دخول من نفس الجهاز ما يفتحش غلط ======
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('lastMode');
    } catch (e) {
      debugPrint('❌ خطأ أثناء تسجيل الخروج: $e');
    }

    if (!context.mounted) return;

    // ====== نمسح كل الشاشات السابقة ونرجع لشاشة تسجيل الدخول من الأول ======
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: context.bgColor,
      child: SafeArea(
        child: Column(
          children: [
            // ====== بيانات اليوزر (بتفتح البروفايل عند الدوس) ======
            InkWell(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PassengerProfileScreen(),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseAuth.instance.currentUser == null
                      ? null
                      : FirebaseFirestore.instance
                            .collection('users')
                            .doc(FirebaseAuth.instance.currentUser!.uid)
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

                    // ====== اسم المستخدم الحقيقي: من بيانات Firestore أولًا
                    // (firstName + lastName اللي المستخدم كتبهم في البروفايل)،
                    // وإلا اسم حساب Google المسجل بيه، وإلا اسم افتراضي
                    // كـ fallback أخير لو معندناش أي مصدر ======
                    final firstName = (personalInfo?['firstName'] as String?)
                        ?.trim();
                    final lastName = (personalInfo?['lastName'] as String?)
                        ?.trim();
                    final firestoreName = [
                      firstName,
                      lastName,
                    ].where((s) => s != null && s.isNotEmpty).join(' ');
                    final googleName = FirebaseAuth
                        .instance
                        .currentUser
                        ?.displayName
                        ?.trim();
                    final displayName = firestoreName.isNotEmpty
                        ? firestoreName
                        : (googleName != null && googleName.isNotEmpty)
                        ? googleName
                        : AppLocalizations.of(context)!.defaultUserName;

                    // ====== متوسط تقييم الراكب: نفس مستند users/{uid} اللي
                    // الـ StreamBuilder ده بيسمعه بالفعل، فمفيش داعي لأي
                    // استعلام إضافي — بنفس منطق ratingSum/ratingCount
                    // المستخدم في تقييم الطيار بالظبط ======
                    final userData = snapshot.data?.data();
                    final ratingCount =
                        (userData?['ratingCount'] as num?)?.toInt() ?? 0;
                    final double? riderRating = ratingCount > 0
                        ? ((userData?['ratingSum'] as num?)?.toDouble() ??
                                  0.0) /
                              ratingCount
                        : null;

                    return Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: TayarColors.primary,
                          backgroundImage: photo,
                          child: photo == null
                              ? Icon(
                                  Icons.person,
                                  color: context.onPrimaryColor,
                                  size: 30,
                                )
                              : null,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                displayName,
                                style: TextStyle(
                                  color: context.textColor,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              // ====== تقييم الراكب: نجمة + الرقم، أو "راكب
                              // جديد" لو لسه معندوش أي تقييمات — نفس ستايل
                              // تقييم الطيار بالظبط في offer_cards.dart ======
                              if (riderRating != null)
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: TayarColors.primary,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      riderRating.toStringAsFixed(1),
                                      style: TextStyle(
                                        color: context.textGreyColor,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Text(
                                  AppLocalizations.of(context)!.newRiderLabel,
                                  style: TextStyle(
                                    color: context.textGreyColor,
                                    fontSize: 14,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: context.textColor),
                      ],
                    );
                  },
                ),
              ),
            ),
            Divider(color: context.dividerColor2, height: 1),

            // ====== قايمة العناصر ======
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _DrawerItem(
                    icon: Icons.two_wheeler,
                    label: AppLocalizations.of(context)!.serviceRideMe,
                    selected: true,
                    onTap: () => Navigator.pop(context),
                  ),
                  _DrawerItem(
                    icon: Icons.delivery_dining,
                    label: AppLocalizations.of(context)!.serviceDeliverOrders,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateDeliveryOrderScreen(),
                        ),
                      );
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.history,
                    label: AppLocalizations.of(context)!.orderHistoryLabel,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OrderHistoryScreen(),
                        ),
                      );
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.schedule_outlined,
                    label: AppLocalizations.of(context)!.myScheduledRidesLabel,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ScheduledRidesScreen(),
                        ),
                      );
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.account_balance_wallet_outlined,
                    label: AppLocalizations.of(context)!.myWalletLabel,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PassengerWalletScreen(),
                        ),
                      );
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.storefront,
                    label: AppLocalizations.of(
                      context,
                    )!.vendorPartnersDrawerLabel,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VendorPartnersScreen(),
                        ),
                      );
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.people_alt_outlined,
                    label: AppLocalizations.of(context)!.myDriversDrawerLabel,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyDriversScreen(),
                        ),
                      );
                    },
                  ),
                  _DrawerItem(
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
                  _DrawerItem(
                    icon: Icons.shield_outlined,
                    label: AppLocalizations.of(context)!.navSecurity,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SecurityScreen(),
                        ),
                      );
                    },
                  ),
                  _DrawerItem(
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
                  _DrawerItem(
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
                  _DrawerItem(
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
                  _DrawerItem(
                    icon: Icons.logout,
                    label: AppLocalizations.of(context)!.logout,
                    isDestructive: true,
                    onTap: () => _confirmLogout(context),
                  ),
                ],
              ),
            ),

            // ====== زرار وضع الطيار ======
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DriverRegistrationScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TayarColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.driverModeButton,
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
                  _SocialIcon(
                    icon: Icon(
                      Icons.facebook,
                      color: context.textColor,
                      size: 20,
                    ),
                    onTap: () =>
                        launchSocialUrl(context, TayarSocialLinks.facebook),
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  _SocialIcon(
                    icon: Icon(
                      Icons.camera_alt_outlined,
                      color: context.textColor,
                      size: 20,
                    ), // إنستجرام
                    onTap: () =>
                        launchSocialUrl(context, TayarSocialLinks.instagram),
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  _SocialIcon(
                    icon: FaIcon(
                      FontAwesomeIcons.whatsapp,
                      color: context.textColor,
                      size: 20,
                    ), // واتساب
                    onTap: () =>
                        launchSocialUrl(context, TayarSocialLinks.whatsapp),
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  _SocialIcon(
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

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isDestructive;
  final VoidCallback? onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.isDestructive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color itemColor = isDestructive
        ? Colors.redAccent
        : (selected ? TayarColors.primary : context.textColor);

    return Container(
      color: selected
          ? TayarColors.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      child: ListTile(
        leading: Icon(
          icon,
          color: isDestructive
              ? Colors.redAccent
              : (selected ? TayarColors.primary : context.textGreyColor),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: itemColor,
            fontSize: 16,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap:
            onTap ??
            () {
              // ====== fallback احتياطي بس: كل عناصر الدرج الحالية بتمرر
              // onTap صريح دايمًا، فالسطر ده عمليًا مش بيتنفذ. سايبينه
              // كحماية لو اتضاف عنصر جديد بالغلط من غير onTap ======
              Navigator.pop(context);
            },
      ),
    );
  }
}

class _SocialIcon extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onTap;
  const _SocialIcon({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: context.dividerColor2),
          shape: BoxShape.circle,
        ),
        child: Center(child: icon),
      ),
    );
  }
}
