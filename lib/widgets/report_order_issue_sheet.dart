import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart'
    show TayarColors, TayarThemeColors;
import 'package:tayay_app/screens/shared/support_screen.dart'
    show ComplaintCategory, ComplaintCategoryValue;
import 'package:tayay_app/widgets/app_card.dart';
import 'package:tayay_app/widgets/app_primary_button.dart';
import 'package:tayay_app/widgets/tayar_bottom_sheet.dart';
import 'package:tayay_app/widgets/tayar_toast.dart';

// ====================================================
// ====== زرار "أبلّغ عن مشكلة" في سجل الطلبات (order_history_screen.dart):
// نفس منطق إرسال تذكرة الدعم في support_screen.dart بالظبط، بس مع إضافة
// orderId عشان الأدمن يشوف سياق الطلب كامل من غير ما يدور عليه يدويًا
// (راجع complaintOrderRef() في لوحة الأدمن). ده اللي بيخلّي سقف تعويض
// الـ 200 جنيه (بند 8) قابل للتنفيذ فعليًا بدل ما يفضل بند نظري في ToS ======
// ====================================================
class ReportOrderIssueSheet extends StatefulWidget {
  final String orderId;
  final ComplaintCategory initialCategory;

  const ReportOrderIssueSheet({
    super.key,
    required this.orderId,
    this.initialCategory = ComplaintCategory.orderIssue,
  });

  /// ====== نقطة الدخول الوحيدة المفروض تتنادى من بره - بتفتح الشيت بنفس
  // أسلوب باقي الشيتات في المشروع (TayarBottomSheet.show) ======
  static Future<void> open(
    BuildContext context, {
    required String orderId,
    ComplaintCategory initialCategory = ComplaintCategory.orderIssue,
  }) {
    return TayarBottomSheet.show(
      context,
      initialHeight: 0.55,
      maxHeight: 0.9,
      child: ReportOrderIssueSheet(
        orderId: orderId,
        initialCategory: initialCategory,
      ),
    );
  }

  @override
  State<ReportOrderIssueSheet> createState() => _ReportOrderIssueSheetState();
}

class _ReportOrderIssueSheetState extends State<ReportOrderIssueSheet> {
  late ComplaintCategory _category = widget.initialCategory;
  final _messageController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('lastMode') ?? 'passenger';
      await FirebaseFirestore.instance.collection('support_tickets').add({
        'userId': user?.uid,
        'userName': user?.displayName,
        'userRole': userRole,
        'category': _category.value,
        'message': text,
        // ====== الفرق الوحيد عن support_screen.dart العادية - ده اللي
        // بيخلّي complaintOrderRef() في لوحة الأدمن يقدر يجيب تفاصيل
        // الطلب. رقم موجود أصلًا (orders/{orderId})، مش بيانات حساسة ======
        'orderId': widget.orderId,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      TayarToast.show(
        context,
        AppLocalizations.of(context)!.supportMessageSentConfirmation,
        type: ToastType.success,
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      TayarToast.show(
        context,
        AppLocalizations.of(context)!.genericErrorTryAgain,
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            loc.reportOrderIssueTitle,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: context.textColor,
            ),
          ),
          const SizedBox(height: 16),
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
                      (c) =>
                          DropdownMenuItem(value: c, child: Text(c.label(loc))),
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
              maxLines: 4,
              minLines: 3,
              style: TextStyle(color: context.textColor),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: loc.supportMessageHint,
                hintStyle: TextStyle(color: context.textGreyColor),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: AppPrimaryButton(
              onPressed: _sending ? null : _submit,
              isLoading: _sending,
              child: Text(loc.sendButton),
            ),
          ),
        ],
      ),
    );
  }
}
