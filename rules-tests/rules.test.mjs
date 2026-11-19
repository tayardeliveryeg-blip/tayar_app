// rules-tests/rules.test.mjs
// التشغيل (من root المشروع):
//   firebase emulators:exec --only firestore --project demo-tayar "cd rules-tests && node rules.test.mjs"
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  doc,
  setDoc,
  updateDoc,
  writeBatch,
  serverTimestamp,
  Timestamp,
} from 'firebase/firestore';
import fs from 'fs';

const env = await initializeTestEnvironment({
  projectId: 'demo-tayar',
  firestore: {
    rules: fs.readFileSync('../firestore.rules', 'utf8'),
    host: '127.0.0.1',
    port: 8080,
  },
});

let failures = 0;
async function expect(name, promise, shouldSucceed) {
  try {
    if (shouldSucceed) await assertSucceeds(promise);
    else await assertFails(promise);
    console.log('PASS:', name);
  } catch (e) {
    failures++;
    console.log('FAIL:', name, '->', String(e.message).split('\n')[0]);
  }
}
const as = (uid) => env.authenticatedContext(uid).firestore();

// ------------------------------------------------------------------ seed
await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'admin/super1'), { role: 'super_admin' });
  await setDoc(doc(db, 'admin/fin1'), { role: 'finance' });
  await setDoc(doc(db, 'admin/sup1'), { role: 'support' });

  await setDoc(doc(db, 'settings/config'), {
    cancellationFeeAmount: 10,
    freeCancellationWindowMinutes: 3,
    referralWelcomeBonus: 20,
  });

  for (const u of ['u1', 'u2', 'u3']) {
    await setDoc(doc(db, `users/${u}`), { walletBalance: 0, status: 'active' });
  }
  await setDoc(doc(db, 'promo_codes/WELCOME50'), {
    active: true, usedCount: 0, maxUses: 100, discountValue: 50,
  });

  await setDoc(doc(db, 'drivers/d1'), { status: 'approved', walletBalance: 100 });
  await setDoc(doc(db, 'drivers/d2'), { status: 'pending_review', walletBalance: 0 });

  // طلبات
  await setDoc(doc(db, 'orders/o1'), { customerId: 'u1', status: 'searching', initialFare: 100 });
  await setDoc(doc(db, 'orders/o2'), { customerId: 'u1', status: 'accepted', driverId: 'd1', initialFare: 100 });
  await setDoc(doc(db, 'orders/o3'), { customerId: 'u1', status: 'searching', initialFare: 100 });
  await setDoc(doc(db, 'orders/o3/offers/off1'), { driverId: 'd1', price: 100 });
  await setDoc(doc(db, 'orders/o4'), { customerId: 'u1', driverId: 'd1', status: 'completed', initialFare: 100 });
  await setDoc(doc(db, 'orders/o5'), { customerId: 'u1', driverId: 'd1', status: 'accepted', initialFare: 100 });
});

// ============================================================ 1) promo
console.log('\n--- promo codes ---');
await expect(
  'wallet-only promo exploit blocked',
  updateDoc(doc(as('u1'), 'users/u1'), { walletBalance: 50, walletLastPromoCode: 'WELCOME50' }),
  false
);
await expect(
  'forged promo_credit ledger line (no balance change) blocked',
  setDoc(doc(as('u3'), 'users/u3/walletTransactions/fake1'), {
    type: 'promo_credit', amount: 999, promoCode: 'WELCOME50',
  }),
  false
);
{
  const db = as('u2');
  const b = writeBatch(db);
  b.update(doc(db, 'users/u2'), { walletBalance: 50, walletLastPromoCode: 'WELCOME50' });
  b.set(doc(db, 'users/u2/redeemedPromoCodes/WELCOME50'), { discountValue: 50 });
  b.update(doc(db, 'promo_codes/WELCOME50'), { usedCount: 1 });
  b.set(doc(db, 'users/u2/walletTransactions/l1'), {
    type: 'promo_credit', amount: 50, promoCode: 'WELCOME50', balanceAfter: 50,
  });
  await expect('legit promo redeem batch (with ledger) works', b.commit(), true);
}
await expect(
  'promo replay (wallet only) blocked',
  updateDoc(doc(as('u2'), 'users/u2'), { walletBalance: 100, walletLastPromoCode: 'WELCOME50' }),
  false
);
{
  const db = as('u2');
  const b = writeBatch(db);
  b.update(doc(db, 'users/u2'), { walletBalance: 100, walletLastPromoCode: 'WELCOME50' });
  b.set(doc(db, 'users/u2/redeemedPromoCodes/WELCOME50'), { discountValue: 50 });
  b.update(doc(db, 'promo_codes/WELCOME50'), { usedCount: 2 });
  await expect('promo double redeem batch blocked', b.commit(), false);
}

// ======================================================= 2) create w/ balance
console.log('\n--- create with balance ---');
await expect('users create with walletBalance 100000 blocked',
  setDoc(doc(as('nu1'), 'users/nu1'), { walletBalance: 100000 }), false);
await expect('users create normal profile works',
  setDoc(doc(as('nu2'), 'users/nu2'), { name: 'Ali', walletBalance: 0 }), true);
await expect('drivers create with walletBalance 100000 blocked',
  setDoc(doc(as('nd1'), 'drivers/nd1'), { walletBalance: 100000 }), false);
await expect('drivers create with status approved blocked',
  setDoc(doc(as('nd2'), 'drivers/nd2'), { status: 'approved' }), false);
await expect('drivers create normal works',
  setDoc(doc(as('nd3'), 'drivers/nd3'), { name: 'Omar', status: 'pending_review' }), true);

// ================================================== 3) users status/profile
console.log('\n--- users self update ---');
await expect('user cannot change own status',
  updateDoc(doc(as('u1'), 'users/u1'), { status: 'vip' }), false);
await expect('user can update normal profile field',
  updateDoc(doc(as('u1'), 'users/u1'), { name: 'Ali' }), true);

// ====================================================== 4) acceptedAt (fee)
console.log('\n--- cancellation fee / acceptedAt ---');
const acceptBase = {
  status: 'accepted', driverId: 'd1', driverName: 'D',
  acceptedFare: 100, acceptedOfferId: 'off1',
};
await expect('accept with FUTURE acceptedAt blocked',
  updateDoc(doc(as('u1'), 'orders/o3'), {
    ...acceptBase,
    acceptedAt: Timestamp.fromMillis(Date.now() + 24 * 3600 * 1000),
  }), false);
await expect('accept WITHOUT acceptedAt blocked',
  updateDoc(doc(as('u1'), 'orders/o3'), acceptBase), false);
await expect('accept with serverTimestamp works',
  updateDoc(doc(as('u1'), 'orders/o3'), { ...acceptBase, acceptedAt: serverTimestamp() }), true);

// ============================================================ 5) offers
console.log('\n--- offers ---');
await expect('pending driver cannot create offer',
  setDoc(doc(as('d2'), 'orders/o1/offers/x2'), { driverId: 'd2', price: 100 }), false);
await expect('offer on non-searching order blocked',
  setDoc(doc(as('d1'), 'orders/o2/offers/x3'), { driverId: 'd1', price: 100 }), false);
await expect('offer with string price blocked',
  setDoc(doc(as('d1'), 'orders/o1/offers/x4'), { driverId: 'd1', price: '100' }), false);
await expect('approved driver offer on searching order works',
  setDoc(doc(as('d1'), 'orders/o1/offers/x1'), { driverId: 'd1', price: 100 }), true);

// ======================================================= 6) admin roles
console.log('\n--- admin roles ---');
await expect('support admin cannot change driver walletBalance',
  updateDoc(doc(as('sup1'), 'drivers/d1'), { walletBalance: 500 }), false);
await expect('support admin can edit non-wallet driver field',
  updateDoc(doc(as('sup1'), 'drivers/d1'), { adminNote: 'ok' }), true);
await expect('finance admin can change driver walletBalance',
  updateDoc(doc(as('fin1'), 'drivers/d1'), { walletBalance: 500 }), true);
await expect('support admin cannot change user walletBalance',
  updateDoc(doc(as('sup1'), 'users/u3'), { walletBalance: 500 }), false);
await expect('finance admin can change user walletBalance',
  updateDoc(doc(as('fin1'), 'users/u3'), { walletBalance: 500 }), true);

// ====================================================== 7) ratings range
console.log('\n--- ratings ---');
await expect('customer rating 99 blocked',
  updateDoc(doc(as('u1'), 'orders/o4'), { rating: 99, ratingComment: 'x', ratedAt: serverTimestamp() }), false);
await expect('customer rating 5 works',
  updateDoc(doc(as('u1'), 'orders/o4'), { rating: 5, ratingComment: 'x', ratedAt: serverTimestamp() }), true);
await expect('driver cannot reopen order as searching',
  updateDoc(doc(as('d1'), 'orders/o5'), { status: 'searching' }), false);
await expect('driverRating 9 blocked',
  updateDoc(doc(as('d1'), 'orders/o5'), { driverRating: 9 }), false);
await expect('driver cannot edit own ratingSum',
  updateDoc(doc(as('d1'), 'drivers/d1'), { ratingSum: 5000, ratingCount: 1000 }), false);

console.log(failures === 0 ? '\nALL PASS' : `\n${failures} FAILED`);
await env.cleanup();
process.exit(failures === 0 ? 0 : 1);