// ====== Cloud Functions بتاعة تطبيق طيار (Tayar) ======
// المسؤولية: أي وقت رسالة شات جديدة أو إشعار جديد يتكتب في Firestore،
// الدالة دي بتشتغل تلقائيًا وتبعت Push Notification حقيقي (FCM) للجهاز
// بتاع الطرف التاني - حتى لو التطبيق مقفول تمامًا.
//
// الفكرة الأساسية: الموبايل (Flutter) بيكتب في Firestore بس زي ما هو
// شغال دلوقتي بالظبط (مفيش أي تعديل مطلوب في كود الشات نفسه). الدالة دي
// هي اللي بتـ"تسمع" للكتابة وتبعت الإشعار - مفيش أي كود إضافي على الموبايل
// غير تسجيل الـ FCM Token (وده متعمول بالفعل في push_notification_service.dart).

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");

admin.initializeApp();

// ====== المنطقة: اختر أقرب منطقة لمستخدميك لتقليل زمن الاستجابة ======
// (europe-west1 = بلجيكا، أقرب منطقة متاحة لمصر حاليًا من مناطق Firebase Functions)
setGlobalOptions({ region: "europe-west1", maxInstances: 10 });

/**
 * بتدور على الـ FCM token بتاع مستخدم معين، سواء كان راكب (users) أو
 * طيار (drivers)، من غير ما تحتاج تعرف نوعه مقدمًا.
 */
async function getFcmTokenForUser(uid) {
  if (!uid) return null;
  const db = admin.firestore();

  const usersDoc = await db.collection("users").doc(uid).get();
  if (usersDoc.exists && usersDoc.data().fcmToken) {
    return usersDoc.data().fcmToken;
  }

  const driversDoc = await db.collection("drivers").doc(uid).get();
  if (driversDoc.exists && driversDoc.data().fcmToken) {
    return driversDoc.data().fcmToken;
  }

  return null;
}

// ====== ⚠️ الدالة دي بقت غير مستخدمة (superseded) ======
// محتاجة خطة Blaze عشان تتنشر أصلًا. الموبايل بقى بينادي بديلها بعد ما
// يبعت رسالة شات: Supabase Edge Function اسمها chat-notify
// (supabase/functions/chat-notify/) - نفس المنطق بالظبط، بس بتتنادى
// مباشرة من trip_chat_screen.dart بدل ما تكون Firestore Trigger (Supabase
// مفيهوش Firestore triggers أصلًا). سايبينها هنا كمرجع/خطة رجوع.
/**
 * ====== 1) إشعار رسالة شات جديدة ======
 * بتتفعّل تلقائيًا لما مستند جديد يتكتب في:
 *   orders/{orderId}/messages/{messageId}
 */
exports.onNewChatMessage = onDocumentCreated(
  "orders/{orderId}/messages/{messageId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const message = snap.data();
    const { orderId } = event.params;
    const senderId = message.senderId;
    const senderName = message.senderName || "";
    const text = message.text || "";

    if (!senderId) {
      console.log("رسالة من غير senderId - تم التجاهل");
      return;
    }

    // ====== نجيب بيانات الأوردر عشان نعرف مين الطرف التاني (المستلم) ======
    const orderDoc = await admin
      .firestore()
      .collection("orders")
      .doc(orderId)
      .get();

    if (!orderDoc.exists) {
      console.log(`الأوردر ${orderId} مش موجود`);
      return;
    }

    const order = orderDoc.data();
    const customerId = order.customerId;
    const driverId = order.driverId;

    // ====== المستلم هو اللي مش الراسل ======
    let recipientId = null;
    if (senderId === customerId) {
      recipientId = driverId;
    } else if (senderId === driverId) {
      recipientId = customerId;
    }

    if (!recipientId) {
      console.log("تعذر تحديد المستلم (senderId مش مطابق لأي طرف في الأوردر)");
      return;
    }

    const token = await getFcmTokenForUser(recipientId);
    if (!token) {
      console.log(`مفيش fcmToken محفوظ للمستخدم ${recipientId}`);
      return;
    }

    try {
      await admin.messaging().send({
        token,
        notification: {
          title: senderName || "رسالة جديدة",
          body: text,
        },
        data: {
          type: "chat",
          orderId: String(orderId),
          senderName: String(senderName),
        },
        android: {
          priority: "high",
          notification: { channelId: "tayar_chat_channel" },
        },
        apns: {
          payload: { aps: { sound: "default" } },
        },
      });
      console.log(`إشعار شات اتبعت للمستخدم ${recipientId}`);
    } catch (err) {
      console.error("فشل إرسال إشعار الشات:", err);
    }
  }
);

/**
 * ====== 2) إشعار شحن محفظة من لوحة الأدمن ======
 * بتتفعّل تلقائيًا لما لوحة الأدمن تضيف رصيد لراكب (submitWalletGrant بتكتب
 * مستند بنوع 'admin_credit' في users/{userId}/walletTransactions). الدالة دي
 * بتكتب مستند في collection('notifications') عشان الراكب ياخد إشعار فوري،
 * وده هيشغّل onNewGeneralNotification تحت تلقائيًا ويبعت الـ Push الحقيقي -
 * مفيش أي تعديل مطلوب في لوحة الأدمن نفسها.
 *
 * ====== ⚠️ الدالة دي بقت غير مستخدمة (superseded) ======
 * محتاجة خطة Blaze عشان تتنشر. بديلها: Supabase Edge Function اسمها
 * general-notify (supabase/functions/general-notify/) - بتتنادى مباشرة
 * من لوحة الأدمن (submitWalletGrant في index.html) بعد نجاح الشحن، وبتعمل
 * الاتنين مع بعض (كتابة مستند notifications + بعت الـ push) في نداء واحد.
 */
exports.onWalletCredit = onDocumentCreated(
  "users/{userId}/walletTransactions/{transactionId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const txn = snap.data();
    // ====== بس شحن الأدمن اليدوي - أي نوع حركة محفظة تاني (خصم رحلة..إلخ)
    // مبيبعتش إشعار من هنا ======
    if (txn.type !== "admin_credit") return;

    const { userId } = event.params;
    const amount = txn.amount || 0;
    const balanceAfter = txn.balanceAfter || 0;
    const reason = txn.reason;

    const body = reason
      ? `تم إضافة ${amount} جنيه إلى محفظتك (${reason}). رصيدك الحالي: ${balanceAfter} جنيه.`
      : `تم إضافة ${amount} جنيه إلى محفظتك. رصيدك الحالي: ${balanceAfter} جنيه.`;

    await admin.firestore().collection("notifications").add({
      userId,
      title: "تم شحن محفظتك",
      body,
      type: "wallet",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    });

    console.log(`إشعار شحن محفظة اتكتب للمستخدم ${userId}`);
  }
);

// ====== ⚠️ الدالة دي بقت غير مستخدمة (superseded) ======
// نفس بديل onWalletCredit فوق - general-notify Edge Function دلوقتي هي
// اللي بتبعت الـ push مباشرة، مفيش حاجة تانية بتستنى الكتابة في
// collection('notifications') عشان تشغّل push (لأن Supabase مفيهوش
// Firestore triggers أصلًا).
/**
 * ====== 3) إشعار عام (طلب اتقبل / الطيار وصل / ... إلخ) ======
 * بتتفعّل تلقائيًا لما مستند جديد يتكتب في collection('notifications')
 * (نفس الـ collection اللي شاشة الإشعارات بتقرا منها بالفعل).
 * الحقول المتوقعة: userId, title, body
 */
exports.onNewGeneralNotification = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const notif = snap.data();
    const userId = notif.userId;
    const title = notif.title || "طيار";
    const body = notif.body || "";

    const token = await getFcmTokenForUser(userId);
    if (!token) {
      console.log(`مفيش fcmToken محفوظ للمستخدم ${userId}`);
      return;
    }

    try {
      await admin.messaging().send({
        token,
        notification: { title, body },
        data: {
          type: notif.type || "system",
        },
        android: {
          priority: "high",
          notification: { channelId: "tayar_chat_channel" },
        },
        apns: {
          payload: { aps: { sound: "default" } },
        },
      });
      console.log(`إشعار عام اتبعت للمستخدم ${userId}`);
    } catch (err) {
      console.error("فشل إرسال الإشعار العام:", err);
    }
  }
);

// ====================================================================
// ====== 4) إنشاء طلب رحلة (createOrder) - Callable Function ======
// ====================================================================
// المسؤولية: بدل ما الموبايل يكتب مباشرة في collection('orders') بالمسافة
// والسعر اللي حسبهم بنفسه (وممكن يتلاعب فيهم أي حد بيعدّل الـ APK)، الدالة
// دي هي المسؤولة الوحيدة عن الكتابة. بتاخد بس إحداثيات نقطة الانطلاق
// والوجهة، وبتحسب المسافة والسعر المقترح بنفسها من السيرفر، وبتتأكد إن
// السعر اللي الراكب حدده (proposedFare) في الحدود المنطقية قبل ما تكتب
// أي حاجة في Firestore.

/**
 * حساب المسافة بخط مستقيم (Haversine) - نفس منطق الـ fallback الموجود في
 * passenger_home.dart لو OSRM فشل أو رجّع خطأ.
 */
function haversineKm(lat1, lon1, lat2, lon2) {
  const toRad = (d) => (d * Math.PI) / 180;
  const R = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.asin(Math.sqrt(a));
}

/**
 * بتجيب المسافة والمدة الحقيقية من OSRM (نفس السيرفر اللي الموبايل
 * بيستخدمه)، ولو فشل بترجع لحساب خط مستقيم بمتوسط سرعة 30 كم/س - مطابق
 * تمامًا لمنطق _fetchRoute في passenger_home.dart.
 */
async function getRouteDistance(origin, destination) {
  try {
    const url =
      "https://router.project-osrm.org/route/v1/driving/" +
      `${origin.lng},${origin.lat};${destination.lng},${destination.lat}` +
      "?overview=false";
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 6000);
    const res = await fetch(url, { signal: controller.signal });
    clearTimeout(timeoutId);
    if (res.ok) {
      const json = await res.json();
      const route = json.routes && json.routes[0];
      if (route) {
        return {
          distanceKm: route.distance / 1000,
          durationMin: Math.ceil(route.duration / 60),
        };
      }
    }
  } catch (err) {
    console.warn("OSRM فشل، هنرجع لحساب خط مستقيم:", err.message);
  }
  const distanceKm = haversineKm(
    origin.lat,
    origin.lng,
    destination.lat,
    destination.lng
  );
  return { distanceKm, durationMin: Math.ceil((distanceKm / 30) * 60) };
}

// ====== معادلة السعر - لازم تفضل مطابقة بالظبط لـ _estimatedFare في
// passenger_home.dart (10 جنيه أساسي + 5 جنيه لكل كيلومتر). لو غيّرت
// المعادلة في الموبايل، غيّرها هنا كمان وإلا الطلبات هترفض بالغلط ======
function calculateSuggestedFare(distanceKm) {
  return 10 + 5 * distanceKm;
}

// ====== ⚠️ الدالة دي بقت غير مستخدمة (superseded) ======
// محتاجة خطة Blaze عشان تتنشر أصلًا. الموبايل بقى بينادي بديلها:
// Supabase Edge Function اسمها create-order (supabase/functions/create-order/)
// نفس المنطق بالظبط، بس شغالة من غير Blaze. سايبينها هنا كمرجع/خطة رجوع لو
// حبينا نرجع نستخدم Cloud Functions بعد ما Blaze تتفعل يومًا ما.
exports.createOrder = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError(
      "unauthenticated",
      "لازم تسجل الدخول الأول عشان تطلب رحلة"
    );
  }

  const data = request.data || {};
  const {
    pickupAddress,
    pickupLat,
    pickupLng,
    destinationAddress,
    destinationLat,
    destinationLng,
    proposedFare,
    autoAccept,
    paymentMethod,
    scheduledFor,
  } = data;

  if (
    typeof pickupLat !== "number" ||
    typeof pickupLng !== "number" ||
    typeof destinationLat !== "number" ||
    typeof destinationLng !== "number" ||
    typeof proposedFare !== "number" ||
    !pickupAddress ||
    !destinationAddress ||
    !paymentMethod
  ) {
    throw new HttpsError("invalid-argument", "بيانات الطلب ناقصة أو غير صحيحة");
  }

  // ====== حجز رحلة مقدمًا (Scheduled rides): scheduledFor اختياري - وقت
  // بالميلي ثانية (epoch ms) لأول ميعاد يبدأ الراكب يدوّر فيه على سائق.
  // لو موجود، لازم يكون في المستقبل (بحد أدنى 10 دقايق قدام عشان يديله
  // وقت حقيقي للمطابقة) ومش أبعد من الحد الأقصى المسموح به من الإعدادات
  // (settings/config.maxScheduleAdvanceDays، افتراضيًا 7 أيام) ======
  const db = admin.firestore();
  let scheduledForTimestamp = null;
  if (scheduledFor !== undefined && scheduledFor !== null) {
    if (typeof scheduledFor !== "number" || !Number.isFinite(scheduledFor)) {
      throw new HttpsError("invalid-argument", "ميعاد الرحلة المجدولة غير صحيح");
    }
    const now = Date.now();
    const minLeadMs = 10 * 60 * 1000;
    if (scheduledFor < now + minLeadMs) {
      throw new HttpsError(
        "invalid-argument",
        "ميعاد الرحلة المجدولة لازم يكون بعد 10 دقايق على الأقل من دلوقتي"
      );
    }
    let maxAdvanceDays = 7;
    try {
      const settingsSnap = await db.collection("settings").doc("config").get();
      const configured = settingsSnap.data()?.maxScheduleAdvanceDays;
      if (typeof configured === "number" && configured > 0) {
        maxAdvanceDays = configured;
      }
    } catch (err) {
      console.warn("تعذر قراءة maxScheduleAdvanceDays، هنستخدم القيمة الافتراضية:", err.message);
    }
    const maxAdvanceMs = maxAdvanceDays * 24 * 60 * 60 * 1000;
    if (scheduledFor > now + maxAdvanceMs) {
      throw new HttpsError(
        "invalid-argument",
        `مينفعش تحجز رحلة أبعد من ${maxAdvanceDays} أيام قدام`
      );
    }
    scheduledForTimestamp = admin.firestore.Timestamp.fromMillis(scheduledFor);
  }

  // ====== المسافة والسعر بيتحسبوا هنا بس - مش بنثق في أي رقم جاي من الموبايل ======
  const { distanceKm, durationMin } = await getRouteDistance(
    { lat: pickupLat, lng: pickupLng },
    { lat: destinationLat, lng: destinationLng }
  );
  const suggestedFare = calculateSuggestedFare(distanceKm);
  const minFare = Math.round(suggestedFare * 0.5);
  const maxFare = Math.round(suggestedFare * 3); // سقف أمان يمنع أرقام غير منطقية

  if (proposedFare < minFare - 0.01) {
    throw new HttpsError(
      "invalid-argument",
      `السعر المقترح (${proposedFare}) أقل من الحد الأدنى المسموح (${minFare})`
    );
  }
  if (proposedFare > maxFare) {
    throw new HttpsError(
      "invalid-argument",
      `السعر المقترح (${proposedFare}) أعلى من الحد المسموح`
    );
  }

  // ====== اسم ورقم الراكب من مصدر موثوق (Firestore / Auth token) - مش من
  // قيمة بتوصل من الموبايل عشان محدش يقدر ينتحل اسم حد تاني ======
  let customerName = "راكب طيار";
  try {
    const userDoc = await db.collection("users").doc(uid).get();
    const personalInfo = userDoc.data()?.personalInfo;
    const fullName = [personalInfo?.firstName, personalInfo?.lastName]
      .filter((s) => s && String(s).trim())
      .join(" ");
    if (fullName) {
      customerName = fullName;
    } else if (request.auth.token.name) {
      customerName = request.auth.token.name;
    }
  } catch (err) {
    console.warn("تعذر جلب اسم الراكب:", err.message);
  }
  const customerPhone = request.auth.token.phone_number || null;

  const orderRef = await db.collection("orders").add({
    customerId: uid,
    customerName,
    customerPhone,
    pickupAddress,
    pickupLocation: new admin.firestore.GeoPoint(pickupLat, pickupLng),
    destinationAddress,
    destinationLocation: new admin.firestore.GeoPoint(
      destinationLat,
      destinationLng
    ),
    distanceKm,
    durationMin,
    suggestedFare,
    proposedFare,
    // ====== ثابتة من لحظة الإنشاء ومتتغيرش تاني، عكس proposedFare اللي
    // بتتحدث كل مرة الراكب أو السائق يغيّر السعر أثناء المفاوضة. دي
    // المرجع اللي بيتحسب عليه حد أقصى/أدنى المفاوضة في الموبايل (شوف
    // fare_negotiation_rules.dart) - لازم تتطابق مع نفس الحقل اللي
    // بيتكتب في create_delivery_order_screen.dart ======
    initialFare: proposedFare,
    autoAccept: autoAccept === true,
    paymentMethod,
    serviceType: "passenger",
    // ====== orderType بيفرّق بين طلب فوري وطلب محجوز مقدمًا فقط لغرض
    // العرض/الترتيب في واجهة السائق - المطابقة نفسها (عرض/قبول) شغالة
    // فورًا على الطلبين زي بعض من لحظة الإنشاء، مفيش انتظار لحد الميعاد ======
    orderType: scheduledForTimestamp ? "scheduled" : "instant",
    scheduledFor: scheduledForTimestamp,
    status: "searching",
    driverId: null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    orderId: orderRef.id,
    distanceKm,
    durationMin,
    suggestedFare,
    minFare,
    orderType: scheduledForTimestamp ? "scheduled" : "instant",
  };
});

// ====================================================================
// ====== 5) تنبيه زرار الطوارئ (SOS) - إشعار فوري للأدمن ======
// ====================================================================
// المسؤولية: بمجرد ما راكب أو طيار يدوس زرار الطوارئ (SosService.triggerAlert
// في sos_service.dart بيكتب مستند جديد في sos_alerts)، الدالة دي بتشتغل
// فورًا وتحاول توصل تنبيه للأدمن بطريقتين، سواء كانت لوحة التحكم مفتوحة
// قدامه دلوقتي أو لأ:
//   أ) SMS لأرقام الأدمن المسجّلة في لوحة التحكم (تاب Settings -> SOS admin
//      phone numbers، محفوظة في settings/config.sosAdminPhones)
//   ب) Push Notification (FCM) لأي أدمن عنده fcmToken مسجّل (مثلاً لو
//      بيستخدم تطبيق الموبايل نفسه بحساب أدمن)
//
// ====== SMS: محتاج ربط فعلي بمزوّد SMS ======
// الدالة دي مبنية على إنها تنادي sendSmsViaProvider لكل رقم، لكن الدالة
// دي حاليًا مجرد placeholder بتسجّل log بس - لسه محتاجة ربط فعلي بأي
// مزوّد SMS (زي SMS Misr, Msegat, 4jawaly, Twilio... إلخ) عن طريق إضافة
// الـ API key بتاعه كـ Secret (firebase functions:secrets:set) واستدعاء
// الـ REST endpoint بتاعه هنا. من غير الربط ده، التنبيه هيتسجل في
// Firestore وهيظهر في تاب SOS Alerts في اللحظة نفسها (زي ما هو شغال
// دلوقتي بالفعل)، لكن مفيش SMS/Push هيتبعت فعليًا لحد ما يتم الربط.
const { defineSecret } = require("firebase-functions/params");
const smsApiKey = defineSecret("SMS_API_KEY");

/**
 * ====== Placeholder لإرسال SMS - محتاج استبداله بالنداء الفعلي لمزوّد
 * الـ SMS اللي هيتم اختياره. اتركها زي ما هي دلوقتي (بترجع false بس
 * وتسجل log) لحد ما يتحدد المزوّد والـ API key. ======
 */
async function sendSmsViaProvider(phone, message) {
  const apiKey = smsApiKey.value();
  if (!apiKey) {
    console.warn(
      `SMS_API_KEY مش متسجّل - مفيش SMS هيتبعت لـ ${phone}. ` +
        "محتاج تحدد مزوّد SMS وتسجّل الـ API key بتاعه كـ secret."
    );
    return false;
  }
  // ====== TODO: استبدل السطور دي بالنداء الفعلي لمزوّد الـ SMS المختار.
  // مثال عام (هيختلف شكل الـ request/response حسب المزوّد الفعلي):
  //
  // const res = await fetch("https://api.<provider>.com/v1/sms/send", {
  //   method: "POST",
  //   headers: {
  //     "Authorization": `Bearer ${apiKey}`,
  //     "Content-Type": "application/json",
  //   },
  //   body: JSON.stringify({ to: phone, text: message, sender: "Tayar" }),
  // });
  // return res.ok;
  console.warn(
    `sendSmsViaProvider: مزوّد الـ SMS لسه مش متربط فعليًا (${phone})`
  );
  return false;
}

/**
 * بيدور على كل الأدمنز اللي عندهم fcmToken مسجّل ويبعتلهم Push مباشرة.
 */
async function sendPushToAllAdmins(title, body, data) {
  const db = admin.firestore();
  const adminsSnap = await db.collection("admin").get();
  const tokens = adminsSnap.docs
    .map((d) => d.data().fcmToken)
    .filter(Boolean);

  if (tokens.length === 0) {
    console.log("مفيش أي أدمن عنده fcmToken مسجّل - مفيش Push هيتبعت");
    return;
  }

  try {
    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data,
      android: {
        priority: "high",
        notification: { channelId: "tayar_chat_channel", sound: "default" },
      },
      apns: { payload: { aps: { sound: "default" } } },
    });
    console.log(`Push تنبيه SOS اتبعت لـ ${tokens.length} أدمن`);
  } catch (err) {
    console.error("فشل إرسال Push تنبيه SOS:", err);
  }
}

exports.onSosAlertCreated = onDocumentCreated(
  { document: "sos_alerts/{alertId}", secrets: [smsApiKey] },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const alert = snap.data();
    const roleLabel = alert.userRole === "driver" ? "طيار" : "راكب";
    const name = alert.userName || "مستخدم";
    const phone = alert.userPhone || "بدون رقم";
    const mapsLink = alert.location
      ? `https://maps.google.com/?q=${alert.location.latitude},${alert.location.longitude}`
      : null;

    const message =
      `🚨 تنبيه طوارئ من ${roleLabel}: ${name} (${phone})` +
      (mapsLink ? ` - الموقع: ${mapsLink}` : " - الموقع مش متاح");

    const db = admin.firestore();
    const settingsDoc = await db.collection("settings").doc("config").get();
    const sosAdminPhones = settingsDoc.data()?.sosAdminPhones || [];

    await Promise.all([
      ...sosAdminPhones.map((p) => sendSmsViaProvider(p, message)),
      sendPushToAllAdmins("🚨 تنبيه طوارئ SOS", message, {
        type: "sos_alert",
        alertId: event.params.alertId,
      }),
    ]);
  }
);