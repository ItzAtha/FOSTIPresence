enum Language {
  english(name: "English", code: 'en'),
  indonesia(name: "Indonesia", code: 'id');

  final String name;
  final String code;

  const Language({required this.name, required this.code});

  static List<Language> get allLanguages {
    return Language.values;
  }
}
