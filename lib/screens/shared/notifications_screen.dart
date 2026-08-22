import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/driver/driver_home_screen.dart';
import 'package:tayay_app/screens/passenger/home/passenger_home_screen.dart';
import 'package:tayay_app/screens/passenger/passenger_wallet_screen.dart';
import 'package:tayay_app/widgets/app_card.dart';

// ====== شاشة الإشعارات: بتعرض إشعارات المستخدم الحالي لحظيًا من Firestore ======
// كل إشعار بيتخزن في collection('notifications') وفيه الحقول:
// userId, title, body, type (order/system/promo/wallet/driver_approval), createdAt, isRead
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  CollectionReference<Map<String, dynamic>> get _notificationsRef =>
      FirebaseFirestore.instance.collection('notifications');

  Future<void> _markAsRead(String docId) {
    return _notificationsRef.doc(docId).update({'isRead': true});
  }

  // ====== لما المستخدم يدوس على إشعار شحن المحفظة، نوديه على شاشة
  // محفظته على طول - بدل ما يفضل بس واقف في شاشة الإشعارات.
  //
  // بنحدد أي محفظة (راكب/طيار) من حقل walletRole المسجّل على الإشعار نفسه
  // (مبعوت من لوحة الأدمن وقت الإنشاء - راجع sendGeneralNotification في
  // tayar-admin/public/index.html وgeneral-notify Edge Function) - مش من
  // آخر وضع مستخدم في الجهاز (lastMode) زي ما كان بيحصل قبل كده. الاعتماد
  // على lastMode كان بيسبب باج واضح: لو الأدمن شحن محفظة الراكب والمستخدم
  // في نفس اللحظة واقف في وضع الطيار، الضغط على الإشعار كان بيفتحله شاشة
  // محفظة الطيار (رصيدها صفر) بدل محفظة الراكب اللي فعلًا اتشحنت.
  //
  // fallback على lastMode لسه موجود بس للإشعارات القديمة اللي اتبعتت قبل
  // إضافة الحقل ده ومفيهاش walletRole أصلًا ======
  Future<void> _handleTap(
    BuildContext context,
    String docId,
    String? type,
    String? walletRole,
  ) async {
    await _markAsRead(docId);
    if (type != 'wallet') return;
    if (!context.mounted) return;

    bool openDriverWallet;
    if (walletRole == 'driver') {
      openDriverWallet = true;
    } else if (walletRole == 'passenger') {
      openDriverWallet = false;
    } else {
      // ====== fallback قديم للإشعارات اللي اتبعتت قبل walletRole ======
      final prefs = await SharedPreferences.getInstance();
      if (!context.mounted) return;
      openDriverWallet = prefs.getString('lastMode') == 'driver';
    }

    if (openDriverWallet) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const DriverHomeScreen(initialTab: 3),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PassengerWalletScreen()),
      );
    }
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
      case 'driver_approval':
        return Icons.verified_outlined;
      case 'driver_rejection':
        return Icons.error_outline;
      default:
        return Icons.notifications_none;
    }
  }

  String _timeAgo(DateTime dateTime, AppLocalizations l10n) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return l10n.justNowLabel;
    if (diff.inMinutes < 60) return l10n.minutesAgoLabel(diff.inMinutes);
    if (diff.inHours < 24) return l10n.hoursAgoLabel(diff.inHours);
    if (diff.inDays < 7) return l10n.daysAgoLabel(diff.inDays);
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textColor),
        title: Text(
          l10n.navNotifications,
          style: TextStyle(color: context.textColor),
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
                  child: Text(
                    l10n.markAllAsReadButton,
                    style: const TextStyle(
                      color: TayarColors.primary,
                      fontSize: 14,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: uid == null
          ? Center(
              child: Text(
                l10n.mustSignInToViewNotifications,
                style: TextStyle(color: context.textGreyColor),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _notificationsRef
                  .where('userId', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  // ignore: avoid_print
                  print('TAYAR_NOTIF_ERROR: ${snapshot.error}');
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            l10n.errorLoadingNotifications,
                            style: TextStyle(color: context.textGreyColor),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${snapshot.error}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
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
                          color: context.textGreyColor.withValues(alpha: 0.6),
                          size: 56,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.noNotificationsYet,
                          style: TextStyle(color: context.textGreyColor),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
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

                    final type = data['type'] as String?;
                    final walletRole = data['walletRole'] as String?;
                    return AppCard(
                      onTap: () => _handleTap(context, doc.id, type, walletRole),
                      padding: const EdgeInsets.all(14),
                      radius: 14,
                      border: isRead
                          ? null
                          : Border.all(
                              color: TayarColors.primary.withValues(
                                alpha: 0.4,
                              ),
                            ),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: isRead
                                  ? context.dividerColor2
                                  : TayarColors.primary.withValues(alpha: 0.15),
                              child: Icon(
                                _iconForType(data['type'] as String?),
                                color: isRead
                                    ? context.textGreyColor
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
                                      color: context.textColor,
                                      fontWeight: isRead
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    body,
                                    style: TextStyle(
                                      color: context.textGreyColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _timeAgo(createdAt, l10n),
                                    style: TextStyle(
                                      color: context.textGreyColor,
                                      fontSize: 12,
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
                    );
                  },
                );
              },
            ),
    );
  }
}
