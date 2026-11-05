import 'package:quran/quran.dart' as quran;

/// Dua kitaplığı ve tesbihat verisi.
/// Kur'an'dan olan dualarda Arapça metin ve meal `quran` paketinden alınır ([sure] / [ayetler]);
/// Kur'an dışı dualar (Sübhaneke, Tahiyyat vb.) elle yazılmıştır.
class Dua {
  final String baslik;
  final String kategori;
  final String okunus;
  final String? _arapca;
  final String? _meal;
  final int? sure;
  final List<int> ayetler;
  /// Kur'an dışı duanın kayıtlı sesi (`assets/sounds/dualar/<ses>.mp3`) ve kelime zamanları:
  /// (kelime sırası 1'den, başlangıç ms, bitiş ms). Ses yoksa telefonun yazıdan-sese motoru okur.
  final String? ses;
  final List<(int, int, int)> sesZamanlari;

  const Dua({
    required this.baslik,
    required this.kategori,
    required this.okunus,
    String? arapca,
    String? meal,
    this.sure,
    this.ayetler = const [],
    this.ses,
    this.sesZamanlari = const [],
  })  : _arapca = arapca,
        _meal = meal;

  bool get kurandan => sure != null;

  String get arapca => kurandan
      ? ayetler.map((a) => quran.getVerse(sure!, a, verseEndSymbol: true)).join(' ')
      : _arapca!;

  String get meal => _meal ??
      ayetler.map((a) => quran.getVerseTranslation(sure!, a, translation: quran.Translation.trSaheeh)).join(' ');

  /// "Bakara 255" gibi kaynak bilgisi
  String? get kaynak {
    if (!kurandan) return null;
    final ad = quran.getSurahNameTurkish(sure!);
    return ayetler.length == 1 ? '$ad ${ayetler.first}' : '$ad ${ayetler.first}-${ayetler.last}';
  }
}

const String namazDualari = 'Namaz Duaları';
const String sabahAksam = 'Sabah - Akşam';

const List<Dua> dualar = [
  // ───────────── Namaz duaları ─────────────
  Dua(
    baslik: 'Sübhâneke',
    kategori: namazDualari,
    ses: 'subhaneke',
    sesZamanlari: [(1, 0, 1060), (2, 1060, 1680), (3, 1680, 2880), (4, 2880, 3760), (5, 3760, 4640), (6, 4640, 5460), (7, 5460, 6460), (8, 6460, 7160), (9, 7160, 7780), (10, 7780, 8360)],
    arapca: 'سُبْحَانَكَ اللّٰهُمَّ وَبِحَمْدِكَ وَتَبَارَكَ اسْمُكَ وَتَعَالٰى جَدُّكَ وَلَا اِلٰهَ غَيْرُكَ',
    okunus: 'Sübhânekellâhümme ve bi-hamdik, ve tebârekesmük, ve teâlâ ceddük, ve lâ ilâhe ğayrük.',
    meal: "Allah'ım! Sen eksik sıfatlardan pak ve uzaksın. Seni daima böyle tenzih eder ve överim. "
        'Senin adın mübarektir. Varlığın her şeyden üstündür. Senden başka ilah yoktur.',
  ),
  Dua(
    baslik: 'Fâtiha',
    kategori: namazDualari,
    sure: 1,
    ayetler: [1, 2, 3, 4, 5, 6, 7],
    okunus: 'Bismillâhirrahmânirrahîm. Elhamdü lillâhi rabbi\'l-âlemîn. Errahmâni\'r-rahîm. Mâliki yevmi\'d-dîn. '
        'İyyâke na\'büdü ve iyyâke neste\'în. İhdine\'s-sırâta\'l-müstakîm. '
        'Sırâta\'llezîne en\'amte aleyhim ğayri\'l-mağdûbi aleyhim ve le\'d-dâllîn.',
  ),
  Dua(
    baslik: 'Ettehiyyâtü',
    kategori: namazDualari,
    ses: 'ettehiyyatu',
    sesZamanlari: [(1, 0, 880), (2, 880, 1700), (3, 1700, 2600), (4, 2600, 3820), (5, 3820, 4460), (6, 4460, 5040), (7, 5040, 5420), (8, 5420, 6040), (9, 6040, 6800), (10, 6800, 7200), (11, 7200, 8380), (12, 8380, 8960), (13, 8960, 9800), (14, 9800, 10280), (15, 10280, 10760), (16, 10760, 11100), (17, 11100, 12260), (18, 12260, 12820), (19, 12820, 13180), (20, 13180, 13580), (21, 13580, 14060), (22, 14060, 14500), (23, 14500, 15120), (24, 15120, 15880), (25, 15880, 16220), (26, 16220, 17300), (27, 17300, 17800), (28, 17800, 18520)],
    arapca: 'اَلتَّحِيَّاتُ لِلّٰهِ وَالصَّلَوَاتُ وَالطَّيِّبَاتُ اَلسَّلَامُ عَلَيْكَ اَيُّهَا النَّبِيُّ وَرَحْمَةُ اللّٰهِ وَبَرَكَاتُهُ '
        'اَلسَّلَامُ عَلَيْنَا وَعَلٰى عِبَادِ اللّٰهِ الصَّالِحِينَ اَشْهَدُ اَنْ لَا اِلٰهَ اِلَّا اللّٰهُ وَاَشْهَدُ اَنَّ مُحَمَّدًا عَبْدُهُ وَرَسُولُهُ',
    okunus: 'Et-tahiyyâtü lillâhi ve\'s-salavâtü ve\'t-tayyibât. Es-selâmü aleyke eyyühe\'n-nebiyyü ve rahmetullâhi ve berakâtüh. '
        'Es-selâmü aleynâ ve alâ ibâdillâhi\'s-sâlihîn. Eşhedü en lâ ilâhe illallâh, ve eşhedü enne Muhammeden abdühû ve rasûlüh.',
    meal: "Dil ile, beden ve mal ile yapılan bütün ibadetler Allah'adır. Ey Peygamber! Allah'ın selâmı, rahmeti ve bereketleri "
        "senin üzerine olsun. Selâm bizim üzerimize ve Allah'ın salih kulları üzerine olsun. Şahitlik ederim ki Allah'tan başka "
        "ilah yoktur. Yine şahitlik ederim ki Muhammed O'nun kulu ve elçisidir.",
  ),
  Dua(
    baslik: 'Allâhümme Salli',
    kategori: namazDualari,
    ses: 'salli',
    sesZamanlari: [(1, 0, 780), (2, 780, 1260), (3, 1260, 1500), (4, 1500, 2620), (5, 2620, 3060), (6, 3060, 3360), (7, 3360, 4200), (8, 4200, 4700), (9, 4700, 5380), (10, 5380, 5600), (11, 5600, 6780), (12, 6780, 7420), (13, 7420, 7660), (14, 7660, 8700), (15, 8700, 9440), (16, 9440, 10240), (17, 10240, 10880)],
    arapca: 'اَللّٰهُمَّ صَلِّ عَلٰى مُحَمَّدٍ وَعَلٰى اٰلِ مُحَمَّدٍ كَمَا صَلَّيْتَ عَلٰى اِبْرَاهِيمَ وَعَلٰى اٰلِ اِبْرَاهِيمَ اِنَّكَ حَمِيدٌ مَجِيدٌ',
    okunus: 'Allâhümme salli alâ Muhammedin ve alâ âli Muhammed, kemâ salleyte alâ İbrâhîme ve alâ âli İbrâhîm, inneke hamîdün mecîd.',
    meal: "Allah'ım! Muhammed'e ve Muhammed'in ümmetine rahmet eyle, şerefini yücelt; İbrahim'e ve İbrahim'in ümmetine "
        'rahmet ettiğin gibi. Şüphesiz Sen övülmeye layıksın, şanı yücesin.',
  ),
  Dua(
    baslik: 'Allâhümme Bârik',
    kategori: namazDualari,
    ses: 'barik',
    sesZamanlari: [(1, 0, 800), (2, 800, 1360), (3, 1360, 1660), (4, 1660, 2740), (5, 2740, 3240), (6, 3240, 3580), (7, 3580, 4460), (8, 4460, 4900), (9, 4900, 5520), (10, 5520, 5760), (11, 5760, 6780), (12, 6780, 7460), (13, 7460, 7780), (14, 7780, 8760), (15, 8760, 9620), (16, 9620, 10600), (17, 10600, 11100)],
    arapca: 'اَللّٰهُمَّ بَارِكْ عَلٰى مُحَمَّدٍ وَعَلٰى اٰلِ مُحَمَّدٍ كَمَا بَارَكْتَ عَلٰى اِبْرَاهِيمَ وَعَلٰى اٰلِ اِبْرَاهِيمَ اِنَّكَ حَمِيدٌ مَجِيدٌ',
    okunus: 'Allâhümme bârik alâ Muhammedin ve alâ âli Muhammed, kemâ bârekte alâ İbrâhîme ve alâ âli İbrâhîm, inneke hamîdün mecîd.',
    meal: "Allah'ım! Muhammed'e ve Muhammed'in ümmetine hayır ve bereket ver; İbrahim'e ve İbrahim'in ümmetine verdiğin gibi. "
        'Şüphesiz Sen övülmeye layıksın, şanı yücesin.',
  ),
  Dua(
    baslik: 'Rabbenâ Âtinâ',
    kategori: namazDualari,
    sure: 2,
    ayetler: [201],
    okunus: 'Rabbenâ âtinâ fi\'d-dünyâ haseneten ve fi\'l-âhireti haseneten ve kınâ azâbe\'n-nâr.',
  ),
  Dua(
    baslik: 'Rabbenağfirlî',
    kategori: namazDualari,
    sure: 14,
    ayetler: [41],
    okunus: 'Rabbenağfirlî ve li-vâlideyye ve li\'l-mü\'minîne yevme yekûmü\'l-hisâb.',
  ),
  Dua(
    baslik: 'Kunut Duası 1',
    kategori: namazDualari,
    ses: 'kunut1',
    sesZamanlari: [(1, 0, 700), (2, 700, 1300), (3, 1300, 2320), (4, 2320, 3440), (5, 3440, 4800), (6, 4800, 5460), (7, 5460, 6060), (8, 6060, 6820), (9, 6820, 7600), (10, 7600, 8580), (11, 8580, 9360), (12, 9360, 10020), (13, 10020, 10460), (14, 10460, 11040), (15, 11040, 11720), (16, 11720, 12780), (17, 12780, 13100), (18, 13100, 14040), (19, 14040, 15080), (20, 15080, 15800), (21, 15800, 16060), (22, 16060, 16780)],
    arapca: 'اَللّٰهُمَّ اِنَّا نَسْتَعِينُكَ وَنَسْتَغْفِرُكَ وَنَسْتَهْدِيكَ وَنُؤْمِنُ بِكَ وَنَتُوبُ اِلَيْكَ وَنَتَوَكَّلُ عَلَيْكَ '
        'وَنُثْنِي عَلَيْكَ الْخَيْرَ كُلَّهُ نَشْكُرُكَ وَلَا نَكْفُرُكَ وَنَخْلَعُ وَنَتْرُكُ مَنْ يَفْجُرُكَ',
    okunus: 'Allâhümme innâ nesteînüke ve nestağfirüke ve nestehdîk, ve nü\'minü bike ve netûbü ileyk, ve netevekkelü aleyk, '
        've nüsnî aleyke\'l-hayra küllehû neşkürük, ve lâ nekfürük, ve nahleu ve netrükü men yefcürük.',
    meal: "Allah'ım! Senden yardım isteriz, günahlarımızı bağışlamanı isteriz, razı olduğun şeylere hidayet etmeni isteriz. "
        'Sana inanırız, sana tövbe ederiz, sana güveniriz. Bize verdiğin bütün nimetleri bilerek seni hayır ile överiz. '
        'Sana şükrederiz, hiçbir nimetini inkâr etmeyiz. Nimetlerini inkâr edeni ve sana karşı geleni bırakırız.',
  ),
  Dua(
    baslik: 'Kunut Duası 2',
    kategori: namazDualari,
    ses: 'kunut2',
    sesZamanlari: [(1, 0, 900), (2, 900, 1500), (3, 1500, 2100), (4, 2100, 2460), (5, 2460, 3260), (6, 3260, 4220), (7, 4220, 4940), (8, 4940, 5620), (9, 5620, 6580), (10, 6580, 7100), (11, 7100, 7940), (12, 7940, 8600), (13, 8600, 9500), (14, 9500, 10000), (15, 10000, 10840), (16, 10840, 11760), (17, 11760, 12380)],
    arapca: 'اَللّٰهُمَّ اِيَّاكَ نَعْبُدُ وَلَكَ نُصَلِّي وَنَسْجُدُ وَاِلَيْكَ نَسْعٰى وَنَحْفِدُ نَرْجُو رَحْمَتَكَ وَنَخْشٰى عَذَابَكَ '
        'اِنَّ عَذَابَكَ بِالْكُفَّارِ مُلْحِقٌ',
    okunus: 'Allâhümme iyyâke na\'büdü ve leke nusallî ve nescüdü, ve ileyke nes\'â ve nahfidü, nercû rahmeteke ve nahşâ azâbek, '
        'inne azâbeke bi\'l-küffâri mülhık.',
    meal: "Allah'ım! Biz yalnız sana kulluk ederiz. Namazı yalnız senin için kılar, yalnız sana secde ederiz. Yalnız sana koşar, "
        'sana yaklaştıracak ibadetlere çalışırız. Rahmetini umar, azabından korkarız. Şüphesiz senin azabın kâfirlere ulaşır.',
  ),

  // ───────────── Sabah - akşam ─────────────
  Dua(
    baslik: 'Âyetü\'l-Kürsî',
    kategori: sabahAksam,
    sure: 2,
    ayetler: [255],
    okunus: 'Allâhü lâ ilâhe illâ hüve\'l-hayyü\'l-kayyûm, lâ te\'huzühû sinetün ve lâ nevm, lehû mâ fi\'s-semâvâti ve mâ fi\'l-ard, '
        'men ze\'llezî yeşfeu indehû illâ bi-iznih, ya\'lemü mâ beyne eydîhim ve mâ halfehüm, ve lâ yuhîtûne bi-şey\'in min ilmihî '
        'illâ bimâ şâ\', vesia kürsiyyühü\'s-semâvâti ve\'l-ard, ve lâ yeûdühû hıfzuhumâ, ve hüve\'l-aliyyü\'l-azîm.',
  ),
  Dua(
    baslik: 'Âmene\'r-Rasûlü',
    kategori: sabahAksam,
    sure: 2,
    ayetler: [285, 286],
    okunus: 'Âmene\'r-rasûlü bimâ ünzile ileyhi min rabbihî ve\'l-mü\'minûn, küllün âmene billâhi ve melâiketihî ve kütübihî ve rusulih, '
        'lâ nüferriku beyne ehadin min rusulih, ve kâlû semi\'nâ ve eta\'nâ ğufrâneke rabbenâ ve ileyke\'l-masîr. '
        'Lâ yükellifullâhu nefsen illâ vüs\'ahâ, lehâ mâ kesebet ve aleyhâ mektesebet, rabbenâ lâ tüâhiznâ in nesînâ ev ahta\'nâ, '
        'rabbenâ ve lâ tahmil aleynâ ısran kemâ hameltehû ale\'llezîne min kablinâ, rabbenâ ve lâ tühammilnâ mâ lâ tâkate lenâ bih, '
        've\'fü annâ, vağfir lenâ, verhamnâ, ente mevlânâ fensurnâ ale\'l-kavmi\'l-kâfirîn.',
  ),
  Dua(
    baslik: 'İhlâs',
    kategori: sabahAksam,
    sure: 112,
    ayetler: [1, 2, 3, 4],
    okunus: 'Kul hüvallâhü ehad. Allâhü\'s-samed. Lem yelid ve lem yûled. Ve lem yekün lehû küfüven ehad.',
  ),
  Dua(
    baslik: 'Felak',
    kategori: sabahAksam,
    sure: 113,
    ayetler: [1, 2, 3, 4, 5],
    okunus: 'Kul eûzü bi-rabbi\'l-felak. Min şerri mâ halak. Ve min şerri ğâsikın izâ vekab. '
        'Ve min şerri\'n-neffâsâti fi\'l-ukad. Ve min şerri hâsidin izâ hased.',
  ),
  Dua(
    baslik: 'Nâs',
    kategori: sabahAksam,
    sure: 114,
    ayetler: [1, 2, 3, 4, 5, 6],
    okunus: 'Kul eûzü bi-rabbi\'n-nâs. Meliki\'n-nâs. İlâhi\'n-nâs. Min şerri\'l-vesvâsi\'l-hannâs. '
        'Ellezî yüvesvisü fî sudûri\'n-nâs. Mine\'l-cinneti ve\'n-nâs.',
  ),
  Dua(
    baslik: 'Hasbiyallâh',
    kategori: sabahAksam,
    sure: 9,
    ayetler: [129],
    okunus: 'Fe in tevellev fe-kul hasbiyallâhü lâ ilâhe illâ hû, aleyhi tevekkeltü ve hüve rabbü\'l-arşi\'l-azîm.',
  ),
];

/// Namaz sonrası tesbihat adımı
class TesbihatAdimi {
  final String ad;
  final String arapca;
  final String okunus;
  final String meal;
  final int adet;
  /// Kur'an'dan ise (Âyetü'l-Kürsî) metin [dua]'dan alınır
  final Dua? dua;

  const TesbihatAdimi({
    required this.ad,
    this.arapca = '',
    this.okunus = '',
    this.meal = '',
    required this.adet,
    this.dua,
  });

  String get arapcaMetin => dua?.arapca ?? arapca;
  String get okunusMetin => dua?.okunus ?? okunus;
  String get mealMetin => dua?.meal ?? meal;
}

final List<TesbihatAdimi> tesbihatAdimlari = [
  const TesbihatAdimi(
    ad: 'Allâhümme ente\'s-selâm',
    arapca: 'اَللّٰهُمَّ اَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْاِكْرَامِ',
    okunus: 'Allâhümme ente\'s-selâmu ve minke\'s-selâm, tebârekte yâ ze\'l-celâli ve\'l-ikrâm.',
    meal: "Allah'ım! Sen selâmsın, selâmet sendendir. Ey celâl ve ikram sahibi, Sen yücesin.",
    adet: 1,
  ),
  TesbihatAdimi(ad: 'Âyetü\'l-Kürsî', adet: 1, dua: dualar.firstWhere((d) => d.sure == 2 && d.ayetler.first == 255)),
  const TesbihatAdimi(ad: 'Sübhânallah', arapca: 'سُبْحَانَ اللّٰهِ', okunus: 'Sübhânallah', meal: "Allah her türlü eksiklikten uzaktır.", adet: 33),
  const TesbihatAdimi(ad: 'Elhamdülillâh', arapca: 'اَلْحَمْدُ لِلّٰهِ', okunus: 'Elhamdülillâh', meal: "Hamd Allah'a mahsustur.", adet: 33),
  const TesbihatAdimi(ad: 'Allâhu Ekber', arapca: 'اَللّٰهُ اَكْبَرُ', okunus: 'Allâhu ekber', meal: 'Allah en büyüktür.', adet: 33),
  const TesbihatAdimi(
    ad: 'Tevhid',
    arapca: 'لَا اِلٰهَ اِلَّا اللّٰهُ وَحْدَهُ لَا شَرِيكَ لَهُ لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلٰى كُلِّ شَيْءٍ قَدِيرٌ',
    okunus: 'Lâ ilâhe illallâhu vahdehû lâ şerîke leh, lehü\'l-mülkü ve lehü\'l-hamdü ve hüve alâ külli şey\'in kadîr.',
    meal: "Allah'tan başka ilah yoktur; O tektir, ortağı yoktur. Mülk O'nundur, hamd O'nadır. O her şeye kadirdir.",
    adet: 1,
  ),
];
