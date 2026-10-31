// Firestore güvenlik kuralları testleri. Çalıştırma: npm test (Firestore emülatörünü kendisi açar)
import { readFileSync } from 'node:fs';
import { test, before, after, beforeEach } from 'node:test';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, writeBatch,
  arrayUnion, arrayRemove, Timestamp,
} from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-namaz',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/ali'), { username: 'ali', friends: [], totalXp: 0 });
    await setDoc(doc(db, 'users/veli'), { username: 'veli', friends: [], totalXp: 0 });
    await setDoc(doc(db, 'users/ayse'), { username: 'ayse', friends: [], cinsiyet: 'kadin' });
    await setDoc(doc(db, 'usernames/ali'), { uid: 'ali' });
    await setDoc(doc(db, 'prayers/p1'), { senderUid: 'veli', text: 'dua', aminBy: [], aminCount: 0 });
    await setDoc(doc(db, 'stories/veli'), {
      viewers: [], viewerProfiles: [], createdAt: Timestamp.now(),
    });
  });
});

const db = (uid) => env.authenticatedContext(uid).firestore();

// ───────────── Kullanıcılar ─────────────

test('kendi profilini güncelleyebilir', async () => {
  await assertSucceeds(updateDoc(doc(db('ali'), 'users/ali'), { totalXp: 50 }));
});

test('başkasının XP\'sini değiştiremez', async () => {
  await assertFails(updateDoc(doc(db('ali'), 'users/veli'), { totalXp: 99999 }));
});

test('giriş yapmayan profil okuyamaz', async () => {
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'users/ali')));
});

test('cinsiyet bir kez belirlenir, sonra değiştirilemez', async () => {
  await assertSucceeds(updateDoc(doc(db('ali'), 'users/ali'), { cinsiyet: 'erkek' }));
  await assertFails(updateDoc(doc(db('ayse'), 'users/ayse'), { cinsiyet: 'erkek' }));
  await assertSucceeds(updateDoc(doc(db('ayse'), 'users/ayse'), { totalXp: 10 }));
});

// ───────────── Arkadaşlık ─────────────

test('istek gönderme: kendi adına bildirim yazabilir', async () => {
  await assertSucceeds(setDoc(doc(db('ali'), 'users/veli/notifications/ali'), {
    type: 'friend_request', fromUid: 'ali', status: 'pending',
  }));
});

test('başkası adına istek yazamaz', async () => {
  await assertFails(setDoc(doc(db('ali'), 'users/veli/notifications/ayse'), {
    type: 'friend_request', fromUid: 'ayse', status: 'pending',
  }));
});

test('başkasının bildirimlerini okuyamaz', async () => {
  await assertFails(getDoc(doc(db('ali'), 'users/veli/notifications/x')));
});

test('isteği kabul etme (batch): iki tarafın friends listesi güncellenir', async () => {
  await env.withSecurityRulesDisabled((ctx) =>
    setDoc(doc(ctx.firestore(), 'users/veli/notifications/ali'), {
      type: 'friend_request', fromUid: 'ali', status: 'pending',
    }));
  const v = db('veli');
  const batch = writeBatch(v);
  batch.update(doc(v, 'users/veli/notifications/ali'), { status: 'accepted' });
  batch.update(doc(v, 'users/veli'), { friends: arrayUnion('ali') });
  batch.update(doc(v, 'users/ali'), { friends: arrayUnion('veli') });
  batch.delete(doc(v, 'users/ali/notifications/veli'));
  batch.set(doc(v, 'users/ali/notifications/veli_kabul'), {
    type: 'friend_accepted', fromUid: 'veli', status: 'unread',
  });
  await assertSucceeds(batch.commit());
});

test('istek olmadan kendini başkasının arkadaş listesine ekleyemez', async () => {
  await assertFails(updateDoc(doc(db('ali'), 'users/veli'), { friends: arrayUnion('ali') }));
});

test('başkasının listesine üçüncü kişiyi ekleyemez', async () => {
  await env.withSecurityRulesDisabled((ctx) =>
    setDoc(doc(ctx.firestore(), 'users/veli/notifications/ali'), {
      fromUid: 'ali', status: 'accepted',
    }));
  await assertFails(updateDoc(doc(db('veli'), 'users/ali'), { friends: arrayUnion('ayse') }));
});

test('arkadaşlıktan çıkma: kendini karşı tarafın listesinden çıkarabilir', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await updateDoc(doc(ctx.firestore(), 'users/ali'), { friends: ['veli'] });
    await updateDoc(doc(ctx.firestore(), 'users/veli'), { friends: ['ali'] });
  });
  const a = db('ali');
  const batch = writeBatch(a);
  batch.update(doc(a, 'users/ali'), { friends: arrayRemove('veli') });
  batch.update(doc(a, 'users/veli'), { friends: arrayRemove('ali') });
  batch.delete(doc(a, 'users/ali/notifications/veli'));
  batch.delete(doc(a, 'users/veli/notifications/ali'));
  await assertSucceeds(batch.commit());
});

test('hatırlatma (dürtme) gönderebilir', async () => {
  await assertSucceeds(setDoc(doc(db('ali'), 'users/veli/notifications/ali_durt'), {
    type: 'nudge', fromUid: 'ali', status: 'unread', gun: '2026-10-31',
  }));
});

// ───────────── Kullanıcı adları ─────────────

test('kullanıcı adı girişsiz okunabilir (kayıt öncesi kontrol)', async () => {
  await assertSucceeds(getDoc(doc(env.unauthenticatedContext().firestore(), 'usernames/ali')));
});

test('başkasının kullanıcı adını alamaz/silemez', async () => {
  await assertFails(setDoc(doc(db('veli'), 'usernames/ali'), { uid: 'veli' }));
  await assertFails(deleteDoc(doc(db('veli'), 'usernames/ali')));
});

// ───────────── Dualar ─────────────

test('kendi adına dua paylaşır, başkası adına paylaşamaz', async () => {
  await assertSucceeds(setDoc(doc(db('ali'), 'prayers/p2'), { senderUid: 'ali', text: 'x' }));
  await assertFails(setDoc(doc(db('ali'), 'prayers/p3'), { senderUid: 'veli', text: 'x' }));
});

test('başkasının duasına amîn der ama metnini değiştiremez/silemez', async () => {
  await assertSucceeds(updateDoc(doc(db('ali'), 'prayers/p1'), { aminBy: ['ali'], aminCount: 1 }));
  await assertFails(updateDoc(doc(db('ali'), 'prayers/p1'), { text: 'değişti' }));
  await assertFails(deleteDoc(doc(db('ali'), 'prayers/p1')));
});

test('duayı kendi adına şikâyet eder, başkası adına edemez', async () => {
  await assertSucceeds(updateDoc(doc(db('ali'), 'prayers/p1'), { sikayetEdenler: ['ali'] }));
  await assertFails(updateDoc(doc(db('ali'), 'prayers/p1'), { sikayetEdenler: ['ali', 'ayse', 'x'] }));
});

test('engellenenler listesi sadece sahibince yazılır', async () => {
  await assertSucceeds(updateDoc(doc(db('ali'), 'users/ali'), { engellenenler: ['veli'] }));
  await assertFails(updateDoc(doc(db('veli'), 'users/ali'), { engellenenler: [] }));
});

// ───────────── Ortak hatim ─────────────

test('ortak hatim: üye cüz alır, üye olmayan göremez, adı sadece kuran değiştirir', async () => {
  await assertSucceeds(setDoc(doc(db('ali'), 'hatimler/h1'), {
    ad: 'Kardeşler', olusturan: 'ali', uyeler: ['ali', 'veli'], cuzler: {},
  }));
  await assertFails(setDoc(doc(db('ali'), 'hatimler/h2'), { ad: 'x', olusturan: 'veli', uyeler: ['veli'] }));
  await assertSucceeds(updateDoc(doc(db('veli'), 'hatimler/h1'), { 'cuzler.3': { uid: 'veli', bitti: false } }));
  await assertFails(getDoc(doc(db('ayse'), 'hatimler/h1')));
  await assertFails(updateDoc(doc(db('veli'), 'hatimler/h1'), { ad: 'değişti' }));
  await assertFails(deleteDoc(doc(db('veli'), 'hatimler/h1')));
  await assertSucceeds(deleteDoc(doc(db('ali'), 'hatimler/h1')));
});

// ───────────── Hikayeler ─────────────

test('başkasının hikayesine izleyen olarak eklenir ama silemez', async () => {
  await assertSucceeds(updateDoc(doc(db('ali'), 'stories/veli'), {
    viewers: ['ali'], viewerProfiles: [{ uid: 'ali' }],
  }));
  await assertFails(deleteDoc(doc(db('ali'), 'stories/veli')));
});

test('süresi dolan hikayeyi herkes temizleyebilir', async () => {
  await env.withSecurityRulesDisabled((ctx) =>
    updateDoc(doc(ctx.firestore(), 'stories/veli'), {
      createdAt: Timestamp.fromMillis(Date.now() - 25 * 3600 * 1000),
    }));
  await assertSucceeds(deleteDoc(doc(db('ali'), 'stories/veli')));
});
