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
 * ====== 2) إشعار عام (طلب اتقبل / الطيار وصل / ... إلخ) ======
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
// ====== 3) إنشاء طلب رحلة (createOrder) - Callable Function ======
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
  const db = admin.firestore();
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
    autoAccept: autoAccept === true,
    paymentMethod,
    serviceType: "passenger",
    status: "searching",
    driverId: null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { orderId: orderRef.id, distanceKm, durationMin, suggestedFare, minFare };
});