#!/usr/bin/env python3
"""ansiklopedi/*.md dosyalarını doğrulayıp JSON'a çevirir.

    python3 tools/ansiklopedi/derle.py

- build/ansiklopedi.json: bütün maddeler (taslaklar dahil); yukle.mjs bunu Firestore'a yazar
- assets/ansiklopedi.json: yalnızca onaylananlar; uygulama ilk açılışta internetsiz de gösterir

Hata varsa (eksik alan, olmayan maddeye bağlantı, bilinmeyen kategori) çıkış kodu 1.
"""
import json
import re
import sys
from pathlib import Path

import yaml

KOK = Path(__file__).resolve().parents[2]
KAYNAK = KOK / "ansiklopedi"
KATEGORILER = ["temel", "peygamberimiz", "peygamberler", "melekler", "halifeler", "sahabe", "kavramlar", "tarih"]
ZORUNLU = ["id", "kategori", "baslik", "ozet", "durum"]


def oku(yol: Path) -> dict:
    metin = yol.read_text(encoding="utf-8")
    m = re.match(r"^---\n(.*?)\n---\n(.*)$", metin, re.S)
    if not m:
        raise ValueError("başlık bölümü (--- ... ---) yok")
    bas = yaml.safe_load(m.group(1)) or {}
    bas["govde"] = m.group(2).strip()
    return bas


def main() -> int:
    maddeler, hatalar = [], []
    for yol in sorted(KAYNAK.glob("*.md")):
        if yol.name == "README.md":
            continue
        try:
            d = oku(yol)
        except Exception as e:  # noqa: BLE001
            hatalar.append(f"{yol.name}: {e}")
            continue
        for alan in ZORUNLU:
            if not d.get(alan):
                hatalar.append(f"{yol.name}: '{alan}' eksik")
        if d.get("id") != yol.stem:
            hatalar.append(f"{yol.name}: id dosya adıyla aynı olmalı ({d.get('id')})")
        if d.get("kategori") not in KATEGORILER:
            hatalar.append(f"{yol.name}: bilinmeyen kategori {d.get('kategori')}")
        if d.get("durum") not in ("taslak", "onaylandi"):
            hatalar.append(f"{yol.name}: durum 'taslak' veya 'onaylandi' olmalı")
        for g in d.get("ozel_gun") or []:
            if not re.fullmatch(r"\d{1,2}-\d{1,2}", str(g)):
                hatalar.append(f"{yol.name}: ozel_gun '{g}' ay-gün biçiminde olmalı")
        maddeler.append({
            "id": d["id"],
            "kategori": d["kategori"],
            "baslik": d["baslik"],
            "ozet": d["ozet"],
            "sira": int(d.get("sira", 99)),
            "kunye": [[str(k), str(v)] for k, v in (d.get("kunye") or {}).items()],
            "baglantilar": list(d.get("baglantilar") or []),
            "ozelGun": [str(g) for g in (d.get("ozel_gun") or [])],
            "kaynak": d.get("kaynak", ""),
            "govde": d["govde"],
            "yayinda": d["durum"] == "onaylandi",
        })

    idler = {m["id"] for m in maddeler}
    for m in maddeler:
        for b in m["baglantilar"]:
            if b not in idler:
                hatalar.append(f"{m['id']}: baglantilar içinde olmayan madde '{b}'")
        for b in re.findall(r"\[\[([^\]|]+)", m["govde"]):
            if b not in idler:
                hatalar.append(f"{m['id']}: metindeki [[{b}]] bağlantısı olmayan bir maddeye gidiyor")

    if hatalar:
        print("\n".join(hatalar), file=sys.stderr)
        return 1

    (KOK / "build").mkdir(exist_ok=True)
    (KOK / "build" / "ansiklopedi.json").write_text(json.dumps(maddeler, ensure_ascii=False, indent=1), encoding="utf-8")
    onayli = [m for m in maddeler if m["yayinda"]]
    (KOK / "assets" / "ansiklopedi.json").write_text(json.dumps(onayli, ensure_ascii=False), encoding="utf-8")
    sayim = {k: sum(m["kategori"] == k for m in maddeler) for k in KATEGORILER}
    print(f"{len(maddeler)} madde ({len(onayli)} onaylı): " + ", ".join(f"{k} {v}" for k, v in sayim.items()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
