import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'passenger_home.dart';

// ====== شاشة الإشعارات: بتعرض إشعارات المستخدم الحالي لحظيًا من Firestore ======
// كل إشعار بيتخزن في collection('notifications') وفيه الحقول:
// userId, title, body, type (order/system/promo), createdAt, isRead
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  CollectionReference<Map<String, dynamic>> get _notificationsRef =>
      FirebaseFirestore.instance.collection('notifications');

  Future<void> _markAsRead(String docId) {
    return _notificationsRef.doc(docId).update({'isRead': true});
  }

  Future<void> _markAllAsRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in docs) {
      if (doc.data()['isRead'] != true) {
        batch.update(doc.reference, {'isRead': true});
      }
    }
    await batch.commit();
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'order':
        return Icons.two_wheeler;
      case 'promo':
        return Icons.local_offer_outlined;
      case 'wallet':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'من ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'من ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'من ${diff.inDays} يوم';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: TayarColors.background,
      appBar: AppBar(
        backgroundColor: TayarColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'الإشعارات',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          if (uid != null)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _notificationsRef
                  .where('userId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                final hasUnread = docs.any((d) => d.data()['isRead'] != true);
                if (!hasUnread) return const SizedBox.shrink();
                return TextButton(
                  onPressed: () => _markAllAsRead(docs),
                  child: const Text(
                    'تحديد الكل كمقروء',
                    style: TextStyle(color: TayarColors.primary, fontSize: 13),
                  ),
                );
              },
            ),
        ],
      ),
      body: uid == null
          ? const Center(
              child: Text(
                'لازم تسجل الدخول عشان تشوف الإشعارات',
                style: TextStyle(color: TayarColors.textGrey),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _notificationsRef
                  .where('userId', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'حصل خطأ في تحميل الإشعارات',
                      style: TextStyle(color: TayarColors.textGrey),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: TayarColors.primary,
                    ),
                  );
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          color: TayarColors.textGrey.withValues(alpha: 0.6),
                          size: 56,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'مفيش إشعارات لسه',
                          style: TextStyle(color: TayarColors.textGrey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final isRead = data['isRead'] == true;
                    final title = data['title'] as String? ?? '';
                    final body = data['body'] as String? ?? '';
                    final ts = data['createdAt'];
                    final createdAt = ts is Timestamp
                        ? ts.toDate()
                        : DateTime.now();

                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _markAsRead(doc.id),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: TayarColors.cardDark,
                          borderRadius: BorderRadius.circular(14),
                          border: isRead
                              ? null
                              : Border.all(
                                  color: TayarColors.primary.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: isRead
                                  ? Colors.white12
                                  : TayarColors.primary.withValues(
                                      alpha: 0.15,
                                    ),
                              child: Icon(
                                _iconForType(data['type'] as String?),
                                color: isRead
                                    ? TayarColors.textGrey
                                    : TayarColors.primary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: isRead
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    body,
                                    style: const TextStyle(
                                      color: TayarColors.textGrey,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _timeAgo(createdAt),
                                    style: const TextStyle(
                                      color: TayarColors.textGrey,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isRead)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(top: 4),
                                decoration: const BoxDecoration(
                                  color: TayarColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
