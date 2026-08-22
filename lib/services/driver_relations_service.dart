import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ====== خدمة السائقين المفضّلين والمحظورين عند الراكب (بند 5 من
/// تحليل الفجوات) ======
///
/// - المفضّلين: users/{passengerId}/favoriteDrivers/{driverId} - مرجعية
///   بس، مفيش تأثير تشغيلي على الطيار، بتُستخدم بس لعرض قايمة سريعة
///   للراكب في بروفايله.
/// - المحظورين: collection منفصلة على المستوى الأعلى driverBlocks
///   (document ID = "{passengerId}_{driverId}") عشان الطيار نفسه يقدر
///   يعمل query عليها (driverId == uid بتاعه) ويعرف مين حاظره، من غير
///   ما يحتاج صلاحية قراءة بروفايل الراكب. ده اللي بيخلي التصفية في
///   driver_requests_tab.dart ممكنة (خطوة تالية).
class DriverRelationsService {
  DriverRelationsService._();

  static final _firestore = FirebaseFirestore.instance;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> _favoritesRef(
    String passengerId,
  ) => _firestore
      .collection('users')
      .doc(passengerId)
      .collection('favoriteDrivers');

  static CollectionReference<Map<String, dynamic>> get _blocksRef =>
      _firestore.collection('driverBlocks');

  static String _blockId(String passengerId, String driverId) =>
      '${passengerId}_$driverId';

  // ====== المفضّلين ======

  /// بتضيف/تشيل طيار من قايمة المفضّلين عند الراكب الحالي.
  static Future<void> setFavorite({
    required String driverId,
    required String driverName,
    required bool isFavorite,
  }) async {
    final uid = _uid;
    if (uid == null || driverId.isEmpty) return;
    final ref = _favoritesRef(uid).doc(driverId);
    if (isFavorite) {
      await ref.set({
        'driverName': driverName,
        'addedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.delete();
    }
  }

  static Stream<bool> isFavoriteStream(String driverId) {
    final uid = _uid;
    if (uid == null || driverId.isEmpty) return Stream.value(false);
    return _favoritesRef(uid).doc(driverId).snapshots().map((s) => s.exists);
  }

  /// قايمة كل السائقين المفضّلين عند الراكب الحالي (لشاشة الإدارة).
  static Stream<QuerySnapshot<Map<String, dynamic>>> favoritesStream() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _favoritesRef(uid).orderBy('addedAt', descending: true).snapshots();
  }

  // ====== المحظورين ======

  /// بتحظر/تفك حظر طيار معيّن عند الراكب الحالي. الطيار المحظور مش هيقدر
  /// يبقى شايف طلبات الراكب ده تاني (التصفية بتحصل عند الطيار).
  static Future<void> setBlocked({
    required String driverId,
    required String driverName,
    required bool isBlocked,
  }) async {
    final uid = _uid;
    if (uid == null || driverId.isEmpty || driverId == uid) return;
    final ref = _blocksRef.doc(_blockId(uid, driverId));
    if (isBlocked) {
      await ref.set({
        'passengerId': uid,
        'driverId': driverId,
        'driverName': driverName,
        'blockedAt': FieldValue.serverTimestamp(),
      });
      // ====== لو الطيار ده كان متسجل كمفضّل قبل كده، بنشيله من
      // المفضّلين تلقائيًا - محدش المفروض يبقى مفضّل ومحظور في نفس الوقت ======
      await _favoritesRef(uid).doc(driverId).delete().catchError((_) {});
    } else {
      await ref.delete();
    }
  }

  static Stream<bool> isBlockedStream(String driverId) {
    final uid = _uid;
    if (uid == null || driverId.isEmpty) return Stream.value(false);
    return _blocksRef
        .doc(_blockId(uid, driverId))
        .snapshots()
        .map((s) => s.exists);
  }

  /// قايمة كل السائقين المحظورين من الراكب الحالي (لشاشة الإدارة).
  static Stream<QuerySnapshot<Map<String, dynamic>>> blockedStream() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _blocksRef
        .where('passengerId', isEqualTo: uid)
        .orderBy('blockedAt', descending: true)
        .snapshots();
  }

  /// بتُستخدم في جانب الطيار (driver_home_screen.dart) - مجموعة الـ
  /// passengerId بتوع كل الركاب اللي حاظرين الطيار الحالي، عشان تتصفّى
  /// بيها الطلبات المتاحة قبل ما يشوفها الطيار. تُنادى مرة واحدة عند
  /// فتح شاشة الطلبات وتتحدّث Live لأنها Stream.
  static Stream<Set<String>> blockedByPassengerIdsForCurrentDriver() {
    final uid = _uid;
    if (uid == null) return Stream.value(const {});
    return _blocksRef
        .where('driverId', isEqualTo: uid)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => d.data()['passengerId'] as String? ?? '')
              .where((id) => id.isNotEmpty)
              .toSet(),
        );
  }
}
