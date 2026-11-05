// İslam Ansiklopedisi içeriğini Firestore'a yükler (ansiklopedi koleksiyonu).
//
//   python3 tools/ansiklopedi/derle.py          # önce doğrula ve JSON üret
//   node tools/ansiklopedi/yukle.mjs            # sonra yükle
//
// Yönetici anahtarı: Firebase konsolu → Proje ayarları → Hizmet hesapları →
// "Yeni özel anahtar oluştur". İnen dosya ~/.config/namaz-app/servis-hesabi.json
// olarak kaydedilir (repoya KONMAZ). Başka yerdeyse GOOGLE_APPLICATION_CREDENTIALS.
//
// Maddeler `yayinda` alanıyla yazılır: taslaklar yalnızca editörlere görünür
// (firestore.rules). Kaynakta artık olmayan maddeler Firestore'dan silinir.
import { readFileSync, existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const kok = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const anahtar = process.env.GOOGLE_APPLICATION_CREDENTIALS || join(homedir(), '.config/namaz-app/servis-hesabi.json');
if (!existsSync(anahtar)) {
  console.error(`Yönetici anahtarı yok: ${anahtar}\nFirebase konsolu → Proje ayarları → Hizmet hesapları → Yeni özel anahtar oluştur.`);
  process.exit(1);
}
const maddeler = JSON.parse(readFileSync(join(kok, 'build/ansiklopedi.json'), 'utf8'));

initializeApp({ credential: cert(JSON.parse(readFileSync(anahtar, 'utf8'))) });
const db = getFirestore();
const koleksiyon = db.collection('ansiklopedi');

const mevcut = await koleksiyon.get();
const eskiler = new Map(mevcut.docs.map((d) => [d.id, d.data()]));
const yeniIdler = new Set(maddeler.map((m) => m.id));

let yazilan = 0;
let ayni = 0;
const batch = db.batch();
for (const m of maddeler) {
  const eski = eskiler.get(m.id);
  // Değişmeyen maddeye dokunma: uygulamalar "guncellendi"ye bakıp yalnızca değişeni yeniler
  const { guncellendi, ...eskiIcerik } = eski ?? {};
  if (eski && JSON.stringify(sirala(eskiIcerik)) === JSON.stringify(sirala(m))) {
    ayni++;
    continue;
  }
  batch.set(koleksiyon.doc(m.id), { ...m, guncellendi: FieldValue.serverTimestamp() });
  yazilan++;
}
const silinen = [...eskiler.keys()].filter((id) => !yeniIdler.has(id));
for (const id of silinen) batch.delete(koleksiyon.doc(id));
await batch.commit();

const yayinda = maddeler.filter((m) => m.yayinda).length;
console.log(`yüklendi: ${yazilan} yeni/değişen, ${ayni} aynı, ${silinen.length} silinen • ${yayinda}/${maddeler.length} yayında`);

function sirala(o) {
  if (Array.isArray(o)) return o.map(sirala);
  if (o && typeof o === 'object') return Object.fromEntries(Object.keys(o).sort().map((k) => [k, sirala(o[k])]));
  return o;
}
