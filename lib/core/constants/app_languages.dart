/// Supported app languages shared across all screens.
class AppLanguage {
  const AppLanguage(this.code, this.name, this.flag);
  final String code;
  final String name;
  final String flag;
}

const kAppLanguages = [
  AppLanguage('en', 'English', '🇺🇸'),
  AppLanguage('es', 'Spanish', '🇪🇸'),
  AppLanguage('fr', 'French', '🇫🇷'),
  AppLanguage('de', 'German', '🇩🇪'),
  AppLanguage('hi', 'Hindi', '🇮🇳'),
  AppLanguage('ta', 'Tamil', '🇮🇳'),
  AppLanguage('pt', 'Portuguese', '🇧🇷'),
  AppLanguage('ja', 'Japanese', '🇯🇵'),
  AppLanguage('ko', 'Korean', '🇰🇷'),
];

AppLanguage appLanguageByCode(String code) =>
    kAppLanguages.firstWhere((l) => l.code == code,
        orElse: () => kAppLanguages.first);
