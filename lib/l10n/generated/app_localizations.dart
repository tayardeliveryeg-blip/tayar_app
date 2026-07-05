import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In ar, this message translates to:
  /// **'طيار - وصلك في لحظة'**
  String get appName;

  /// No description provided for @clientOrderPriority.
  ///
  /// In ar, this message translates to:
  /// **'طلبك بيوصل لأقرب طيارين، السعر الأفضل بياخد الأولوية'**
  String get clientOrderPriority;

  /// No description provided for @driverNoOrders.
  ///
  /// In ar, this message translates to:
  /// **'مفيش طلبات متاحة دلوقتي.. خليك مستعد!'**
  String get driverNoOrders;

  /// No description provided for @driverNoRatings.
  ///
  /// In ar, this message translates to:
  /// **'لسه مفيش تقييمات من الركاب.. شد حيلك'**
  String get driverNoRatings;

  /// No description provided for @tabRequests.
  ///
  /// In ar, this message translates to:
  /// **'طلباتي'**
  String get tabRequests;

  /// No description provided for @tabIncome.
  ///
  /// In ar, this message translates to:
  /// **'دخلي'**
  String get tabIncome;

  /// No description provided for @tabRatings.
  ///
  /// In ar, this message translates to:
  /// **'تقييماتي'**
  String get tabRatings;

  /// No description provided for @tabWallet.
  ///
  /// In ar, this message translates to:
  /// **'محفظتي'**
  String get tabWallet;

  /// No description provided for @errorLoadingOrders.
  ///
  /// In ar, this message translates to:
  /// **'حصل خطأ في تحميل الطلبات'**
  String get errorLoadingOrders;

  /// No description provided for @defaultDriverName.
  ///
  /// In ar, this message translates to:
  /// **'طيار'**
  String get defaultDriverName;

  /// No description provided for @statusAvailable.
  ///
  /// In ar, this message translates to:
  /// **'متاح دلوقتي'**
  String get statusAvailable;

  /// No description provided for @statusUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'غير متاح'**
  String get statusUnavailable;

  /// No description provided for @permissionLocationRequired.
  ///
  /// In ar, this message translates to:
  /// **'محتاج تسمح بصلاحية الموقع الأول عشان تبقى متاح'**
  String get permissionLocationRequired;

  /// No description provided for @offerSentWaitingPassenger.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال عرضك، بننتظر رد الراكب'**
  String get offerSentWaitingPassenger;

  /// No description provided for @offerSendFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذر إرسال العرض، حاول تاني'**
  String get offerSendFailed;

  /// No description provided for @arrivedAtDestination.
  ///
  /// In ar, this message translates to:
  /// **'🎉 وصلت لوجهة الرحلة'**
  String get arrivedAtDestination;

  /// No description provided for @endTrip.
  ///
  /// In ar, this message translates to:
  /// **'إنهاء الرحلة'**
  String get endTrip;

  /// No description provided for @startTrip.
  ///
  /// In ar, this message translates to:
  /// **'بدء الرحلة'**
  String get startTrip;

  /// No description provided for @driverToggleOnline.
  ///
  /// In ar, this message translates to:
  /// **'متاح'**
  String get driverToggleOnline;

  /// No description provided for @driverToggleOffline.
  ///
  /// In ar, this message translates to:
  /// **'غير متاح'**
  String get driverToggleOffline;

  /// No description provided for @mustSignInFirst.
  ///
  /// In ar, this message translates to:
  /// **'لازم تسجل دخول الأول'**
  String get mustSignInFirst;

  /// No description provided for @paymentMethodCash.
  ///
  /// In ar, this message translates to:
  /// **'كاش'**
  String get paymentMethodCash;

  /// No description provided for @navProfile.
  ///
  /// In ar, this message translates to:
  /// **'البروفايل'**
  String get navProfile;

  /// No description provided for @navIncome.
  ///
  /// In ar, this message translates to:
  /// **'الدخل'**
  String get navIncome;

  /// No description provided for @navRatings.
  ///
  /// In ar, this message translates to:
  /// **'التقييم'**
  String get navRatings;

  /// No description provided for @navWallet.
  ///
  /// In ar, this message translates to:
  /// **'المحفظة'**
  String get navWallet;

  /// No description provided for @distanceDurationLabel.
  ///
  /// In ar, this message translates to:
  /// **'{distance} كم • {duration} دقيقة'**
  String distanceDurationLabel(String distance, int duration);

  /// No description provided for @currencyEGP.
  ///
  /// In ar, this message translates to:
  /// **'{amount} جنيه'**
  String currencyEGP(String amount);

  /// No description provided for @distanceKmLabel.
  ///
  /// In ar, this message translates to:
  /// **'{distance} كم'**
  String distanceKmLabel(String distance);

  /// No description provided for @offerSentAlreadyLabel.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال عرضك، في انتظار الراكب'**
  String get offerSentAlreadyLabel;

  /// No description provided for @offerCustomButton.
  ///
  /// In ar, this message translates to:
  /// **'عرض سعر مختلف'**
  String get offerCustomButton;

  /// No description provided for @acceptProposedPrice.
  ///
  /// In ar, this message translates to:
  /// **'قبول بالسعر المقترح'**
  String get acceptProposedPrice;

  /// No description provided for @setYourPriceLabel.
  ///
  /// In ar, this message translates to:
  /// **'حدد السعر اللي تقدمه'**
  String get setYourPriceLabel;

  /// No description provided for @submitOfferButton.
  ///
  /// In ar, this message translates to:
  /// **'إرسال العرض'**
  String get submitOfferButton;

  /// No description provided for @tripInProgressLabel.
  ///
  /// In ar, this message translates to:
  /// **'الرحلة جارية الآن'**
  String get tripInProgressLabel;

  /// No description provided for @tripAcceptedWaitingLabel.
  ///
  /// In ar, this message translates to:
  /// **'رحلة مقبولة - في انتظار البدء'**
  String get tripAcceptedWaitingLabel;

  /// No description provided for @todayIncome.
  ///
  /// In ar, this message translates to:
  /// **'دخل اليوم'**
  String get todayIncome;

  /// No description provided for @totalIncome.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الدخل'**
  String get totalIncome;

  /// No description provided for @completedTripsCount.
  ///
  /// In ar, this message translates to:
  /// **'عدد الرحلات المكتملة'**
  String get completedTripsCount;

  /// No description provided for @ratingCountLabel.
  ///
  /// In ar, this message translates to:
  /// **'من {count} تقييم'**
  String ratingCountLabel(int count);

  /// No description provided for @availableBalance.
  ///
  /// In ar, this message translates to:
  /// **'رصيدك المتاح'**
  String get availableBalance;

  /// No description provided for @totalEarningsBeforeCommission.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الأرباح (قبل العمولة)'**
  String get totalEarningsBeforeCommission;

  /// No description provided for @companyCommission.
  ///
  /// In ar, this message translates to:
  /// **'عمولة الشركة (10%)'**
  String get companyCommission;

  /// No description provided for @motorcycleInfoTitle.
  ///
  /// In ar, this message translates to:
  /// **'بيانات الموتوسيكل'**
  String get motorcycleInfoTitle;

  /// No description provided for @bikeModelLabel.
  ///
  /// In ar, this message translates to:
  /// **'الموديل'**
  String get bikeModelLabel;

  /// No description provided for @bikeColorLabel.
  ///
  /// In ar, this message translates to:
  /// **'اللون'**
  String get bikeColorLabel;

  /// No description provided for @bikePlateLabel.
  ///
  /// In ar, this message translates to:
  /// **'رقم اللوحة'**
  String get bikePlateLabel;

  /// No description provided for @bikeYearLabel.
  ///
  /// In ar, this message translates to:
  /// **'الموديل (سنة الصنع)'**
  String get bikeYearLabel;

  /// No description provided for @orderDetailsTitle.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الطلب'**
  String get orderDetailsTitle;

  /// No description provided for @locationUnavailableForOrder.
  ///
  /// In ar, this message translates to:
  /// **'الموقع غير متاح لهذا الطلب'**
  String get locationUnavailableForOrder;

  /// No description provided for @offerAtMyPriceButton.
  ///
  /// In ar, this message translates to:
  /// **'تقديم بسعري'**
  String get offerAtMyPriceButton;

  /// No description provided for @alreadyOfferedOnOrder.
  ///
  /// In ar, this message translates to:
  /// **'قدّمت عرض بالفعل على الطلب ده'**
  String get alreadyOfferedOnOrder;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
