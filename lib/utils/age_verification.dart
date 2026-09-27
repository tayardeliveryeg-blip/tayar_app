// ====================================================
// ====== بند 8 من gap analysis: حد السن الأدنى لاستخدام التطبيق (راكب
// أو طيار) كان مذكور في الشروط والأحكام بس من غير أي تحقق فعلي وقت
// التسجيل - birthDate كان حقل اختياري في شاشات البروفايل بس، ممكن
// يتسيب فاضي أو يتحط فيه أي تاريخ من غير أي تحقق. الملف ده بيجمع
// منطق التحقق في مكان واحد بدل ما يتكرر في كل شاشة تسجيل (راكب وطيار) ======
// ====================================================

const int kMinimumAgeYears = 18;

/// بيرجع true لو تاريخ الميلاد بيدي عمر >= [kMinimumAgeYears] اعتبارًا
/// من النهاردة - بياخد بالاعتبار لو عيد الميلاد بتاعه السنادي لسه ما
/// جاش (يعني منقصش سنة من العمر غلط لمجرد إن السنة الميلادية اتغيرت) ======
bool isAtLeastMinimumAge(DateTime birthDate) {
  final now = DateTime.now();
  var age = now.year - birthDate.year;
  final hasHadBirthdayThisYear =
      (now.month > birthDate.month) ||
      (now.month == birthDate.month && now.day >= birthDate.day);
  if (!hasHadBirthdayThisYear) age -= 1;
  return age >= kMinimumAgeYears;
}

/// أقصى تاريخ مسموح يختاره المستخدم في الـ DatePicker (يوم ما قبل
/// [kMinimumAgeYears] سنة من النهاردة بالظبط) - بيمنع اختيار تاريخ
/// ميلاد بيدي عمر أقل من الحد الأدنى من الأساس، بدل ما نسيبه يختار
/// أي تاريخ ونرفضله بعد كده ======
DateTime get maxAllowedBirthDateForRegistration {
  final now = DateTime.now();
  return DateTime(now.year - kMinimumAgeYears, now.month, now.day);
}

/// بيحاول يحوّل نص التاريخ (بصيغة yyyy-MM-dd المستخدمة في كل شاشات
/// التطبيق زي driver_profile_screen.dart و passenger_profile_screen.dart)
/// لـ DateTime - بيرجع null لو النص فاضي أو الصيغة غلط ======
DateTime? parseStoredBirthDate(String value) {
  if (value.trim().isEmpty) return null;
  return DateTime.tryParse(value.trim());
}
