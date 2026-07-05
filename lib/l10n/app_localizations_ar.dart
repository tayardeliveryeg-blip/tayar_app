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
}
