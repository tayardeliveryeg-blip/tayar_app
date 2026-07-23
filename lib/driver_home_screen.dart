import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'passenger_home.dart';
import 'login_screen.dart';
import 'main.dart';
import 'notifications_screen.dart';
import 'security_screen.dart';
import 'settings_screen.dart';
import 'help_screen.dart';
import 'support_screen.dart';
import 'driver_profile_screen.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'trip_chat_screen.dart';
import 'call_invitation_setup.dart';
import 'call_invitation_helper.dart';
import 'push_notification_service.dart';
import 'driver_trip_tracking_screen.dart';
import 'pin_marker.dart';
import 'map_tile_layer.dart';
import 'wallet_service.dart';
import 'driver_wallet_topup_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  // ====== لتتبع الطلبات اللي الطيار قدّم عليها عرض في الجلسة الحالية ======
  final Set<String> _offeredOrderIds = {};

  // ====== مشاركة الموقع اللحظي وقت وجود رحلة نشطة (accepted / in_progress) ======
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _activeTripListener;
  StreamSubscription<Position>? _positionSub;
  String? _sharingTripId;

  // ====== لكشف الوصول للوجهة تلقائيًا وقت الرحلة الفعلية (in_progress) ======
  String? _activeTripStatus;
  LatLng? _activeTripDestination;
  bool _hasNotifiedArrival = false;

  // ====== تحكم الطيار اليدوي: متاح ولا لأ (زرار "متاح/غير متاح") ======
  // بيبدأ false افتراضيًا؛ الطيار لازم يدوس بنفسه عشان يظهر للركاب
  bool _isOnline = false;
  bool _isTogglingOnline = false;

  // ====== التبويب المختار في الشريط السفلي ======
  int _selectedTab = 0;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  CollectionReference<Map<String, dynamic>> get _ordersRef =>
      FirebaseFirestore.instance.collection('orders');

  // ====== كوليكشن منفصلة وخفيفة لموقع التوفر اللحظي بس (مش بيانات الطيار الحساسة) ======
  // بيقدر أي مستخدم داخل بحسابه يقراها (عشان الراكب يشوف الطيارين القريبين)
  // من غير ما يقدر يشوف بيانات drivers الحساسة (رخصة، مستندات، إلخ)
  CollectionReference<Map<String, dynamic>> get _driverLocationsRef =>
      FirebaseFirestore.instance.collection('driver_locations');

  @override
  void initState() {
    super.initState();
    // ====== نحفظ إن آخر وضع فتحه المستخدم هو "طيار" عشان لو قفل التطبيق وفتحه تاني يرجعله ======
    _saveLastMode('driver');
    _watchActiveTripForLocationSharing();
    // ====== بدء بث الموقع المستمر طول ما شاشة الطيار مفتوحة ======
    // (سواء الطيار "متاح" وبيدور على طلبات، أو في رحلة فعلية)
    _startLocationBroadcast();
    // ====== تفعيل استقبال إشعارات الشات + دعوات المكالمات (لازم بعد تسجيل الدخول) ======
    PushNotificationService.instance.init(isDriver: true);
    setupCallInvitationService(navigatorKey: navigatorKey);
    // ====== تعبئة رقم التليفون تلقائيًا لو السائق سجل قبل إضافة هذا الحقل ======
    _backfillPhoneNumber();
  }

  // ====== لوحة التحكم محتاجة رقم تليفون السائق؛ السائقين اللي سجلوا قبل ما نضيف
  // الحقل ده هيتملّه تلقائيًا من رقم تسجيل الدخول أول ما يفتحوا الشاشة دي ======
  Future<void> _backfillPhoneNumber() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber;
    if (uid == null || phone == null || phone.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('drivers').doc(uid).get();
      final existingPhone = (doc.data()?['personalInfo'] as Map?)?['phone'] as String?;
      if (existingPhone == null || existingPhone.isEmpty) {
        await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
          'personalInfo': {'phone': phone},
        }, SetOptions(merge: true));
      }
    } catch (_) {
      // صامت: مجرد تعبئة اختيارية، لا داعي لإزعاج السائق لو فشلت
    }
  }

  Future<void> _saveLastMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastMode', mode);
  }

  // ====== تأكيد تسجيل الخروج قبل تنفيذه فعليًا ======
  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Text(
          AppLocalizations.of(context)!.logout,
          style: TextStyle(color: context.textColor),
        ),
        content: Text(
          AppLocalizations.of(context)!.confirmLogoutMessage,
          style: TextStyle(color: context.textGreyColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppLocalizations.of(context)!.cancel,
              style: TextStyle(color: context.textGreyColor),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppLocalizations.of(context)!.logout,
              style: const TextStyle(color: TayarColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      // ====== نسجل خروج من Google لو المستخدم داخل بيه، وبعدين من Firebase ======
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
      await FirebaseAuth.instance.signOut();
      // ====== نمسح آخر وضع محفوظ عشان أي حساب تاني يسجل دخول من نفس الجهاز ما يفتحش غلط ======
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('lastMode');
    } catch (e) {
      debugPrint('❌ خطأ أثناء تسجيل الخروج: $e');
    }

    if (!context.mounted) return;

    // ====== نمسح كل الشاشات السابقة ونرجع لشاشة تسجيل الدخول من الأول ======
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _activeTripListener?.cancel();
    _positionSub?.cancel();
    // ====== إخفاء الطيار من قايمة "المتاحين" عند إغلاق الشاشة/التطبيق ======
    final uid = _currentUser?.uid;
    if (uid != null) {
      _driverLocationsRef
          .doc(uid)
          .set({'isAvailable': false}, SetOptions(merge: true))
          .catchError((_) {});
    }
    super.dispose();
  }

  // ====== دالة مساعدة موحّدة لاستخراج GeoPoint من حقول الموقع ======
  // بتدعم صيغة geoflutterfire_plus الجديدة (Map فيه geopoint + geohash)
  // وكمان الصيغة القديمة (GeoPoint مباشر) كـ fallback
  GeoPoint? _extractGeoPoint(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw['geopoint'] as GeoPoint?;
    } else if (raw is GeoPoint) {
      return raw;
    }
    return null;
  }

  // ====== بيراقب لو فيه رحلة نشطة للطيار الحالي، ويحدّث isAvailable تبعًا لكده ======
  void _watchActiveTripForLocationSharing() {
    final uid = _currentUser?.uid;
    if (uid == null) return;

    _activeTripListener = _ordersRef
        .where('driverId', isEqualTo: uid)
        .where('status', whereIn: ['accepted', 'in_progress'])
        .limit(1)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isEmpty) {
            if (_sharingTripId != null) {
              _sharingTripId = null;
              _activeTripStatus = null;
              _activeTripDestination = null;
              _hasNotifiedArrival = false;
              // ====== يرجع "متاح" بس لو الطيار مفعّل الزرار بنفسه ======
              _driverLocationsRef
                  .doc(uid)
                  .set({'isAvailable': _isOnline}, SetOptions(merge: true))
                  .catchError((_) {});
            }
            return;
          }

          final doc = snapshot.docs.first;
          final tripId = doc.id;
          final data = doc.data();

          // ====== نحدّث حالة الرحلة ووجهتها في كل مرة (حتى لو نفس الرحلة)
          // عشان نلحق لحظة تحول الحالة من accepted لـ in_progress، واللي
          // عليها بيتوقف كشف الوصول للوجهة تحت ======
          _activeTripStatus = data['status'] as String?;
          final destGeo = _extractGeoPoint(data['destinationLocation']);
          _activeTripDestination = destGeo != null
              ? LatLng(destGeo.latitude, destGeo.longitude)
              : null;

          if (_sharingTripId == tripId) return;
          final bool isNewlyAcceptedTrip = _sharingTripId == null;
          _sharingTripId = tripId;
          _hasNotifiedArrival = false;
          // ====== اختفي من قايمة "المتاحين" فورًا عند قبول رحلة ======
          _driverLocationsRef
              .doc(uid)
              .set({'isAvailable': false}, SetOptions(merge: true))
              .catchError((_) {});
          // ====== نبعت موقعه الحالي فورًا من غير ما ننتظر أول حركة فعلية،
          // عشان الراكب يشوفه على طول لحظة القبول مش بعد ما يمشي 5 متر ======
          _pushImmediateDriverLocation(tripId);

          // ====== أول لحظة يتقبل فيها عرض الطيار، نفتحله شاشة الخريطة/التتبع
          // تلقائيًا عشان يشوف نقطة الانطلاق والوصول والمسار على طول ======
          if (isNewlyAcceptedTrip) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DriverTripTrackingScreen(orderId: tripId),
                ),
              );
            });
          }
        });
  }

  // ====== بتاخد موقع الطيار الحالي مرة واحدة وتبعته فورًا لمستند الرحلة،
  // بتتنفذ فقط لحظة قبول الرحلة عشان الراكب مايستناش لحد ما الطيار يتحرك ======
  Future<void> _pushImmediateDriverLocation(String tripId) async {
    try {
      final granted = await _ensureLocationPermission();
      if (!granted) return;

      // ====== أول حاجة: آخر موقع معروف (لو موجود) بيرجع فورًا من غير أي
      // انتظار، فنبعته على طول عشان الراكب يشوف الطيار فورًا. القراءة الدقيقة
      // الجديدة هتوصل بعد كده وتحدّثه تاني (تحت). ======
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null && mounted && _sharingTripId == tripId) {
          final quickPoint = GeoFirePoint(
            GeoPoint(lastKnown.latitude, lastKnown.longitude),
          );
          await _ordersRef.doc(tripId).update({
            'driverLocation': quickPoint.data,
            'driverHeading': lastKnown.heading,
            'driverLocationUpdatedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (_) {
        // تجاهل، هنكمل على القراءة الدقيقة الجديدة تحت
      }

      // ====== دلوقتي قراءة حقيقية جديدة، بدقة متوسطة (أسرع بكتير من العالية
      // خصوصًا على المتصفح/الديسكتوب) ومع سقف وقت 8 ثواني عشان الطلب
      // مايفضلش معلّق للأبد لو الجهاز مالوش GPS حقيقي ======
      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 8),
          ),
        );
      } on TimeoutException {
        debugPrint(
          '⏱️ تحديد موقع الطيار الدقيق استغرق وقت طويل، هنكتفي بآخر قراءة',
        );
        return;
      }

      if (!mounted || _sharingTripId != tripId) return;

      final geoFirePoint = GeoFirePoint(
        GeoPoint(position.latitude, position.longitude),
      );
      await _ordersRef.doc(tripId).update({
        'driverLocation': geoFirePoint.data,
        'driverHeading': position.heading,
        'driverLocationUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ خطأ في إرسال أول موقع للطيار لحظة القبول: $e');
    }
  }

  Future<bool> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  // ====== بث الموقع المستمر: يشتغل طول ما شاشة الطيار مفتوحة ======
  // لو في رحلة (_sharingTripId != null) → يحدّث موقعه في مستند الطلب (للراكب في التتبع اللحظي)
  // لو متاح (مفيش رحلة) → يحدّث موقعه في مستند الطيار نفسه (عشان يظهر للركاب القريبين على الخريطة الرئيسية)
  Future<void> _startLocationBroadcast() async {
    final granted = await _ensureLocationPermission();
    if (!granted || !mounted) return;

    final uid = _currentUser?.uid;
    if (uid == null) return;

    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            distanceFilter:
                5, // يحدّث كل ما يتحرك 5 متر، توفيرًا للبطارية والداتا
          ),
        ).listen((position) {
          final geoFirePoint = GeoFirePoint(
            GeoPoint(position.latitude, position.longitude),
          );

          final tripId = _sharingTripId;
          if (tripId != null) {
            // ====== في رحلة فعلية: حدّث موقعه في مستند الطلب ======
            _ordersRef
                .doc(tripId)
                .update({
                  'driverLocation': geoFirePoint.data,
                  'driverHeading': position.heading,
                  'driverLocationUpdatedAt': FieldValue.serverTimestamp(),
                })
                .catchError((e) {
                  debugPrint('❌ خطأ في إرسال موقع الطيار: $e');
                });

            // ====== كشف الوصول للوجهة تلقائيًا: لو الرحلة شغالة فعليًا
            // (in_progress) والطيار قرّب من نقطة الوجهة (أقل من 40 متر)
            // لأول مرة، نوريه إشعار واضح مع زرار سريع لإنهاء الرحلة ======
            if (_activeTripStatus == 'in_progress' &&
                _activeTripDestination != null &&
                !_hasNotifiedArrival) {
              final distanceMeters = Geolocator.distanceBetween(
                position.latitude,
                position.longitude,
                _activeTripDestination!.latitude,
                _activeTripDestination!.longitude,
              );
              if (distanceMeters < 40) {
                _hasNotifiedArrival = true;
                _notifyArrivalAtDestination(tripId);
              }
            }
          } else {
            // ====== متاح (مفيش رحلة): حدّث موقعه بس لو دوس "متاح" بنفسه ======
            if (_isOnline) {
              _driverLocationsRef
                  .doc(uid)
                  .set({
                    'currentLocation': geoFirePoint.data,
                    'currentHeading': position.heading,
                    'isAvailable': true,
                    'locationUpdatedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true))
                  .catchError((e) {
                    debugPrint('❌ خطأ في إرسال موقع التوفر: $e');
                  });
            }
          }
        });
  }

  // ====== يتنفذ لما الطيار يدوس زرار "متاح/غير متاح" ======
  Future<void> _toggleOnline() async {
    final uid = _currentUser?.uid;
    if (uid == null || _isTogglingOnline) return;

    setState(() => _isTogglingOnline = true);
    final goingOnline = !_isOnline;

    try {
      if (!goingOnline) {
        // ====== غير متاح: يختفي من خريطة الراكب فورًا ======
        await _driverLocationsRef.doc(uid).set({
          'isAvailable': false,
        }, SetOptions(merge: true));
        if (mounted) setState(() => _isOnline = false);
      } else {
        // ====== متاح: نفعّلها فورًا من غير ما ننتظر GPS دقيق ======
        final granted = await _ensureLocationPermission();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)!.permissionLocationRequired,
                ),
              ),
            );
          }
          return;
        }

        // ====== نجيب آخر موقع معروف (فوري) عشان الظهور يبقى سريع ======
        Position? quickPosition;
        try {
          quickPosition = await Geolocator.getLastKnownPosition();
        } catch (_) {}

        final updateData = <String, dynamic>{
          'isAvailable': true,
          'locationUpdatedAt': FieldValue.serverTimestamp(),
        };
        if (quickPosition != null) {
          final geoFirePoint = GeoFirePoint(
            GeoPoint(quickPosition.latitude, quickPosition.longitude),
          );
          updateData['currentLocation'] = geoFirePoint.data;
          updateData['currentHeading'] = quickPosition.heading;
        }
        await _driverLocationsRef
            .doc(uid)
            .set(updateData, SetOptions(merge: true));
        if (mounted) setState(() => _isOnline = true);

        // ====== نجيب موقع دقيق فعلي في الخلفية من غير ما نعطّل الزرار ======
        // (الاستريم المستمر في _startLocationBroadcast هيكمّل تحديثه بعد كده على أي حال)
        Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium,
                timeLimit: Duration(seconds: 10),
              ),
            )
            .then((freshPosition) {
              if (!mounted || !_isOnline) return;
              final geoFirePoint = GeoFirePoint(
                GeoPoint(freshPosition.latitude, freshPosition.longitude),
              );
              _driverLocationsRef
                  .doc(uid)
                  .set({
                    'currentLocation': geoFirePoint.data,
                    'currentHeading': freshPosition.heading,
                    'locationUpdatedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true))
                  .catchError((_) {});
            })
            .catchError((e) {
              debugPrint('⚠️ تعذر الحصول على موقع دقيق فورًا: $e');
            });
      }
    } catch (e) {
      debugPrint('❌ خطأ في تغيير حالة التوفر: $e');
    } finally {
      if (mounted) setState(() => _isTogglingOnline = false);
    }
  }

  // ====== جلب متوسط تقييم السائق من الكاش الجاهز ======
  // بدل ما نجيب كل الطلبات المكتملة ونحسب المتوسط كل مرة (استعلام تقيل ومكلّف)،
  // بنقرا مستند drivers/{uid} بس اللي فيه ratingSum و ratingCount جاهزين
  // ومتحدّثين أول ما يوصل تقييم جديد (شوف transaction في شاشة تقييم الرحلة)
  // بيرجع null لو السائق لسه معندوش أي تقييمات (سائق جديد)
  Future<double?> _getDriverAverageRating(String driverId) async {
    try {
      await ensureDriverRatingCacheExists(driverId);
      final doc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .get();
      final data = doc.data();
      final count = (data?['ratingCount'] as num?)?.toInt() ?? 0;
      if (count <= 0) return null;
      final sum = (data?['ratingSum'] as num?)?.toDouble() ?? 0.0;
      return sum / count;
    } catch (e) {
      debugPrint('⚠️ تعذر جلب متوسط تقييم السائق: $e');
      return null;
    }
  }

  // ====== جلب اسم السائق الحقيقي من بروفايله في Firestore ======
  // بنفس الأولوية المستخدمة في باقي الشاشة: الاسم اللي السائق كتبه في بياناته
  // الشخصية (firstName + lastName) أولًا، وإلا اسم حساب Google، وإلا اسم
  // افتراضي كـ fallback أخير. من غير كده كان بيتسجّل اسم حساب المصادقة بس،
  // فلو السائق غيّر اسمه في البروفايل ما كانش بيظهر للراكب في الرحلة.
  Future<String> _getDriverDisplayName(String driverId, String fallback) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .get();
      final personalInfo = doc.data()?['personalInfo'] as Map<String, dynamic>?;
      final firstName = (personalInfo?['firstName'] as String?)?.trim();
      final lastName = (personalInfo?['lastName'] as String?)?.trim();
      final firestoreName = [
        firstName,
        lastName,
      ].where((s) => s != null && s.isNotEmpty).join(' ');
      if (firestoreName.isNotEmpty) return firestoreName;
    } catch (e) {
      debugPrint('⚠️ تعذر جلب اسم بروفايل السائق: $e');
    }
    final googleName = _currentUser?.displayName?.trim();
    if (googleName != null && googleName.isNotEmpty) return googleName;
    return fallback;
  }

  // ====== إرسال عرض سعر على طلب معين ======
  Future<void> _submitOffer(String orderId, double price) async {
    final user = _currentUser;
    if (user == null) return;

    // ====== ناخد النص الافتراضي قبل أي await، عشان منستخدمش context
    // بعد فجوة async من غير ما نتأكد إن الشاشة لسه mounted ======
    final defaultDriverName = AppLocalizations.of(context)!.defaultDriverName;

    try {
      final averageRating = await _getDriverAverageRating(user.uid);
      final driverName = await _getDriverDisplayName(
        user.uid,
        defaultDriverName,
      );

      await _ordersRef.doc(orderId).collection('offers').add({
        'driverId': user.uid,
        'driverName': driverName,
        // لو السائق لسه معندوش تقييمات، بنبعت null بدل رقم وهمي؛
        // شاشة الراكب لازم تتعامل مع null كـ "سائق جديد" بدل ما تعرض نجوم فاضية
        'driverRating': averageRating,
        'price': price,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => _offeredOrderIds.add(orderId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.offerSentWaitingPassenger,
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ خطأ في إرسال العرض: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.offerSendFailed)),
      );
    }
  }

  void _openOfferSheet(QueryDocumentSnapshot<Map<String, dynamic>> orderDoc) {
    final data = orderDoc.data();
    final double proposedFare = (data['proposedFare'] as num?)?.toDouble() ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _OfferSheet(
        proposedFare: proposedFare,
        pickupAddress: (data['pickupAddress'] as String?) ?? '',
        destinationAddress: (data['destinationAddress'] as String?) ?? '',
        distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0,
        onSubmit: (price) {
          Navigator.pop(context);
          _submitOffer(orderDoc.id, price);
        },
      ),
    );
  }

  // ====== بدء الرحلة (بعد قبول العرض) ======
  Future<void> _startTrip(String orderId) async {
    await _ordersRef.doc(orderId).update({'status': 'in_progress'});
  }

  // ====== إنهاء الرحلة ======
  Future<void> _completeTrip(String orderId) async {
    final driverId = _currentUser?.uid;
    if (driverId == null) return;
    await completeTripAndDeductCommission(
      orderId: orderId,
      driverId: driverId,
    );
  }

  // ====== إشعار للطيار لحظة وصوله فعليًا لنقطة الوجهة، مع زرار سريع
  // لإنهاء الرحلة من غير ما يدور على الزرار في الكارت ======
  void _notifyArrivalAtDestination(String tripId) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 12),
        backgroundColor: TayarColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        content: Text(
          AppLocalizations.of(context)!.arrivedAtDestination,
          style: TextStyle(
            color: context.onPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        action: SnackBarAction(
          label: AppLocalizations.of(context)!.endTrip,
          textColor: context.textColor,
          onPressed: () => _completeTrip(tripId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: context.textColor),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: GestureDetector(
          onTap: _isTogglingOnline ? null : _toggleOnline,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: _isOnline
                  ? TayarColors.primary.withValues(alpha: 0.15)
                  : context.textColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.xxl),
              border: Border.all(
                color: _isOnline ? TayarColors.primary : context.dividerColor2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isTogglingOnline)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.textColor,
                    ),
                  )
                else
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: _isOnline ? TayarColors.primary : Colors.grey,
                  ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _isOnline
                      ? AppLocalizations.of(context)!.driverToggleOnline
                      : AppLocalizations.of(context)!.driverToggleOffline,
                  style: TextStyle(
                    color: _isOnline
                        ? TayarColors.primary
                        : context.textGreyColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          // ====== زرار تبديل اللغة اتشال من هنا؛ التحكم في اللغة بقى
          // من شاشة الإعدادات فقط (مكان واحد موحّد لكل التطبيق) ======
          IconButton(
            icon: Icon(Icons.person, color: context.textColor),
            onPressed: () async {
              // ====== نحفظ إن آخر وضع بقى "راكب" عشان يفتح عليه المرة الجاية ======
              await _saveLastMode('passenger');
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const PassengerHomeScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: user == null
          ? Center(
              child: Text(
                AppLocalizations.of(context)!.mustSignInFirst,
                style: TextStyle(color: context.textGreyColor),
              ),
            )
          : IndexedStack(
              index: _selectedTab,
              children: [
                _buildRequestsTab(user),
                _DriverIncomeTab(driverId: user.uid),
                _DriverRatingTab(driverId: user.uid),
                _DriverWalletTab(driverId: user.uid),
              ],
            ),
      drawer: _buildDriverDrawer(context),
      bottomNavigationBar: user == null
          ? null
          : BottomNavigationBar(
              currentIndex: _selectedTab,
              onTap: (index) => setState(() => _selectedTab = index),
              backgroundColor: context.cardColor,
              selectedItemColor: TayarColors.primary,
              unselectedItemColor: context.textGreyColor,
              type: BottomNavigationBarType.fixed,
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.list_alt),
                  label: AppLocalizations.of(context)!.tabRequests,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.payments_outlined),
                  label: AppLocalizations.of(context)!.tabIncome,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.star_outline),
                  label: AppLocalizations.of(context)!.tabRatings,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: AppLocalizations.of(context)!.tabWallet,
                ),
              ],
            ),
    );
  }

  // ====== محتوى تبويب "طلباتي" (الرحلة النشطة + الطلبات المتاحة) ======
  Widget _buildRequestsTab(User user) {
    return Column(
      children: [
        // ====== الرحلة النشطة (لو موجودة) ======
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _ordersRef
              .where('driverId', isEqualTo: user.uid)
              .where('status', whereIn: ['accepted', 'in_progress'])
              .limit(1)
              .snapshots(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) return const SizedBox.shrink();

            final trip = docs.first;
            final data = trip.data();
            final bool inProgress = data['status'] == 'in_progress';

            return _ActiveTripCard(
              orderId: trip.id,
              customerId: (data['customerId'] as String?) ?? '',
              customerName:
                  (data['customerName'] as String?) ??
                  AppLocalizations.of(context)!.defaultCustomerName,
              pickupAddress: (data['pickupAddress'] as String?) ?? '',
              destinationAddress: (data['destinationAddress'] as String?) ?? '',
              fare: (data['acceptedFare'] as num?)?.toDouble() ?? 0,
              paymentMethod:
                  (data['paymentMethod'] as String?) ??
                  AppLocalizations.of(context)!.paymentMethodCash,
              inProgress: inProgress,
              onStart: () => _startTrip(trip.id),
              onComplete: () => _completeTrip(trip.id),
              onOpenTracking: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DriverTripTrackingScreen(orderId: trip.id),
                ),
              ),
            );
          },
        ),

        // ====== الطلبات المتاحة اللي بتدور على عروض (تظهر بس لو الطيار أونلاين) ======
        Expanded(
          child: !_isOnline
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.power_settings_new,
                          color: context.textGreyColor,
                          size: 40,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          AppLocalizations.of(context)!.driverOfflineHint,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.textGreyColor),
                        ),
                      ],
                    ),
                  ),
                )
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _ordersRef
                      .where('status', isEqualTo: 'searching')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          AppLocalizations.of(context)!.errorLoadingOrders,
                          style: TextStyle(color: context.textGreyColor),
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

                    final orders = snapshot.data!.docs;
                    if (orders.isEmpty) {
                      return Center(
                        child: Text(
                          AppLocalizations.of(context)!.driverNoOrders,
                          style: TextStyle(color: context.textGreyColor),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: orders.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        final data = order.data();
                        final bool alreadyOffered = _offeredOrderIds.contains(
                          order.id,
                        );

                        return _OrderRequestCard(
                          pickupAddress:
                              (data['pickupAddress'] as String?) ?? '',
                          destinationAddress:
                              (data['destinationAddress'] as String?) ?? '',
                          distanceKm:
                              (data['distanceKm'] as num?)?.toDouble() ?? 0,
                          durationMin:
                              (data['durationMin'] as num?)?.toInt() ?? 0,
                          proposedFare:
                              (data['proposedFare'] as num?)?.toDouble() ?? 0,
                          paymentMethod:
                              (data['paymentMethod'] as String?) ??
                              AppLocalizations.of(context)!.paymentMethodCash,
                          alreadyOffered: alreadyOffered,
                          onQuickAccept: alreadyOffered
                              ? null
                              : () => _submitOffer(
                                  order.id,
                                  (data['proposedFare'] as num?)?.toDouble() ??
                                      0,
                                ),
                          onCustomOffer: alreadyOffered
                              ? null
                              : () => _openOfferSheet(order),
                          onOpenDetails: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _TripRequestDetailScreen(
                                orderId: order.id,
                                pickupAddress:
                                    (data['pickupAddress'] as String?) ?? '',
                                destinationAddress:
                                    (data['destinationAddress'] as String?) ??
                                    '',
                                pickupLocation: _extractGeoPoint(
                                  data['pickupLocation'],
                                ),
                                destinationLocation: _extractGeoPoint(
                                  data['destinationLocation'],
                                ),
                                distanceKm:
                                    (data['distanceKm'] as num?)?.toDouble() ??
                                    0,
                                durationMin:
                                    (data['durationMin'] as num?)?.toInt() ?? 0,
                                proposedFare:
                                    (data['proposedFare'] as num?)
                                        ?.toDouble() ??
                                    0,
                                paymentMethod:
                                    (data['paymentMethod'] as String?) ??
                                    AppLocalizations.of(
                                      context,
                                    )!.paymentMethodCash,
                                alreadyOffered: alreadyOffered,
                                onQuickAccept: alreadyOffered
                                    ? null
                                    : () => _submitOffer(
                                        order.id,
                                        (data['proposedFare'] as num?)
                                                ?.toDouble() ??
                                            0,
                                      ),
                                onCustomOffer: alreadyOffered
                                    ? null
                                    : (price) => _submitOffer(order.id, price),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ====== القايمة الجانبية (Drawer) ======
  Widget _buildDriverDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: context.bgColor,
      child: SafeArea(
        child: Column(
          children: [
            InkWell(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DriverProfileScreen(),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _currentUser == null
                      ? null
                      : FirebaseFirestore.instance
                            .collection('drivers')
                            .doc(_currentUser!.uid)
                            .snapshots(),
                  builder: (context, snapshot) {
                    final personalInfo =
                        snapshot.data?.data()?['personalInfo']
                            as Map<String, dynamic>?;

                    final photoBase64 = personalInfo?['photoBase64'] as String?;
                    ImageProvider? photo;
                    if (photoBase64 != null && photoBase64.isNotEmpty) {
                      try {
                        photo = MemoryImage(base64Decode(photoBase64));
                      } catch (_) {
                        photo = null;
                      }
                    }

                    // ====== اسم السائق الحقيقي: من بيانات Firestore أولًا
                    // (firstName + lastName اللي السائق كتبهم في البروفايل)،
                    // وإلا اسم حساب Google المسجل بيه، وإلا اسم افتراضي
                    // كـ fallback أخير — بنفس منطق شاشة الراكب بالظبط ======
                    final firstName = (personalInfo?['firstName'] as String?)
                        ?.trim();
                    final lastName = (personalInfo?['lastName'] as String?)
                        ?.trim();
                    final firestoreName = [
                      firstName,
                      lastName,
                    ].where((s) => s != null && s.isNotEmpty).join(' ');
                    final googleName = _currentUser?.displayName?.trim();
                    final displayName = firestoreName.isNotEmpty
                        ? firestoreName
                        : (googleName != null && googleName.isNotEmpty)
                        ? googleName
                        : AppLocalizations.of(context)!.defaultDriverName;

                    return Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: TayarColors.primary,
                          backgroundImage: photo,
                          child: photo == null
                              ? Icon(
                                  Icons.two_wheeler,
                                  color: context.onPrimaryColor,
                                  size: 30,
                                )
                              : null,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: TextStyle(
                                  color: context.textColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                _isOnline
                                    ? AppLocalizations.of(
                                        context,
                                      )!.statusAvailable
                                    : AppLocalizations.of(
                                        context,
                                      )!.statusUnavailable,
                                style: TextStyle(
                                  color: _isOnline
                                      ? TayarColors.primary
                                      : context.textGreyColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: context.textGreyColor),
                      ],
                    );
                  },
                ),
              ),
            ),
            Divider(color: context.dividerColor2, height: 1),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _DriverDrawerItem(
                    icon: Icons.list_alt,
                    label: AppLocalizations.of(context)!.tabRequests,
                    selected: _selectedTab == 0,
                    onTap: () {
                      setState(() => _selectedTab = 0);
                      Navigator.pop(context);
                    },
                  ),
                  _DriverDrawerItem(
                    icon: Icons.payments_outlined,
                    label: AppLocalizations.of(context)!.navIncome,
                    selected: _selectedTab == 1,
                    onTap: () {
                      setState(() => _selectedTab = 1);
                      Navigator.pop(context);
                    },
                  ),
                  _DriverDrawerItem(
                    icon: Icons.star_outline,
                    label: AppLocalizations.of(context)!.navRatings,
                    selected: _selectedTab == 2,
                    onTap: () {
                      setState(() => _selectedTab = 2);
                      Navigator.pop(context);
                    },
                  ),
                  _DriverDrawerItem(
                    icon: Icons.account_balance_wallet_outlined,
                    label: AppLocalizations.of(context)!.navWallet,
                    selected: _selectedTab == 3,
                    onTap: () {
                      setState(() => _selectedTab = 3);
                      Navigator.pop(context);
                    },
                  ),
                  Divider(color: context.dividerColor2, height: 24),
                  _DriverDrawerItem(
                    icon: Icons.notifications_none,
                    label: AppLocalizations.of(context)!.navNotifications,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                    },
                  ),
                  _DriverDrawerItem(
                    icon: Icons.shield_outlined,
                    label: AppLocalizations.of(context)!.navSecurity,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SecurityScreen(),
                        ),
                      );
                    },
                  ),
                  _DriverDrawerItem(
                    icon: Icons.settings_outlined,
                    label: AppLocalizations.of(context)!.navSettings,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  _DriverDrawerItem(
                    icon: Icons.info_outline,
                    label: AppLocalizations.of(context)!.navHelp,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HelpScreen()),
                      );
                    },
                  ),
                  _DriverDrawerItem(
                    icon: Icons.support_agent,
                    label: AppLocalizations.of(context)!.navSupport,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SupportScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(color: context.dividerColor2, height: 24),
                  _DriverDrawerItem(
                    icon: Icons.logout,
                    label: AppLocalizations.of(context)!.logout,
                    isDestructive: true,
                    onTap: () => _confirmLogout(context),
                  ),
                ],
              ),
            ),

            // ====== زرار الرجوع لوضع الركاب ======
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    // ====== نحفظ إن آخر وضع بقى "راكب" عشان يفتح عليه المرة الجاية ======
                    await _saveLastMode('passenger');
                    if (!context.mounted) return;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PassengerHomeScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TayarColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.backToPassengerModeButton,
                    style: TextStyle(
                      color: context.onPrimaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            // ====== أيقونات السوشيال ميديا ======
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _DriverSocialIcon(
                    icon: Icons.facebook,
                    onTap: () =>
                        launchSocialUrl(context, TayarSocialLinks.facebook),
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  _DriverSocialIcon(
                    icon: Icons.camera_alt_outlined, // إنستجرام
                    onTap: () =>
                        launchSocialUrl(context, TayarSocialLinks.instagram),
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  _DriverSocialIcon(
                    icon: Icons.chat_bubble_outline, // واتساب
                    onTap: () =>
                        launchSocialUrl(context, TayarSocialLinks.whatsapp),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====== كارت طلب راكب متاح ======
class _OrderRequestCard extends StatelessWidget {
  final String pickupAddress;
  final String destinationAddress;
  final double distanceKm;
  final int durationMin;
  final double proposedFare;
  final String paymentMethod;
  final bool alreadyOffered;
  final VoidCallback? onQuickAccept;
  final VoidCallback? onCustomOffer;
  final VoidCallback? onOpenDetails;

  const _OrderRequestCard({
    required this.pickupAddress,
    required this.destinationAddress,
    required this.distanceKm,
    required this.durationMin,
    required this.proposedFare,
    required this.paymentMethod,
    required this.alreadyOffered,
    required this.onQuickAccept,
    required this.onCustomOffer,
    this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      onTap: onOpenDetails,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: TayarColors.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: TayarColors.primary,
                  size: 16,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    pickupAddress,
                    style: TextStyle(color: context.textColor, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: Row(
                children: [
                  SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    height: 14,
                    child: VerticalDivider(
                      color: context.dividerColor2,
                      thickness: 2,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                const Icon(Icons.flag, color: TayarColors.primary, size: 16),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    destinationAddress,
                    style: TextStyle(color: context.textColor, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.distanceDurationLabel(
                    distanceKm.toStringAsFixed(1),
                    durationMin,
                  ),
                  style: TextStyle(color: context.textGreyColor, fontSize: 12),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      AppLocalizations.of(
                        context,
                      )!.currencyEGP(proposedFare.toStringAsFixed(0)),
                      style: const TextStyle(
                        color: TayarColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: context.textColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.xxl),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.payments_outlined,
                            color: context.textGreyColor,
                            size: 12,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            paymentMethodDisplay(context, paymentMethod),
                            style: TextStyle(
                              color: context.textGreyColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (alreadyOffered)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(
                    AppLocalizations.of(context)!.offerSentAlreadyLabel,
                    style: TextStyle(
                      color: context.textGreyColor,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCustomOffer,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        side: const BorderSide(color: TayarColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.offerCustomButton,
                        style: TextStyle(color: TayarColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onQuickAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TayarColors.primary,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.acceptProposedPrice,
                        style: TextStyle(color: context.textColor),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ====== شيت تقديم عرض بسعر مخصص ======
class _OfferSheet extends StatefulWidget {
  final double proposedFare;
  final String pickupAddress;
  final String destinationAddress;
  final double distanceKm;
  final ValueChanged<double> onSubmit;

  const _OfferSheet({
    required this.proposedFare,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.distanceKm,
    required this.onSubmit,
  });

  @override
  State<_OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends State<_OfferSheet> {
  late double _price;
  static const double _step = 5.0;

  @override
  void initState() {
    super.initState();
    _price = widget.proposedFare;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.handleColor,
              borderRadius: BorderRadius.circular(AppRadius.handle),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '${widget.pickupAddress} ← ${widget.destinationAddress}',
            style: TextStyle(color: context.textColor, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppLocalizations.of(
              context,
            )!.distanceKmLabel(widget.distanceKm.toStringAsFixed(1)),
            style: TextStyle(color: context.textGreyColor, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            AppLocalizations.of(context)!.setYourPriceLabel,
            style: TextStyle(color: context.textColor, fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StepButton(
                icon: Icons.remove,
                onTap: () {
                  if (_price - _step > 0) setState(() => _price -= _step);
                },
              ),
              SizedBox(
                width: 130,
                child: Text(
                  AppLocalizations.of(
                    context,
                  )!.currencyEGP(_price.toStringAsFixed(0)),
                  textAlign: TextAlign.center,
                  style: TayarStatTextStyles.statSmall,
                ),
              ),
              _StepButton(
                icon: Icons.add,
                onTap: () => setState(() => _price += _step),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => widget.onSubmit(_price),
              style: ElevatedButton.styleFrom(
                backgroundColor: TayarColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: Text(
                AppLocalizations.of(context)!.submitOfferButton,
                style: TextStyle(
                  color: context.onPrimaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: TayarColors.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: context.onPrimaryColor, size: 20),
      ),
    );
  }
}

// ====== كارت الرحلة النشطة فوق قائمة الطلبات ======
class _ActiveTripCard extends StatelessWidget {
  final String orderId;
  final String customerId;
  final String customerName;
  final String pickupAddress;
  final String destinationAddress;
  final double fare;
  final String paymentMethod;
  final bool inProgress;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onOpenTracking;

  const _ActiveTripCard({
    required this.orderId,
    required this.customerId,
    required this.customerName,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.fare,
    required this.paymentMethod,
    required this.inProgress,
    required this.onStart,
    required this.onComplete,
    required this.onOpenTracking,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
      decoration: BoxDecoration(
        color: TayarColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: TayarColors.primary.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ====== منطقة قابلة للضغط: بتفتح شاشة الخريطة والتتبع اللحظي ======
          InkWell(
            onTap: onOpenTracking,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          inProgress
                              ? AppLocalizations.of(
                                  context,
                                )!.tripInProgressLabel
                              : AppLocalizations.of(
                                  context,
                                )!.tripAcceptedWaitingLabel,
                          style: const TextStyle(
                            color: TayarColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.map_outlined,
                        color: TayarColors.primary.withValues(alpha: 0.8),
                        size: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '$pickupAddress ← $destinationAddress',
                    style: TextStyle(color: context.textColor, fontSize: 14),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Text(
                        AppLocalizations.of(
                          context,
                        )!.currencyEGP(fare.toStringAsFixed(0)),
                        style: TextStyle(
                          color: context.textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Icon(
                        Icons.payments_outlined,
                        color: context.textColor.withValues(alpha: 0.7),
                        size: 14,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        paymentMethodDisplay(context, paymentMethod),
                        style: TextStyle(
                          color: context.textColor.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ====== زرارين التواصل مع الراكب: شات ومكالمة صوتية ======
                Row(
                  children: [
                    Expanded(
                      child: _DriverContactButton(
                        icon: Icons.chat_bubble_outline,
                        label: AppLocalizations.of(
                          context,
                        )!.chatWithPassengerLabel,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TripChatScreen(
                                orderId: orderId,
                                otherPartyName: customerName,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _DriverContactButton(
                        icon: Icons.call_outlined,
                        label: AppLocalizations.of(context)!.callPassengerLabel,
                        onTap: () async {
                          try {
                            await sendCallInvitation(
                              calleeId: customerId,
                              calleeName: customerName,
                            );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('تعذر بدء المكالمة: $e'),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: inProgress ? onComplete : onStart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TayarColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                    child: Text(
                      inProgress
                          ? AppLocalizations.of(context)!.endTrip
                          : AppLocalizations.of(context)!.startTrip,
                      style: TextStyle(
                        color: context.textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ====== زرار موحّد لأزرار "شات" و"مكالمة" في كارت الرحلة النشطة للطيار ======
class _DriverContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DriverContactButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: TayarColors.primary.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: TayarColors.primary.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: TayarColors.primary, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: const TextStyle(
                color: TayarColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====== عنصر واحد في القايمة الجانبية لشاشة الطيار ======
class _DriverDrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isDestructive;
  final VoidCallback? onTap;

  const _DriverDrawerItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.isDestructive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color itemColor = isDestructive
        ? TayarColors.error
        : (selected ? TayarColors.primary : context.textColor);

    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive
            ? TayarColors.error
            : (selected ? TayarColors.primary : context.textGreyColor),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: itemColor,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: onTap,
    );
  }
}

// ====== أيقونة سوشيال ميديا دايرية في أسفل القايمة الجانبية ======
class _DriverSocialIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _DriverSocialIcon({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: context.textGreyColor),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: context.textColor, size: 20),
      ),
    );
  }
}

// ====== تبويب "دخلي": إجمالي الأرباح واليوم الحالي ======
class _DriverIncomeTab extends StatelessWidget {
  final String driverId;
  const _DriverIncomeTab({required this.driverId});

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
            _IncomeSummaryCard(
              title: AppLocalizations.of(context)!.todayIncome,
              value: todayTotal,
              icon: Icons.today,
            ),
            const SizedBox(height: AppSpacing.lg),
            _IncomeSummaryCard(
              title: AppLocalizations.of(context)!.totalIncome,
              value: total,
              icon: Icons.payments,
            ),
            const SizedBox(height: AppSpacing.lg),
            _IncomeSummaryCard(
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

// ====== يتأكد إن مستند drivers/{uid} فيه ratingSum/ratingCount جاهزين ======
// لو السائق قديم من قبل إضافة الكاش ده (أو مفيش كاش لأي سبب)، بيحسبها مرة واحدة
// من كل الطلبات المكتملة القديمة ويخزنها، عشان أي قراءة بعد كده تبقى رخيصة
// (مستند واحد بدل مسح كل الطلبات في كل مرة). لو الكاش موجود بالفعل، منعملش حاجة.
// top-level (مش جوه كلاس) عشان يتنادى من أي مكان في الملف: شاشة الطيار وتبويب التقييم.
Future<void> ensureDriverRatingCacheExists(String driverId) async {
  final driverRef = FirebaseFirestore.instance
      .collection('drivers')
      .doc(driverId);
  try {
    final doc = await driverRef.get();
    if (doc.data()?['ratingCount'] != null) return; // متحسبة بالفعل

    final snapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'completed')
        .get();

    final ratings = <double>[];
    for (final d in snapshot.docs) {
      final r = (d.data()['rating'] as num?)?.toDouble();
      if (r != null) ratings.add(r);
    }
    final sum = ratings.fold<double>(0, (a, b) => a + b);

    await driverRef.set({
      'ratingSum': sum,
      'ratingCount': ratings.length,
    }, SetOptions(merge: true));
  } catch (e) {
    debugPrint('⚠️ تعذر تجهيز كاش تقييم السائق: $e');
  }
}

// ====== تبويب "تقييمي": متوسط تقييمات الركاب ======
// بيقرا من كاش drivers/{uid} (ratingSum/ratingCount) بدل ما يمسح كل الطلبات
// المكتملة في كل مرة الشاشة تتفتح. أول مرة (initState) بنتأكد إن الكاش
// موجود أصلًا (بيتحسب تلقائي لو مفيش) وبعد كده الـ stream بيتحدث لحظيًا.
class _DriverRatingTab extends StatefulWidget {
  final String driverId;
  const _DriverRatingTab({required this.driverId});

  @override
  State<_DriverRatingTab> createState() => _DriverRatingTabState();
}

class _DriverRatingTabState extends State<_DriverRatingTab> {
  @override
  void initState() {
    super.initState();
    ensureDriverRatingCacheExists(widget.driverId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('drivers')
          .doc(widget.driverId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: TayarColors.primary),
          );
        }

        final data = snapshot.data!.data();
        final count = (data?['ratingCount'] as num?)?.toInt() ?? 0;

        if (count <= 0) {
          return Center(
            child: Text(
              AppLocalizations.of(context)!.driverNoRatings,
              style: TextStyle(color: context.textGreyColor),
            ),
          );
        }

        final sum = (data?['ratingSum'] as num?)?.toDouble() ?? 0.0;
        final avg = sum / count;

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(avg.toStringAsFixed(2), style: TayarStatTextStyles.statHuge),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final filled = i < avg.round();
                  return Icon(
                    filled ? Icons.star : Icons.star_border,
                    color: TayarColors.primary,
                    size: 24,
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                AppLocalizations.of(context)!.ratingCountLabel(count),
                style: TextStyle(color: context.textGreyColor, fontSize: 14),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ====== تبويب "محفظتي": الرصيد الصافي بعد عمولة الشركة (10%) ======
class _DriverWalletTab extends StatelessWidget {
  final String driverId;
  const _DriverWalletTab({required this.driverId});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .snapshots(),
      builder: (context, driverSnapshot) {
        final balance =
            (driverSnapshot.data?.data()?['walletBalance'] as num?)
                ?.toDouble() ??
            0;
        final isNegative = balance < 0;

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            // ====== كارت الرصيد الحالي ======
            Container(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              decoration: BoxDecoration(
                color: (isNegative ? TayarColors.error : TayarColors.primary)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.xxl),
                border: Border.all(
                  color: (isNegative ? TayarColors.error : TayarColors.primary)
                      .withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    loc.availableBalance,
                    style: TextStyle(
                      color: context.textGreyColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    loc.currencyEGP(balance.toStringAsFixed(0)),
                    style: TayarStatTextStyles.statMedium.copyWith(
                      color: isNegative ? TayarColors.error : TayarColors.primary,
                    ),
                  ),
                  if (isNegative) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      loc.negativeWalletBalanceNote,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: TayarColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ====== زرار شحن المحفظة ======
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TayarColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
                icon: Icon(
                  Icons.add_card_outlined,
                  color: context.onPrimaryColor,
                ),
                label: Text(
                  loc.topUpWalletButton,
                  style: TextStyle(
                    color: context.onPrimaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DriverWalletTopupScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // ====== سجل المعاملات ======
            Text(
              loc.walletTransactionsTitle,
              style: TextStyle(
                color: context.textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('drivers')
                  .doc(driverId)
                  .collection('walletTransactions')
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, txnSnapshot) {
                if (!txnSnapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: CircularProgressIndicator(
                        color: TayarColors.primary,
                      ),
                    ),
                  );
                }
                final docs = txnSnapshot.data!.docs;
                if (docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Center(
                      child: Text(
                        loc.noWalletTransactionsLabel,
                        style: TextStyle(color: context.textGreyColor),
                      ),
                    ),
                  );
                }
                return Column(
                  children: docs
                      .map((doc) => _WalletTransactionTile(data: doc.data()))
                      .toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// ====== سطر واحد في سجل معاملات المحفظة (عمولة رحلة أو طلب شحن) ======
class _WalletTransactionTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _WalletTransactionTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final type = data['type'] as String? ?? '';
    final status = data['status'] as String? ?? '';
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;

    late final String label;
    late final IconData icon;
    late final Color color;

    if (type == 'commission') {
      label = loc.walletCommissionTransactionLabel;
      icon = Icons.percent;
      color = TayarColors.error;
    } else if (status == 'approved') {
      label = loc.walletTopupApprovedLabel;
      icon = Icons.check_circle_outline;
      color = TayarColors.success;
    } else if (status == 'rejected') {
      label = loc.walletTopupRejectedLabel;
      icon = Icons.cancel_outlined;
      color = TayarColors.error;
    } else {
      label = loc.walletTopupPendingLabel;
      icon = Icons.hourglass_top_outlined;
      color = TayarColors.warning;
    }

    final displayAmount = type == 'commission'
        ? amount // من الأساس بالسالب في الداتا
        : amount.abs();
    final sign = displayAmount < 0 || type == 'commission' ? '' : '+';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: context.textColor, fontSize: 14),
            ),
          ),
          Text(
            '$sign${loc.currencyEGP(displayAmount.abs().toStringAsFixed(0))}',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ====== كارت ملخص رقمي (بيتستخدم في تبويبات الدخل والمحفظة) ======
class _IncomeSummaryCard extends StatelessWidget {
  final String title;
  final double value;
  final IconData icon;
  final bool isCurrency;

  const _IncomeSummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    this.isCurrency = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
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

// ====== شاشة تفاصيل طلب الرحلة: خريطة بالنقطتين + واجهة المزايدة ======
class _TripRequestDetailScreen extends StatefulWidget {
  final String orderId;
  final String pickupAddress;
  final String destinationAddress;
  final GeoPoint? pickupLocation;
  final GeoPoint? destinationLocation;
  final double distanceKm;
  final int durationMin;
  final double proposedFare;
  final String paymentMethod;
  final bool alreadyOffered;
  final VoidCallback? onQuickAccept;
  final ValueChanged<double>? onCustomOffer;

  const _TripRequestDetailScreen({
    required this.orderId,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.pickupLocation,
    required this.destinationLocation,
    required this.distanceKm,
    required this.durationMin,
    required this.proposedFare,
    required this.paymentMethod,
    required this.alreadyOffered,
    this.onQuickAccept,
    this.onCustomOffer,
  });

  @override
  State<_TripRequestDetailScreen> createState() =>
      _TripRequestDetailScreenState();
}

class _TripRequestDetailScreenState extends State<_TripRequestDetailScreen> {
  List<LatLng> _routePoints = [];
  late double _price;

  @override
  void initState() {
    super.initState();
    _price = widget.proposedFare;
    _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    final pickup = widget.pickupLocation;
    final dest = widget.destinationLocation;
    if (pickup == null || dest == null) return;

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${pickup.longitude},${pickup.latitude};'
        '${dest.longitude},${dest.latitude}'
        '?overview=full&geometries=geojson',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return;

      final json = jsonDecode(response.body);
      final coords =
          json['routes'][0]['geometry']['coordinates'] as List<dynamic>;
      final points = coords
          .map(
            (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
          )
          .toList();

      if (mounted) setState(() => _routePoints = points);
    } catch (e) {
      debugPrint('⚠️ تعذر جلب المسار: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pickup = widget.pickupLocation;
    final dest = widget.destinationLocation;
    final hasLocations = pickup != null && dest != null;

    final center = hasLocations
        ? LatLng(
            (pickup.latitude + dest.latitude) / 2,
            (pickup.longitude + dest.longitude) / 2,
          )
        : const LatLng(30.2854, 31.7414); // مركز افتراضي (العاشر من رمضان)

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textColor),
        title: Text(
          AppLocalizations.of(context)!.orderDetailsTitle,
          style: TextStyle(color: context.textColor),
        ),
      ),
      body: Column(
        children: [
          // ====== الخريطة: نقطة الانطلاق (A) والوجهة (B) ======
          Expanded(
            flex: 3,
            child: hasLocations
                ? FlutterMap(
                    options: MapOptions(initialCenter: center, initialZoom: 13),
                    children: [
                      const TayarTileLayer(),
                      if (_routePoints.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _routePoints,
                              color: TayarColors.primary,
                              strokeWidth: 4,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(pickup.latitude, pickup.longitude),
                            width: 40,
                            height: 40,
                            child: const PinMarker(
                              type: PinType.pickup,
                              size: 40,
                            ),
                          ),
                          Marker(
                            point: LatLng(dest.latitude, dest.longitude),
                            width: 40,
                            height: 40,
                            child: const PinMarker(
                              type: PinType.destination,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Center(
                    child: Text(
                      AppLocalizations.of(context)!.locationUnavailableForOrder,
                      style: TextStyle(color: context.textGreyColor),
                    ),
                  ),
          ),

          // ====== كارت العنوانين + واجهة المزايدة ======
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: TayarColors.primary,
                              size: 16,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                widget.pickupAddress,
                                style: TextStyle(color: context.textColor),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          child: SizedBox(
                            height: 14,
                            child: VerticalDivider(
                              color: context.dividerColor2,
                              thickness: 2,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.flag,
                              color: TayarColors.primary,
                              size: 16,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                widget.destinationAddress,
                                style: TextStyle(color: context.textColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppLocalizations.of(
                                context,
                              )!.distanceDurationLabel(
                                widget.distanceKm.toStringAsFixed(1),
                                widget.durationMin,
                              ),
                              style: TextStyle(
                                color: context.textGreyColor,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              paymentMethodDisplay(
                                context,
                                widget.paymentMethod,
                              ),
                              style: TextStyle(
                                color: context.textGreyColor,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ====== واجهة المزايدة (زيادة/نقصان السعر) ======
                  if (!widget.alreadyOffered) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _StepButton(
                          icon: Icons.remove,
                          onTap: () {
                            if (_price - 5 > 0) {
                              setState(() => _price -= 5);
                            }
                          },
                        ),
                        SizedBox(
                          width: 120,
                          child: Text(
                            AppLocalizations.of(
                              context,
                            )!.currencyEGP(_price.toStringAsFixed(0)),
                            textAlign: TextAlign.center,
                            style: TayarStatTextStyles.statSmall,
                          ),
                        ),
                        _StepButton(
                          icon: Icons.add,
                          onTap: () => setState(() => _price += 5),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              widget.onCustomOffer?.call(_price);
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                              side: const BorderSide(
                                color: TayarColors.primary,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(
                                context,
                              )!.offerAtMyPriceButton,
                              style: TextStyle(color: TayarColors.primary),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              widget.onQuickAccept?.call();
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TayarColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.acceptProposedPrice,
                              style: TextStyle(color: context.textColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.alreadyOfferedOnOrder,
                          style: TextStyle(color: context.textGreyColor),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
