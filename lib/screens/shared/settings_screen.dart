import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/main.dart';
import 'package:tayay_app/widgets/app_card.dart';

// ====== شاشة الإعدادات: اللغة، الإشعارات، ونبذة عن التطبيق ======
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushEnabled = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPushSetting();
  }

  Future<void> _loadPushSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushEnabled = prefs.getBool('pushNotificationsEnabled') ?? true;
      _loading = false;
    });
  }

  Future<void> _togglePush(bool value) async {
    setState(() => _pushEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pushNotificationsEnabled', value);

    // ====== لو المستخدم مسجل دخول، نحفظ التفضيل في مستنده كمان عشان
    // السيرفر يعرف ميبعتش إشعارات لو قافلها ======
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'pushNotificationsEnabled': value}, SetOptions(merge: true))
          .catchError((_) {});
    }
  }

  // ====== بيفتح صفحة سياسة الخصوصية أو الشروط والأحكام الكاملة (مستضافين
  // على Firebase Hosting) في المتصفح، بدل ما يعرض ملخص قصير جوه التطبيق -
  // الاتنين بقوا بنفس المنطق دلوقتي بعد ما اتبنت صفحة terms.html كاملة
  // (كانت الشروط قبل كده بتفتح ديالوج بنص مختصر بس بيحيل على "الموقع
  // الرسمي" اللي مكنش فيه محتوى فعلي) ======
  static const String _privacyPolicyUrl =
      'https://b10-app-1e682.web.app/privacy.html';
  static const String _termsAndConditionsUrl =
      'https://b10-app-1e682.web.app/terms.html';

  Future<void> _openHostedPage(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.failedToOpenAppError),
        ),
      );
    }
  }

  Future<void> _openPrivacyPolicy(BuildContext context) =>
      _openHostedPage(context, _privacyPolicyUrl);

  Future<void> _openTermsAndConditions(BuildContext context) =>
      _openHostedPage(context, _termsAndConditionsUrl);

  // ====== بيفتح شيت لاختيار اللغة: عربي / إنجليزي / لغة الجهاز ======
  void _showLanguageSheet(BuildContext context) {
    // ====== null = التطبيق شغال حاليًا على لغة الجهاز تلقائيًا ======
    final manualLocale = TayarApp.getManualLocale(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    AppLocalizations.of(context)!.appLanguageLabel,
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              RadioGroup<Locale?>(
                groupValue: manualLocale,
                onChanged: (value) {
                  TayarApp.setLocale(context, value);
                  Navigator.pop(sheetContext);
                },
                child: Column(
                  children: [
                    RadioListTile<Locale?>(
                      value: null,
                      activeColor: TayarColors.primary,
                      title: Text(
                        AppLocalizations.of(context)!.useDeviceLanguageLabel,
                        style: TextStyle(color: context.textColor),
                      ),
                    ),
                    RadioListTile<Locale?>(
                      value: const Locale('ar'),
                      activeColor: TayarColors.primary,
                      title: Text(
                        'العربية',
                        style: TextStyle(color: context.textColor),
                      ),
                    ),
                    RadioListTile<Locale?>(
                      value: const Locale('en'),
                      activeColor: TayarColors.primary,
                      title: Text(
                        'English',
                        style: TextStyle(color: context.textColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ====== بيفتح شيت لاختيار وضع الإضاءة: فاتح / غامق / تلقائي حسب الجهاز ======
  void _showThemeModeSheet(BuildContext context) {
    final currentMode = TayarApp.getThemeMode(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    AppLocalizations.of(context)!.appThemeLabel,
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              RadioGroup<ThemeMode>(
                groupValue: currentMode,
                onChanged: (value) {
                  TayarApp.setThemeMode(context, value!);
                  Navigator.pop(sheetContext);
                },
                child: Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.dark,
                      activeColor: TayarColors.primary,
                      title: Text(
                        AppLocalizations.of(context)!.darkModeLabel,
                        style: TextStyle(color: context.textColor),
                      ),
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.light,
                      activeColor: TayarColors.primary,
                      title: Text(
                        AppLocalizations.of(context)!.lightModeLabel,
                        style: TextStyle(color: context.textColor),
                      ),
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.system,
                      activeColor: TayarColors.primary,
                      title: Text(
                        AppLocalizations.of(context)!.useDeviceThemeLabel,
                        style: TextStyle(color: context.textColor),
                      ),
                    ),
                  ],
                ),
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
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    // ====== null يعني التطبيق شغال على لغة الجهاز تلقائيًا ======
    final manualLocale = TayarApp.getManualLocale(context);
    final languageSubtitle = manualLocale == null
        ? AppLocalizations.of(context)!.useDeviceLanguageLabel
        : (isArabic ? 'العربية' : 'English');

    final currentThemeMode = TayarApp.getThemeMode(context);
    final themeSubtitle = switch (currentThemeMode) {
      ThemeMode.light => AppLocalizations.of(context)!.lightModeLabel,
      ThemeMode.dark => AppLocalizations.of(context)!.darkModeLabel,
      ThemeMode.system => AppLocalizations.of(context)!.useDeviceThemeLabel,
    };

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textColor),
        title: Text(
          AppLocalizations.of(context)!.navSettings,
          style: TextStyle(color: context.textColor),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: TayarColors.primary),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SettingsSection(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.language,
                        color: TayarColors.primary,
                      ),
                      title: Text(
                        AppLocalizations.of(context)!.appLanguageLabel,
                        style: TextStyle(color: context.textColor),
                      ),
                      subtitle: Text(
                        languageSubtitle,
                        style: TextStyle(color: context.textGreyColor),
                      ),
                      trailing: Icon(
                        Icons.chevron_left,
                        color: context.textGreyColor,
                      ),
                      onTap: () => _showLanguageSheet(context),
                    ),
                    Divider(color: context.dividerColor2, height: 1),
                    ListTile(
                      leading: Icon(
                        context.isDarkMode
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined,
                        color: TayarColors.primary,
                      ),
                      title: Text(
                        AppLocalizations.of(context)!.appThemeLabel,
                        style: TextStyle(color: context.textColor),
                      ),
                      subtitle: Text(
                        themeSubtitle,
                        style: TextStyle(color: context.textGreyColor),
                      ),
                      trailing: Icon(
                        Icons.chevron_left,
                        color: context.textGreyColor,
                      ),
                      onTap: () => _showThemeModeSheet(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  children: [
                    SwitchListTile(
                      value: _pushEnabled,
                      onChanged: _togglePush,
                      activeThumbColor: TayarColors.primary,
                      secondary: const Icon(
                        Icons.notifications_active_outlined,
                        color: TayarColors.primary,
                      ),
                      title: Text(
                        AppLocalizations.of(context)!.enablePushNotifications,
                        style: TextStyle(color: context.textColor),
                      ),
                      subtitle: Text(
                        AppLocalizations.of(
                          context,
                        )!.pushNotificationsDescription,
                        style: TextStyle(color: context.textGreyColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.description_outlined,
                        color: TayarColors.primary,
                      ),
                      title: Text(
                        AppLocalizations.of(context)!.termsAndConditions,
                        style: TextStyle(color: context.textColor),
                      ),
                      trailing: Icon(
                        Icons.chevron_left,
                        color: context.textGreyColor,
                      ),
                      onTap: () => _openTermsAndConditions(context),
                    ),
                    Divider(color: context.dividerColor2, height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.privacy_tip_outlined,
                        color: TayarColors.primary,
                      ),
                      title: Text(
                        AppLocalizations.of(context)!.privacyPolicy,
                        style: TextStyle(color: context.textColor),
                      ),
                      trailing: Icon(
                        Icons.chevron_left,
                        color: context.textGreyColor,
                      ),
                      onTap: () => _openPrivacyPolicy(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.info_outline,
                        color: TayarColors.primary,
                      ),
                      title: Text(
                        AppLocalizations.of(context)!.appVersionLabel,
                        style: TextStyle(color: context.textColor),
                      ),
                      trailing: Text(
                        '1.0.0',
                        style: TextStyle(color: context.textGreyColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final List<Widget> children;
  const _SettingsSection({required this.children});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 14,
      padding: EdgeInsets.zero,
      showShadow: false,
      child: Column(children: children),
    );
  }
}
