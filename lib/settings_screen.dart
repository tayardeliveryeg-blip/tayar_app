import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'passenger_home.dart';

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
        backgroundColor: TayarColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Text(
            body,
            style: const TextStyle(color: TayarColors.textGrey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'تمام',
              style: TextStyle(color: TayarColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: TayarColors.background,
      appBar: AppBar(
        backgroundColor: TayarColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('الإعدادات', style: TextStyle(color: Colors.white)),
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
                      title: const Text(
                        'لغة التطبيق',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        isArabic ? 'العربية' : 'English',
                        style: const TextStyle(color: TayarColors.textGrey),
                      ),
                      trailing: const Icon(
                        Icons.chevron_left,
                        color: TayarColors.textGrey,
                      ),
                      onTap: () {
                        TayarApp.setLocale(
                          context,
                          isArabic ? const Locale('en') : const Locale('ar'),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  children: [
                    SwitchListTile(
                      value: _pushEnabled,
                      onChanged: _togglePush,
                      activeColor: TayarColors.primary,
                      secondary: const Icon(
                        Icons.notifications_active_outlined,
                        color: TayarColors.primary,
                      ),
                      title: const Text(
                        'تفعيل إشعارات التطبيق',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        'إشعارات الطلبات والعروض والتحديثات المهمة',
                        style: TextStyle(color: TayarColors.textGrey),
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
                      title: const Text(
                        'الشروط والأحكام',
                        style: TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(
                        Icons.chevron_left,
                        color: TayarColors.textGrey,
                      ),
                      onTap: () => _showTextDialog(
                        'الشروط والأحكام',
                        'باستخدامك تطبيق طيار أنت موافق على شروط الاستخدام '
                            'الخاصة بيه، وإن الخدمة مقدَّمة بين الراكب والطيار '
                            'مباشرة، وإن الشركة بتوفر منصة الربط فقط.',
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.privacy_tip_outlined,
                        color: TayarColors.primary,
                      ),
                      title: const Text(
                        'سياسة الخصوصية',
                        style: TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(
                        Icons.chevron_left,
                        color: TayarColors.textGrey,
                      ),
                      onTap: () => _showTextDialog(
                        'سياسة الخصوصية',
                        'بنحافظ على بياناتك ومنستخدمش موقعك إلا وقت وجود '
                            'رحلة فعلية، ومبنشاركش بياناتك مع أي طرف تالت '
                            'من غير موافقتك.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  children: [
                    const ListTile(
                      leading: Icon(
                        Icons.info_outline,
                        color: TayarColors.primary,
                      ),
                      title: Text(
                        'إصدار التطبيق',
                        style: TextStyle(color: Colors.white),
                      ),
                      trailing: Text(
                        '1.0.0',
                        style: TextStyle(color: TayarColors.textGrey),
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
        color: TayarColors.cardDark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: children),
    );
  }
}
