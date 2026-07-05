// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Tayar - Arrived in a flash';

  @override
  String get clientOrderPriority =>
      'Your order reaches the nearest drivers, the lowest price takes priority.';

  @override
  String get driverNoOrders => 'No available orders right now.. stay ready!';

  @override
  String get driverNoRatings => 'No ratings from passengers yet.. keep it up';

  @override
  String get tabRequests => 'Requests';

  @override
  String get tabIncome => 'Income';

  @override
  String get tabRatings => 'Ratings';

  @override
  String get tabWallet => 'Wallet';

  @override
  String get errorLoadingOrders => 'An error occurred while loading orders';

  @override
  String get defaultDriverName => 'Driver';

  @override
  String get statusAvailable => 'Available Now';

  @override
  String get statusUnavailable => 'Unavailable';
}
