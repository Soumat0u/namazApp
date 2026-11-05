import 'package:flutter/material.dart';

import '../../views/widgets/namaz_figuru.dart';

/// Temel ilmihal bilgileri (Hanefî mezhebine göre, Diyanet'in anlatımıyla).
/// Adımlardaki [Madde.dua], Dua Kitaplığı'ndaki duanın başlığıdır; o adımdan
/// duanın sayfası açılır.
class IlmihalKonusu {
  final String baslik;
  final String ozet;
  final IconData ikon;
  final Color renk;
  final List<IlmihalBolumu> bolumler;
  /// Sayfanın üstünde namaz animasyonu gösterilsin mi
  final bool namazAnimasyonu;
  const IlmihalKonusu({
    this.namazAnimasyonu = false,
    required this.baslik,
    required this.ozet,
    required this.ikon,
    required this.renk,
    required this.bolumler,
  });
}

class IlmihalBolumu {
  final String baslik;
  /// true: sıralı adımlar (numaralı); false: madde listesi
  final bool adimli;
  final List<Madde> maddeler;
  final String? not;
  const IlmihalBolumu(this.baslik, this.maddeler, {this.adimli = false, this.not});
}

class Madde {
  final String metin;
  final String? aciklama;
  final IconData? ikon;
  final List<String> dua;
  /// Namaz adımlarında figürle gösterilecek duruş
  final Durus? durus;
  const Madde(this.metin, {this.aciklama, this.ikon, this.dua = const [], this.durus});
}

const List<IlmihalKonusu> ilmihalKonulari = [
  IlmihalKonusu(
    baslik: 'Abdest',
    ozet: 'Farzları, adım adım alınışı ve abdesti bozan durumlar',
    ikon: Icons.water_drop_rounded,
    renk: Color(0xFF1E88E5),
    bolumler: [
      IlmihalBolumu('Abdestin farzları', [
        Madde('Yüzü bir kere yıkamak'),
        Madde('Kolları dirseklerle birlikte bir kere yıkamak'),
        Madde('Başın dörtte birini meshetmek'),
        Madde('Ayakları topuklarla birlikte bir kere yıkamak'),
      ], not: 'Bunlardan biri eksik kalırsa abdest olmaz. Aşağıdaki diğer adımlar sünnet ve âdaptır.'),
      IlmihalBolumu('Abdest nasıl alınır?', adimli: true, [
        Madde('Niyet edilir', aciklama: '"Niyet ettim Allah rızası için abdest almaya" diye kalben niyet edilir; Eûzü Besmele çekilir.', ikon: Icons.favorite_rounded),
        Madde('Eller yıkanır', aciklama: 'Eller bileklere kadar üç kez yıkanır, parmak araları ovulur. Yüzük varsa oynatılarak altı ıslatılır.', ikon: Icons.back_hand_rounded),
        Madde('Ağza su verilir', aciklama: 'Sağ elle ağza üç kez su alınıp her seferinde iyice çalkalanır (mazmaza).', ikon: Icons.water_rounded),
        Madde('Buruna su çekilir', aciklama: 'Sağ elle buruna üç kez su çekilir, sol elle sümkürülerek temizlenir (istinşak).', ikon: Icons.air_rounded),
        Madde('Yüz yıkanır', aciklama: 'Alında saçların bittiği yerden çene altına, kulak yumuşaklarına kadar yüz üç kez yıkanır.', ikon: Icons.face_rounded),
        Madde('Kollar yıkanır', aciklama: 'Önce sağ, sonra sol kol dirseklerle birlikte üç kez yıkanır.', ikon: Icons.front_hand_rounded),
        Madde('Baş meshedilir', aciklama: 'Sağ elin içi ıslatılarak başın en az dörtte biri meshedilir.', ikon: Icons.person_rounded),
        Madde('Kulaklar ve boyun meshedilir', aciklama: 'Islak serçe parmaklarıyla kulak içleri, başparmaklarla kulak arkaları; ellerin dış yüzüyle boyun meshedilir.', ikon: Icons.hearing_rounded),
        Madde('Ayaklar yıkanır', aciklama: 'Önce sağ, sonra sol ayak topuklarla birlikte üç kez yıkanır, parmak araları ovulur.', ikon: Icons.directions_walk_rounded),
      ]),
      IlmihalBolumu('Abdesti bozan durumlar', [
        Madde('Önden veya arkadan idrar, dışkı, yel gibi bir şeyin çıkması'),
        Madde('Vücudun bir yerinden kan, irin gibi bir akıntının çıkıp akması'),
        Madde('Ağız dolusu kusmak'),
        Madde('Bayılmak, sarhoş olmak'),
        Madde('Bir yere dayanarak veya yaslanarak uyumak'),
        Madde('Rükûlu ve secdeli bir namazda yanındakilerin duyacağı kadar gülmek'),
      ]),
    ],
  ),
  IlmihalKonusu(
    baslik: 'Gusül',
    ozet: 'Boy abdestinin farzları, alınışı ve gerektiren durumlar',
    ikon: Icons.shower_rounded,
    renk: Color(0xFF00897B),
    bolumler: [
      IlmihalBolumu('Guslün farzları', [
        Madde('Ağza su vermek (mazmaza)'),
        Madde('Buruna su çekmek (istinşak)'),
        Madde('Bütün bedeni kuru yer kalmayacak şekilde yıkamak'),
      ]),
      IlmihalBolumu('Gusül nasıl alınır?', adimli: true, [
        Madde('Niyet edilir', aciklama: '"Niyet ettim Allah rızası için gusül abdesti almaya" diye niyet edilir, Besmele çekilir.', ikon: Icons.favorite_rounded),
        Madde('Eller ve avret yerleri yıkanır', aciklama: 'Bedende bir necaset (pislik) varsa önce o temizlenir.', ikon: Icons.back_hand_rounded),
        Madde('Namaz abdesti gibi abdest alınır', aciklama: 'Ağza ve buruna su verilerek abdest alınır.', ikon: Icons.water_drop_rounded),
        Madde('Baştan aşağı su dökülür', aciklama: 'Önce başa, sonra sağ omza, sonra sol omza üçer kez su dökülür.', ikon: Icons.shower_rounded),
        Madde('Bütün beden ovularak yıkanır', aciklama: 'Göbek çukuru, kulak delikleri ve saç dipleri dahil kuru yer kalmamalıdır.', ikon: Icons.check_circle_rounded),
      ]),
      IlmihalBolumu('Guslü gerektiren durumlar', [
        Madde('Cünüplük'),
        Madde('Hayız (âdet) hâlinin sona ermesi'),
        Madde('Nifas (lohusalık) hâlinin sona ermesi'),
      ]),
    ],
  ),
  IlmihalKonusu(
    baslik: 'Teyemmüm',
    ozet: 'Su bulunamadığında veya kullanılamadığında',
    ikon: Icons.landscape_rounded,
    renk: Color(0xFF8D6E63),
    bolumler: [
      IlmihalBolumu('Ne zaman yapılır?', [
        Madde('Abdest veya gusül için yeterli su bulunamadığında'),
        Madde('Su kullanmak hastalığa yol açacak ya da hastalığı artıracaksa'),
      ]),
      IlmihalBolumu('Teyemmümün farzları', [
        Madde('Niyet etmek'),
        Madde('İki darp: eller temiz toprağa vurulup yüz, tekrar vurulup kollar dirseklerle birlikte meshedilir'),
      ]),
      IlmihalBolumu('Teyemmüm nasıl yapılır?', adimli: true, [
        Madde('Niyet edilir', aciklama: 'Abdest ya da gusül yerine teyemmüme niyet edilir, Besmele çekilir.', ikon: Icons.favorite_rounded),
        Madde('Eller toprağa vurulur', aciklama: 'Parmaklar açık olarak eller temiz toprağa (veya taş, kum gibi toprak cinsinden bir şeye) vurulur, silkelenir.', ikon: Icons.back_hand_rounded),
        Madde('Yüz meshedilir', aciklama: 'Eller bütün yüze sürülür.', ikon: Icons.face_rounded),
        Madde('Eller tekrar vurulur, kollar meshedilir', aciklama: 'Önce sağ, sonra sol kol dirseklerle birlikte meshedilir.', ikon: Icons.front_hand_rounded),
      ]),
    ],
  ),
  IlmihalKonusu(
    baslik: 'Namazın Farzları',
    ozet: 'Namazın dışındaki 6 ve içindeki 6 farz',
    ikon: Icons.checklist_rounded,
    renk: Color(0xFF5E35B1),
    bolumler: [
      IlmihalBolumu('Namazın dışındaki farzlar (şartlar)', adimli: true, [
        Madde('Hadesten tahâret', aciklama: 'Abdestli olmak; gerekiyorsa gusül almış olmak.'),
        Madde('Necasetten tahâret', aciklama: 'Beden, elbise ve namaz kılınacak yerin temiz olması.'),
        Madde('Setr-i avret', aciklama: 'Örtülmesi gereken yerleri örtmek.'),
        Madde('İstikbâl-i kıble', aciklama: 'Kıbleye yönelmek.'),
        Madde('Vakit', aciklama: 'Namazı vaktinde kılmak.'),
        Madde('Niyet', aciklama: 'Hangi namazı kıldığını bilip ona kalben niyet etmek.'),
      ]),
      IlmihalBolumu('Namazın içindeki farzlar (rükünler)', adimli: true, [
        Madde('İftitah tekbiri', aciklama: 'Namaza "Allâhu Ekber" diyerek başlamak.'),
        Madde('Kıyam', aciklama: 'Gücü yetenin ayakta durması.'),
        Madde('Kıraat', aciklama: 'Ayakta Kur\'an\'dan bir miktar okumak.'),
        Madde('Rükû', aciklama: 'Eğilmek.'),
        Madde('Sücûd', aciklama: 'Her rekatta iki kez secde etmek.'),
        Madde('Ka\'de-i ahîre', aciklama: 'Son oturuşta Ettehiyyâtü okuyacak kadar oturmak.'),
      ]),
    ],
  ),
  IlmihalKonusu(
    baslik: 'Rekât Sayıları',
    ozet: 'Beş vakit, Cuma, vitir ve bayram namazları',
    ikon: Icons.format_list_numbered_rounded,
    renk: Color(0xFFF4511E),
    bolumler: [
      IlmihalBolumu('Beş vakit namaz', [
        Madde('Sabah', aciklama: '2 rekât sünnet, 2 rekât farz'),
        Madde('Öğle', aciklama: '4 rekât ilk sünnet, 4 rekât farz, 2 rekât son sünnet'),
        Madde('İkindi', aciklama: '4 rekât sünnet, 4 rekât farz'),
        Madde('Akşam', aciklama: '3 rekât farz, 2 rekât sünnet'),
        Madde('Yatsı', aciklama: '4 rekât ilk sünnet, 4 rekât farz, 2 rekât son sünnet, 3 rekât vitir (vacip)'),
      ]),
      IlmihalBolumu('Diğer namazlar', [
        Madde('Cuma', aciklama: '4 rekât ilk sünnet, 2 rekât farz (cemaatle), 4 rekât son sünnet'),
        Madde('Teravih', aciklama: 'Ramazan gecelerinde yatsıdan sonra 20 rekât (ikişer ya da dörder rekât olarak)'),
        Madde('Bayram namazı', aciklama: '2 rekât, cemaatle; fazladan alınan tekbirlerle (vacip)'),
      ]),
    ],
  ),
  IlmihalKonusu(
    baslik: 'Namazın Kılınışı',
    namazAnimasyonu: true,
    ozet: 'İki rekâtlı bir namaz adım adım (sabah namazının farzı)',
    ikon: Icons.self_improvement_rounded,
    renk: Color(0xFF2E7D32),
    bolumler: [
      IlmihalBolumu('Adım adım', adimli: true, [
        Madde('Niyet', aciklama: 'Kıbleye dönülür. "Niyet ettim Allah rızası için bugünkü sabah namazının farzını kılmaya" diye kalben niyet edilir.', ikon: Icons.favorite_rounded, durus: Durus.ayakta),
        Madde('İftitah tekbiri', aciklama: 'Eller kaldırılarak "Allâhu Ekber" denir. Erkekler başparmaklarını kulak yumuşaklarına değdirir; kadınlar ellerini omuz hizasına kaldırır.', ikon: Icons.pan_tool_rounded, durus: Durus.tekbir),
        Madde('Kıyam', aciklama: 'Eller bağlanır (erkekler göbek altında, kadınlar göğüs üzerinde), gözler secde yerine bakar. Sübhâneke okunur, Eûzü Besmele çekilir, Fâtiha ve ardından bir sure (zamm-ı sure) okunur.', ikon: Icons.accessibility_new_rounded, dua: ['Sübhâneke', 'Fâtiha', 'İhlâs'], durus: Durus.kiyam),
        Madde('Rükû', aciklama: '"Allâhu Ekber" diyerek eğilinir; eller dizlere konur, sırt düz tutulur. Üç kez "Sübhâne Rabbiye\'l-azîm" denir.', ikon: Icons.airline_seat_legroom_normal_rounded, durus: Durus.ruku),
        Madde('Kavme', aciklama: '"Semi\'allâhu limen hamideh" diyerek doğrulunur; ayakta "Rabbenâ leke\'l-hamd" denir.', ikon: Icons.accessibility_rounded, durus: Durus.ayakta),
        Madde('Birinci secde', aciklama: '"Allâhu Ekber" diyerek secdeye varılır; alın ve burun yere konur. Üç kez "Sübhâne Rabbiye\'l-a\'lâ" denir.', ikon: Icons.south_rounded, durus: Durus.secde),
        Madde('Celse', aciklama: '"Allâhu Ekber" diyerek oturulur ve kısa bir süre durulur.', ikon: Icons.event_seat_rounded, durus: Durus.oturus),
        Madde('İkinci secde', aciklama: '"Allâhu Ekber" diyerek tekrar secdeye varılır, yine üç kez "Sübhâne Rabbiye\'l-a\'lâ" denir. Böylece birinci rekât tamamlanır.', ikon: Icons.south_rounded, durus: Durus.secde),
        Madde('İkinci rekât', aciklama: '"Allâhu Ekber" diyerek ayağa kalkılır. Besmele çekilip Fâtiha ve bir sure okunur; rükû ve secdeler birinci rekâttaki gibi yapılır.', ikon: Icons.replay_rounded, dua: ['Fâtiha'], durus: Durus.kiyam),
        Madde('Son oturuş (ka\'de-i ahîre)', aciklama: 'İkinci secdeden sonra oturulur; Ettehiyyâtü, Allâhümme Salli, Allâhümme Bârik ve Rabbenâ duaları okunur.', ikon: Icons.event_seat_rounded, dua: ['Ettehiyyâtü', 'Allâhümme Salli', 'Allâhümme Bârik', 'Rabbenâ Âtinâ', 'Rabbenağfirlî'], durus: Durus.oturus),
        Madde('Selam', aciklama: 'Önce sağa, sonra sola "Esselâmü aleyküm ve rahmetullâh" denilerek selam verilir. Namaz tamamlanır.', ikon: Icons.waving_hand_rounded, durus: Durus.selamSag),
      ]),
      IlmihalBolumu('Üç ve dört rekâtlı namazlarda', [
        Madde('İlk oturuş', aciklama: 'İkinci rekâtın sonunda oturulur, yalnızca Ettehiyyâtü okunup üçüncü rekâta kalkılır.', dua: ['Ettehiyyâtü']),
        Madde('Farzların son rekâtları', aciklama: 'Farz namazların üçüncü ve dördüncü rekâtlarında yalnızca Fâtiha okunur. Sünnetlerde ve vitirde Fâtiha\'dan sonra bir sure de okunur.'),
        Madde('Vitir', aciklama: 'Üçüncü rekâtta Fâtiha ve sureden sonra eller kaldırılarak tekbir alınır, Kunut duaları okunup rükûya gidilir.', dua: ['Kunut Duası 1', 'Kunut Duası 2']),
      ]),
    ],
  ),
];
