// ====== وحدة مشتركة: بديل خفيف لـ Firebase Admin SDK داخل Supabase Edge
// Functions (Deno) ======
//
// السبب: Firebase Admin SDK الرسمي مبني لـ Node.js ومش شغال جوه بيئة Deno
// بتاعة Supabase. بدل كده، الوحدة دي بتعمل نفس الحاجتين اللي محتاجينهم
// بس، عن طريق REST APIs مباشرة:
//
//   1) verifyFirebaseIdToken(idToken): تتأكد إن التوكن اللي جاي من
//      الموبايل (Flutter، FirebaseAuth.instance.currentUser.getIdToken())
//      حقيقي وموقّع من Google فعلاً ومش منتهي، وترجع بيانات المستخدم
//      (uid, phone_number, name) - بنفس الثقة اللي كانت متاحة جوه
//      request.auth في Cloud Functions.
//
//   2) FirestoreClient: بيتصرف بنفس صلاحيات Admin SDK (بيتجاوز
//      firestore.rules تمامًا) عن طريق توليد Google OAuth2 access token
//      من Service Account، وبعدين ينادي Firestore REST API مباشرة.
//
// الاعتماديات: بنستخدم مكتبة "jose" (JWT/JWK) عن طريق esm.sh - Deno
// بيدعم استيراد مباشر من URL من غير npm install.
//
// الـ Secrets المطلوب تسجيلها في Supabase (Project Settings -> Edge
// Functions -> Secrets)، من ملف Service Account JSON اللي بينزل من
// Firebase Console (Project Settings -> Service Accounts -> Generate
// new private key):
//   FIREBASE_PROJECT_ID     = project_id
//   FIREBASE_CLIENT_EMAIL   = client_email
//   FIREBASE_PRIVATE_KEY    = private_key (النص كامل، شامل
//                             -----BEGIN PRIVATE KEY----- و-----END...)

import * as jose from "https://esm.sh/jose@5";

const PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID") ?? "";
const CLIENT_EMAIL = Deno.env.get("FIREBASE_CLIENT_EMAIL") ?? "";
// بعض طرق تسجيل الـ secrets بتحول "\n" الحرفية لسطر جديد فعلي وبعضها لأ -
// بنطبع الاتنين عشان نضمن إن المفتاح يتقرا صح مهما كانت طريقة التسجيل.
const PRIVATE_KEY = (Deno.env.get("FIREBASE_PRIVATE_KEY") ?? "").replace(
  /\\n/g,
  "\n",
);

const FIRESTORE_BASE =
  `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

// ====== 1) التحقق من Firebase ID Token ======

const firebaseJwks = jose.createRemoteJWKSet(
  new URL(
    "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com",
  ),
);

export interface VerifiedFirebaseUser {
  uid: string;
  phoneNumber: string | null;
  name: string | null;
}

/**
 * بتتحقق من صحة وتوقيع وصلاحية Firebase ID Token، وترجع بيانات المستخدم
 * الموثوقة منه. بترمي Error لو التوكن مزوّر/منتهي/من مشروع تاني.
 */
export async function verifyFirebaseIdToken(
  idToken: string,
): Promise<VerifiedFirebaseUser> {
  if (!PROJECT_ID) {
    throw new Error("FIREBASE_PROJECT_ID secret مش متسجل");
  }
  const { payload } = await jose.jwtVerify(idToken, firebaseJwks, {
    issuer: `https://securetoken.google.com/${PROJECT_ID}`,
    audience: PROJECT_ID,
  });
  const uid = (payload.sub as string) || (payload.user_id as string);
  if (!uid) {
    throw new Error("توكن غير صالح: مفيش uid");
  }
  return {
    uid,
    phoneNumber: (payload.phone_number as string) ?? null,
    name: (payload.name as string) ?? null,
  };
}

// ====== 2) عميل Firestore REST API (بصلاحيات Service Account) ======

let cachedAccessToken: { token: string; expiresAt: number } | null = null;

// ====== النطاقين مع بعض في نفس التوكن: datastore (Firestore) و
// firebase.messaging (بعت FCM push). أسهل من إدارة كاش منفصل لكل نطاق،
// وGoogle بتسمح بأكتر من scope في نفس access token عادي. ======
const GOOGLE_SCOPES =
  "https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/firebase.messaging";

async function getGoogleAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedAccessToken && cachedAccessToken.expiresAt - 60 > now) {
    return cachedAccessToken.token;
  }
  if (!CLIENT_EMAIL || !PRIVATE_KEY) {
    throw new Error(
      "FIREBASE_CLIENT_EMAIL أو FIREBASE_PRIVATE_KEY مش متسجلين",
    );
  }

  const privateKey = await jose.importPKCS8(PRIVATE_KEY, "RS256");
  const assertion = await new jose.SignJWT({
    scope: GOOGLE_SCOPES,
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(CLIENT_EMAIL)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(privateKey);

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!res.ok) {
    throw new Error(`فشل الحصول على Google access token: ${await res.text()}`);
  }
  const json = await res.json();
  cachedAccessToken = {
    token: json.access_token,
    expiresAt: now + (json.expires_in ?? 3600),
  };
  return cachedAccessToken.token;
}

// ====== تحويل بين JS values و Firestore REST "Value" format ======
// راجع: https://firebase.google.com/docs/firestore/reference/rest/v1/Value

// deno-lint-ignore no-explicit-any
export function toFirestoreValue(value: any): any {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number") {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (value instanceof Date) {
    return { timestampValue: value.toISOString() };
  }
  if (
    typeof value === "object" && "latitude" in value && "longitude" in value
  ) {
    return {
      geoPointValue: { latitude: value.latitude, longitude: value.longitude },
    };
  }
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(toFirestoreValue) } };
  }
  if (typeof value === "object") {
    return { mapValue: { fields: toFirestoreFields(value) } };
  }
  throw new Error(`نوع بيانات غير مدعوم: ${typeof value}`);
}

export function toFirestoreFields(
  // deno-lint-ignore no-explicit-any
  obj: Record<string, any>,
  // deno-lint-ignore no-explicit-any
): Record<string, any> {
  const fields: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(obj)) {
    if (value === undefined) continue; // نتجاهل الحقول undefined زي JS العادي
    fields[key] = toFirestoreValue(value);
  }
  return fields;
}

// deno-lint-ignore no-explicit-any
export function fromFirestoreValue(value: any): any {
  if (!value) return null;
  if ("stringValue" in value) return value.stringValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return value.doubleValue;
  if ("booleanValue" in value) return value.booleanValue;
  if ("nullValue" in value) return null;
  if ("timestampValue" in value) return new Date(value.timestampValue);
  if ("geoPointValue" in value) return value.geoPointValue;
  if ("arrayValue" in value) {
    return (value.arrayValue.values ?? []).map(fromFirestoreValue);
  }
  if ("mapValue" in value) return fromFirestoreFields(value.mapValue.fields ?? {});
  return null;
}

export function fromFirestoreFields(
  // deno-lint-ignore no-explicit-any
  fields: Record<string, any>,
  // deno-lint-ignore no-explicit-any
): Record<string, any> {
  const obj: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(fields ?? {})) {
    obj[key] = fromFirestoreValue(value);
  }
  return obj;
}

export class FirestoreClient {
  /** بيرجع مستند واحد، أو null لو مش موجود. path مثلاً: "users/abc123" */
  async get(path: string): Promise<Record<string, unknown> | null> {
    const token = await getGoogleAccessToken();
    const res = await fetch(`${FIRESTORE_BASE}/${path}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (res.status === 404) return null;
    if (!res.ok) {
      throw new Error(`Firestore get فشل (${res.status}): ${await res.text()}`);
    }
    const json = await res.json();
    return fromFirestoreFields(json.fields ?? {});
  }

  /**
   * بينشئ مستند جديد بـ id عشوائي جوه collection معينة، ويرجع الـ id بتاعه.
   * collectionPath مثلاً: "orders"
   */
  async create(
    collectionPath: string,
    // deno-lint-ignore no-explicit-any
    data: Record<string, any>,
  ): Promise<string> {
    const token = await getGoogleAccessToken();
    const res = await fetch(`${FIRESTORE_BASE}/${collectionPath}`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ fields: toFirestoreFields(data) }),
    });
    if (!res.ok) {
      throw new Error(
        `Firestore create فشل (${res.status}): ${await res.text()}`,
      );
    }
    const json = await res.json();
    // json.name شكله: projects/{p}/databases/(default)/documents/orders/{id}
    const parts = String(json.name).split("/");
    return parts[parts.length - 1];
  }

  /**
   * بيبحث في collection معينة بشروط equality/range/in بسيطة (structured
   * query عن طريق Firestore REST :runQuery). محتاجينها عشان
   * scheduled-ride-reminder تدور على الرحلات المجدولة القريبة الميعاد.
   * ملحوظة: أي تركيبة equality + IN + range هتحتاج على الأغلب composite
   * index في Firestore أول مرة تتنادى - Firestore بترجع خطأ فيه رابط
   * لإنشائه بضغطة واحدة من الكونسول، ده طبيعي ومتوقع لأي query جديدة. */
  async query(
    collectionId: string,
    filters: Array<{ field: string; op: string; value: unknown }>,
    options?: { limit?: number },
  ): Promise<Array<{ id: string; data: Record<string, unknown> }>> {
    const token = await getGoogleAccessToken();
    // deno-lint-ignore no-explicit-any
    const structuredQuery: Record<string, any> = {
      from: [{ collectionId }],
      where: {
        compositeFilter: {
          op: "AND",
          filters: filters.map((f) => ({
            fieldFilter: {
              field: { fieldPath: f.field },
              op: f.op,
              value: toFirestoreValue(f.value),
            },
          })),
        },
      },
    };
    if (options?.limit) structuredQuery.limit = options.limit;

    const res = await fetch(`${FIRESTORE_BASE}:runQuery`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ structuredQuery }),
    });
    if (!res.ok) {
      throw new Error(
        `Firestore query فشل (${res.status}): ${await res.text()}`,
      );
    }
    const json = await res.json();
    const results: Array<{ id: string; data: Record<string, unknown> }> = [];
    for (const item of json as Array<{ document?: { name: string; fields?: unknown } }>) {
      if (!item.document) continue;
      const parts = String(item.document.name).split("/");
      results.push({
        id: parts[parts.length - 1],
        // deno-lint-ignore no-explicit-any
        data: fromFirestoreFields((item.document.fields as any) ?? {}),
      });
    }
    return results;
  }

  /** بيمسح مستند. مش بترمي خطأ لو أصلاً مش موجود (404) - نفس سلوك
   * .delete() العادي في Admin SDK. path مثلاً: "drivers/abc123" */
  async delete(path: string): Promise<void> {
    const token = await getGoogleAccessToken();
    const res = await fetch(`${FIRESTORE_BASE}/${path}`, {
      method: "DELETE",
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!res.ok && res.status !== 404) {
      throw new Error(
        `Firestore delete فشل (${res.status}): ${await res.text()}`,
      );
    }
  }

  /**
   * بيعمل كذا عملية (merge على مستند / delete لمستند) في نداء واحد
   * ذرّي (atomic) - يا كلهم بينفذوا يا مفيش حاجة بتتنفذ خالص. عن طريق
   * Firestore REST :batchWrite. محتاجينها عشان عمليات زي "انقل بيانات
   * من مستند قديم لمستند جديد وامسح القديم" من غير ما نسيب حالة
   * نصفانية لو حصل خطأ في النص. ملحوظة: "merge" هنا بتحدث الحقول
   * المذكورة بس (زي SetOptions(merge:true))، مش بتمسح باقي حقول
   * المستند اللي مش مذكورة.
   */
  async batchWrite(
    writes: Array<
      | { type: "merge"; path: string; data: Record<string, unknown> }
      | { type: "delete"; path: string }
    >,
  ): Promise<void> {
    const token = await getGoogleAccessToken();
    const body = {
      writes: writes.map((w) => {
        const name =
          `projects/${PROJECT_ID}/databases/(default)/documents/${w.path}`;
        if (w.type === "delete") {
          return { delete: name };
        }
        return {
          update: { name, fields: toFirestoreFields(w.data) },
          updateMask: { fieldPaths: Object.keys(w.data) },
        };
      }),
    };
    const res = await fetch(`${FIRESTORE_BASE}:batchWrite`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });
    if (!res.ok) {
      throw new Error(
        `Firestore batchWrite فشل (${res.status}): ${await res.text()}`,
      );
    }
  }

  /**
   * بيعدّل حقول محددة بس في مستند موجود (زي .update() في Admin SDK)،
   * من غير ما يمسح باقي الحقول اللي مش مذكورة (عن طريق updateMask).
   * path مثلاً: "orders/abc123"
   */
  async update(
    path: string,
    // deno-lint-ignore no-explicit-any
    data: Record<string, any>,
  ): Promise<void> {
    const token = await getGoogleAccessToken();
    const maskParams = Object.keys(data)
      .map((f) => `updateMask.fieldPaths=${encodeURIComponent(f)}`)
      .join("&");
    const res = await fetch(`${FIRESTORE_BASE}/${path}?${maskParams}`, {
      method: "PATCH",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ fields: toFirestoreFields(data) }),
    });
    if (!res.ok) {
      throw new Error(
        `Firestore update فشل (${res.status}): ${await res.text()}`,
      );
    }
  }
}

// ====== 3) إرسال Push Notification عن طريق FCM HTTP v1 API ======
// (بديل admin.messaging().send() اللي كان متاح في Cloud Functions - هنا
// بننادي REST API مباشرة بنفس Service Account، بنفس النطاق اللي فوق)

export interface FcmPushOptions {
  token: string;
  title: string;
  body: string;
  data?: Record<string, string>;
  /** channelId لأندرويد - افتراضيًا نفس القناة المستخدمة في التطبيق فعلاً */
  androidChannelId?: string;
}

/**
 * بتبعت push notification لجهاز واحد عن طريق FCM HTTP v1 API. بترجع true
 * لو نجحت، وبتطبع تحذير وترجع false لو فشلت (زي ما كانت الدوال القديمة
 * بتعمل try/catch وتكمل من غير ما توقف كل حاجة).
 */
export async function sendFcmPush(options: FcmPushOptions): Promise<boolean> {
  if (!PROJECT_ID) {
    throw new Error("FIREBASE_PROJECT_ID secret مش متسجل");
  }
  try {
    const token = await getGoogleAccessToken();
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${PROJECT_ID}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token: options.token,
            notification: {
              title: options.title,
              body: options.body,
            },
            data: options.data ?? {},
            android: {
              priority: "high",
              notification: {
                channel_id: options.androidChannelId ?? "tayar_chat_channel",
              },
            },
            apns: {
              payload: { aps: { sound: "default" } },
            },
          },
        }),
      },
    );
    if (!res.ok) {
      console.warn(`FCM send فشل (${res.status}): ${await res.text()}`);
      return false;
    }
    return true;
  } catch (err) {
    console.warn("FCM send استثناء:", err);
    return false;
  }
}

/**
 * بتدور على fcmToken بتاع مستخدم معين، سواء كان راكب (users) أو كابتن
 * (drivers)، من غير ما تحتاج تعرف نوعه مقدمًا - مطابقة لمنطق
 * getFcmTokenForUser في functions/index.js القديمة.
 */
export async function getFcmTokenForUser(
  db: FirestoreClient,
  uid: string,
): Promise<string | null> {
  if (!uid) return null;
  const usersDoc = await db.get(`users/${uid}`);
  if (usersDoc?.fcmToken) return usersDoc.fcmToken as string;
  const driversDoc = await db.get(`drivers/${uid}`);
  if (driversDoc?.fcmToken) return driversDoc.fcmToken as string;
  return null;
}
