import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tayay_app/screens/passenger/home/passenger_home_screen.dart';
import 'package:tayay_app/screens/auth/login_screen.dart';
import 'package:tayay_app/main.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/services/call_invitation_setup.dart';
import 'package:tayay_app/services/push_notification_service.dart';
import 'package:tayay_app/widgets/pulsing_dot.dart';
import 'package:tayay_app/screens/driver/driver_trip_tracking_screen.dart';
import 'package:tayay_app/services/wallet_service.dart';
import 'package:tayay_app/services/driver_relations_service.dart';
import 'package:tayay_app/theme/app_settings.dart';
import 'package:tayay_app/screens/driver/driver_home_widgets/driver_income_tab.dart';
import 'package:tayay_app/screens/driver/driver_home_widgets/driver_rating_tab.dart';
import 'package:tayay_app/screens/driver/driver_home_widgets/driver_wallet_tab.dart';
import 'package:tayay_app/screens/driver/driver_home_widgets/driver_home_drawer.dart';
import 'package:tayay_app/screens/driver/driver_home_widgets/driver_requests_tab.dart';
import 'package:tayay_app/widgets/tayar_toast.dart';
import 'package:tayay_app/widgets/empty_state.dart';
import 'package:tayay_app/utils/tayar_page_route.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key, this.initialTab = 0});

  // ====== التبويب اللي المفروض الشاشة تفتح عليه (0=طلباتي، 1=دخلي،
  // 2=تقييمي، 3=محفظتي) - بيتستخدم لما نيجي من إشعار (زي شحن المحفظة)
  // عايزين نودّي الطيار على تاب معين على طول ======
  final int initialTab;

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
  late int _selectedTab = widget.initialTab;

  // ====== آخر موقع معروف للطيار، بنستخدمه لفلترة الطلبات القريبة بس ======
  // (ضمن نطاق serviceRadiusKm من الإعدادات) بدل ما يشوف طلبات من مدينة تانية
  LatLng? _driverCurrentPosition;

  // ====== مجموعة الركاب اللي حاظرين الطيار الحالي (bund 5 - طيارين
  // مفضّلين/محظورين) - بتتحدّث Live، وبتُستخدم لإخفاء طلباتهم عن
  // الطيار خالص، نفس فكرة فلترة النطاق الجغرافي بالظبط ======
  StreamSubscription<Set<String>>? _blockedByPassengersSub;
  Set<String> _blockedByPassengerIds = {};

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
    // ====== نجيب آخر موقع معروف فورًا (من غير انتظار الـ stream) عشان فلترة
    // الطلبات القريبة تشتغل من أول لحظة تفتح فيها الشاشة ======
    _seedInitialDriverPosition();
    // ====== تفعيل استقبال إشعارات الشات + دعوات المكالمات (لازم بعد تسجيل الدخول) ======
    PushNotificationService.instance.init(isDriver: true);
    setupCallInvitationService(navigatorKey: navigatorKey);
    // ====== تعبئة رقم التليفون تلقائيًا لو الطيار سجل قبل إضافة هذا الحقل ======
    _backfillPhoneNumber();
    // ====== الاستماع لقايمة الركاب اللي حاظريني عشان أستخدمها في فلترة
    // الطلبات المعروضة (bund 5) ======
    _blockedByPassengersSub = DriverRelationsService
        .blockedByPassengerIdsForCurrentDriver()
        .listen((ids) {
          if (mounted) setState(() => _blockedByPassengerIds = ids);
        });
  }

  // ====== لوحة التحكم محتاجة رقم تليفون الطيار؛ الطيارين اللي سجلوا قبل ما نضيف
  // الحقل ده هيتملّه تلقائيًا من رقم تسجيل الدخول أول ما يفتحوا الشاشة دي ======
  Future<void> _backfillPhoneNumber() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber;
    if (uid == null || phone == null || phone.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(uid)
          .get();
      final existingPhone =
          (doc.data()?['personalInfo'] as Map?)?['phone'] as String?;
      if (existingPhone == null || existingPhone.isEmpty) {
        await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
          'personalInfo': {'phone': phone},
        }, SetOptions(merge: true));
      }
    } catch (_) {
      // صامت: مجرد تعبئة اختيارية، لا داعي لإزعاج الطيار لو فشلت
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
      TayarPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _activeTripListener?.cancel();
    _positionSub?.cancel();
    _blockedByPassengersSub?.cancel();
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

  // ====== بيفلتر قايمة الطلبات المعروضة للطيار بحيث يشوف بس اللي نقطة
  // انطلاقها جوه نطاق الخدمة (serviceRadiusKm) من موقعه الحالي — مهم مع
  // توسع التطبيق لمدن تانية غير العاشر من رمضان، عشان طيار في مدينة معينة
  // ما يشوفش طلبات من مدينة تانية بعيدة تمامًا. لو موقع الطيار لسه مش معروف
  // (أول لحظة فتح الشاشة قبل ما GPS يرد) بنسيب القايمة زي ما هي من غير فلترة
  // عشان مايفضلش شايف قايمة فاضية من غير سبب واضح. كمان بتستبعد أي طلب
  // من راكب حاظر الطيار الحالي (bund 5 - طيارين مفضّلين/محظورين) ======
  List<QueryDocumentSnapshot<Map<String, dynamic>>>
  _filterOrdersWithinServiceRadius(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> orders,
  ) {
    final driverPos = _driverCurrentPosition;
    final radiusMeters = AppSettings.instance.serviceRadiusKm * 1000;

    return orders.where((order) {
      final data = order.data();

      // ====== لو الراكب صاحب الطلب ده حاظر الطيار الحالي، الطلب يختفي
      // خالص - قبل ما نوصل لأي حساب مسافة ======
      final customerId = data['customerId'] as String?;
      if (customerId != null && _blockedByPassengerIds.contains(customerId)) {
        return false;
      }

      if (driverPos == null) return true;

      final pickupGeo = _extractGeoPoint(data['pickupLocation']);
      // ====== طلب من غير موقع انطلاق محفوظ (حالة قديمة/استثنائية): نوريه
      // برضه بدل ما يختفي بلا سبب ======
      if (pickupGeo == null) return true;

      final distanceMeters = Geolocator.distanceBetween(
        driverPos.latitude,
        driverPos.longitude,
        pickupGeo.latitude,
        pickupGeo.longitude,
      );
      return distanceMeters <= radiusMeters;
    }).toList();
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
                TayarPageRoute(
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

  // ====== يجيب آخر موقع معروف للطيار (سريع، من غير انتظار GPS دقيق) عشان
  // فلترة الطلبات القريبة تبدأ فورًا، وهيتحدّث بعد كده أوتوماتيك من بث الموقع ======
  Future<void> _seedInitialDriverPosition() async {
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        setState(() {
          _driverCurrentPosition = LatLng(
            lastKnown.latitude,
            lastKnown.longitude,
          );
        });
      }
    } catch (_) {
      // تجاهل: هيتحدّث لاحقًا من بث الموقع لو نجح
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

          // ====== تحديث آخر موقع معروف للطيار عشان فلترة الطلبات القريبة
          // تفضل دقيقة مع تحركه ======
          if (mounted) {
            setState(() {
              _driverCurrentPosition = LatLng(
                position.latitude,
                position.longitude,
              );
            });
          }

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
            TayarToast.show(
              context,
              AppLocalizations.of(context)!.permissionLocationRequired,
              type: ToastType.warning,
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

  // ====== جلب متوسط تقييم الطيار من الكاش الجاهز ======
  // بدل ما نجيب كل الطلبات المكتملة ونحسب المتوسط كل مرة (استعلام تقيل ومكلّف)،
  // بنقرا مستند drivers/{uid} بس اللي فيه ratingSum و ratingCount جاهزين
  // ومتحدّثين أول ما يوصل تقييم جديد (شوف transaction في شاشة تقييم الرحلة)
  // بيرجع null لو الطيار لسه معندوش أي تقييمات (طيار جديد)
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
      debugPrint('⚠️ تعذر جلب متوسط تقييم الطيار: $e');
      return null;
    }
  }

  // ====== جلب اسم الطيار الحقيقي من بروفايله في Firestore ======
  // بنفس الأولوية المستخدمة في باقي الشاشة: الاسم اللي الطيار كتبه في بياناته
  // الشخصية (firstName + lastName) أولًا، وإلا اسم حساب Google، وإلا اسم
  // افتراضي كـ fallback أخير. من غير كده كان بيتسجّل اسم حساب المصادقة بس،
  // فلو الطيار غيّر اسمه في البروفايل ما كانش بيظهر للراكب في الرحلة.
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
      debugPrint('⚠️ تعذر جلب اسم بروفايل الطيار: $e');
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
        // لو الطيار لسه معندوش تقييمات، بنبعت null بدل رقم وهمي؛
        // شاشة الراكب لازم تتعامل مع null كـ "طيار جديد" بدل ما تعرض نجوم فاضية
        'driverRating': averageRating,
        'price': price,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => _offeredOrderIds.add(orderId));
      TayarToast.show(
        context,
        AppLocalizations.of(context)!.offerSentWaitingPassenger,
        type: ToastType.success,
      );
    } catch (e) {
      debugPrint('❌ خطأ في إرسال العرض: $e');
      if (!mounted) return;
      TayarToast.show(
        context,
        AppLocalizations.of(context)!.offerSendFailed,
        type: ToastType.error,
      );
    }
  }

  // ====== بدء الرحلة (بعد قبول العرض) ======
  Future<void> _startTrip(String orderId) async {
    await _ordersRef.doc(orderId).update({'status': 'in_progress'});
  }

  // ====== إنهاء الرحلة ======
  Future<void> _completeTrip(String orderId) async {
    final driverId = _currentUser?.uid;
    if (driverId == null) return;
    try {
      await completeTripAndDeductCommission(orderId: orderId);
    } on CompleteTripException catch (e) {
      if (!mounted) return;
      TayarToast.show(context, e.message, type: ToastType.error);
    }
  }

  // ====== إشعار للطيار لحظة وصوله فعليًا لنقطة الوجهة، مع زرار سريع
  // لإنهاء الرحلة من غير ما يدور على الزرار في الكارت ======
  void _notifyArrivalAtDestination(String tripId) {
    if (!mounted) return;
    TayarToast.show(
      context,
      AppLocalizations.of(context)!.arrivedAtDestination,
      type: ToastType.success,
      duration: const Duration(seconds: 12),
      actionLabel: AppLocalizations.of(context)!.endTrip,
      onAction: () => _completeTrip(tripId),
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
                else if (_isOnline)
                  const PulsingDot(color: TayarColors.primary, size: 10)
                else
                  const Icon(Icons.circle, size: 10, color: Colors.grey),
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
                TayarPageRoute(
                  builder: (context) => const PassengerHomeScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: user == null
          ? EmptyState(
              icon: Icons.lock_outline,
              title: AppLocalizations.of(context)!.mustSignInFirst,
            )
          : IndexedStack(
              index: _selectedTab,
              children: [
                DriverRequestsTab(
                  user: user,
                  ordersRef: _ordersRef,
                  isOnline: _isOnline,
                  offeredOrderIds: _offeredOrderIds,
                  filterOrdersWithinServiceRadius:
                      _filterOrdersWithinServiceRadius,
                  onSubmitOffer: _submitOffer,
                  onStartTrip: _startTrip,
                  onCompleteTrip: _completeTrip,
                ),
                DriverIncomeTab(driverId: user.uid),
                DriverRatingTab(driverId: user.uid),
                DriverWalletTab(driverId: user.uid),
              ],
            ),
      drawer: DriverHomeDrawer(
        selectedTab: _selectedTab,
        isOnline: _isOnline,
        onTabSelected: (index) => setState(() => _selectedTab = index),
        onLogout: () => _confirmLogout(context),
      ),
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
}
