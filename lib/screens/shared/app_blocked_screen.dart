import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart'
    show TayarColors, TayarThemeColors;
import 'package:tayay_app/theme/app_settings.dart';
import 'package:tayay_app/widgets/app_primary_button.dart';

// ====================================================
// ====== شاشة حجب التطبيق (Force-update / وضع الصيانة): بتتعرض فوق كل
// حاجة من MaterialApp.builder في main.dart - نفس أسلوب AppLockScreen -
// لما AppSettings.blockReason مش none. التحكم فيها كله من تاب Settings
// في لوحة الأدمن (minAppBuild / maintenanceMode / maintenanceMessage) ======
// ====================================================
class AppBlockedScreen extends StatefulWidget {
  final AppBlockReason reason;
  // ====== بتعيد قراءة الإعدادات من السيرفر وتحدّث حالة الحجب في main.dart ======
  final Future<void> Function() onRetry;

  const AppBlockedScreen({
    super.key,
    required this.reason,
    required this.onRetry,
  });

  @override
  State<AppBlockedScreen> createState() => _AppBlockedScreenState();
}

class _AppBlockedScreenState extends State<AppBlockedScreen> {
  bool _isRetrying = false;

  Future<void> _retry() async {
    setState(() => _isRetrying = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  Future<void> _openStore() async {
    try {
      await launchUrl(
        Uri.parse(AppSettings.instance.updateUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // صامت: المستخدم يقدر يجرب تاني أو يفتح المتجر بنفسه
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isUpdate = widget.reason == AppBlockReason.updateRequired;
    final customMessage = AppSettings.instance.maintenanceMessage.trim();

    final title = isUpdate ? loc.appUpdateRequiredTitle : loc.maintenanceTitle;
    final body = isUpdate
        ? loc.appUpdateRequiredBody
        : (customMessage.isNotEmpty ? customMessage : loc.maintenanceDefaultBody);

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: TayarColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  isUpdate
                      ? Icons.system_update_alt_rounded
                      : Icons.construction_rounded,
                  color: TayarColors.primary,
                  size: 40,
                ),
              ),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: context.textColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textGreyColor, height: 1.6),
              ),
              const SizedBox(height: 32),
              AppPrimaryButton(
                onPressed: _isRetrying ? null : (isUpdate ? _openStore : _retry),
                isLoading: !isUpdate && _isRetrying,
                child: Text(
                  isUpdate ? loc.appUpdateButton : loc.tryAgainLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: context.onPrimaryColor,
                    fontSize: 16,
                  ),
                ),
              ),
              if (isUpdate)
                TextButton(
                  onPressed: _isRetrying ? null : _retry,
                  child: Text(
                    loc.tryAgainLabel,
                    style: TextStyle(color: context.textGreyColor),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
