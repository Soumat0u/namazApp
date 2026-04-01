class ReligiousDay {
  final String dateStr; // yyyy-MM-dd formatında miladi tarih
  final String englishName;
  final String turkishName;
  final String? description;

  ReligiousDay({
    required this.dateStr,
    required this.englishName,
    required this.turkishName,
    this.description,
  });

  factory ReligiousDay.fromJson(Map<String, dynamic> json) {
    return ReligiousDay(
      dateStr: json['dateStr'],
      englishName: json['englishName'],
      turkishName: json['turkishName'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dateStr': dateStr,
      'englishName': englishName,
      'turkishName': turkishName,
      'description': description,
    };
  }
}
