import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/shared/support_screen.dart';
import 'package:tayay_app/theme/theme_extensions.dart';
import 'package:tayay_app/widgets/app_card.dart';
import 'package:tayay_app/widgets/empty_state.dart';
import 'package:tayay_app/widgets/tayar_shimmer.dart';

// ====== شاشة "شكاويّ": بتعرض للمستخدم كل التذاكر اللي بعتها من شاشة الدعم
// (support_tickets حيث userId == uid) لحظيًا، مع حالة كل تذكرة ورد الدعم
// الفني لو اتبعت. القراءة مسموحة له من firestore.rules (resource.data.userId
// == request.auth.uid) لكن التعديل (status/adminReply) محصور على الأدمن -
// فالشاشة دي read-only بالكامل من ناحية المستخدم ======
class MyTicketsScreen extends StatelessWidget {
  const MyTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textColor),
        title: Text(
          loc.myTicketsScreenTitle,
          style: TextStyle(color: context.textColor),
        ),
      ),
      body: uid == null
          ? const SizedBox.shrink()
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('support_tickets')
                  .where('userId', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      loc.genericErrorTryAgain,
                      style: TextStyle(color: context.textGreyColor),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: TayarShimmer.list(count: 4),
                  );
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return EmptyState(
                    icon: Icons.confirmation_number_outlined,
                    title: loc.noTicketsYetLabel,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final d = docs[index].data();
                    return _TicketCard(data: d, loc: loc);
                  },
                );
              },
            ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final AppLocalizations loc;

  const _TicketCard({required this.data, required this.loc});

  ComplaintCategory _categoryFromValue(String? value) {
    return ComplaintCategory.values.firstWhere(
      (c) => c.value == value,
      orElse: () => ComplaintCategory.other,
    );
  }

  ({Color color, String label}) _statusMeta(String? status) {
    switch (status) {
      case 'resolved':
        return (color: const Color(0xFF2ECC71), label: loc.ticketStatusResolved);
      case 'in_progress':
        return (color: const Color(0xFF3498DB), label: loc.ticketStatusInProgress);
      default:
        return (color: const Color(0xFFF39C12), label: loc.ticketStatusOpen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String?;
    final statusMeta = _statusMeta(status);
    final category = _categoryFromValue(data['category'] as String?);
    final message = (data['message'] as String?) ?? '';
    final adminReply = data['adminReply'] as String?;

    return AppCard(
      radius: 14,
      padding: const EdgeInsets.all(14),
      showShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  category.label(loc),
                  style: TextStyle(
                    color: context.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusMeta.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusMeta.label,
                  style: TextStyle(
                    color: statusMeta.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: context.textGreyColor, fontSize: 13)),
          if (adminReply != null && adminReply.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: TayarColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: TayarColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.adminReplyLabel,
                    style: const TextStyle(
                      color: TayarColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    adminReply,
                    style: TextStyle(color: context.textColor, fontSize: 13),
                  ),
                ],
              ),
            ),
          ] else if (status != 'resolved') ...[
            const SizedBox(height: 8),
            Text(
              loc.ticketAwaitingReplyLabel,
              style: TextStyle(
                color: context.textGreyColor,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
