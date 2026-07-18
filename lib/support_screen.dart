import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'passenger_home.dart';

// ====== شاشة الدعم: تواصل مباشر (واتساب/اتصال/إيميل) + إرسال شكوى/استفسار ======
// عدّل رقم الواتساب والإيميل تحت لبيانات الدعم الفعلية بتاعتك
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  static const String _supportPhone = '+201142263460';
  static const String _supportEmail = 'tayardeliveryeg@gmail.com';

  final _messageController = TextEditingController();
  bool _sending = false;

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
      await FirebaseFirestore.instance.collection('support_tickets').add({
        'userId': user?.uid,
        'userName': user?.displayName,
        'message': text,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
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
        iconTheme:  IconThemeData(color: context.textColor),
        title: Text(
          loc.navSupport,
          style:  TextStyle(color: context.textColor),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            loc.contactUsDirectlyLabel,
            style:  TextStyle(
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
                  icon: Icons.chat,
                  label: loc.whatsappLabel,
                  onTap: _openWhatsapp,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SupportActionButton(
                  icon: Icons.call_outlined,
                  label: loc.callLabel,
                  onTap: _callSupport,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SupportActionButton(
                  icon: Icons.email_outlined,
                  label: loc.emailLabel,
                  onTap: _emailSupport,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            loc.orSendMessageHereLabel,
            style:  TextStyle(
              color: context.textColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _messageController,
              maxLines: 5,
              style:  TextStyle(color: context.textColor),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: loc.supportMessageHint,
                hintStyle:  TextStyle(color: context.textGreyColor),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _sending ? null : _sendMessage,
              style: ElevatedButton.styleFrom(
                backgroundColor: TayarColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _sending
                  ?  SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.textColor,
                      ),
                    )
                  : Text(
                      loc.sendButton,
                      style:  TextStyle(
                        color: context.textColor,
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
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SupportActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: TayarColors.primary, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(color: context.textColor, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
