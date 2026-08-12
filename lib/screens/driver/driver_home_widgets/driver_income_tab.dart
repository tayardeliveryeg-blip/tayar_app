import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/theme/theme_extensions.dart';
import 'package:tayay_app/widgets/app_card.dart';

// ====== تبويب "دخلي": إجمالي الأرباح واليوم الحالي ======
// (كانت قبل كده private classes جوه driver_home_screen.dart واتقسمت في ملف منفصل)
class DriverIncomeTab extends StatelessWidget {
  final String driverId;
  const DriverIncomeTab({super.key, required this.driverId});

  @override
  Widget build(BuildContext context) {
    final startOfToday = DateTime.now();
    final todayStart = DateTime(
      startOfToday.year,
      startOfToday.month,
      startOfToday.day,
    );

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'completed')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: TayarColors.primary),
          );
        }

        final docs = snapshot.data!.docs;
        double total = 0;
        double todayTotal = 0;
        for (final doc in docs) {
          final data = doc.data();
          final fare = (data['acceptedFare'] as num?)?.toDouble() ?? 0;
          total += fare;

          final completedAt = data['completedAt'];
          if (completedAt is Timestamp &&
              completedAt.toDate().isAfter(todayStart)) {
            todayTotal += fare;
          }
        }

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            IncomeSummaryCard(
              title: AppLocalizations.of(context)!.todayIncome,
              value: todayTotal,
              icon: Icons.today,
            ),
            const SizedBox(height: AppSpacing.lg),
            IncomeSummaryCard(
              title: AppLocalizations.of(context)!.totalIncome,
              value: total,
              icon: Icons.payments,
            ),
            const SizedBox(height: AppSpacing.lg),
            IncomeSummaryCard(
              title: AppLocalizations.of(context)!.completedTripsCount,
              value: docs.length.toDouble(),
              icon: Icons.route,
              isCurrency: false,
            ),
          ],
        );
      },
    );
  }
}

// ====== كارت ملخص واحد (دخل اليوم/الإجمالي/عدد الرحلات) ======
class IncomeSummaryCard extends StatelessWidget {
  final String title;
  final double value;
  final IconData icon;
  final bool isCurrency;

  const IncomeSummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.isCurrency = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        children: [
          Icon(icon, color: TayarColors.primary, size: 28),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: context.textGreyColor, fontSize: 14),
            ),
          ),
          Text(
            isCurrency
                ? AppLocalizations.of(
                    context,
                  )!.currencyEGP(value.toStringAsFixed(0))
                : value.toStringAsFixed(0),
            style: TextStyle(
              color: context.textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

