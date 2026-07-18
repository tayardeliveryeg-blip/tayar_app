import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'main.dart';

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

  void _showTextDialog(String title, String body) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: TextStyle(color: context.textColor)),
        content: SingleChildScrollView(
          child: Text(body, style: TextStyle(color: context.textGreyColor)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context)!.ok,
              style: const TextStyle(color: TayarColors.primary),
            ),
          ),
        ],
      ),
    );
  }

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
              RadioListTile<Locale?>(
                value: null,
                groupValue: manualLocale,
                activeColor: TayarColors.primary,
                title: Text(
                  AppLocalizations.of(context)!.useDeviceLanguageLabel,
                  style: TextStyle(color: context.textColor),
                ),
                onChanged: (value) {
                  TayarApp.setLocale(context, value);
                  Navigator.pop(sheetContext);
                },
              ),
              RadioListTile<Locale?>(
                value: const Locale('ar'),
                groupValue: manualLocale,
                activeColor: TayarColors.primary,
                title: Text(
                  'العربية',
                  style: TextStyle(color: context.textColor),
                ),
                onChanged: (value) {
                  TayarApp.setLocale(context, value);
                  Navigator.pop(sheetContext);
                },
              ),
              RadioListTile<Locale?>(
                value: const Locale('en'),
                groupValue: manualLocale,
                activeColor: TayarColors.primary,
                title: Text(
                  'English',
                  style: TextStyle(color: context.textColor),
                ),
                onChanged: (value) {
                  TayarApp.setLocale(context, value);
                  Navigator.pop(sheetContext);
                },
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
              RadioListTile<ThemeMode>(
                value: ThemeMode.dark,
                groupValue: currentMode,
                activeColor: TayarColors.primary,
                title: Text(
                  AppLocalizations.of(context)!.darkModeLabel,
                  style: TextStyle(color: context.textColor),
                ),
                onChanged: (value) {
                  TayarApp.setThemeMode(context, value!);
                  Navigator.pop(sheetContext);
                },
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.light,
                groupValue: currentMode,
                activeColor: TayarColors.primary,
                title: Text(
                  AppLocalizations.of(context)!.lightModeLabel,
                  style: TextStyle(color: context.textColor),
                ),
                onChanged: (value) {
                  TayarApp.setThemeMode(context, value!);
                  Navigator.pop(sheetContext);
                },
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.system,
                groupValue: currentMode,
                activeColor: TayarColors.primary,
                title: Text(
                  AppLocalizations.of(context)!.useDeviceThemeLabel,
                  style: TextStyle(color: context.textColor),
                ),
                onChanged: (value) {
                  TayarApp.setThemeMode(context, value!);
                  Navigator.pop(sheetContext);
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
                      onTap: () => _showTextDialog(
                        AppLocalizations.of(context)!.termsAndConditions,
                        AppLocalizations.of(context)!.termsAndConditionsBody,
                      ),
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
                      onTap: () => _showTextDialog(
                        AppLocalizations.of(context)!.privacyPolicy,
                        AppLocalizations.of(context)!.privacyPolicyBody,
                      ),
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
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: children),
    );
  }
}
