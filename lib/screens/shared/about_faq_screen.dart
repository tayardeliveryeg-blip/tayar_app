import 'package:flutter/material.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart'
    show TayarColors, TayarThemeColors;
import 'package:tayay_app/widgets/app_card.dart';

// ====================================================
// ====== بند 9 من gap analysis: صفحة "نبذة عن التطبيق" + الأسئلة
// الشائعة - مكانتش موجودة خالص قبل كده. شاشة إنفورميشن بحتة (من غير
// أي كتابة على Firestore)، بتتفتح من شاشة الإعدادات ======
// ====================================================
class AboutFaqScreen extends StatelessWidget {
  const AboutFaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    // ====== نفس ترتيب الأسئلة السبعة في الـ arb - لو ضفت سؤال جديد
    // بعدين، ضيفه هنا وفي app_ar.arb/app_en.arb بنفس النمط ======
    final faqs = <_FaqItem>[
      _FaqItem(loc.faqBookingQuestion, loc.faqBookingAnswer),
      _FaqItem(loc.faqPricingQuestion, loc.faqPricingAnswer),
      _FaqItem(loc.faqCancellationQuestion, loc.faqCancellationAnswer),
      _FaqItem(loc.faqWalletQuestion, loc.faqWalletAnswer),
      _FaqItem(loc.faqBecomeDriverQuestion, loc.faqBecomeDriverAnswer),
      _FaqItem(loc.faqSosQuestion, loc.faqSosAnswer),
      _FaqItem(loc.faqSupportQuestion, loc.faqSupportAnswer),
    ];

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textColor),
        title: Text(loc.navAboutFaq, style: TextStyle(color: context.textColor)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ====== شعار/أيقونة التطبيق فوق النبذة - نفس هوية العلامة
          // التجارية (اللون البرتقالي الأساسي) ======
          Center(
            child: Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: TayarColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.two_wheeler,
                color: TayarColors.primary,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            loc.aboutUsSectionTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.textColor,
            ),
          ),
          const SizedBox(height: 8),
          AppCard(
            radius: 14,
            padding: const EdgeInsets.all(16),
            showShadow: false,
            child: Text(
              loc.aboutUsBody,
              style: TextStyle(color: context.textGreyColor, height: 1.6),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            loc.faqSectionTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.textColor,
            ),
          ),
          const SizedBox(height: 8),
          AppCard(
            radius: 14,
            padding: EdgeInsets.zero,
            showShadow: false,
            child: Column(
              children: [
                for (var i = 0; i < faqs.length; i++) ...[
                  if (i > 0) Divider(color: context.dividerColor2, height: 1),
                  Theme(
                    // ====== بنشيل خط الفصل الافتراضي بتاع ExpansionTile
                    // نفسه عشان نستخدم الـ Divider اليدوي بس، من غير
                    // ازدواج خطوط ======
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      iconColor: TayarColors.primary,
                      collapsedIconColor: context.textGreyColor,
                      title: Text(
                        faqs[i].question,
                        style: TextStyle(
                          color: context.textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                        ),
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      expandedAlignment: Alignment.centerLeft,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            faqs[i].answer,
                            style: TextStyle(
                              color: context.textGreyColor,
                              height: 1.5,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem(this.question, this.answer);
}
