// ====== Edge Function: create-order ======
// بديل كامل لـ Cloud Function اسمها createOrder (كانت في functions/index.js)
// اللي محتاجة خطة Blaze في Firebase عشان تتنشر. المنطق هنا نفسه بالظبط
// (المسافة/السعر بيتحسبوا من السيرفر مش من الموبايل، عشان محدش يقدر
// يتلاعب بالسعر)، بس بيشتغل هنا على Supabase (مجاني بالكامل) بدل Firebase
// Cloud Functions.
//
// بتتنادى مباشرة من order_confirmation_screen.dart بدل
// FirebaseFunctions.instance.httpsCallable('createOrder').
//
// الأمان: هيدر Authorization هنا محجوز لـ Supabase نفسها (anon key -
// مطلوب من الـ Gateway بتاعها عشان تسمح بنداء الدالة أصلًا، نفس نمط
// sos_service.dart بالظبط). التوكن الحقيقي اللي بيثبت هوية المستخدم
// (Firebase ID Token) بيتبعت في هيدر مخصوص X-Firebase-Id-Token، والدالة
// دي بتتحقق منه (verifyFirebaseIdToken) قبل ما تعمل أي حاجة - يعني نفس
// مستوى الثقة اللي كان متاح جوه request.auth في Cloud Functions. الكتابة
// في Firestore بتتم بصلاحيات Service Account (FirestoreClient) اللي
// بتتجاوز firestore.rules تمامًا (نفس سلوك Admin SDK) - وده مهم لأن
// firestore.rules أصلاً بتمنع أي كتابة مباشرة من الموبايل على
// collection('orders') (allow create: if false) عشان تفرض إن كل طلب
// لازم يعدي من هنا.

import {
  FirestoreClient,
  verifyFirebaseIdToken,
} from "../_shared/firebase-admin.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

/** خطأ بمعنى واضح للمستخدم - بيترجم لرسالة SnackBar في الموبايل */
class OrderError extends Error {
  status: number;
  constructor(message: string, status = 400) {
    super(message);
    this.status = status;
  }
}

/** حساب المسافة بخط مستقيم (Haversine) - fallback لو OSRM فشل، مطابق
 * لمنطق passenger_home.dart و functions/index.js الأصلية. */
function haversineKm(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
): number {
  const toRad = (d: number) => (d * Math.PI) / 180;
  const R = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.asin(Math.sqrt(a));
}

async function getRouteDistance(
  origin: { lat: number; lng: number },
  destination: { lat: number; lng: number },
): Promise<{ distanceKm: number; durationMin: number }> {
  try {
    const url = "https://router.project-osrm.org/route/v1/driving/" +
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
    console.warn("OSRM فشل، هنرجع لحساب خط مستقيم:", err);
  }
  const distanceKm = haversineKm(
    origin.lat,
    origin.lng,
    destination.lat,
    destination.lng,
  );
  return { distanceKm, durationMin: Math.ceil((distanceKm / 30) * 60) };
}

// ====== لازم تفضل مطابقة بالظبط لـ _estimatedFare في passenger_home.dart
// (10 جنيه أساسي + 5 جنيه لكل كم). لو اتغيرت في الموبايل، غيّرها هنا كمان.
function calculateSuggestedFare(distanceKm: number): number {
  return 10 + 5 * distanceKm;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const idToken = req.headers.get("X-Firebase-Id-Token") ?? "";
    if (!idToken) {
      throw new OrderError("لازم تسجل الدخول الأول عشان تطلب رحلة", 401);
    }
    const user = await verifyFirebaseIdToken(idToken).catch(() => {
      throw new OrderError("جلسة الدخول غير صالحة، سجّل دخول تاني", 401);
    });

    const body = await req.json();
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
    } = body ?? {};

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
      throw new OrderError("بيانات الطلب ناقصة أو غير صحيحة");
    }

    const db = new FirestoreClient();

    // ====== حجز رحلة مقدمًا (Scheduled rides) - نفس حدود الفاليديشن
    // اللي كانت في Cloud Function الأصلية بالظبط ======
    let scheduledForDate: Date | null = null;
    if (scheduledFor !== undefined && scheduledFor !== null) {
      if (typeof scheduledFor !== "number" || !Number.isFinite(scheduledFor)) {
        throw new OrderError("ميعاد الرحلة المجدولة غير صحيح");
      }
      const now = Date.now();
      const minLeadMs = 10 * 60 * 1000;
      if (scheduledFor < now + minLeadMs) {
        throw new OrderError(
          "ميعاد الرحلة المجدولة لازم يكون بعد 10 دقايق على الأقل من دلوقتي",
        );
      }
      let maxAdvanceDays = 7;
      try {
        const settings = await db.get("settings/config");
        const configured = settings?.maxScheduleAdvanceDays;
        if (typeof configured === "number" && configured > 0) {
          maxAdvanceDays = configured;
        }
      } catch (err) {
        console.warn("تعذر قراءة maxScheduleAdvanceDays:", err);
      }
      const maxAdvanceMs = maxAdvanceDays * 24 * 60 * 60 * 1000;
      if (scheduledFor > now + maxAdvanceMs) {
        throw new OrderError(
          `مينفعش تحجز رحلة أبعد من ${maxAdvanceDays} أيام قدام`,
        );
      }
      scheduledForDate = new Date(scheduledFor);
    }

    // ====== المسافة والسعر بيتحسبوا هنا بس - مش بنثق في أي رقم جاي من
    // الموبايل ======
    const { distanceKm, durationMin } = await getRouteDistance(
      { lat: pickupLat, lng: pickupLng },
      { lat: destinationLat, lng: destinationLng },
    );
    const suggestedFare = calculateSuggestedFare(distanceKm);
    const minFare = Math.round(suggestedFare * 0.5);
    const maxFare = Math.round(suggestedFare * 3);

    if (proposedFare < minFare - 0.01) {
      throw new OrderError(
        `السعر المقترح (${proposedFare}) أقل من الحد الأدنى المسموح (${minFare})`,
      );
    }
    if (proposedFare > maxFare) {
      throw new OrderError(`السعر المقترح (${proposedFare}) أعلى من الحد المسموح`);
    }

    // ====== اسم ورقم الراكب من مصدر موثوق (Firestore / التوكن) - مش من
    // قيمة بتوصل من الموبايل ======
    let customerName = "راكب طيار";
    try {
      const userDoc = await db.get(`users/${user.uid}`);
      const personalInfo = userDoc?.personalInfo as
        | Record<string, unknown>
        | undefined;
      const fullName = [personalInfo?.firstName, personalInfo?.lastName]
        .filter((s) => s && String(s).trim())
        .join(" ");
      if (fullName) {
        customerName = fullName;
      } else if (user.name) {
        customerName = user.name;
      }
    } catch (err) {
      console.warn("تعذر جلب اسم الراكب:", err);
    }

    const orderType = scheduledForDate ? "scheduled" : "instant";
    const orderId = await db.create("orders", {
      customerId: user.uid,
      customerName,
      customerPhone: user.phoneNumber,
      pickupAddress,
      pickupLocation: { latitude: pickupLat, longitude: pickupLng },
      destinationAddress,
      destinationLocation: { latitude: destinationLat, longitude: destinationLng },
      distanceKm,
      durationMin,
      suggestedFare,
      proposedFare,
      initialFare: proposedFare,
      autoAccept: autoAccept === true,
      paymentMethod,
      serviceType: "passenger",
      orderType,
      scheduledFor: scheduledForDate,
      status: "searching",
      driverId: null,
      createdAt: new Date(),
    });

    return jsonResponse({
      orderId,
      distanceKm,
      durationMin,
      suggestedFare,
      minFare,
      orderType,
    });
  } catch (err) {
    if (err instanceof OrderError) {
      return jsonResponse({ error: err.message }, err.status);
    }
    console.error("create-order فشلت:", err);
    return jsonResponse({ error: "حصل خطأ غير متوقع، حاول تاني" }, 500);
  }
});
