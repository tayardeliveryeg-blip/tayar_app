import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/passenger/home/passenger_home_screen.dart';
import 'package:tayay_app/screens/shared/my_tickets_screen.dart';
import 'package:tayay_app/theme/app_settings.dart';
import 'package:tayay_app/theme/theme_extensions.dart';
import 'package:tayay_app/widgets/app_card.dart';
import 'package:tayay_app/widgets/app_primary_button.dart';

// ====== تصنيفات الشكوى الثابتة - نفس القيم بالظبط لازم تتطابق مع
// الـ allow list في firestore.rules (match /support_tickets/{ticketId})
// عشان الإرسال ينجح. لو ضفت تصنيف جديد هنا لازم تضيفه في الـ rules برضه ======
enum ComplaintCategory { orderIssue, driverBehavior, payment, technical, other }

extension ComplaintCategoryValue on ComplaintCategory {
  String get value {
    switch (this) {
      case ComplaintCategory.orderIssue:
        return 'order_issue';
      case ComplaintCategory.driverBehavior:
        return 'driver_behavior';
      case ComplaintCategory.payment:
        return 'payment';
      case ComplaintCategory.technical:
        return 'technical';
      case ComplaintCategory.other:
        return 'other';
    }
  }

  String label(AppLocalizations loc) {
    switch (this) {
      case ComplaintCategory.orderIssue:
        return loc.categoryOrderIssue;
      case ComplaintCategory.driverBehavior:
        return loc.categoryDriverBehavior;
      case ComplaintCategory.payment:
        return loc.categoryPayment;
      case ComplaintCategory.technical:
        return loc.categoryTechnical;
      case ComplaintCategory.other:
        return loc.categoryOther;
    }
  }
}

// ====== شاشة الدعم: تواصل مباشر (واتساب/اتصال/إيميل) + إرسال شكوى/استفسار ======
// رقم الواتساب/الاتصال بييجي من إعدادات لوحة الأدمن (AppSettings)، والإيميل ثابت تحت
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  String get _supportPhone => AppSettings.instance.supportPhone;
  static const String _supportEmail = 'tayardeliveryeg@gmail.com';

  final _messageController = TextEditingController();
  bool _sending = false;
  ComplaintCategory _category = ComplaintCategory.orderIssue;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _launch(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.failedToOpenAppError),
        ),
      );
    }
  }

  Future<void> _openWhatsapp() => _launch(
    Uri.parse(
      'https://wa.me/${_supportPhone.replaceAll('+', '')}'
      '?text=${Uri.encodeComponent(AppLocalizations.of(context)!.whatsappSupportMessage)}',
    ),
  );

  Future<void> _callSupport() => _launch(Uri.parse('tel:$_supportPhone'));

  Future<void> _emailSupport() => _launch(
    Uri.parse(
      'mailto:$_supportEmail?subject=${AppLocalizations.of(context)!.supportEmailSubject}',
    ),
  );

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      // ====== userRole بيتسجل وقت الإرسال من lastMode المحفوظة (نفس
      // الفكرة المستخدمة في notifications_screen.dart لتوجيه إشعار
      // المحفظة) - معلومة سياق للأدمن وقت المراجعة بس، مش حقل أمني ======
      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('lastMode') ?? 'passenger';
      await FirebaseFirestore.instance.collection('support_tickets').add({
        'userId': user?.uid,
        'userName': user?.displayName,
        'userRole': userRole,
        'category': _category.value,
        'message': text,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
        // ====== adminReply متعمّد إنه مش موجود هنا خالص (مش حتى null) -
        // firestore.rules بترفض أي طلب إنشاء فيه المفتاح ده أصلًا
        // (!('adminReply' in request.resource.data))، والأدمن بس اللي
        // بيضيفه لاحقًا عن طريق update ======
      });
      _messageController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.supportMessageSentConfirmation,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.genericErrorTryAgain),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textColor),
        title: Text(loc.navSupport, style: TextStyle(color: context.textColor)),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyTicketsScreen()),
            ),
            icon: const Icon(Icons.history, color: TayarColors.primary),
            label: Text(
              loc.myComplaintsLabel,
              style: const TextStyle(
                color: TayarColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            loc.contactUsDirectlyLabel,
            style: TextStyle(
              color: context.textColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SupportActionButton(
                  icon: const FaIcon(FontAwesomeIcons.whatsapp),
                  label: loc.whatsappLabel,
                  onTap: _openWhatsapp,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SupportActionButton(
                  icon: const Icon(Icons.call_outlined),
                  label: loc.callLabel,
                  onTap: _callSupport,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SupportActionButton(
                  icon: const Icon(Icons.email_outlined),
                  label: loc.emailLabel,
                  onTap: _emailSupport,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            loc.orSendMessageHereLabel,
            style: TextStyle(
              color: context.textColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            loc.complaintCategoryLabel,
            style: TextStyle(color: context.textGreyColor, fontSize: 13),
          ),
          const SizedBox(height: 8),
          AppCard(
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            showShadow: false,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ComplaintCategory>(
                value: _category,
                isExpanded: true,
                dropdownColor: context.bgColor,
                iconEnabledColor: context.textGreyColor,
                style: TextStyle(color: context.textColor, fontSize: 15),
                items: ComplaintCategory.values
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.label(loc)),
                      ),
                    )
                    .toList(),
                onChanged: (c) {
                  if (c != null) setState(() => _category = c);
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            radius: 14,
            padding: const EdgeInsets.all(14),
            showShadow: false,
            child: TextField(
              controller: _messageController,
              maxLines: 5,
              style: TextStyle(color: context.textColor),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: loc.supportMessageHint,
                hintStyle: TextStyle(color: context.textGreyColor),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: AppPrimaryButton(
              onPressed: _sending ? null : _sendMessage,
              style: ElevatedButton.styleFrom(
                backgroundColor: TayarColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _sending
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.onPrimaryColor,
                      ),
                    )
                  : Text(
                      loc.sendButton,
                      style: TextStyle(
                        color: context.onPrimaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportActionButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  const _SupportActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      radius: 14,
      padding: const EdgeInsets.symmetric(vertical: 16),
      showShadow: false,
      child: Column(
        children: [
          IconTheme(
            data: const IconThemeData(color: TayarColors.primary, size: 26),
            child: icon,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(color: context.textColor, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
