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

  /// No description provided for @newDriverLabel.
  ///
  /// In ar, this message translates to:
  /// **'طيار جديد'**
  String get newDriverLabel;

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

  /// No description provided for @logout.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get logout;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @confirmLogoutMessage.
  ///
  /// In ar, this message translates to:
  /// **'متأكد إنك عايز تسجل خروج من حسابك؟'**
  String get confirmLogoutMessage;

  /// No description provided for @languageToggleTooltip.
  ///
  /// In ar, this message translates to:
  /// **'العربية / English'**
  String get languageToggleTooltip;

  /// No description provided for @navNotifications.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get navNotifications;

  /// No description provided for @navSecurity.
  ///
  /// In ar, this message translates to:
  /// **'الأمان'**
  String get navSecurity;

  /// No description provided for @navSettings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get navSettings;

  /// No description provided for @navHelp.
  ///
  /// In ar, this message translates to:
  /// **'مساعدة'**
  String get navHelp;

  /// No description provided for @navSupport.
  ///
  /// In ar, this message translates to:
  /// **'الدعم'**
  String get navSupport;

  /// No description provided for @backToPassengerModeButton.
  ///
  /// In ar, this message translates to:
  /// **'رجوع لوضع الركاب'**
  String get backToPassengerModeButton;

  /// No description provided for @appLanguageLabel.
  ///
  /// In ar, this message translates to:
  /// **'لغة التطبيق'**
  String get appLanguageLabel;

  /// No description provided for @useDeviceLanguageLabel.
  ///
  /// In ar, this message translates to:
  /// **'استخدام لغة الجهاز'**
  String get useDeviceLanguageLabel;

  /// No description provided for @enablePushNotifications.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل إشعارات التطبيق'**
  String get enablePushNotifications;

  /// No description provided for @pushNotificationsDescription.
  ///
  /// In ar, this message translates to:
  /// **'إشعارات الطلبات والعروض والتحديثات المهمة'**
  String get pushNotificationsDescription;

  /// No description provided for @termsAndConditions.
  ///
  /// In ar, this message translates to:
  /// **'الشروط والأحكام'**
  String get termsAndConditions;

  /// No description provided for @termsAndConditionsBody.
  ///
  /// In ar, this message translates to:
  /// **'باستخدامك تطبيق طيار أنت موافق على شروط الاستخدام الخاصة بيه، وإن الخدمة مقدَّمة بين الراكب والطيار مباشرة، وإن الشركة بتوفر منصة الربط فقط.'**
  String get termsAndConditionsBody;

  /// No description provided for @privacyPolicy.
  ///
  /// In ar, this message translates to:
  /// **'سياسة الخصوصية'**
  String get privacyPolicy;

  /// No description provided for @privacyPolicyBody.
  ///
  /// In ar, this message translates to:
  /// **'بنحافظ على بياناتك ومنستخدمش موقعك إلا وقت وجود رحلة فعلية، ومبنشاركش بياناتك مع أي طرف تالت من غير موافقتك.'**
  String get privacyPolicyBody;

  /// No description provided for @appVersionLabel.
  ///
  /// In ar, this message translates to:
  /// **'إصدار التطبيق'**
  String get appVersionLabel;

  /// No description provided for @ok.
  ///
  /// In ar, this message translates to:
  /// **'تمام'**
  String get ok;

  /// No description provided for @firstNameHint.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get firstNameHint;

  /// No description provided for @lastNameHint.
  ///
  /// In ar, this message translates to:
  /// **'الاسم الاخير'**
  String get lastNameHint;

  /// No description provided for @birthDateHint.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الميلاد'**
  String get birthDateHint;

  /// No description provided for @phoneNumberLabel.
  ///
  /// In ar, this message translates to:
  /// **'رقم الموبايل'**
  String get phoneNumberLabel;

  /// No description provided for @addressLabel.
  ///
  /// In ar, this message translates to:
  /// **'العنوان'**
  String get addressLabel;

  /// No description provided for @saveButton.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get saveButton;

  /// No description provided for @fullNameRequiredError.
  ///
  /// In ar, this message translates to:
  /// **'من فضلك أدخل الاسم كاملًا'**
  String get fullNameRequiredError;

  /// No description provided for @saveFailedError.
  ///
  /// In ar, this message translates to:
  /// **'تعذر الحفظ، حاول تاني'**
  String get saveFailedError;

  /// No description provided for @profileUpdatedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث البروفايل بنجاح'**
  String get profileUpdatedSuccess;

  /// No description provided for @changePhotoLabel.
  ///
  /// In ar, this message translates to:
  /// **'تغيير الصورة'**
  String get changePhotoLabel;

  /// No description provided for @photoTooLargeError.
  ///
  /// In ar, this message translates to:
  /// **'الصورة كبيرة جدًا، من فضلك اختار صورة تانية أصغر'**
  String get photoTooLargeError;

  /// No description provided for @locatingAddress.
  ///
  /// In ar, this message translates to:
  /// **'جاري تحديد الموقع...'**
  String get locatingAddress;

  /// No description provided for @addressUnknown.
  ///
  /// In ar, this message translates to:
  /// **'موقع غير معروف'**
  String get addressUnknown;

  /// No description provided for @addressFetchFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذر تحديد العنوان'**
  String get addressFetchFailed;

  /// No description provided for @paymentMethodWallet.
  ///
  /// In ar, this message translates to:
  /// **'محفظة إلكترونية'**
  String get paymentMethodWallet;

  /// No description provided for @paymentMethodInstapay.
  ///
  /// In ar, this message translates to:
  /// **'إنستاباي'**
  String get paymentMethodInstapay;

  /// No description provided for @choosePaymentMethodTitle.
  ///
  /// In ar, this message translates to:
  /// **'اختار طريقة الدفع'**
  String get choosePaymentMethodTitle;

  /// No description provided for @fromLabel.
  ///
  /// In ar, this message translates to:
  /// **'من أين'**
  String get fromLabel;

  /// No description provided for @chooseDestinationHint.
  ///
  /// In ar, this message translates to:
  /// **'اختار الواجهة اللي عايز تروحها'**
  String get chooseDestinationHint;

  /// No description provided for @serviceRideMe.
  ///
  /// In ar, this message translates to:
  /// **'وصلني'**
  String get serviceRideMe;

  /// No description provided for @serviceDeliverOrders.
  ///
  /// In ar, this message translates to:
  /// **'وصل طلباتي'**
  String get serviceDeliverOrders;

  /// No description provided for @deliveryOrderTitle.
  ///
  /// In ar, this message translates to:
  /// **'توصيل طلب'**
  String get deliveryOrderTitle;

  /// No description provided for @pickupLocationLabel.
  ///
  /// In ar, this message translates to:
  /// **'مكان الاستلام'**
  String get pickupLocationLabel;

  /// No description provided for @deliveryLocationLabel.
  ///
  /// In ar, this message translates to:
  /// **'مكان التسليم'**
  String get deliveryLocationLabel;

  /// No description provided for @tapToSelectLocationLabel.
  ///
  /// In ar, this message translates to:
  /// **'اضغط لاختيار الموقع'**
  String get tapToSelectLocationLabel;

  /// No description provided for @pickupAddressDetailsLabel.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل مكان الاستلام'**
  String get pickupAddressDetailsLabel;

  /// No description provided for @pickupAddressDetailsHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: الدور التاني، جنب الصيدلية'**
  String get pickupAddressDetailsHint;

  /// No description provided for @deliveryAddressDetailsLabel.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل مكان التسليم'**
  String get deliveryAddressDetailsLabel;

  /// No description provided for @deliveryAddressDetailsHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: الدور التاني، جنب الصيدلية'**
  String get deliveryAddressDetailsHint;

  /// No description provided for @senderPhoneLabel.
  ///
  /// In ar, this message translates to:
  /// **'رقم موبايل المُرسل'**
  String get senderPhoneLabel;

  /// No description provided for @receiverPhoneLabel.
  ///
  /// In ar, this message translates to:
  /// **'رقم موبايل المُستلم'**
  String get receiverPhoneLabel;

  /// No description provided for @phoneNumberHint.
  ///
  /// In ar, this message translates to:
  /// **'01xxxxxxxxx'**
  String get phoneNumberHint;

  /// No description provided for @saveOrderButton.
  ///
  /// In ar, this message translates to:
  /// **'حفظ الطلب'**
  String get saveOrderButton;

  /// No description provided for @fillAllFieldsError.
  ///
  /// In ar, this message translates to:
  /// **'من فضلك اختار المواقع واملأ كل البيانات المطلوبة'**
  String get fillAllFieldsError;

  /// No description provided for @estimatedFareLabel.
  ///
  /// In ar, this message translates to:
  /// **'السعر المقترح'**
  String get estimatedFareLabel;

  /// No description provided for @selectPickupLocationTitle.
  ///
  /// In ar, this message translates to:
  /// **'اختار مكان الاستلام'**
  String get selectPickupLocationTitle;

  /// No description provided for @selectDeliveryLocationTitle.
  ///
  /// In ar, this message translates to:
  /// **'اختار مكان التسليم'**
  String get selectDeliveryLocationTitle;

  /// No description provided for @paymentMethodLabel.
  ///
  /// In ar, this message translates to:
  /// **'طريقة الدفع'**
  String get paymentMethodLabel;

  /// No description provided for @confirmButton.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get confirmButton;

  /// No description provided for @durationMinLabel.
  ///
  /// In ar, this message translates to:
  /// **'{duration} دقيقة'**
  String durationMinLabel(int duration);

  /// No description provided for @defaultUserName.
  ///
  /// In ar, this message translates to:
  /// **'محمد'**
  String get defaultUserName;

  /// No description provided for @driverModeButton.
  ///
  /// In ar, this message translates to:
  /// **'وضع الطيار'**
  String get driverModeButton;

  /// No description provided for @orderHistoryLabel.
  ///
  /// In ar, this message translates to:
  /// **'سجل الطلبات'**
  String get orderHistoryLabel;

  /// No description provided for @driverRegistrationTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الطيار'**
  String get driverRegistrationTitle;

  /// No description provided for @closeButton.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get closeButton;

  /// No description provided for @submitApplicationSuccessTitle.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال طلبك!'**
  String get submitApplicationSuccessTitle;

  /// No description provided for @submitApplicationSuccessBody.
  ///
  /// In ar, this message translates to:
  /// **'سنراجع بياناتك خلال 24 ساعة، وهنبلغك أول ما يتم قبول حسابك كطيار.'**
  String get submitApplicationSuccessBody;

  /// No description provided for @submitFailedError.
  ///
  /// In ar, this message translates to:
  /// **'تعذر إرسال الطلب، حاول تاني'**
  String get submitFailedError;

  /// No description provided for @applicationUnderReviewBanner.
  ///
  /// In ar, this message translates to:
  /// **'طلبك قيد المراجعة حاليًا، هنبلغك أول ما يتم الرد.'**
  String get applicationUnderReviewBanner;

  /// No description provided for @registrationIntroText.
  ///
  /// In ar, this message translates to:
  /// **'قم بتحميل بياناتك الشخصية وبيانات مركبتك. سنراجع جميع البيانات خلال 24 ساعة'**
  String get registrationIntroText;

  /// No description provided for @sectionPersonalInfo.
  ///
  /// In ar, this message translates to:
  /// **'المعلومات الشخصية'**
  String get sectionPersonalInfo;

  /// No description provided for @sectionDrivingLicense.
  ///
  /// In ar, this message translates to:
  /// **'رخصة القيادة'**
  String get sectionDrivingLicense;

  /// No description provided for @sectionPersonalDocuments.
  ///
  /// In ar, this message translates to:
  /// **'المستندات الشخصية'**
  String get sectionPersonalDocuments;

  /// No description provided for @sectionBikeInfo.
  ///
  /// In ar, this message translates to:
  /// **'معلومات الموتوسيكل'**
  String get sectionBikeInfo;

  /// No description provided for @applicationUnderReviewButton.
  ///
  /// In ar, this message translates to:
  /// **'طلبك قيد المراجعة'**
  String get applicationUnderReviewButton;

  /// No description provided for @continueButton.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get continueButton;

  /// No description provided for @sectionCompleteLabel.
  ///
  /// In ar, this message translates to:
  /// **'تم استكمال البيانات'**
  String get sectionCompleteLabel;

  /// No description provided for @sectionIncompleteLabel.
  ///
  /// In ar, this message translates to:
  /// **'قم بتعبئة المعلومات المطلوبة'**
  String get sectionIncompleteLabel;

  /// No description provided for @optionalLabel.
  ///
  /// In ar, this message translates to:
  /// **'اختياري'**
  String get optionalLabel;

  /// No description provided for @personalPhotoLabel.
  ///
  /// In ar, this message translates to:
  /// **'صورة شخصية'**
  String get personalPhotoLabel;

  /// No description provided for @licensePhotoUploadRequired.
  ///
  /// In ar, this message translates to:
  /// **'من فضلك ارفع صورة الرخصة وأدخل تاريخ الانتهاء'**
  String get licensePhotoUploadRequired;

  /// No description provided for @licenseExpiryHint.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ انتهاء الصلاحية'**
  String get licenseExpiryHint;

  /// No description provided for @criminalRecordUploadRequired.
  ///
  /// In ar, this message translates to:
  /// **'من فضلك ارفع صحيفة الحالة الجنائية وأدخل رقم الهوية'**
  String get criminalRecordUploadRequired;

  /// No description provided for @criminalRecordFrontLabel.
  ///
  /// In ar, this message translates to:
  /// **'صحيفة الحالة الجنائية'**
  String get criminalRecordFrontLabel;

  /// No description provided for @criminalRecordBackLabel.
  ///
  /// In ar, this message translates to:
  /// **'الجانب الخلفي لصحيفة الحالة الجنائية'**
  String get criminalRecordBackLabel;

  /// No description provided for @idNumberHint.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهوية'**
  String get idNumberHint;

  /// No description provided for @bikeInfoRequiredError.
  ///
  /// In ar, this message translates to:
  /// **'من فضلك أكمل بيانات الموتوسيكل الأساسية'**
  String get bikeInfoRequiredError;

  /// No description provided for @bikePhotoLabel.
  ///
  /// In ar, this message translates to:
  /// **'صورة الموتوسيكل'**
  String get bikePhotoLabel;

  /// No description provided for @bikeLicensePhotoLabel.
  ///
  /// In ar, this message translates to:
  /// **'رخصة الموتوسيكل'**
  String get bikeLicensePhotoLabel;

  /// No description provided for @bikeBrandHint.
  ///
  /// In ar, this message translates to:
  /// **'العلامة التجارية للموتوسيكل'**
  String get bikeBrandHint;

  /// No description provided for @bikeModelHint.
  ///
  /// In ar, this message translates to:
  /// **'طراز الموتوسيكل'**
  String get bikeModelHint;

  /// No description provided for @bikeColorHint.
  ///
  /// In ar, this message translates to:
  /// **'لون الموتوسيكل'**
  String get bikeColorHint;

  /// No description provided for @bikeYearHint.
  ///
  /// In ar, this message translates to:
  /// **'سنة الانتاج'**
  String get bikeYearHint;

  /// No description provided for @helpScreenTitle.
  ///
  /// In ar, this message translates to:
  /// **'مساعدة'**
  String get helpScreenTitle;

  /// No description provided for @faqOrderTripQuestion.
  ///
  /// In ar, this message translates to:
  /// **'إزاي أطلب رحلة؟'**
  String get faqOrderTripQuestion;

  /// No description provided for @faqOrderTripAnswer.
  ///
  /// In ar, this message translates to:
  /// **'من الشاشة الرئيسية، حدد نقطة الانطلاق ثم اختار الوجهة، وبعدها شوف السعر المقترح وابعت الطلب. هتظهرلك عروض من الطيارين القريبين وتقدر تختار العرض اللي يناسبك.'**
  String get faqOrderTripAnswer;

  /// No description provided for @faqPricingQuestion.
  ///
  /// In ar, this message translates to:
  /// **'إزاي بيتحدد السعر؟'**
  String get faqPricingQuestion;

  /// No description provided for @faqPricingAnswer.
  ///
  /// In ar, this message translates to:
  /// **'السعر بيتحسب على أساس المسافة الفعلية بين نقطة الانطلاق والوجهة، وتقدر تزود أو تقلل السعر المقترح وقت المزايدة مع الطيارين.'**
  String get faqPricingAnswer;

  /// No description provided for @faqPaymentMethodsQuestion.
  ///
  /// In ar, this message translates to:
  /// **'وسايل الدفع المتاحة إيه؟'**
  String get faqPaymentMethodsQuestion;

  /// No description provided for @faqPaymentMethodsAnswer.
  ///
  /// In ar, this message translates to:
  /// **'تقدر تدفع كاش للطيار مباشرة، أو من خلال المحفظة الإلكترونية، أو عن طريق إنستاباي. تقدر تختار وسيلة الدفع وانت بتأكد الطلب.'**
  String get faqPaymentMethodsAnswer;

  /// No description provided for @faqNoAcceptQuestion.
  ///
  /// In ar, this message translates to:
  /// **'مفيش حد بيقبل طلبي، أعمل إيه؟'**
  String get faqNoAcceptQuestion;

  /// No description provided for @faqNoAcceptAnswer.
  ///
  /// In ar, this message translates to:
  /// **'جرب تزود السعر شوية وقت المزايدة، خصوصًا في أوقات الذروة أو المناطق البعيدة، ده بيخلي الطلب أكثر جاذبية للطيارين القريبين.'**
  String get faqNoAcceptAnswer;

  /// No description provided for @faqBecomeDriverQuestion.
  ///
  /// In ar, this message translates to:
  /// **'إزاي أبقى طيار في تطبيق طيار؟'**
  String get faqBecomeDriverQuestion;

  /// No description provided for @faqBecomeDriverAnswer.
  ///
  /// In ar, this message translates to:
  /// **'من القايمة الجانبية اختار \"وضع الطيار\" وكمّل خطوات التسجيل (البيانات، الرخصة، الموتوسيكل)، وبعد المراجعة هتقدر تستقبل طلبات.'**
  String get faqBecomeDriverAnswer;

  /// No description provided for @faqDriverEarningsQuestion.
  ///
  /// In ar, this message translates to:
  /// **'إزاي بتتحسب أرباح الطيار؟'**
  String get faqDriverEarningsQuestion;

  /// No description provided for @faqDriverEarningsAnswer.
  ///
  /// In ar, this message translates to:
  /// **'من كل رحلة، الطيار بياخد نسبة 90% من قيمة الرحلة والشركة بتاخد 10% مقابل تشغيل المنصة. تقدر تتابع تفاصيل أرباحك من تبويب \"الدخلي\".'**
  String get faqDriverEarningsAnswer;

  /// No description provided for @faqDeliverPackageQuestion.
  ///
  /// In ar, this message translates to:
  /// **'تقدر أوصّل طرد بدل ما أعمل رحلة راكب؟'**
  String get faqDeliverPackageQuestion;

  /// No description provided for @faqDeliverPackageAnswer.
  ///
  /// In ar, this message translates to:
  /// **'أيوه، من خدمة \"توصيل الطرود\" تقدر تبعت طرد من مكان لمكان من غير ما تكون موجود في الرحلة، ونفس نظام المزايدة بيتطبق برضه.'**
  String get faqDeliverPackageAnswer;

  /// No description provided for @faqTripProblemQuestion.
  ///
  /// In ar, this message translates to:
  /// **'إيه اللي أعمله لو حصلت مشكلة في رحلة؟'**
  String get faqTripProblemQuestion;

  /// No description provided for @faqTripProblemAnswer.
  ///
  /// In ar, this message translates to:
  /// **'تقدر تتواصل مع فريق الدعم مباشرة من شاشة \"الدعم\" في القايمة الجانبية، وهنساعدك تحل المشكلة أول بأول.'**
  String get faqTripProblemAnswer;

  /// No description provided for @chooseYourRideSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'اختار المشوار المناسب ليك'**
  String get chooseYourRideSubtitle;

  /// No description provided for @continueWithGoogleButton.
  ///
  /// In ar, this message translates to:
  /// **'المتابعة باستخدام Google'**
  String get continueWithGoogleButton;

  /// No description provided for @continueWithAppleButton.
  ///
  /// In ar, this message translates to:
  /// **'المتابعة باستخدام Apple'**
  String get continueWithAppleButton;

  /// No description provided for @continueWithPhoneButton.
  ///
  /// In ar, this message translates to:
  /// **'المتابعة عبر الهاتف'**
  String get continueWithPhoneButton;

  /// No description provided for @loginTermsAgreementNotice.
  ///
  /// In ar, this message translates to:
  /// **'يشير الانضمام إلى موافقتك على شروط الاستخدام والسياسة الخصوصية'**
  String get loginTermsAgreementNotice;

  /// No description provided for @signInFailedError.
  ///
  /// In ar, this message translates to:
  /// **'فشل تسجيل الدخول: {error}'**
  String signInFailedError(String error);

  /// No description provided for @signInWithAppleFailedError.
  ///
  /// In ar, this message translates to:
  /// **'فشل تسجيل الدخول بآبل: {error}'**
  String signInWithAppleFailedError(String error);

  /// No description provided for @markAllAsReadButton.
  ///
  /// In ar, this message translates to:
  /// **'تحديد الكل كمقروء'**
  String get markAllAsReadButton;

  /// No description provided for @mustSignInToViewNotifications.
  ///
  /// In ar, this message translates to:
  /// **'لازم تسجل الدخول عشان تشوف الإشعارات'**
  String get mustSignInToViewNotifications;

  /// No description provided for @errorLoadingNotifications.
  ///
  /// In ar, this message translates to:
  /// **'حصل خطأ في تحميل الإشعارات'**
  String get errorLoadingNotifications;

  /// No description provided for @noNotificationsYet.
  ///
  /// In ar, this message translates to:
  /// **'مفيش إشعارات لسه'**
  String get noNotificationsYet;

  /// No description provided for @justNowLabel.
  ///
  /// In ar, this message translates to:
  /// **'الآن'**
  String get justNowLabel;

  /// No description provided for @minutesAgoLabel.
  ///
  /// In ar, this message translates to:
  /// **'من {minutes} دقيقة'**
  String minutesAgoLabel(int minutes);

  /// No description provided for @hoursAgoLabel.
  ///
  /// In ar, this message translates to:
  /// **'من {hours} ساعة'**
  String hoursAgoLabel(int hours);

  /// No description provided for @daysAgoLabel.
  ///
  /// In ar, this message translates to:
  /// **'من {days} يوم'**
  String daysAgoLabel(int days);

  /// No description provided for @defaultCustomerName.
  ///
  /// In ar, this message translates to:
  /// **'مستخدم'**
  String get defaultCustomerName;

  /// No description provided for @setYourFareTitle.
  ///
  /// In ar, this message translates to:
  /// **'حدد سعرك'**
  String get setYourFareTitle;

  /// No description provided for @routeFromLabel.
  ///
  /// In ar, this message translates to:
  /// **'من'**
  String get routeFromLabel;

  /// No description provided for @routeToLabel.
  ///
  /// In ar, this message translates to:
  /// **'إلى'**
  String get routeToLabel;

  /// No description provided for @distanceLabel.
  ///
  /// In ar, this message translates to:
  /// **'المسافة'**
  String get distanceLabel;

  /// No description provided for @estimatedTimeLabel.
  ///
  /// In ar, this message translates to:
  /// **'الوقت المتوقع'**
  String get estimatedTimeLabel;

  /// No description provided for @suggestedFareForDriversLabel.
  ///
  /// In ar, this message translates to:
  /// **'السعر المقترح للطيارين'**
  String get suggestedFareForDriversLabel;

  /// No description provided for @autoSuggestedFareLabel.
  ///
  /// In ar, this message translates to:
  /// **'السعر المقترح تلقائيًا: {amount} جنيه'**
  String autoSuggestedFareLabel(String amount);

  /// No description provided for @autoAcceptCheckboxLabel.
  ///
  /// In ar, this message translates to:
  /// **'قبول تلقائي لأول عرض بنفس السعر المقترح'**
  String get autoAcceptCheckboxLabel;

  /// No description provided for @searchForDriversButton.
  ///
  /// In ar, this message translates to:
  /// **'البحث عن طيارين'**
  String get searchForDriversButton;

  /// No description provided for @invalidPhoneNumberError.
  ///
  /// In ar, this message translates to:
  /// **'من فضلك اكتب رقم موبايل صحيح'**
  String get invalidPhoneNumberError;

  /// No description provided for @tryAgainLabel.
  ///
  /// In ar, this message translates to:
  /// **'حاول تاني'**
  String get tryAgainLabel;

  /// No description provided for @errorOccurredWithMessage.
  ///
  /// In ar, this message translates to:
  /// **'حصل خطأ: {message}'**
  String errorOccurredWithMessage(String message);

  /// No description provided for @otpSendNoticeLabel.
  ///
  /// In ar, this message translates to:
  /// **'هنبعتلك كود تحقق على الرقم ده'**
  String get otpSendNoticeLabel;

  /// No description provided for @sendCodeButton.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الكود'**
  String get sendCodeButton;

  /// No description provided for @otpLengthError.
  ///
  /// In ar, this message translates to:
  /// **'اكتب الكود المكون من 6 أرقام'**
  String get otpLengthError;

  /// No description provided for @invalidOtpError.
  ///
  /// In ar, this message translates to:
  /// **'الكود غلط، حاول تاني'**
  String get invalidOtpError;

  /// No description provided for @confirmPhoneNumberTitle.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الرقم'**
  String get confirmPhoneNumberTitle;

  /// No description provided for @otpSentToNumberLabel.
  ///
  /// In ar, this message translates to:
  /// **'بعتنالك كود تحقق على {phone}'**
  String otpSentToNumberLabel(String phone);

  /// No description provided for @determiningAddressLabel.
  ///
  /// In ar, this message translates to:
  /// **'جاري تحديد العنوان...'**
  String get determiningAddressLabel;

  /// No description provided for @customLocationLabel.
  ///
  /// In ar, this message translates to:
  /// **'موقع مخصص'**
  String get customLocationLabel;

  /// No description provided for @doneButton.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get doneButton;

  /// No description provided for @rateTripArrivedSafelyTitle.
  ///
  /// In ar, this message translates to:
  /// **'وصلت لوجهتك بأمان!'**
  String get rateTripArrivedSafelyTitle;

  /// No description provided for @rateTripSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'قيّم رحلتك مع الطيار'**
  String get rateTripSubtitle;

  /// No description provided for @pleaseSelectStarsFirst.
  ///
  /// In ar, this message translates to:
  /// **'من فضلك اختار عدد النجوم الأول'**
  String get pleaseSelectStarsFirst;

  /// No description provided for @failedToSaveRatingError.
  ///
  /// In ar, this message translates to:
  /// **'تعذر حفظ التقييم، حاول تاني'**
  String get failedToSaveRatingError;

  /// No description provided for @thankYouForRatingLabel.
  ///
  /// In ar, this message translates to:
  /// **'شكرًا لتقييمك! 🌟'**
  String get thankYouForRatingLabel;

  /// No description provided for @ratingVeryBadLabel.
  ///
  /// In ar, this message translates to:
  /// **'سيء جدًا'**
  String get ratingVeryBadLabel;

  /// No description provided for @ratingFairLabel.
  ///
  /// In ar, this message translates to:
  /// **'مقبول'**
  String get ratingFairLabel;

  /// No description provided for @ratingGoodLabel.
  ///
  /// In ar, this message translates to:
  /// **'كويس'**
  String get ratingGoodLabel;

  /// No description provided for @ratingVeryGoodLabel.
  ///
  /// In ar, this message translates to:
  /// **'جيد جدًا'**
  String get ratingVeryGoodLabel;

  /// No description provided for @ratingExcellentLabel.
  ///
  /// In ar, this message translates to:
  /// **'ممتاز'**
  String get ratingExcellentLabel;

  /// No description provided for @chooseYourRatingLabel.
  ///
  /// In ar, this message translates to:
  /// **'اختار تقييمك'**
  String get chooseYourRatingLabel;

  /// No description provided for @commentHintOptional.
  ///
  /// In ar, this message translates to:
  /// **'اكتب تعليقك (اختياري)'**
  String get commentHintOptional;

  /// No description provided for @submitRatingButton.
  ///
  /// In ar, this message translates to:
  /// **'إرسال التقييم'**
  String get submitRatingButton;

  /// No description provided for @skipButton.
  ///
  /// In ar, this message translates to:
  /// **'تخطي'**
  String get skipButton;

  /// No description provided for @failedToAcceptOfferError.
  ///
  /// In ar, this message translates to:
  /// **'تعذر قبول العرض، حاول تاني'**
  String get failedToAcceptOfferError;

  /// No description provided for @offerAcceptedTitle.
  ///
  /// In ar, this message translates to:
  /// **'تم قبول العرض!'**
  String get offerAcceptedTitle;

  /// No description provided for @driverOnWayWithFareLabel.
  ///
  /// In ar, this message translates to:
  /// **'الطيار {driverName} في الطريق ليك بسعر {price} جنيه'**
  String driverOnWayWithFareLabel(String driverName, String price);

  /// No description provided for @cancelSearchTitle.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء البحث؟'**
  String get cancelSearchTitle;

  /// No description provided for @cancelSearchBody.
  ///
  /// In ar, this message translates to:
  /// **'هيتم إلغاء طلبك وإيقاف البحث عن طيارين'**
  String get cancelSearchBody;

  /// No description provided for @goBackButton.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get goBackButton;

  /// No description provided for @cancelOrderButton.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الطلب'**
  String get cancelOrderButton;

  /// No description provided for @increaseFareButton.
  ///
  /// In ar, this message translates to:
  /// **'زيادة الأجرة'**
  String get increaseFareButton;

  /// No description provided for @autoAcceptNearestDriverLabel.
  ///
  /// In ar, this message translates to:
  /// **'قبول أقرب طيار مقابل {amount} جنيه تلقائيًا'**
  String autoAcceptNearestDriverLabel(String amount);

  /// No description provided for @cashAmountLabel.
  ///
  /// In ar, this message translates to:
  /// **'{amount} جنيه نقدًا'**
  String cashAmountLabel(String amount);

  /// No description provided for @oneDriverViewingOrderLabel.
  ///
  /// In ar, this message translates to:
  /// **'طيار واحد بيشوف طلبك'**
  String get oneDriverViewingOrderLabel;

  /// No description provided for @multipleDriversViewingOrderLabel.
  ///
  /// In ar, this message translates to:
  /// **'{count} طيارين بيشوفوا طلبك'**
  String multipleDriversViewingOrderLabel(int count);

  /// No description provided for @tryRaisingFareTitle.
  ///
  /// In ar, this message translates to:
  /// **'جرب تزود السعر'**
  String get tryRaisingFareTitle;

  /// No description provided for @raiseFareHintBody.
  ///
  /// In ar, this message translates to:
  /// **'ممكن تزود فرصك للحصول علي مشوارك بسرعة'**
  String get raiseFareHintBody;

  /// No description provided for @searchWithFareLabel.
  ///
  /// In ar, this message translates to:
  /// **'البحث بسعر {amount} جنيه'**
  String searchWithFareLabel(String amount);

  /// No description provided for @newOfferFromDriverLabel.
  ///
  /// In ar, this message translates to:
  /// **'عرض جديد من {driverName}'**
  String newOfferFromDriverLabel(String driverName);

  /// No description provided for @rejectButton.
  ///
  /// In ar, this message translates to:
  /// **'رفض'**
  String get rejectButton;

  /// No description provided for @acceptButton.
  ///
  /// In ar, this message translates to:
  /// **'قبول'**
  String get acceptButton;

  /// No description provided for @setPinTitle.
  ///
  /// In ar, this message translates to:
  /// **'حدد رقم سري من 4 أرقام'**
  String get setPinTitle;

  /// No description provided for @unknownProviderLabel.
  ///
  /// In ar, this message translates to:
  /// **'غير معروف'**
  String get unknownProviderLabel;

  /// No description provided for @googleAccountLabel.
  ///
  /// In ar, this message translates to:
  /// **'حساب Google'**
  String get googleAccountLabel;

  /// No description provided for @phoneNumberProviderLabel.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف ({phone})'**
  String phoneNumberProviderLabel(String phone);

  /// No description provided for @emailPasswordProviderLabel.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني وكلمة المرور'**
  String get emailPasswordProviderLabel;

  /// No description provided for @deleteAccountPermanentlyTitle.
  ///
  /// In ar, this message translates to:
  /// **'حذف الحساب نهائيًا'**
  String get deleteAccountPermanentlyTitle;

  /// No description provided for @deleteAccountConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'هيتم حذف حسابك وكل بياناتك نهائيًا ومش هتقدر ترجعها تاني. متأكد؟'**
  String get deleteAccountConfirmBody;

  /// No description provided for @deletePermanentlyButton.
  ///
  /// In ar, this message translates to:
  /// **'حذف نهائي'**
  String get deletePermanentlyButton;

  /// No description provided for @reauthRequiredForDeleteError.
  ///
  /// In ar, this message translates to:
  /// **'لازم تسجل الخروج والدخول تاني قبل ما تقدر تحذف حسابك'**
  String get reauthRequiredForDeleteError;

  /// No description provided for @signInMethodLabel.
  ///
  /// In ar, this message translates to:
  /// **'وسيلة تسجيل الدخول'**
  String get signInMethodLabel;

  /// No description provided for @appLockTitle.
  ///
  /// In ar, this message translates to:
  /// **'قفل التطبيق برقم سري'**
  String get appLockTitle;

  /// No description provided for @appLockSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'هتحتاج تدخل الرقم السري كل ما تفتح التطبيق'**
  String get appLockSubtitle;

  /// No description provided for @noMatchingResultsError.
  ///
  /// In ar, this message translates to:
  /// **'مفيش نتائج مطابقة'**
  String get noMatchingResultsError;

  /// No description provided for @searchFailedTryAgainError.
  ///
  /// In ar, this message translates to:
  /// **'تعذر البحث حاليًا، حاول تاني'**
  String get searchFailedTryAgainError;

  /// No description provided for @unknownPlaceLabel.
  ///
  /// In ar, this message translates to:
  /// **'مكان غير معروف'**
  String get unknownPlaceLabel;

  /// No description provided for @whereDoYouWantToGoTitle.
  ///
  /// In ar, this message translates to:
  /// **'عايز تروح فين؟'**
  String get whereDoYouWantToGoTitle;

  /// No description provided for @selectDropoffLocationTitle.
  ///
  /// In ar, this message translates to:
  /// **'اختار مكان التسليم'**
  String get selectDropoffLocationTitle;

  /// No description provided for @searchPlaceHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسم الشارع أو المكان...'**
  String get searchPlaceHint;

  /// No description provided for @pickFromMapLabel.
  ///
  /// In ar, this message translates to:
  /// **'اختار من الخريطة'**
  String get pickFromMapLabel;

  /// No description provided for @startTypingToSearchLabel.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ الكتابة عشان تدور على مكان'**
  String get startTypingToSearchLabel;

  /// No description provided for @recentSearchesLabel.
  ///
  /// In ar, this message translates to:
  /// **'عمليات البحث الأخيرة'**
  String get recentSearchesLabel;

  /// No description provided for @failedToOpenAppError.
  ///
  /// In ar, this message translates to:
  /// **'تعذر فتح التطبيق المطلوب'**
  String get failedToOpenAppError;

  /// No description provided for @whatsappSupportMessage.
  ///
  /// In ar, this message translates to:
  /// **'مرحبًا، محتاج مساعدة في تطبيق طيار'**
  String get whatsappSupportMessage;

  /// No description provided for @supportEmailSubject.
  ///
  /// In ar, this message translates to:
  /// **'مساعدة تطبيق طيار'**
  String get supportEmailSubject;

  /// No description provided for @supportMessageSentConfirmation.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال رسالتك، هيتواصل معاك فريق الدعم قريب'**
  String get supportMessageSentConfirmation;

  /// No description provided for @genericErrorTryAgain.
  ///
  /// In ar, this message translates to:
  /// **'حصل خطأ، حاول تاني'**
  String get genericErrorTryAgain;

  /// No description provided for @contactUsDirectlyLabel.
  ///
  /// In ar, this message translates to:
  /// **'تواصل معانا مباشرة'**
  String get contactUsDirectlyLabel;

  /// No description provided for @whatsappLabel.
  ///
  /// In ar, this message translates to:
  /// **'واتساب'**
  String get whatsappLabel;

  /// No description provided for @callLabel.
  ///
  /// In ar, this message translates to:
  /// **'اتصال'**
  String get callLabel;

  /// No description provided for @emailLabel.
  ///
  /// In ar, this message translates to:
  /// **'إيميل'**
  String get emailLabel;

  /// No description provided for @orSendMessageHereLabel.
  ///
  /// In ar, this message translates to:
  /// **'أو ابعتلنا رسالتك هنا'**
  String get orSendMessageHereLabel;

  /// No description provided for @supportMessageHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب مشكلتك أو استفسارك هنا...'**
  String get supportMessageHint;

  /// No description provided for @sendButton.
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get sendButton;

  /// No description provided for @tripCompletedTitle.
  ///
  /// In ar, this message translates to:
  /// **'وصلت لوجهتك!'**
  String get tripCompletedTitle;

  /// No description provided for @tripCancelledTitle.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء الرحلة'**
  String get tripCancelledTitle;

  /// No description provided for @thankYouForUsingTayarLabel.
  ///
  /// In ar, this message translates to:
  /// **'شكرا لاستخدامك طيار!'**
  String get thankYouForUsingTayarLabel;

  /// No description provided for @tripCancelledByDriverOrSystemLabel.
  ///
  /// In ar, this message translates to:
  /// **'الرحلة اتلغت من الطيار أو من النظام'**
  String get tripCancelledByDriverOrSystemLabel;

  /// No description provided for @arrivedAtYourDestinationStatusLabel.
  ///
  /// In ar, this message translates to:
  /// **'وصلتوا لوجهتكم 🎉'**
  String get arrivedAtYourDestinationStatusLabel;

  /// No description provided for @driverOnWayToYouLabel.
  ///
  /// In ar, this message translates to:
  /// **'الطيار في الطريق ليك'**
  String get driverOnWayToYouLabel;

  /// No description provided for @tripStartedOnWayToDestinationLabel.
  ///
  /// In ar, this message translates to:
  /// **'الرحلة بدأت - في الطريق للوجهة'**
  String get tripStartedOnWayToDestinationLabel;

  /// No description provided for @updatingLabel.
  ///
  /// In ar, this message translates to:
  /// **'جاري التحديث...'**
  String get updatingLabel;

  /// No description provided for @arrivedWaitingDriverToEndTripLabel.
  ///
  /// In ar, this message translates to:
  /// **'وصلتوا لوجهتكم! في انتظار الطيار ينهي الرحلة'**
  String get arrivedWaitingDriverToEndTripLabel;

  /// No description provided for @waitingDriverShareLocationLabel.
  ///
  /// In ar, this message translates to:
  /// **'في انتظار بدء الطيار مشاركة موقعه...'**
  String get waitingDriverShareLocationLabel;
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
