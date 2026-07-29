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
  String get driverNoOrders => 'مفيش طلبات متاحة';

  @override
  String get driverOfflineHint =>
      'أنت غير متاح دوس \"اونلاين\" عشان تشوف الطلبات المتاحة';

  @override
  String get driverNoRatings => 'مفيش تقييمات';

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
  String get errorLoadingOrders => 'خطأ في تحميل الطلبات';

  @override
  String get defaultDriverName => 'طيار';

  @override
  String get statusAvailable => 'متاح';

  @override
  String get statusUnavailable => 'غير متاح';

  @override
  String get permissionLocationRequired =>
      'لازم تسمح بصلاحية الوصول للموقع الأول عشان تظهر أونلاين';

  @override
  String get offerSentWaitingPassenger => 'تم إرسال عرضك، في انتظار رد الراكب';

  @override
  String get offerSendFailed => 'تعذر إرسال العرض، حاول تاني';

  @override
  String get arrivedAtDestination => 'وصلت وجهتك';

  @override
  String get endTrip => 'إنهي الرحلة';

  @override
  String get startTrip => 'ابدأ الرحلة';

  @override
  String get driverToggleOnline => 'متاح';

  @override
  String get driverToggleOffline => 'غير متاح';

  @override
  String get mustSignInFirst => 'لازم تسجل الدخول الأول';

  @override
  String get paymentMethodCash => 'نقدي';

  @override
  String get navProfile => 'الملف الشخصي';

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
  String get offerSentAlreadyLabel => 'تم إرسال عرضك، في انتظار رد الراكب';

  @override
  String get offerCustomButton => 'عرض سعر مختلف';

  @override
  String get acceptProposedPrice => 'قبول بالسعر المقترح';

  @override
  String get setYourPriceLabel => 'حدد سعرك';

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
  String get bikePlateLabel => 'رقم اللوحة';

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
  String get confirmLogoutMessage => 'تأكيد تسجيل الخروج؟';

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
  String get appThemeLabel => 'مظهر التطبيق';

  @override
  String get darkModeLabel => 'الوضع الغامق';

  @override
  String get lightModeLabel => 'الوضع الفاتح';

  @override
  String get useDeviceThemeLabel => 'استخدام إعداد الجهاز';

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
  String get phoneNumberLabel => 'رقم الهاتف';

  @override
  String get addressLabel => 'المدينة';

  @override
  String get saveButton => 'حفظ';

  @override
  String get fullNameRequiredError => 'من فضلك أدخل الاسم كاملًا';

  @override
  String get saveFailedError => 'تعذر الحفظ، حاول تاني';

  @override
  String get profileUpdatedSuccess => 'تم تحديث الملف الشخصي بنجاح';

  @override
  String get changePhotoLabel => 'تغيير الصورة';

  @override
  String get choosePhotoSourceTitle => 'اختار مصدر الصورة';

  @override
  String get chooseFromGalleryLabel => 'اختيار من المعرض';

  @override
  String get takePhotoLabel => 'التقاط صورة بالكاميرا';

  @override
  String get photoTooLargeError =>
      'الصورة كبيرة جدًا، من فضلك اختار صورة تانية أصغر';

  @override
  String get invalidPhoneNumberError =>
      'رقم الهاتف غير صحيح، لازم يكون رقم مصري صحيح';

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
  String get fromLabel => 'من';

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
  String get senderPhoneLabel => 'رقم هاتف المُرسل';

  @override
  String get receiverPhoneLabel => 'رقم هاتف المُستلم';

  @override
  String get phoneNumberHint => '01xxxxxxxxx';

  @override
  String get saveOrderButton => 'حفظ الطلب';

  @override
  String get fillAllFieldsError =>
      'من فضلك اختار المواقع واملأ كل البيانات المطلوبة';

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
  String get defaultUserName => 'مستخدم';

  @override
  String get driverModeButton => 'وضع الطيار';

  @override
  String get orderHistoryLabel => 'سجل الطلبات';

  @override
  String get driverRegistrationTitle => 'تسجيل الطيار';

  @override
  String get closeButton => 'إغلاق';

  @override
  String get submitApplicationSuccessTitle => 'تم إرسال طلبك';

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
  String get sectionBikeInfo => 'معلومات الدراجة النارية';

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
  String get bikeInfoRequiredError =>
      'من فضلك أكمل بيانات الدراجة النارية الأساسية';

  @override
  String get bikePhotoLabel => 'صورة الدراجة النارية';

  @override
  String get bikeLicensePhotoLabel => 'رخصة الدراجة النارية';

  @override
  String get bikeBrandHint => 'العلامة التجارية للدراجة نارية';

  @override
  String get bikeModelHint => 'طراز الدراجة النارية';

  @override
  String get bikeColorHint => 'لون الدراجة النارية';

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
      'تقدر تدفع نقدي للطيار مباشرة، أو من خلال المحفظة الإلكترونية، أو عن طريق إنستاباي. تقدر تختار وسيلة الدفع وانت بتأكد الطلب.';

  @override
  String get faqNoAcceptQuestion => 'مفيش حد بيقبل طلبي، أعمل إيه؟';

  @override
  String get faqNoAcceptAnswer =>
      'جرب تزود السعر شوية وقت المزايدة، خصوصًا في أوقات الذروة أو المناطق البعيدة، ده بيخلي الطلب أكثر جاذبية للطيارين القريبين.';

  @override
  String get faqBecomeDriverQuestion => 'إزاي أبقى طيار في تطبيق طيار؟';

  @override
  String get faqBecomeDriverAnswer =>
      'من القايمة الجانبية اختار \"وضع الطيار\" وكمّل خطوات التسجيل (البيانات، الرخصة، الدراجة النارية)، وبعد المراجعة هتقدر تستقبل طلبات.';

  @override
  String get faqDriverEarningsQuestion => 'إزاي بتتحسب أرباح الطيار؟';

  @override
  String get faqDriverEarningsAnswer =>
      'من كل رحلة، الطيار بياخد نسبة 90% من قيمة الرحلة والشركة بتاخد 10% مقابل تشغيل المنصة. تقدر تتابع تفاصيل أرباحك من تبويب \"دخلي\".';

  @override
  String get faqDeliverPackageQuestion =>
      'اقدر أوصّل طلب بدل ما أعمل رحلة راكب؟';

  @override
  String get faqDeliverPackageAnswer =>
      'أيوه، من خدمة \"وصل طلباتي\" تقدر تبعت طرد من مكان لمكان من غير ما تكون موجود في الرحلة، ونفس نظام المزايدة بيتطبق برضه.';

  @override
  String get faqTripProblemQuestion => 'إيه اللي أعمله لو حصلت مشكلة في رحلة؟';

  @override
  String get faqTripProblemAnswer =>
      'تقدر تتواصل مع فريق الدعم مباشرة من شاشة \"الدعم\" في القايمة الجانبية، وهنساعدك تحل المشكلة أول بأول.';

  @override
  String get chooseYourRideSubtitle => 'اختار الرحلة المناسبة ليك';

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
  String get nameLabel => 'الاسم';

  @override
  String get requiredFieldError => 'هذا الحقل مطلوب';

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
  String get phoneNumberFormatError => 'من فضلك اكتب رقم هاتف صحيح';

  @override
  String get mobileNumberMatchHint =>
      'لو حد من الإدارة ضافك قبل كده، اكتب نفس رقم الموبايل بالظبط اللي اتسجل بيه';

  @override
  String get credentialAlreadyInUseError =>
      'رقم الموبايل ده متسجل بحساب تاني بالفعل. من فضلك اكتب رقم مختلف';

  @override
  String get otpSendFailedGenericError =>
      'حدث خطأ أثناء إرسال كود التحقق، برجاء المحاولة مرة أخرى لاحقًا';

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
  String get invalidOtpError => 'الكود غلط، حاول تاني';

  @override
  String get confirmPhoneNumberTitle => 'تأكيد الرقم';

  @override
  String otpSentToNumberLabel(String phone) {
    return 'بعتنالك كود تحقق على $phone';
  }

  @override
  String get resendCodeButton => 'إعادة إرسال الكود';

  @override
  String resendCodeCountdown(int seconds) {
    return 'تقدر تطلب الكود تاني بعد $seconds ثانية';
  }

  @override
  String get didntReceiveCodeLabel => 'لسه مبعتلكش الكود؟';

  @override
  String get codeResentMessage => 'اتبعت الكود تاني';

  @override
  String get determiningAddressLabel => 'جاري تحديد العنوان...';

  @override
  String get customLocationLabel => 'موقع مخصص';

  @override
  String get doneButton => 'تم';

  @override
  String get rateTripArrivedSafelyTitle => 'وصلت وجهتك بأمان';

  @override
  String get rateTripSubtitle => 'قيّم رحلتك مع الطيار';

  @override
  String get pleaseSelectStarsFirst => 'من فضلك اختار عدد النجوم الأول';

  @override
  String get failedToSaveRatingError => 'تعذر حفظ التقييم، حاول تاني';

  @override
  String get thankYouForRatingLabel => 'شكراً لتقييمك';

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
  String get offerAcceptedTitle => 'تم قبول العرض';

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
  String get raiseFareHintBody => 'زود فرصتك للحصول علي الرحلة بسرعة';

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
  String get whereDoYouWantToGoTitle => 'حدد مسارك';

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
  String get tripCancelledTitle => 'تم إلغاء الرحلة';

  @override
  String get tripCancelledByDriverOrSystemLabel =>
      'الرحلة اتلغت من الطيار أو من النظام';

  @override
  String get driverOnWayToYouLabel => 'الطيار في الطريق ليك';

  @override
  String get driverArrivedAtPickupLabel => 'الطيار وصلك';

  @override
  String get arrivedAtYourDestinationStatusLabel => 'وصلت وجهتك';

  @override
  String get tripStartedOnWayToDestinationLabel =>
      'الرحلة بدأت - في الطريق للوجهة';

  @override
  String get updatingLabel => 'جاري التحديث...';

  @override
  String get arrivedWaitingDriverToEndTripLabel =>
      'وصلت وجهتك، اطلب من الطيار ينهي الرحلة';

  @override
  String get waitingDriverShareLocationLabel =>
      'في انتظار مشاركة موقع الطيار...';

  @override
  String get noOrdersYetTitle => 'مفيش طلبات';

  @override
  String get noOrdersYetSubtitle => 'طلباتك اللي هتعملها هتظهر هنا';

  @override
  String get orderStatusSearchingLabel => 'بيدور على طيار';

  @override
  String get orderStatusAcceptedLabel => 'مقبول';

  @override
  String get orderStatusInProgressLabel => 'جاري التنفيذ';

  @override
  String get orderStatusCompletedLabel => 'مكتمل';

  @override
  String get orderStatusCancelledLabel => 'ملغي';

  @override
  String get rideOrderTypeLabel => 'رحلة';

  @override
  String get deliveryOrderTypeLabel => 'توصيل';

  @override
  String fareAmountEgpLabel(String amount) {
    return '$amount جنيه';
  }

  @override
  String get chatWithDriverLabel => 'محادثة';

  @override
  String get callDriverLabel => 'مكالمة';

  @override
  String get chatWithPassengerLabel => 'محادثة';

  @override
  String get callPassengerLabel => 'مكالمة';

  @override
  String originalProposedFareLabel(String amount) {
    return 'السعر المقترح: $amount جنيه';
  }

  @override
  String get chatErrorLoadingMessages => 'خطأ في تحميل الرسائل';

  @override
  String get chatNoMessagesYet => 'ابدأ المحادثة';

  @override
  String get chatTypeMessageHint => 'اكتب رسالة...';

  @override
  String get chatTypingIndicator => 'بيكتب الآن...';

  @override
  String get chatQuickReplyOnMyWay => 'أنا في الطريق';

  @override
  String get chatQuickReplyArrived => 'وصلت المكان';

  @override
  String get chatQuickReplyWaitPlease => 'استنى شوية لو سمحت';

  @override
  String get chatQuickReplyOk => 'تمام';

  @override
  String get chooseAccountTypeTitle => 'اختار نوع حسابك';

  @override
  String get chooseAccountTypeSubtitle => 'تقدر تبدأ كراكب أو كطيار';

  @override
  String get passengerRoleTitle => 'راكب';

  @override
  String get passengerRoleDescription => 'اطلب رحلتك بسهولة وسرعة';

  @override
  String get driverRoleTitle => 'طيار';

  @override
  String get driverRoleDescription => 'اشتغل واكسب فلوس بموتوسيكلك';

  @override
  String get completeProfileTitle => 'كمّل بياناتك';

  @override
  String get completeProfileSubtitle => 'هنستخدم اسمك عشان الناس تتعرف عليك';

  @override
  String get topUpWalletButton => 'اشحن محفظتك';

  @override
  String get topUpWalletTitle => 'شحن رصيد المحفظة';

  @override
  String get topUpWalletSubtitle =>
      'حوّل المبلغ إنستاباي وارفع صورة إيصال التحويل، وهنراجع طلبك ونضيفه لرصيدك أول بأول';

  @override
  String get topUpAmountLabel => 'المبلغ (جنيه)';

  @override
  String get topUpProofLabel => 'صورة إثبات التحويل';

  @override
  String get topUpProofRequiredError => 'لازم ترفع صورة إثبات التحويل';

  @override
  String get invalidAmountError => 'أدخل مبلغ صحيح';

  @override
  String get topUpSubmitButton => 'إرسال الطلب';

  @override
  String get topUpSubmittedTitle => 'تم إرسال طلبك';

  @override
  String get topUpSubmittedBody => 'هنراجع طلب الشحن ونضيفه لرصيدك في أقرب وقت';

  @override
  String get walletTransactionsTitle => 'سجل المعاملات';

  @override
  String get noWalletTransactionsLabel => 'مفيش معاملات لسه';

  @override
  String get walletCommissionTransactionLabel => 'عمولة رحلة';

  @override
  String get walletTopupPendingLabel => 'طلب شحن - في انتظار المراجعة';

  @override
  String get walletTopupApprovedLabel => 'طلب شحن - تم القبول';

  @override
  String get walletTopupRejectedLabel => 'طلب شحن - مرفوض';

  @override
  String get negativeWalletBalanceNote =>
      'رصيدك بالسالب، لازم تشحن المحفظة عشان تقدر تستقبل طلبات جديدة';

  @override
  String get myWalletLabel => 'محفظتي';

  @override
  String get walletTripPaymentLabel => 'رحلة مدفوعة بالمحفظة';

  @override
  String get walletAdminCreditLabel => 'رصيد مضاف من الإدارة';

  @override
  String walletAvailableBalanceLabel(String amount) {
    return 'الرصيد المتاح: $amount جنيه';
  }

  @override
  String get walletInsufficientBalanceLabel => 'الرصيد مش كافي لدفع الأجرة دي';

  @override
  String walletMaxFareCapLabel(String amount) {
    return 'أقصى سعر ممكن تقترحه حسب رصيد محفظتك: $amount جنيه';
  }

  @override
  String get homePromoBannerText => 'احصل على أول توصيل مجانًا';

  @override
  String get homeSearchHint => 'عايز تروح فين؟';

  @override
  String get savedPlacesLabel => 'أماكن محفوظة';

  @override
  String get savedPlaceHome => 'البيت';

  @override
  String get savedPlaceWork => 'الشغل';

  @override
  String get savedPlaceAdd => 'إضافة';

  @override
  String get savedPlacesComingSoonMessage => 'الميزة دي هتضاف قريبًا';

  @override
  String get lastTripLabel => 'آخر رحلة';

  @override
  String get reorderTripLabel => 'إعادة الطلب';

  @override
  String get recentDestinationsLabel => 'وجهات أخيرة';

  @override
  String nearbyDriversCountLabel(int count) {
    return '$count سواقين قريبين منك';
  }

  @override
  String get rateLastTripReminderText => 'قيّم رحلتك الأخيرة';

  @override
  String get selectHomeAddressTitle => 'اختار عنوان البيت';

  @override
  String get selectWorkAddressTitle => 'اختار عنوان الشغل';

  @override
  String get savedAddressSavedConfirmation => 'تم حفظ العنوان';

  @override
  String get savedAddressSaveError => 'حصل خطأ أثناء حفظ العنوان، حاول تاني';

  @override
  String get selectCustomPlaceTitle => 'اختار مكان الحفظ';

  @override
  String get nameSavedPlaceTitle => 'سمّي المكان';

  @override
  String get nameSavedPlaceHint => 'مثلاً: الجيم، المكتب';

  @override
  String get nameSavedPlaceRequiredError => 'من فضلك اكتب اسم للمكان';

  @override
  String get removeSavedPlaceTitle => 'حذف المكان المحفوظ؟';

  @override
  String get removeSavedPlaceMessage =>
      'هيتم حذف المكان ده من الأماكن المحفوظة';

  @override
  String get removeSavedPlaceButton => 'حذف';

  @override
  String get savedPlaceRemovedConfirmation => 'تم حذف المكان المحفوظ';

  @override
  String get becomeVendorTitle => 'عايز تبقى شريك تجاري معانا؟';

  @override
  String get becomeVendorIntro =>
      'املأ بيانات محلك وهنتواصل معاك بعد المراجعة.';

  @override
  String get vendorStoreNameLabel => 'اسم المحل';

  @override
  String get vendorStoreNameHint => 'مثال: سوبر ماركت النور';

  @override
  String get vendorBusinessTypeLabel => 'نوع النشاط';

  @override
  String get vendorTypeRestaurant => 'مطعم';

  @override
  String get vendorTypeSupermarket => 'سوبر ماركت';

  @override
  String get vendorTypePharmacy => 'صيدلية';

  @override
  String get vendorTypeOther => 'أخرى';

  @override
  String get vendorPhoneLabel => 'رقم موبايل/واتساب';

  @override
  String get vendorLocationLabel => 'موقع المحل';

  @override
  String get vendorLocationPickTitle => 'حدد موقع المحل';

  @override
  String get vendorNoteLabel => 'ملاحظة (اختياري)';

  @override
  String get vendorNoteHint => 'أي تفاصيل إضافية تحب تضيفها';

  @override
  String get vendorSubmitButton => 'إرسال الطلب';

  @override
  String get vendorFillRequiredFieldsError =>
      'من فضلك املأ اسم المحل ورقم الموبايل وحدد الموقع';

  @override
  String get vendorSubmitFailedError => 'تعذر إرسال الطلب، حاول تاني';

  @override
  String get vendorApplicationSentTitle => 'تم إرسال طلبك';

  @override
  String get vendorApplicationSentMessage =>
      'طلبك قيد المراجعة حاليًا، هنتواصل معاك قريبًا.';

  @override
  String get okButton => 'تمام';

  @override
  String get registerStoreDrawerLabel => 'لو عايز تبقى شريك تجاري معانا؟';
}
