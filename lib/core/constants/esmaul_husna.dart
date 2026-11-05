/// Esmâ-ül Hüsnâ: Allah'ın güzel isimleri (Tirmizî rivayetindeki 99 isim).
/// Okunuş ve anlamlar Türkiye'de yaygın kullanılan (Diyanet) biçimdedir.
class Esma {
  final int no;
  final String okunus;
  final String arapca;
  final String anlam;
  const Esma(this.no, this.okunus, this.arapca, this.anlam);

  /// Zikirde okunuş: "Yâ Rahmân" gibi (Allah lafzı ve bileşik isimler olduğu gibi)
  String get zikir {
    if (no == 1) return 'Allah';
    final ad = okunus.replaceFirst(RegExp(r"^(el-|er-|es-|eş-|et-|ez-|ed-|en-)"), '');
    return 'Yâ ${ad[0].toUpperCase()}${ad.substring(1)}';
  }

  /// Her gün başka bir isim (yılın gününe göre, herkes için aynı)
  static Esma gunun([DateTime? tarih]) {
    final t = tarih ?? DateTime.now();
    final yilinGunu = t.difference(DateTime(t.year)).inDays;
    return esmaulHusna[(t.year * 7 + yilinGunu) % esmaulHusna.length];
  }
}

const List<Esma> esmaulHusna = [
  Esma(1, 'Allah', 'الله', 'Eşi ve benzeri olmayan, bütün noksan sıfatlardan uzak, bütün güzel isimleri ve kemal sıfatları kendinde toplayan yüce varlığın özel adı.'),
  Esma(2, 'er-Rahmân', 'الرَّحْمٰنُ', 'Dünyada bütün yaratılmışlara merhamet eden, rahmetiyle her şeyi kuşatan.'),
  Esma(3, 'er-Rahîm', 'الرَّحِيمُ', 'Ahirette müminlere sonsuz rahmet ve ikramda bulunan.'),
  Esma(4, 'el-Melik', 'الْمَلِكُ', 'Mülkün ve kâinatın gerçek sahibi, mülkü ve saltanatı sürekli olan.'),
  Esma(5, 'el-Kuddûs', 'الْقُدُّوسُ', 'Her türlü eksiklikten ve kusurdan uzak, tertemiz olan.'),
  Esma(6, 'es-Selâm', 'السَّلَامُ', 'Kullarını tehlikelerden selamete çıkaran; her türlü ayıp ve kusurdan salim olan.'),
  Esma(7, 'el-Mü\'min', 'الْمُؤْمِنُ', 'Güven veren, gönüllere iman nuru veren, kullarını koruyan.'),
  Esma(8, 'el-Müheymin', 'الْمُهَيْمِنُ', 'Her şeyi görüp gözeten, koruyan ve yöneten.'),
  Esma(9, 'el-Azîz', 'الْعَزِيزُ', 'İzzet sahibi, mağlup edilemeyen, her şeye galip olan.'),
  Esma(10, 'el-Cebbâr', 'الْجَبَّارُ', 'Azamet ve kudret sahibi; dilediğini yapan, kırılanı onaran.'),
  Esma(11, 'el-Mütekebbir', 'الْمُتَكَبِّرُ', 'Büyüklükte eşi benzeri olmayan; büyüklük yalnız kendisine ait olan.'),
  Esma(12, 'el-Hâlık', 'الْخَالِقُ', 'Her şeyi yoktan var eden, yaratan.'),
  Esma(13, 'el-Bâri\'', 'الْبَارِئُ', 'Her şeyi kusursuz ve birbirine uyumlu biçimde yaratan.'),
  Esma(14, 'el-Musavvir', 'الْمُصَوِّرُ', 'Varlıklara şekil ve suret veren.'),
  Esma(15, 'el-Gaffâr', 'الْغَفَّارُ', 'Günahları örten ve çokça bağışlayan.'),
  Esma(16, 'el-Kahhâr', 'الْقَهَّارُ', 'Her şeye galip gelen, karşı konulamayan.'),
  Esma(17, 'el-Vehhâb', 'الْوَهَّابُ', 'Karşılıksız nimetler veren, bol bol bağışta bulunan.'),
  Esma(18, 'er-Rezzâk', 'الرَّزَّاقُ', 'Bütün canlıların rızkını veren.'),
  Esma(19, 'el-Fettâh', 'الْفَتَّاحُ', 'Her türlü darlığı açan, kolaylık ve hayır kapılarını açan.'),
  Esma(20, 'el-Alîm', 'الْعَلِيمُ', 'Gizli ve açık her şeyi en ince ayrıntısına kadar bilen.'),
  Esma(21, 'el-Kâbıd', 'الْقَابِضُ', 'Dilediğine darlık veren, rızkı ve ruhları kabzeden.'),
  Esma(22, 'el-Bâsıt', 'الْبَاسِطُ', 'Dilediğine bolluk ve genişlik veren.'),
  Esma(23, 'el-Hâfıd', 'الْخَافِضُ', 'Dilediğini alçaltan.'),
  Esma(24, 'er-Râfi\'', 'الرَّافِعُ', 'Dilediğini yükselten, şeref veren.'),
  Esma(25, 'el-Muiz', 'الْمُعِزُّ', 'Dilediğini aziz eden, izzet veren.'),
  Esma(26, 'el-Müzil', 'الْمُذِلُّ', 'Dilediğini zillete düşüren.'),
  Esma(27, 'es-Semî\'', 'السَّمِيعُ', 'Her şeyi işiten, duaları duyan.'),
  Esma(28, 'el-Basîr', 'الْبَصِيرُ', 'Gizli açık her şeyi gören.'),
  Esma(29, 'el-Hakem', 'الْحَكَمُ', 'Mutlak hâkim; hakkı batıldan ayıran, hükmüne itiraz edilemeyen.'),
  Esma(30, 'el-Adl', 'الْعَدْلُ', 'Mutlak adalet sahibi, asla zulmetmeyen.'),
  Esma(31, 'el-Latîf', 'اللَّطِيفُ', 'Lütfu ve ihsanı bol; her şeyin inceliğini bilen.'),
  Esma(32, 'el-Habîr', 'الْخَبِيرُ', 'Her şeyin iç yüzünden haberdar olan.'),
  Esma(33, 'el-Halîm', 'الْحَلِيمُ', 'Cezalandırmada acele etmeyen, yumuşak davranan.'),
  Esma(34, 'el-Azîm', 'الْعَظِيمُ', 'Büyüklüğü akılla kavranamayacak kadar yüce olan.'),
  Esma(35, 'el-Gafûr', 'الْغَفُورُ', 'Bağışlaması ve affı pek çok olan.'),
  Esma(36, 'eş-Şekûr', 'الشَّكُورُ', 'Az amele çok karşılık veren, şükredenleri mükâfatlandıran.'),
  Esma(37, 'el-Aliyy', 'الْعَلِيُّ', 'Yüceler yücesi, her şeyin üstünde olan.'),
  Esma(38, 'el-Kebîr', 'الْكَبِيرُ', 'Her şeyden büyük, büyüklükte benzeri olmayan.'),
  Esma(39, 'el-Hafîz', 'الْحَفِيظُ', 'Her şeyi koruyan ve muhafaza eden.'),
  Esma(40, 'el-Mukît', 'الْمُقِيتُ', 'Her yaratılmışın azığını ve gücünü veren.'),
  Esma(41, 'el-Hasîb', 'الْحَسِيبُ', 'Kullarının hesabını en iyi gören, kendisine güvenene yeten.'),
  Esma(42, 'el-Celîl', 'الْجَلِيلُ', 'Celal ve azamet sahibi.'),
  Esma(43, 'el-Kerîm', 'الْكَرِيمُ', 'Keremi, cömertliği ve ikramı bol olan.'),
  Esma(44, 'er-Rakîb', 'الرَّقِيبُ', 'Her an her şeyi gözetleyen.'),
  Esma(45, 'el-Mücîb', 'الْمُجِيبُ', 'Duaları kabul eden, isteklere karşılık veren.'),
  Esma(46, 'el-Vâsi\'', 'الْوَاسِعُ', 'Rahmeti, ilmi ve kudreti her şeyi kuşatan.'),
  Esma(47, 'el-Hakîm', 'الْحَكِيمُ', 'Her işi hikmetli, her emri yerinde olan.'),
  Esma(48, 'el-Vedûd', 'الْوَدُودُ', 'Kullarını seven, sevilmeye en layık olan.'),
  Esma(49, 'el-Mecîd', 'الْمَجِيدُ', 'Şanı ve şerefi yüce olan.'),
  Esma(50, 'el-Bâis', 'الْبَاعِثُ', 'Ölüleri dirilten, peygamberler gönderen.'),
  Esma(51, 'eş-Şehîd', 'الشَّهِيدُ', 'Her şeye şahit olan, her zaman her yerde hazır olan.'),
  Esma(52, 'el-Hakk', 'الْحَقُّ', 'Varlığı hiç değişmeden duran; hakkın ta kendisi.'),
  Esma(53, 'el-Vekîl', 'الْوَكِيلُ', 'Kendisine güvenip dayananların işlerini en güzel sonuca ulaştıran.'),
  Esma(54, 'el-Kaviyy', 'الْقَوِيُّ', 'Kudreti en üstün, her şeye gücü yeten.'),
  Esma(55, 'el-Metîn', 'الْمَتِينُ', 'Kuvveti sarsılmaz, hiç yorulmayan.'),
  Esma(56, 'el-Veliyy', 'الْوَلِيُّ', 'İnananların dostu ve yardımcısı.'),
  Esma(57, 'el-Hamîd', 'الْحَمِيدُ', 'Her türlü övgüye layık olan.'),
  Esma(58, 'el-Muhsî', 'الْمُحْصِي', 'Her şeyin sayısını bilen.'),
  Esma(59, 'el-Mübdi\'', 'الْمُبْدِئُ', 'Örneksiz olarak ilk defa yaratan.'),
  Esma(60, 'el-Muîd', 'الْمُعِيدُ', 'Yok ettiğini yeniden yaratan, ölümden sonra dirilten.'),
  Esma(61, 'el-Muhyî', 'الْمُحْيِي', 'Hayat veren, dirilten.'),
  Esma(62, 'el-Mümît', 'الْمُمِيتُ', 'Ölümü yaratan.'),
  Esma(63, 'el-Hayy', 'الْحَيُّ', 'Ezelî ve ebedî hayat sahibi, diri olan.'),
  Esma(64, 'el-Kayyûm', 'الْقَيُّومُ', 'Kendi zatıyla var olan ve her şeyi ayakta tutan.'),
  Esma(65, 'el-Vâcid', 'الْوَاجِدُ', 'İstediğini istediği anda bulan, hiçbir şeye muhtaç olmayan.'),
  Esma(66, 'el-Mâcid', 'الْمَاجِدُ', 'Kadri ve şanı büyük, cömertliği bol olan.'),
  Esma(67, 'el-Vâhid', 'الْوَاحِدُ', 'Zatında, sıfatlarında ve işlerinde tek olan.'),
  Esma(68, 'es-Samed', 'الصَّمَدُ', 'Hiçbir şeye muhtaç olmayan, her şeyin kendisine muhtaç olduğu.'),
  Esma(69, 'el-Kâdir', 'الْقَادِرُ', 'Dilediğini yapmaya gücü yeten.'),
  Esma(70, 'el-Muktedir', 'الْمُقْتَدِرُ', 'Her şeye gücü yeten, kudret sahiplerinin de üzerinde kudreti olan.'),
  Esma(71, 'el-Mukaddim', 'الْمُقَدِّمُ', 'Dilediğini öne alan.'),
  Esma(72, 'el-Muahhir', 'الْمُؤَخِّرُ', 'Dilediğini geriye bırakan.'),
  Esma(73, 'el-Evvel', 'الْأَوَّلُ', 'Varlığının başlangıcı olmayan.'),
  Esma(74, 'el-Âhir', 'الْآخِرُ', 'Varlığının sonu olmayan.'),
  Esma(75, 'ez-Zâhir', 'الظَّاهِرُ', 'Varlığı delilleriyle apaçık olan.'),
  Esma(76, 'el-Bâtın', 'الْبَاطِنُ', 'Zatının hakikati akılların idrakinden gizli olan.'),
  Esma(77, 'el-Vâlî', 'الْوَالِي', 'Bütün kâinatı idare eden.'),
  Esma(78, 'el-Müteâlî', 'الْمُتَعَالِي', 'Yaratılmışların sıfatlarından son derece yüce olan.'),
  Esma(79, 'el-Berr', 'الْبَرُّ', 'İyiliği ve ihsanı bol olan.'),
  Esma(80, 'et-Tevvâb', 'التَّوَّابُ', 'Tövbeleri kabul eden, kullarını tövbeye muvaffak kılan.'),
  Esma(81, 'el-Müntakim', 'الْمُنْتَقِمُ', 'Zalimlere hak ettikleri cezayı veren.'),
  Esma(82, 'el-Afüvv', 'الْعَفُوُّ', 'Affı çok olan, günahları silen.'),
  Esma(83, 'er-Raûf', 'الرَّؤُوفُ', 'Çok şefkatli ve merhametli olan.'),
  Esma(84, 'Mâlikü\'l-Mülk', 'مَالِكُ الْمُلْكِ', 'Mülkün ebedî sahibi, mülkünde dilediği gibi tasarruf eden.'),
  Esma(85, 'Zü\'l-Celâli ve\'l-İkrâm', 'ذُو الْجَلَالِ وَالْإِكْرَامِ', 'Celal (büyüklük) ve ikram (cömertlik) sahibi.'),
  Esma(86, 'el-Muksit', 'الْمُقْسِطُ', 'Her işi adaletle yapan, hakkı yerine koyan.'),
  Esma(87, 'el-Câmi\'', 'الْجَامِعُ', 'İstediğini istediği zaman ve yerde toplayan.'),
  Esma(88, 'el-Ganiyy', 'الْغَنِيُّ', 'Hiçbir şeye muhtaç olmayan, zengin olan.'),
  Esma(89, 'el-Muğnî', 'الْمُغْنِي', 'Dilediğini zengin eden.'),
  Esma(90, 'el-Mâni\'', 'الْمَانِعُ', 'Dilemediği şeye engel olan.'),
  Esma(91, 'ed-Dârr', 'الضَّارُّ', 'Elem ve zarar verecek şeyleri de yaratan (imtihan için).'),
  Esma(92, 'en-Nâfi\'', 'النَّافِعُ', 'Fayda ve hayır verecek şeyleri yaratan.'),
  Esma(93, 'en-Nûr', 'النُّورُ', 'Âlemleri nurlandıran, gönüllere nur veren.'),
  Esma(94, 'el-Hâdî', 'الْهَادِي', 'Hidayet veren, doğru yolu gösteren.'),
  Esma(95, 'el-Bedî\'', 'الْبَدِيعُ', 'Eşsiz ve benzersiz şekilde yaratan.'),
  Esma(96, 'el-Bâkî', 'الْبَاقِي', 'Varlığının sonu olmayan, ebedî olan.'),
  Esma(97, 'el-Vâris', 'الْوَارِثُ', 'Her şey yok olduktan sonra baki kalan, her şeyin gerçek sahibi.'),
  Esma(98, 'er-Reşîd', 'الرَّشِيدُ', 'Doğru yolu gösteren; her işi isabetli olan.'),
  Esma(99, 'es-Sabûr', 'الصَّبُورُ', 'Çok sabırlı olan, cezalandırmada acele etmeyen.'),
];
