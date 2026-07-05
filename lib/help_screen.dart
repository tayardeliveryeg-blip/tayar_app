import 'package:flutter/material.dart';
import 'passenger_home.dart';

// ====== شاشة مساعدة: أسئلة شائعة عن استخدام طيار (راكب وطيار) ======
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const List<_FaqItem> _faqs = [
    _FaqItem(
      question: 'إزاي أطلب رحلة؟',
      answer:
          'من الشاشة الرئيسية، حدد نقطة الانطلاق ثم اختار الوجهة، وبعدها '
          'شوف السعر المقترح وابعت الطلب. هتظهرلك عروض من الطيارين القريبين '
          'وتقدر تختار العرض اللي يناسبك.',
    ),
    _FaqItem(
      question: 'إزاي بيتحدد السعر؟',
      answer:
          'السعر بيتحسب على أساس المسافة الفعلية بين نقطة الانطلاق والوجهة، '
          'وتقدر تزود أو تقلل السعر المقترح وقت المزايدة مع الطيارين.',
    ),
    _FaqItem(
      question: 'وسايل الدفع المتاحة إيه؟',
      answer:
          'تقدر تدفع كاش للطيار مباشرة، أو من خلال المحفظة الإلكترونية، أو '
          'عن طريق إنستاباي. تقدر تختار وسيلة الدفع وانت بتأكد الطلب.',
    ),
    _FaqItem(
      question: 'مفيش حد بيقبل طلبي، أعمل إيه؟',
      answer:
          'جرب تزود السعر شوية وقت المزايدة، خصوصًا في أوقات الذروة أو '
          'المناطق البعيدة، ده بيخلي الطلب أكثر جاذبية للطيارين القريبين.',
    ),
    _FaqItem(
      question: 'إزاي أبقى طيار في تطبيق طيار؟',
      answer:
          'من القايمة الجانبية اختار "وضع الطيار" وكمّل خطوات التسجيل '
          '(البيانات، الرخصة، الموتوسيكل)، وبعد المراجعة هتقدر تستقبل طلبات.',
    ),
    _FaqItem(
      question: 'إزاي بتتحسب أرباح الطيار؟',
      answer:
          'من كل رحلة، الطيار بياخد نسبة 90% من قيمة الرحلة والشركة بتاخد '
          '10% مقابل تشغيل المنصة. تقدر تتابع تفاصيل أرباحك من تبويب "الدخلي".',
    ),
    _FaqItem(
      question: 'تقدر أوصّل طرد بدل ما أعمل رحلة راكب؟',
      answer:
          'أيوه، من خدمة "توصيل الطرود" تقدر تبعت طرد من مكان لمكان من غير '
          'ما تكون موجود في الرحلة، ونفس نظام المزايدة بيتطبق برضه.',
    ),
    _FaqItem(
      question: 'إيه اللي أعمله لو حصلت مشكلة في رحلة؟',
      answer:
          'تقدر تتواصل مع فريق الدعم مباشرة من شاشة "الدعم" في القايمة '
          'الجانبية، وهنساعدك تحل المشكلة أول بأول.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TayarColors.background,
      appBar: AppBar(
        backgroundColor: TayarColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('مساعدة', style: TextStyle(color: Colors.white)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _faqs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final faq = _faqs[index];
          return Theme(
            data: Theme.of(
              context,
            ).copyWith(dividerColor: Colors.transparent),
            child: Container(
              decoration: BoxDecoration(
                color: TayarColors.cardDark,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ExpansionTile(
                iconColor: TayarColors.primary,
                collapsedIconColor: TayarColors.textGrey,
                title: Text(
                  faq.question,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    faq.answer,
                    style: const TextStyle(
                      color: TayarColors.textGrey,
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
