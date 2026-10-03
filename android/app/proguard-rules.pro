# ====== قواعد R8 للإصدار ======
# stack traces مقروءة في Crashlytics (الـ mapping بيترفع تلقائي)
-keepattributes SourceFile,LineNumberTable,*Annotation*
-renamesourcefileattribute SourceFile

# Flutter + أغلب الـ plugins (Firebase, OneSignal, ...) بتجيب consumer rules
# بتاعتها لوحدها. لو ظهر crash بعد التصغير، ضيف keep rule هنا للكلاس المعني.
