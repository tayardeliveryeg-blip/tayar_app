import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:tayay_app/screens/passenger/home/passenger_home_screen.dart';
import 'package:tayay_app/screens/passenger/home/passenger_home_controller.dart';
import 'package:tayay_app/screens/shared/security_screen.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/services/sos_service.dart';
import 'package:tayay_app/theme/app_settings.dart';

const String _kEgyptPoliceNumber = '122';

/// ====== بيفتح شيت زرار الطوارئ: بيسجل تنبيه فوري في لوحة الأدمن أول ما
/// يتفتح، وبيدي المستخدم إجراءات سريعة: اتصال بالشرطة، اتصال بدعم Tayar،
/// وإبعات تنبيه واتساب لجهة اتصال الطوارئ المحفوظة (لو موجودة) ======
Future<void> showSosActionSheet(
  BuildContext context, {
  required String userRole, // 'passenger' | 'driver'
  String? orderId,
}) async {
  final loc = AppLocalizations.of(context)!;

  // ====== نسجل التنبيه فورًا لحظة فتح الشيت، مش لما المستخدم يختار إجراء
  // معين - عشان الأدمن يبقى عارف حتى لو المستخدم قفل الشيت على طول ======
  SosService.triggerAlert(userRole: userRole, orderId: orderId);

  if (!context.mounted) return;

  final emergencyContact = await SosService.getEmergencyContact(userRole);
  if (!context.mounted) return;

  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => _SosSheetContent(
      loc: loc,
      userRole: userRole,
      emergencyContact: emergencyContact,
    ),
  );
}

Future<void> _launch(BuildContext context, Uri uri) async {
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.failedToOpenAppError)),
    );
  }
}

class _SosSheetContent extends StatelessWidget {
  final AppLocalizations loc;
  final String userRole;
  final String? emergencyContact;

  const _SosSheetContent({
    required this.loc,
    required this.userRole,
    required this.emergencyContact,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_rounded, color: Colors.redAccent, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    loc.sosSheetTitle,
                    style: TextStyle(
                      color: context.textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              loc.sosAlertSentToAdminNotice,
              style: TextStyle(color: context.textGreyColor, fontSize: 13),
            ),
            const SizedBox(height: 18),

            _SosOptionTile(
              icon: Icons.local_police_outlined,
              color: Colors.redAccent,
              title: loc.sosCallPoliceLabel,
              subtitle: _kEgyptPoliceNumber,
              onTap: () => _launch(context, Uri.parse('tel:$_kEgyptPoliceNumber')),
            ),
            const SizedBox(height: 10),
            _SosOptionTile(
              icon: Icons.support_agent_outlined,
              color: TayarColors.primary,
              title: loc.sosCallSupportLabel,
              subtitle: AppSettings.instance.supportPhone,
              onTap: () => _launch(
                context,
                Uri.parse('tel:${AppSettings.instance.supportPhone}'),
              ),
            ),
            const SizedBox(height: 10),
            _SosOptionTile(
              icon: Icons.contact_phone_outlined,
              color: Colors.green,
              title: loc.sosNotifyEmergencyContactLabel,
              subtitle: emergencyContact ?? loc.sosNoEmergencyContactSetHint,
              onTap: () {
                if (emergencyContact != null) {
                  _launch(
                    context,
                    Uri.parse(
                      'https://wa.me/${emergencyContact!.replaceAll('+', '')}'
                      '?text=${Uri.encodeComponent(loc.sosWhatsappMessage)}',
                    ),
                  );
                } else {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          SecurityScreen(isDriver: userRole == 'driver'),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                loc.cancel,
                style: TextStyle(color: context.textGreyColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SosOptionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SosOptionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: context.textGreyColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_left, color: context.textGreyColor),
          ],
        ),
      ),
    );
  }
}
