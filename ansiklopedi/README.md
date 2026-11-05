# İslam Ansiklopedisi içeriği

Her madde bir Markdown dosyasıdır. Başındaki `---` arasındaki alanlar:

| Alan | Anlamı |
|---|---|
| `id` | Benzersiz kimlik (dosya adıyla aynı) |
| `kategori` | temel, peygamberimiz, peygamberler, melekler, halifeler, sahabe, kavramlar, tarih |
| `baslik`, `ozet` | Listede ve kartlarda görünen başlık ve 1-2 cümlelik özet |
| `sira` | Kategori içindeki sıra |
| `kunye` | Künye kutusu (anahtar: değer) |
| `baglantilar` | İlgili maddelerin id'leri |
| `ozel_gun` | Hicrî "ay-gün" (ör. `9-17`): o gün "Günün Bilgisi" olarak öne çıkar |
| `kaynak` | Maddenin dayandığı kaynaklar |
| `durum` | `taslak` (yalnızca editör görür) veya `onaylandi` (herkese açık) |

Metinde: `## Ara başlık`, `- madde`, `**kalın**`, `> alıntı/ayet`,
`[[madde-id]]` veya `[[madde-id|görünen ad]]` (başka maddeye bağlantı).

Yükleme: `node tools/ansiklopedi/yukle.mjs` (bkz. o dosyanın başı).
