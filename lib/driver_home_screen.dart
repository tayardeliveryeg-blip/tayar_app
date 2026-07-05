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
        backgroundColor: TayarColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          AppLocalizations.of(context)!.logout,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          AppLocalizations.of(context)!.confirmLogoutMessage,
          style: const TextStyle(color: TayarColors.textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppLocalizations.of(context)!.cancel,
              style: const TextStyle(color: TayarColors.textGrey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppLocalizations.of(context)!.logout,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      // ====== نسجل خروج من Google لو المستخدم داخل بيه، وبعدين من Firebase ======
      final googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }
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
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 8),
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

  // ====== إرسال عرض سعر على طلب معين ======
  Future<void> _submitOffer(String orderId, double price) async {
    final user = _currentUser;
    if (user == null) return;

    try {
      await _ordersRef.doc(orderId).collection('offers').add({
        'driverId': user.uid,
        'driverName':
            user.displayName ?? AppLocalizations.of(context)!.defaultDriverName,
        'driverRating':
            4.8, // TODO: هيتحدث لاحقًا من بيانات تقييم الطيار الحقيقية
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
      backgroundColor: TayarColors.cardDark,
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
    await _ordersRef.doc(orderId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          AppLocalizations.of(context)!.arrivedAtDestination,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        action: SnackBarAction(
          label: AppLocalizations.of(context)!.endTrip,
          textColor: Colors.white,
          onPressed: () => _completeTrip(tripId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;

    return Scaffold(
      backgroundColor: TayarColors.background,
      appBar: AppBar(
        backgroundColor: TayarColors.background,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            AppLocalizations.of(context)!.appName,
            style: const TextStyle(color: Colors.white),
            maxLines: 1,
          ),
        ),
        titleSpacing: 0,
        actions: [
          // ====== زرار "متاح / غير متاح" ======
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: _isTogglingOnline ? null : _toggleOnline,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _isOnline
                      ? TayarColors.primary.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isOnline ? TayarColors.primary : Colors.white38,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isTogglingOnline)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      Icon(
                        Icons.circle,
                        size: 10,
                        color: _isOnline ? TayarColors.primary : Colors.grey,
                      ),
                    const SizedBox(width: 6),
                    Text(
                      _isOnline
                          ? AppLocalizations.of(context)!.driverToggleOnline
                          : AppLocalizations.of(context)!.driverToggleOffline,
                      style: TextStyle(
                        color: _isOnline ? TayarColors.primary : Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ====== زرار تبديل اللغة (عربي / إنجليزي) ======
          IconButton(
            icon: const Icon(Icons.language, color: Colors.white),
            tooltip: AppLocalizations.of(context)!.languageToggleTooltip,
            onPressed: () {
              final isArabic =
                  Localizations.localeOf(context).languageCode == 'ar';
              TayarApp.setLocale(
                context,
                isArabic ? const Locale('en') : const Locale('ar'),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
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
                style: TextStyle(color: TayarColors.textGrey),
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
              backgroundColor: TayarColors.cardDark,
              selectedItemColor: TayarColors.primary,
              unselectedItemColor: TayarColors.textGrey,
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
              pickupAddress: (data['pickupAddress'] as String?) ?? '',
              destinationAddress: (data['destinationAddress'] as String?) ?? '',
              fare: (data['acceptedFare'] as num?)?.toDouble() ?? 0,
              paymentMethod:
                  (data['paymentMethod'] as String?) ??
                  AppLocalizations.of(context)!.paymentMethodCash,
              inProgress: inProgress,
              onStart: () => _startTrip(trip.id),
              onComplete: () => _completeTrip(trip.id),
            );
          },
        ),

        // ====== الطلبات المتاحة اللي بتدور على عروض ======
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _ordersRef
                .where('status', isEqualTo: 'searching')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    AppLocalizations.of(context)!.errorLoadingOrders,
                    style: TextStyle(color: TayarColors.textGrey),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: TayarColors.primary),
                );
              }

              final orders = snapshot.data!.docs;
              if (orders.isEmpty) {
                return Center(
                  child: Text(
                    AppLocalizations.of(context)!.driverNoOrders,
                    style: const TextStyle(color: TayarColors.textGrey),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final data = order.data();
                  final bool alreadyOffered = _offeredOrderIds.contains(
                    order.id,
                  );

                  return _OrderRequestCard(
                    pickupAddress: (data['pickupAddress'] as String?) ?? '',
                    destinationAddress:
                        (data['destinationAddress'] as String?) ?? '',
                    distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0,
                    durationMin: (data['durationMin'] as num?)?.toInt() ?? 0,
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
                            (data['proposedFare'] as num?)?.toDouble() ?? 0,
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
                              (data['destinationAddress'] as String?) ?? '',
                          pickupLocation: _extractGeoPoint(
                            data['pickupLocation'],
                          ),
                          destinationLocation: _extractGeoPoint(
                            data['destinationLocation'],
                          ),
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
      backgroundColor: TayarColors.background,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: TayarColors.primary,
                    child: Icon(
                      Icons.two_wheeler,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentUser?.displayName ??
                              AppLocalizations.of(context)!.defaultDriverName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isOnline
                              ? AppLocalizations.of(context)!.statusAvailable
                              : AppLocalizations.of(context)!.statusUnavailable,
                          style: TextStyle(
                            color: _isOnline
                                ? TayarColors.primary
                                : TayarColors.textGrey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _DriverDrawerItem(
                    icon: Icons.person_outline,
                    label: AppLocalizations.of(context)!.navProfile,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DriverProfileScreen(),
                        ),
                      );
                    },
                  ),
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
                  const Divider(color: Colors.white24, height: 24),
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
                  const Divider(color: Colors.white24, height: 24),
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
              padding: const EdgeInsets.all(16),
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
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.backToPassengerModeButton,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            // ====== أيقونات السوشيال ميديا ======
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _DriverSocialIcon(icon: Icons.facebook),
                  SizedBox(width: 20),
                  _DriverSocialIcon(
                    icon: Icons.camera_alt_outlined,
                  ), // إنستجرام placeholder
                  SizedBox(width: 20),
                  _DriverSocialIcon(
                    icon: Icons.chat_bubble_outline,
                  ), // واتساب placeholder
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
      borderRadius: BorderRadius.circular(16),
      onTap: onOpenDetails,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: TayarColors.cardDark,
          borderRadius: BorderRadius.circular(16),
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
                  Icons.radio_button_checked,
                  color: TayarColors.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pickupAddress,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(width: 7),
                  SizedBox(
                    height: 14,
                    child: VerticalDivider(color: Colors.white24, thickness: 2),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: Colors.redAccent,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    destinationAddress,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.distanceDurationLabel(
                    distanceKm.toStringAsFixed(1),
                    durationMin,
                  ),
                  style: const TextStyle(
                    color: TayarColors.textGrey,
                    fontSize: 12,
                  ),
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
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.payments_outlined,
                            color: TayarColors.textGrey,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            paymentMethod,
                            style: const TextStyle(
                              color: TayarColors.textGrey,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (alreadyOffered)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    AppLocalizations.of(context)!.offerSentAlreadyLabel,
                    style: TextStyle(color: TayarColors.textGrey, fontSize: 13),
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
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: TayarColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.offerCustomButton,
                        style: TextStyle(color: TayarColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onQuickAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TayarColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.acceptProposedPrice,
                        style: const TextStyle(color: Colors.white),
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
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade700,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${widget.pickupAddress} ← ${widget.destinationAddress}',
            style: const TextStyle(color: Colors.white, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(
              context,
            )!.distanceKmLabel(widget.distanceKm.toStringAsFixed(1)),
            style: const TextStyle(color: TayarColors.textGrey, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context)!.setYourPriceLabel,
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 12),
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
                  style: const TextStyle(
                    color: TayarColors.primary,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _StepButton(
                icon: Icons.add,
                onTap: () => setState(() => _price += _step),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => widget.onSubmit(_price),
              style: ElevatedButton.styleFrom(
                backgroundColor: TayarColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                AppLocalizations.of(context)!.submitOfferButton,
                style: TextStyle(
                  color: Colors.white,
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
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: TayarColors.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ====== كارت الرحلة النشطة فوق قائمة الطلبات ======
class _ActiveTripCard extends StatelessWidget {
  final String pickupAddress;
  final String destinationAddress;
  final double fare;
  final String paymentMethod;
  final bool inProgress;
  final VoidCallback onStart;
  final VoidCallback onComplete;

  const _ActiveTripCard({
    required this.pickupAddress,
    required this.destinationAddress,
    required this.fare,
    required this.paymentMethod,
    required this.inProgress,
    required this.onStart,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TayarColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TayarColors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            inProgress
                ? AppLocalizations.of(context)!.tripInProgressLabel
                : AppLocalizations.of(context)!.tripAcceptedWaitingLabel,
            style: const TextStyle(
              color: TayarColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$pickupAddress ← $destinationAddress',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                AppLocalizations.of(
                  context,
                )!.currencyEGP(fare.toStringAsFixed(0)),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.payments_outlined,
                color: Colors.white.withValues(alpha: 0.7),
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                paymentMethod,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: inProgress ? onComplete : onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: TayarColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                inProgress
                    ? AppLocalizations.of(context)!.endTrip
                    : AppLocalizations.of(context)!.startTrip,
                style: const TextStyle(
                  color: Colors.white,
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
        ? Colors.redAccent
        : (selected ? TayarColors.primary : Colors.white);

    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive
            ? Colors.redAccent
            : (selected ? TayarColors.primary : Colors.white70),
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
  const _DriverSocialIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white54),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 20),
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
          padding: const EdgeInsets.all(20),
          children: [
            _IncomeSummaryCard(
              title: AppLocalizations.of(context)!.todayIncome,
              value: todayTotal,
              icon: Icons.today,
            ),
            const SizedBox(height: 16),
            _IncomeSummaryCard(
              title: AppLocalizations.of(context)!.totalIncome,
              value: total,
              icon: Icons.payments,
            ),
            const SizedBox(height: 16),
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

// ====== تبويب "تقييمي": متوسط تقييمات الركاب ======
class _DriverRatingTab extends StatelessWidget {
  final String driverId;
  const _DriverRatingTab({required this.driverId});

  @override
  Widget build(BuildContext context) {
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

        final ratings = <double>[];
        for (final doc in snapshot.data!.docs) {
          final r = (doc.data()['rating'] as num?)?.toDouble();
          if (r != null) ratings.add(r);
        }

        if (ratings.isEmpty) {
          return Center(
            child: Text(
              AppLocalizations.of(context)!.driverNoRatings,
              style: TextStyle(color: TayarColors.textGrey),
            ),
          );
        }

        final avg = ratings.reduce((a, b) => a + b) / ratings.length;

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                avg.toStringAsFixed(2),
                style: const TextStyle(
                  color: TayarColors.primary,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
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
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.ratingCountLabel(ratings.length),
                style: const TextStyle(
                  color: TayarColors.textGrey,
                  fontSize: 14,
                ),
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

  static const double _driverShare = 0.9; // نسبة الطيار من كل رحلة (90%)

  @override
  Widget build(BuildContext context) {
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

        double total = 0;
        for (final doc in snapshot.data!.docs) {
          total += (doc.data()['acceptedFare'] as num?)?.toDouble() ?? 0;
        }
        final netBalance = total * _driverShare;
        final commission = total - netBalance;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: TayarColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: TayarColors.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    AppLocalizations.of(context)!.availableBalance,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(
                      context,
                    )!.currencyEGP(netBalance.toStringAsFixed(0)),
                    style: const TextStyle(
                      color: TayarColors.primary,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _IncomeSummaryCard(
              title: AppLocalizations.of(
                context,
              )!.totalEarningsBeforeCommission,
              value: total,
              icon: Icons.summarize,
            ),
            const SizedBox(height: 16),
            _IncomeSummaryCard(
              title: AppLocalizations.of(context)!.companyCommission,
              value: commission,
              icon: Icons.percent,
            ),
          ],
        );
      },
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TayarColors.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: TayarColors.primary, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          Text(
            isCurrency
                ? AppLocalizations.of(
                    context,
                  )!.currencyEGP(value.toStringAsFixed(0))
                : value.toStringAsFixed(0),
            style: const TextStyle(
              color: Colors.white,
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
      backgroundColor: TayarColors.background,
      appBar: AppBar(
        backgroundColor: TayarColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          AppLocalizations.of(context)!.orderDetailsTitle,
          style: const TextStyle(color: Colors.white),
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
                      TileLayer(
                        urlTemplate:
                            'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.tayar.app',
                      ),
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
                            child: const Icon(
                              Icons.radio_button_checked,
                              color: TayarColors.primary,
                              size: 32,
                            ),
                          ),
                          Marker(
                            point: LatLng(dest.latitude, dest.longitude),
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.redAccent,
                              size: 36,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Center(
                    child: Text(
                      AppLocalizations.of(context)!.locationUnavailableForOrder,
                      style: TextStyle(color: TayarColors.textGrey),
                    ),
                  ),
          ),

          // ====== كارت العنوانين + واجهة المزايدة ======
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: TayarColors.cardDark,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.radio_button_checked,
                              color: TayarColors.primary,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.pickupAddress,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: SizedBox(
                            height: 14,
                            child: VerticalDivider(
                              color: Colors.white24,
                              thickness: 2,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Colors.redAccent,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.destinationAddress,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
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
                              style: const TextStyle(
                                color: TayarColors.textGrey,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              widget.paymentMethod,
                              style: const TextStyle(
                                color: TayarColors.textGrey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

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
                            style: const TextStyle(
                              color: TayarColors.primary,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _StepButton(
                          icon: Icons.add,
                          onTap: () => setState(() => _price += 5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              widget.onCustomOffer?.call(_price);
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(
                                color: TayarColors.primary,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
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
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              widget.onQuickAccept?.call();
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TayarColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.acceptProposedPrice,
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          AppLocalizations.of(context)!.alreadyOfferedOnOrder,
                          style: TextStyle(color: TayarColors.textGrey),
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
