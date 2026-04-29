import 'package:quran/quran.dart' as q;
import 'dart:io';
void main() {
  File f = File('baqarah.txt');
  List<String> lines = [];
  for (int i = 1; i <= q.getVerseCount(2); i++) {
    lines.add(q.getVerseTranslation(2, i, translation: q.Translation.trSaheeh));
  }
  f.writeAsStringSync(lines.join('\n'));
}
