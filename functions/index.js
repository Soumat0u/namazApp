// Namaz App Cloud Functions
// Uygulama içi bildirimleri (arkadaşlık isteği, kabul, namaz hatırlatması, amîn) telefona push olarak iletir.
// Dağıtım: firebase deploy --only functions  (Blaze planı gerekir)

const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

const BOLGE = 'europe-west1';

/** Bildirim türüne göre başlık/metin ve uygulamada açılacak sekme */
function icerik(veri) {
  const ad = veri.fromDisplayName || veri.fromUsername || 'Bir arkadaşın';
  switch (veri.type) {
    case 'friend_request':
      return { title: '🤝 Yeni arkadaşlık isteği', body: `${ad} seni arkadaşlığına davet ediyor.`, sekme: 'sosyal' };
    case 'friend_accepted':
      return { title: '🤝 İsteğin kabul edildi', body: `${ad} ile artık arkadaşsınız.`, sekme: 'sosyal' };
    case 'nudge':
      return {
        title: '👋 Arkadaşın hatırlatıyor',
        body: `${ad}: ${veri.vakit || 'Namazını'} kıldın mı? Kıldıysan işaretlemeyi unutma.`,
        sekme: 'ana',
      };
    default:
      return null;
  }
}

/** Kullanıcının FCM token'ına gönderir; geçersiz token'ı temizler */
async function gonder(uid, mesaj) {
  const db = getFirestore();
  const kullanici = await db.doc(`users/${uid}`).get();
  const token = kullanici.get('fcmToken');
  if (!token) return;
  try {
    await getMessaging().send({
      token,
      notification: { title: mesaj.title, body: mesaj.body },
      data: { sekme: mesaj.sekme },
      android: { priority: 'high', notification: { channelId: 'sosyal_channel' } },
      apns: { payload: { aps: { sound: 'default' } } },
    });
  } catch (e) {
    if (e.code === 'messaging/registration-token-not-registered' ||
        e.code === 'messaging/invalid-registration-token') {
      await db.doc(`users/${uid}`).update({ fcmToken: null });
    } else {
      console.error('FCM gönderim hatası', uid, e);
    }
  }
}

// Yeni ya da yeniden yazılan (ör. ertesi gün tekrar gönderilen hatırlatma) bildirimler
exports.bildirimiIlet = onDocumentWritten(
  { document: 'users/{uid}/notifications/{nid}', region: BOLGE },
  async (event) => {
    const sonra = event.data?.after?.data();
    if (!sonra) return; // silindi
    const once = event.data?.before?.data();
    const yeniBekleyen = sonra.status === 'pending' || sonra.status === 'unread';
    // Sadece okunmamış/bekleyen hale geçtiğinde ya da yeni hatırlatma gününde gönder
    const degisti = !once || once.status !== sonra.status || once.gun !== sonra.gun;
    if (!yeniBekleyen || !degisti) return;
    const mesaj = icerik(sonra);
    if (mesaj) await gonder(event.params.uid, mesaj);
  },
);

const SIKAYET_ESIGI = 3;

// Duaya amîn denince sahibine haber ver; yeterince şikâyet alan duayı herkesten gizle
exports.aminBildirimi = onDocumentWritten(
  { document: 'prayers/{id}', region: BOLGE },
  async (event) => {
    const once = event.data?.before?.data();
    const sonra = event.data?.after?.data();
    if (!once || !sonra) return;
    if ((sonra.sikayetEdenler || []).length >= SIKAYET_ESIGI && sonra.isApproved !== false) {
      await event.data.after.ref.update({ isApproved: false });
      return;
    }
    const eski = new Set(once.aminBy || []);
    const yeniler = (sonra.aminBy || []).filter((u) => !eski.has(u) && u !== sonra.senderUid);
    if (yeniler.length === 0) return;
    const sayi = (sonra.aminBy || []).length;
    await gonder(sonra.senderUid, {
      title: '🤲 Duana amîn dendi',
      body: sayi === 1 ? 'Bir arkadaşın duana amîn dedi.' : `${sayi} arkadaşın duana amîn dedi.`,
      sekme: 'sosyal',
    });
  },
);
