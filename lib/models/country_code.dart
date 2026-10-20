class CountryCode {
  final String name;
  final String code; // e.g. "+91"
  final String flag; // e.g. "🇮🇳"
  final String iso;  // e.g. "IN"

  const CountryCode({
    required this.name,
    required this.code,
    required this.flag,
    required this.iso,
  });

  static const List<CountryCode> defaultCountries = [
    CountryCode(name: 'India', code: '+91', flag: '🇮🇳', iso: 'IN'),
    CountryCode(name: 'United States', code: '+1', flag: '🇺🇸', iso: 'US'),
    CountryCode(name: 'United Kingdom', code: '+44', flag: '🇬🇧', iso: 'GB'),
    CountryCode(name: 'Canada', code: '+1', flag: '🇨🇦', iso: 'CA'),
    CountryCode(name: 'United Arab Emirates', code: '+971', flag: '🇦🇪', iso: 'AE'),
    CountryCode(name: 'Saudi Arabia', code: '+966', flag: '🇸🇦', iso: 'SA'),
    CountryCode(name: 'Australia', code: '+61', flag: '🇦🇺', iso: 'AU'),
    CountryCode(name: 'Germany', code: '+49', flag: '🇩🇪', iso: 'DE'),
    CountryCode(name: 'France', code: '+33', flag: '🇫🇷', iso: 'FR'),
    CountryCode(name: 'Singapore', code: '+65', flag: '🇸🇬', iso: 'SG'),
    CountryCode(name: 'Malaysia', code: '+60', flag: '🇲🇾', iso: 'MY'),
    CountryCode(name: 'Pakistan', code: '+92', flag: '🇵🇰', iso: 'PK'),
    CountryCode(name: 'Bangladesh', code: '+880', flag: '🇧🇩', iso: 'BD'),
    CountryCode(name: 'Nepal', code: '+977', flag: '🇳🇵', iso: 'NP'),
    CountryCode(name: 'Sri Lanka', code: '+94', flag: '🇱🇰', iso: 'LK'),
    CountryCode(name: 'South Africa', code: '+27', flag: '🇿🇦', iso: 'ZA'),
    CountryCode(name: 'Brazil', code: '+55', flag: '🇧🇷', iso: 'BR'),
    CountryCode(name: 'Japan', code: '+81', flag: '🇯🇵', iso: 'JP'),
    CountryCode(name: 'Qatar', code: '+974', flag: '🇶🇦', iso: 'QA'),
    CountryCode(name: 'Kuwait', code: '+965', flag: '🇰🇼', iso: 'KW'),
    CountryCode(name: 'Oman', code: '+968', flag: '🇴🇲', iso: 'OM'),
    CountryCode(name: 'Indonesia', code: '+62', flag: '🇮🇩', iso: 'ID'),
    CountryCode(name: 'Philippines', code: '+63', flag: '🇵🇭', iso: 'PH'),
    CountryCode(name: 'Nigeria', code: '+234', flag: '🇳🇬', iso: 'NG'),
    CountryCode(name: 'Kenya', code: '+254', flag: '🇰🇪', iso: 'KE'),
  ];
}
