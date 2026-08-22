import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/passenger/home/passenger_home_screen.dart'
    show TayarColors, TayarThemeColors;
import 'package:tayay_app/services/driver_relations_service.dart';
import 'package:tayay_app/widgets/app_card.dart';
import 'package:tayay_app/widgets/empty_state.dart';

/// ====== شاشة "سائقيني" - تبويبين: المفضّلين والمحظورين (بند 5 من
/// تحليل الفجوات، خطوة 2/3). بتقرا مباشرة من الـ streams اللي في
/// DriverRelationsService، فأي تغيير (من شاشة التقييم مثلًا) بينعكس
/// هنا فورًا من غير ما نحتاج نعمل refresh يدوي ======
class MyDriversScreen extends StatelessWidget {
  const MyDriversScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: context.bgColor,
        appBar: AppBar(
          backgroundColor: context.bgColor,
          elevation: 0,
          iconTheme: IconThemeData(color: context.textColor),
          title: Text(
            loc.myDriversScreenTitle,
            style: TextStyle(
              color: context.textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          bottom: TabBar(
            labelColor: TayarColors.primary,
            unselectedLabelColor: context.textGreyColor,
            indicatorColor: TayarColors.primary,
            tabs: [
              Tab(text: loc.favoriteDriversTabLabel),
              Tab(text: loc.blockedDriversTabLabel),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _DriversList(
              stream: DriverRelationsService.favoritesStream(),
              nameField: 'driverName',
              dateField: 'addedAt',
              emptyMessage: loc.noFavoriteDriversYetMessage,
              leadingIcon: Icons.star,
              leadingColor: TayarColors.primary,
              actionLabel: loc.removeFromFavoriteDriversButton,
              onAction: (driverId, driverName) =>
                  DriverRelationsService.setFavorite(
                    driverId: driverId,
                    driverName: driverName,
                    isFavorite: false,
                  ),
            ),
            _DriversList(
              stream: DriverRelationsService.blockedStream(),
              nameField: 'driverName',
              dateField: 'blockedAt',
              driverIdField: 'driverId',
              emptyMessage: loc.noBlockedDriversYetMessage,
              leadingIcon: Icons.block,
              leadingColor: Colors.redAccent,
              actionLabel: loc.unblockDriverButton,
              onAction: (driverId, driverName) =>
                  DriverRelationsService.setBlocked(
                    driverId: driverId,
                    driverName: driverName,
                    isBlocked: false,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriversList extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String nameField;
  final String dateField;
  // ====== favoriteDrivers: doc.id هو نفسه driverId. driverBlocks:
  // doc.id مركّب "{passengerId}_{driverId}"، فمحتاجين نقرا driverId
  // من حقل منفصل جوه المستند بدل الاعتماد على doc.id ======
  final String? driverIdField;
  final String emptyMessage;
  final IconData leadingIcon;
  final Color leadingColor;
  final String actionLabel;
  final Future<void> Function(String driverId, String driverName) onAction;

  const _DriversList({
    required this.stream,
    required this.nameField,
    required this.dateField,
    this.driverIdField,
    required this.emptyMessage,
    required this.leadingIcon,
    required this.leadingColor,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: TayarColors.primary),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return EmptyState(
            icon: leadingIcon,
            title: emptyMessage,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final driverId = driverIdField != null
                ? (data[driverIdField!] as String? ?? doc.id)
                : doc.id;
            final driverName = data[nameField] as String? ?? '';
            return AppCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: leadingColor.withValues(alpha: 0.15),
                    child: Icon(leadingIcon, color: leadingColor, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      driverName,
                      style: TextStyle(
                        color: context.textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => onAction(driverId, driverName),
                    child: Text(
                      actionLabel,
                      style: TextStyle(color: leadingColor, fontSize: 13),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
