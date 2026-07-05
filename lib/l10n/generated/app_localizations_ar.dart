// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'طيار - وصلك في لحظة';

  @override
  String get clientOrderPriority =>
      'طلبك بيوصل لأقرب طيارين، السعر الأفضل بياخد الأولوية';

  @override
  String get driverNoOrders => 'مفيش طلبات متاحة دلوقتي.. خليك مستعد!';

  @override
  String get driverNoRatings => 'لسه مفيش تقييمات من الركاب.. شد حيلك';

  @override
  String get tabRequests => 'طلباتي';

  @override
  String get tabIncome => 'دخلي';

  @override
  String get tabRatings => 'تقييماتي';

  @override
  String get tabWallet => 'محفظتي';

  @override
  String get errorLoadingOrders => 'حصل خطأ في تحميل الطلبات';

  @override
  String get defaultDriverName => 'طيار';

  @override
  String get statusAvailable => 'متاح دلوقتي';

  @override
  String get statusUnavailable => 'غير متاح';

  @override
  String get permissionLocationRequired =>
      'محتاج تسمح بصلاحية الموقع الأول عشان تبقى متاح';

  @override
  String get offerSentWaitingPassenger => 'تم إرسال عرضك، بننتظر رد الراكب';

  @override
  String get offerSendFailed => 'تعذر إرسال العرض، حاول تاني';

  @override
  String get arrivedAtDestination => '🎉 وصلت لوجهة الرحلة';

  @override
  String get endTrip => 'إنهاء الرحلة';

  @override
  String get startTrip => 'بدء الرحلة';

  @override
  String get driverToggleOnline => 'متاح';

  @override
  String get driverToggleOffline => 'غير متاح';

  @override
  String get mustSignInFirst => 'لازم تسجل دخول الأول';

  @override
  String get paymentMethodCash => 'كاش';

  @override
  String get navProfile => 'البروفايل';

  @override
  String get navIncome => 'الدخل';

  @override
  String get navRatings => 'التقييم';

  @override
  String get navWallet => 'المحفظة';

  @override
  String distanceDurationLabel(String distance, int duration) {
    return '$distance كم • $duration دقيقة';
  }

  @override
  String currencyEGP(String amount) {
    return '$amount جنيه';
  }

  @override
  String distanceKmLabel(String distance) {
    return '$distance كم';
  }

  @override
  String get offerSentAlreadyLabel => 'تم إرسال عرضك، في انتظار الراكب';

  @override
  String get offerCustomButton => 'عرض سعر مختلف';

  @override
  String get acceptProposedPrice => 'قبول بالسعر المقترح';

  @override
  String get setYourPriceLabel => 'حدد السعر اللي تقدمه';

  @override
  String get submitOfferButton => 'إرسال العرض';

  @override
  String get tripInProgressLabel => 'الرحلة جارية الآن';

  @override
  String get tripAcceptedWaitingLabel => 'رحلة مقبولة - في انتظار البدء';

  @override
  String get todayIncome => 'دخل اليوم';

  @override
  String get totalIncome => 'إجمالي الدخل';

  @override
  String get completedTripsCount => 'عدد الرحلات المكتملة';

  @override
  String ratingCountLabel(int count) {
    return 'من $count تقييم';
  }

  @override
  String get availableBalance => 'رصيدك المتاح';

  @override
  String get totalEarningsBeforeCommission => 'إجمالي الأرباح (قبل العمولة)';

  @override
  String get companyCommission => 'عمولة الشركة (10%)';

  @override
  String get motorcycleInfoTitle => 'بيانات الموتوسيكل';

  @override
  String get bikeModelLabel => 'الموديل';

  @override
  String get bikeColorLabel => 'اللون';

  @override
  String get bikePlateLabel => 'رقم اللوحة';

  @override
  String get bikeYearLabel => 'الموديل (سنة الصنع)';

  @override
  String get orderDetailsTitle => 'تفاصيل الطلب';

  @override
  String get locationUnavailableForOrder => 'الموقع غير متاح لهذا الطلب';

  @override
  String get offerAtMyPriceButton => 'تقديم بسعري';

  @override
  String get alreadyOfferedOnOrder => 'قدّمت عرض بالفعل على الطلب ده';
}
