import 'package:flutter/material.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart'
    show TayarColors, TayarThemeColors, PassengerHomeScreen;
import 'package:tayay_app/screens/driver/registration/driver_registration_screen.dart';
import 'package:tayay_app/screens/auth/profile_setup_screen.dart';
import 'package:tayay_app/theme/app_settings.dart';
import 'package:tayay_app/widgets/app_card.dart';

// ====================================================
// ====== شاشة اختيار نوع الحساب بعد أول تسجيل دخول ======
// بتظهر مرة واحدة بس للمستخدم الجديد (راكب / طيار) ======
// ====================================================
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  // ====== اختار "راكب" → نكمل نجمع اسمه في شاشة استكمال البروفايل ======
  void _continueAsPassenger(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const ProfileSetupScreen(role: 'passenger'),
      ),
    );
  }

  // ====== اختار "طيار" → نفس مسار "وضع الطيار" الموجود بالفعل من
  // الشاشة الرئيسية: نروح للرئيسية الأول وبعدين نفتح فوقها شاشة
  // تسجيل الطيار (بيانات شخصية + رخصة + دراجة) عشان لو رجع بـ pop
  // يرجع مكان سليم ======
  void _continueAsDriver(BuildContext context) {
    final navigator = Navigator.of(context);
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PassengerHomeScreen()),
      (route) => false,
    );
    navigator.push(
      MaterialPageRoute(builder: (_) => const DriverRegistrationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 50),
              Text(
                loc.chooseAccountTypeTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: context.textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                loc.chooseAccountTypeSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textGreyColor),
              ),
              const SizedBox(height: 40),
              _RoleCard(
                icon: Icons.person_outline,
                title: loc.passengerRoleTitle,
                subtitle: loc.passengerRoleDescription,
                onTap: () => _continueAsPassenger(context),
              ),
              const SizedBox(height: 20),
              _RoleCard(
                icon: Icons.two_wheeler,
                title: loc.driverRoleTitle,
                subtitle: loc.driverRoleDescription,
                badge: loc.driverCommissionBadge(
                  (AppSettings.instance.commissionRate * 100).round().toString(),
                ),
                onTap: () => _continueAsDriver(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.dividerColor2),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: TayarColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: TayarColors.primary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: context.textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textGreyColor,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(height: 8),
                    AppCard(
                      color: TayarColors.primary.withValues(alpha: 0.15),
                      radius: 20,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      showShadow: false,
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: TayarColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: context.textGreyColor,
            ),
          ],
        ),
      ),
    );
  }
}
