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
  String get newDriverLabel => 'طيار جديد';

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

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get cancel => 'إلغاء';

  @override
  String get confirmLogoutMessage => 'متأكد إنك عايز تسجل خروج من حسابك؟';

  @override
  String get languageToggleTooltip => 'العربية / English';

  @override
  String get navNotifications => 'الإشعارات';

  @override
  String get navSecurity => 'الأمان';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get navHelp => 'مساعدة';

  @override
  String get navSupport => 'الدعم';

  @override
  String get backToPassengerModeButton => 'رجوع لوضع الركاب';

  @override
  String get appLanguageLabel => 'لغة التطبيق';

  @override
  String get useDeviceLanguageLabel => 'استخدام لغة الجهاز';

  @override
  String get enablePushNotifications => 'تفعيل إشعارات التطبيق';

  @override
  String get pushNotificationsDescription =>
      'إشعارات الطلبات والعروض والتحديثات المهمة';

  @override
  String get termsAndConditions => 'الشروط والأحكام';

  @override
  String get termsAndConditionsBody =>
      'باستخدامك تطبيق طيار أنت موافق على شروط الاستخدام الخاصة بيه، وإن الخدمة مقدَّمة بين الراكب والطيار مباشرة، وإن الشركة بتوفر منصة الربط فقط.';

  @override
  String get privacyPolicy => 'سياسة الخصوصية';

  @override
  String get privacyPolicyBody =>
      'بنحافظ على بياناتك ومنستخدمش موقعك إلا وقت وجود رحلة فعلية، ومبنشاركش بياناتك مع أي طرف تالت من غير موافقتك.';

  @override
  String get appVersionLabel => 'إصدار التطبيق';

  @override
  String get ok => 'تمام';

  @override
  String get firstNameHint => 'الاسم';

  @override
  String get lastNameHint => 'الاسم الاخير';

  @override
  String get birthDateHint => 'تاريخ الميلاد';

  @override
  String get phoneNumberLabel => 'رقم الموبايل';

  @override
  String get addressLabel => 'العنوان';

  @override
  String get saveButton => 'حفظ';

  @override
  String get fullNameRequiredError => 'من فضلك أدخل الاسم كاملًا';

  @override
  String get saveFailedError => 'تعذر الحفظ، حاول تاني';

  @override
  String get profileUpdatedSuccess => 'تم تحديث البروفايل بنجاح';

  @override
  String get changePhotoLabel => 'تغيير الصورة';

  @override
  String get photoTooLargeError =>
      'الصورة كبيرة جدًا، من فضلك اختار صورة تانية أصغر';

  @override
  String get locatingAddress => 'جاري تحديد الموقع...';

  @override
  String get addressUnknown => 'موقع غير معروف';

  @override
  String get addressFetchFailed => 'تعذر تحديد العنوان';

  @override
  String get paymentMethodWallet => 'محفظة إلكترونية';

  @override
  String get paymentMethodInstapay => 'إنستاباي';

  @override
  String get choosePaymentMethodTitle => 'اختار طريقة الدفع';

  @override
  String get fromLabel => 'من أين';

  @override
  String get chooseDestinationHint => 'اختار الواجهة اللي عايز تروحها';

  @override
  String get serviceRideMe => 'وصلني';

  @override
  String get serviceDeliverOrders => 'وصل طلباتي';

  @override
  String get deliveryOrderTitle => 'توصيل طلب';

  @override
  String get pickupLocationLabel => 'مكان الاستلام';

  @override
  String get deliveryLocationLabel => 'مكان التسليم';

  @override
  String get tapToSelectLocationLabel => 'اضغط لاختيار الموقع';

  @override
  String get pickupAddressDetailsLabel => 'تفاصيل مكان الاستلام';

  @override
  String get pickupAddressDetailsHint => 'مثال: الدور التاني، جنب الصيدلية';

  @override
  String get deliveryAddressDetailsLabel => 'تفاصيل مكان التسليم';

  @override
  String get deliveryAddressDetailsHint => 'مثال: الدور التاني، جنب الصيدلية';

  @override
  String get senderPhoneLabel => 'رقم موبايل المُرسل';

  @override
  String get receiverPhoneLabel => 'رقم موبايل المُستلم';

  @override
  String get phoneNumberHint => '01xxxxxxxxx';

  @override
  String get saveOrderButton => 'حفظ الطلب';

  @override
  String get fillAllFieldsError => 'من فضلك اختار المواقع واملأ كل البيانات المطلوبة';

  @override
  String get estimatedFareLabel => 'السعر المقترح';

  @override
  String get selectPickupLocationTitle => 'اختار مكان الاستلام';

  @override
  String get selectDeliveryLocationTitle => 'اختار مكان التسليم';

  @override
  String get paymentMethodLabel => 'طريقة الدفع';

  @override
  String get confirmButton => 'تأكيد';

  @override
  String durationMinLabel(int duration) {
    return '$duration دقيقة';
  }

  @override
  String get defaultUserName => 'محمد';

  @override
  String get driverModeButton => 'وضع الطيار';

  @override
  String get orderHistoryLabel => 'سجل الطلبات';

  @override
  String get driverRegistrationTitle => 'تسجيل الطيار';

  @override
  String get closeButton => 'إغلاق';

  @override
  String get submitApplicationSuccessTitle => 'تم إرسال طلبك!';

  @override
  String get submitApplicationSuccessBody =>
      'سنراجع بياناتك خلال 24 ساعة، وهنبلغك أول ما يتم قبول حسابك كطيار.';

  @override
  String get submitFailedError => 'تعذر إرسال الطلب، حاول تاني';

  @override
  String get applicationUnderReviewBanner =>
      'طلبك قيد المراجعة حاليًا، هنبلغك أول ما يتم الرد.';

  @override
  String get registrationIntroText =>
      'قم بتحميل بياناتك الشخصية وبيانات مركبتك. سنراجع جميع البيانات خلال 24 ساعة';

  @override
  String get sectionPersonalInfo => 'المعلومات الشخصية';

  @override
  String get sectionDrivingLicense => 'رخصة القيادة';

  @override
  String get sectionPersonalDocuments => 'المستندات الشخصية';

  @override
  String get sectionBikeInfo => 'معلومات الموتوسيكل';

  @override
  String get applicationUnderReviewButton => 'طلبك قيد المراجعة';

  @override
  String get continueButton => 'متابعة';

  @override
  String get sectionCompleteLabel => 'تم استكمال البيانات';

  @override
  String get sectionIncompleteLabel => 'قم بتعبئة المعلومات المطلوبة';

  @override
  String get optionalLabel => 'اختياري';

  @override
  String get personalPhotoLabel => 'صورة شخصية';

  @override
  String get licensePhotoUploadRequired =>
      'من فضلك ارفع صورة الرخصة وأدخل تاريخ الانتهاء';

  @override
  String get licenseExpiryHint => 'تاريخ انتهاء الصلاحية';

  @override
  String get criminalRecordUploadRequired =>
      'من فضلك ارفع صحيفة الحالة الجنائية وأدخل رقم الهوية';

  @override
  String get criminalRecordFrontLabel => 'صحيفة الحالة الجنائية';

  @override
  String get criminalRecordBackLabel => 'الجانب الخلفي لصحيفة الحالة الجنائية';

  @override
  String get idNumberHint => 'رقم الهوية';

  @override
  String get bikeInfoRequiredError => 'من فضلك أكمل بيانات الموتوسيكل الأساسية';

  @override
  String get bikePhotoLabel => 'صورة الموتوسيكل';

  @override
  String get bikeLicensePhotoLabel => 'رخصة الموتوسيكل';

  @override
  String get bikeBrandHint => 'العلامة التجارية للموتوسيكل';

  @override
  String get bikeModelHint => 'طراز الموتوسيكل';

  @override
  String get bikeColorHint => 'لون الموتوسيكل';

  @override
  String get bikeYearHint => 'سنة الانتاج';

  @override
  String get helpScreenTitle => 'مساعدة';

  @override
  String get faqOrderTripQuestion => 'إزاي أطلب رحلة؟';

  @override
  String get faqOrderTripAnswer =>
      'من الشاشة الرئيسية، حدد نقطة الانطلاق ثم اختار الوجهة، وبعدها شوف السعر المقترح وابعت الطلب. هتظهرلك عروض من الطيارين القريبين وتقدر تختار العرض اللي يناسبك.';

  @override
  String get faqPricingQuestion => 'إزاي بيتحدد السعر؟';

  @override
  String get faqPricingAnswer =>
      'السعر بيتحسب على أساس المسافة الفعلية بين نقطة الانطلاق والوجهة، وتقدر تزود أو تقلل السعر المقترح وقت المزايدة مع الطيارين.';

  @override
  String get faqPaymentMethodsQuestion => 'وسايل الدفع المتاحة إيه؟';

  @override
  String get faqPaymentMethodsAnswer =>
      'تقدر تدفع كاش للطيار مباشرة، أو من خلال المحفظة الإلكترونية، أو عن طريق إنستاباي. تقدر تختار وسيلة الدفع وانت بتأكد الطلب.';

  @override
  String get faqNoAcceptQuestion => 'مفيش حد بيقبل طلبي، أعمل إيه؟';

  @override
  String get faqNoAcceptAnswer =>
      'جرب تزود السعر شوية وقت المزايدة، خصوصًا في أوقات الذروة أو المناطق البعيدة، ده بيخلي الطلب أكثر جاذبية للطيارين القريبين.';

  @override
  String get faqBecomeDriverQuestion => 'إزاي أبقى طيار في تطبيق طيار؟';

  @override
  String get faqBecomeDriverAnswer =>
      'من القايمة الجانبية اختار \"وضع الطيار\" وكمّل خطوات التسجيل (البيانات، الرخصة، الموتوسيكل)، وبعد المراجعة هتقدر تستقبل طلبات.';

  @override
  String get faqDriverEarningsQuestion => 'إزاي بتتحسب أرباح الطيار؟';

  @override
  String get faqDriverEarningsAnswer =>
      'من كل رحلة، الطيار بياخد نسبة 90% من قيمة الرحلة والشركة بتاخد 10% مقابل تشغيل المنصة. تقدر تتابع تفاصيل أرباحك من تبويب \"الدخلي\".';

  @override
  String get faqDeliverPackageQuestion =>
      'تقدر أوصّل طرد بدل ما أعمل رحلة راكب؟';

  @override
  String get faqDeliverPackageAnswer =>
      'أيوه، من خدمة \"توصيل الطرود\" تقدر تبعت طرد من مكان لمكان من غير ما تكون موجود في الرحلة، ونفس نظام المزايدة بيتطبق برضه.';

  @override
  String get faqTripProblemQuestion => 'إيه اللي أعمله لو حصلت مشكلة في رحلة؟';

  @override
  String get faqTripProblemAnswer =>
      'تقدر تتواصل مع فريق الدعم مباشرة من شاشة \"الدعم\" في القايمة الجانبية، وهنساعدك تحل المشكلة أول بأول.';

  @override
  String get chooseYourRideSubtitle => 'اختار المشوار المناسب ليك';

  @override
  String get continueWithGoogleButton => 'المتابعة باستخدام Google';

  @override
  String get continueWithAppleButton => 'المتابعة باستخدام Apple';

  @override
  String get continueWithPhoneButton => 'المتابعة عبر الهاتف';

  @override
  String get loginTermsAgreementNotice =>
      'يشير الانضمام إلى موافقتك على شروط الاستخدام والسياسة الخصوصية';

  @override
  String signInFailedError(String error) {
    return 'فشل تسجيل الدخول: $error';
  }

  @override
  String signInWithAppleFailedError(String error) {
    return 'فشل تسجيل الدخول بآبل: $error';
  }

  @override
  String get markAllAsReadButton => 'تحديد الكل كمقروء';

  @override
  String get mustSignInToViewNotifications =>
      'لازم تسجل الدخول عشان تشوف الإشعارات';

  @override
  String get errorLoadingNotifications => 'حصل خطأ في تحميل الإشعارات';

  @override
  String get noNotificationsYet => 'مفيش إشعارات لسه';

  @override
  String get justNowLabel => 'الآن';

  @override
  String minutesAgoLabel(int minutes) {
    return 'من $minutes دقيقة';
  }

  @override
  String hoursAgoLabel(int hours) {
    return 'من $hours ساعة';
  }

  @override
  String daysAgoLabel(int days) {
    return 'من $days يوم';
  }

  @override
  String get defaultCustomerName => 'مستخدم';

  @override
  String get setYourFareTitle => 'حدد سعرك';

  @override
  String get routeFromLabel => 'من';

  @override
  String get routeToLabel => 'إلى';

  @override
  String get distanceLabel => 'المسافة';

  @override
  String get estimatedTimeLabel => 'الوقت المتوقع';

  @override
  String get suggestedFareForDriversLabel => 'السعر المقترح للطيارين';

  @override
  String autoSuggestedFareLabel(String amount) {
    return 'السعر المقترح تلقائيًا: $amount جنيه';
  }

  @override
  String get autoAcceptCheckboxLabel =>
      'قبول تلقائي لأول عرض بنفس السعر المقترح';

  @override
  String get searchForDriversButton => 'البحث عن طيارين';

  @override
  String get invalidPhoneNumberError => 'من فضلك اكتب رقم موبايل صحيح';

  @override
  String get tryAgainLabel => 'حاول تاني';

  @override
  String errorOccurredWithMessage(String message) {
    return 'حصل خطأ: $message';
  }

  @override
  String get otpSendNoticeLabel => 'هنبعتلك كود تحقق على الرقم ده';

  @override
  String get sendCodeButton => 'إرسال الكود';

  @override
  String get otpLengthError => 'اكتب الكود المكون من 6 أرقام';

  @override
  String get invalidOtpError => 'الكود غلط، حاول تاني';

  @override
  String get confirmPhoneNumberTitle => 'تأكيد الرقم';

  @override
  String otpSentToNumberLabel(String phone) {
    return 'بعتنالك كود تحقق على $phone';
  }

  @override
  String get determiningAddressLabel => 'جاري تحديد العنوان...';

  @override
  String get customLocationLabel => 'موقع مخصص';

  @override
  String get doneButton => 'تم';

  @override
  String get rateTripArrivedSafelyTitle => 'وصلت لوجهتك بأمان!';

  @override
  String get rateTripSubtitle => 'قيّم رحلتك مع الطيار';

  @override
  String get pleaseSelectStarsFirst => 'من فضلك اختار عدد النجوم الأول';

  @override
  String get failedToSaveRatingError => 'تعذر حفظ التقييم، حاول تاني';

  @override
  String get thankYouForRatingLabel => 'شكرًا لتقييمك! 🌟';

  @override
  String get ratingVeryBadLabel => 'سيء جدًا';

  @override
  String get ratingFairLabel => 'مقبول';

  @override
  String get ratingGoodLabel => 'كويس';

  @override
  String get ratingVeryGoodLabel => 'جيد جدًا';

  @override
  String get ratingExcellentLabel => 'ممتاز';

  @override
  String get chooseYourRatingLabel => 'اختار تقييمك';

  @override
  String get commentHintOptional => 'اكتب تعليقك (اختياري)';

  @override
  String get submitRatingButton => 'إرسال التقييم';

  @override
  String get skipButton => 'تخطي';

  @override
  String get failedToAcceptOfferError => 'تعذر قبول العرض، حاول تاني';

  @override
  String get offerAcceptedTitle => 'تم قبول العرض!';

  @override
  String driverOnWayWithFareLabel(String driverName, String price) {
    return 'الطيار $driverName في الطريق ليك بسعر $price جنيه';
  }

  @override
  String get cancelSearchTitle => 'إلغاء البحث؟';

  @override
  String get cancelSearchBody => 'هيتم إلغاء طلبك وإيقاف البحث عن طيارين';

  @override
  String get goBackButton => 'رجوع';

  @override
  String get cancelOrderButton => 'إلغاء الطلب';

  @override
  String get increaseFareButton => 'زيادة الأجرة';

  @override
  String autoAcceptNearestDriverLabel(String amount) {
    return 'قبول أقرب طيار مقابل $amount جنيه تلقائيًا';
  }

  @override
  String cashAmountLabel(String amount) {
    return '$amount جنيه نقدًا';
  }

  @override
  String get oneDriverViewingOrderLabel => 'طيار واحد بيشوف طلبك';

  @override
  String multipleDriversViewingOrderLabel(int count) {
    return '$count طيارين بيشوفوا طلبك';
  }

  @override
  String get tryRaisingFareTitle => 'جرب تزود السعر';

  @override
  String get raiseFareHintBody => 'ممكن تزود فرصك للحصول علي مشوارك بسرعة';

  @override
  String searchWithFareLabel(String amount) {
    return 'البحث بسعر $amount جنيه';
  }

  @override
  String newOfferFromDriverLabel(String driverName) {
    return 'عرض جديد من $driverName';
  }

  @override
  String get rejectButton => 'رفض';

  @override
  String get acceptButton => 'قبول';

  @override
  String get setPinTitle => 'حدد رقم سري من 4 أرقام';

  @override
  String get unknownProviderLabel => 'غير معروف';

  @override
  String get googleAccountLabel => 'حساب Google';

  @override
  String phoneNumberProviderLabel(String phone) {
    return 'رقم الهاتف ($phone)';
  }

  @override
  String get emailPasswordProviderLabel => 'البريد الإلكتروني وكلمة المرور';

  @override
  String get deleteAccountPermanentlyTitle => 'حذف الحساب نهائيًا';

  @override
  String get deleteAccountConfirmBody =>
      'هيتم حذف حسابك وكل بياناتك نهائيًا ومش هتقدر ترجعها تاني. متأكد؟';

  @override
  String get deletePermanentlyButton => 'حذف نهائي';

  @override
  String get reauthRequiredForDeleteError =>
      'لازم تسجل الخروج والدخول تاني قبل ما تقدر تحذف حسابك';

  @override
  String get signInMethodLabel => 'وسيلة تسجيل الدخول';

  @override
  String get appLockTitle => 'قفل التطبيق برقم سري';

  @override
  String get appLockSubtitle => 'هتحتاج تدخل الرقم السري كل ما تفتح التطبيق';

  @override
  String get noMatchingResultsError => 'مفيش نتائج مطابقة';

  @override
  String get searchFailedTryAgainError => 'تعذر البحث حاليًا، حاول تاني';

  @override
  String get unknownPlaceLabel => 'مكان غير معروف';

  @override
  String get whereDoYouWantToGoTitle => 'عايز تروح فين؟';

  @override
  String get selectDropoffLocationTitle => 'اختار مكان التسليم';

  @override
  String get searchPlaceHint => 'اكتب اسم الشارع أو المكان...';

  @override
  String get pickFromMapLabel => 'اختار من الخريطة';

  @override
  String get startTypingToSearchLabel => 'ابدأ الكتابة عشان تدور على مكان';

  @override
  String get recentSearchesLabel => 'عمليات البحث الأخيرة';

  @override
  String get failedToOpenAppError => 'تعذر فتح التطبيق المطلوب';

  @override
  String get whatsappSupportMessage => 'مرحبًا، محتاج مساعدة في تطبيق طيار';

  @override
  String get supportEmailSubject => 'مساعدة تطبيق طيار';

  @override
  String get supportMessageSentConfirmation =>
      'تم إرسال رسالتك، هيتواصل معاك فريق الدعم قريب';

  @override
  String get genericErrorTryAgain => 'حصل خطأ، حاول تاني';

  @override
  String get contactUsDirectlyLabel => 'تواصل معانا مباشرة';

  @override
  String get whatsappLabel => 'واتساب';

  @override
  String get callLabel => 'اتصال';

  @override
  String get emailLabel => 'إيميل';

  @override
  String get orSendMessageHereLabel => 'أو ابعتلنا رسالتك هنا';

  @override
  String get supportMessageHint => 'اكتب مشكلتك أو استفسارك هنا...';

  @override
  String get sendButton => 'إرسال';

  @override
  String get tripCompletedTitle => 'وصلت لوجهتك!';

  @override
  String get tripCancelledTitle => 'تم إلغاء الرحلة';

  @override
  String get thankYouForUsingTayarLabel => 'شكرا لاستخدامك طيار!';

  @override
  String get tripCancelledByDriverOrSystemLabel =>
      'الرحلة اتلغت من الطيار أو من النظام';

  @override
  String get arrivedAtYourDestinationStatusLabel => 'وصلتوا لوجهتكم 🎉';

  @override
  String get driverOnWayToYouLabel => 'الطيار في الطريق ليك';

  @override
  String get tripStartedOnWayToDestinationLabel =>
      'الرحلة بدأت - في الطريق للوجهة';

  @override
  String get updatingLabel => 'جاري التحديث...';

  @override
  String get arrivedWaitingDriverToEndTripLabel =>
      'وصلتوا لوجهتكم! في انتظار الطيار ينهي الرحلة';

  @override
  String get waitingDriverShareLocationLabel =>
      'في انتظار بدء الطيار مشاركة موقعه...';
}
