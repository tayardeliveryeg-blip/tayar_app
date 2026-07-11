import 'package:flutter/material.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'passenger_home.dart';

// ====== شاشة مساعدة: أسئلة شائعة عن استخدام طيار (راكب وطيار) ======
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  List<_FaqItem> _buildFaqs(AppLocalizations l10n) {
    return [
      _FaqItem(
        question: l10n.faqOrderTripQuestion,
        answer: l10n.faqOrderTripAnswer,
      ),
      _FaqItem(
        question: l10n.faqPricingQuestion,
        answer: l10n.faqPricingAnswer,
      ),
      _FaqItem(
        question: l10n.faqPaymentMethodsQuestion,
        answer: l10n.faqPaymentMethodsAnswer,
      ),
      _FaqItem(
        question: l10n.faqNoAcceptQuestion,
        answer: l10n.faqNoAcceptAnswer,
      ),
      _FaqItem(
        question: l10n.faqBecomeDriverQuestion,
        answer: l10n.faqBecomeDriverAnswer,
      ),
      _FaqItem(
        question: l10n.faqDriverEarningsQuestion,
        answer: l10n.faqDriverEarningsAnswer,
      ),
      _FaqItem(
        question: l10n.faqDeliverPackageQuestion,
        answer: l10n.faqDeliverPackageAnswer,
      ),
      _FaqItem(
        question: l10n.faqTripProblemQuestion,
        answer: l10n.faqTripProblemAnswer,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final faqs = _buildFaqs(l10n);
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        iconTheme:  IconThemeData(color: context.textColor),
        title: Text(
          l10n.helpScreenTitle,
          style:  TextStyle(color: context.textColor),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: faqs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final faq = faqs[index];
          return Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Container(
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ExpansionTile(
                iconColor: TayarColors.primary,
                collapsedIconColor: context.textGreyColor,
                title: Text(
                  faq.question,
                  style: TextStyle(
                    color: context.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    faq.answer,
                    style:  TextStyle(
                      color: context.textGreyColor,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem({required this.question, required this.answer});
}
