class CountryCode {
  final String name;
  final String code;   // e.g. "+91"
  final String flag;   // e.g. "🇮🇳"
  final String iso;    // e.g. "IN"
  final int phoneDigits; // exact local phone digits (without country code)

  const CountryCode({
    required this.name,
    required this.code,
    required this.flag,
    required this.iso,
    required this.phoneDigits,
  });

  static const List<CountryCode> defaultCountries = [
    CountryCode(name: 'India',                 code: '+91',  flag: '🇮🇳', iso: 'IN', phoneDigits: 10),
    CountryCode(name: 'United States',         code: '+1',   flag: '🇺🇸', iso: 'US', phoneDigits: 10),
    CountryCode(name: 'United Kingdom',        code: '+44',  flag: '🇬🇧', iso: 'GB', phoneDigits: 10),
    CountryCode(name: 'Canada',                code: '+1',   flag: '🇨🇦', iso: 'CA', phoneDigits: 10),
    CountryCode(name: 'United Arab Emirates',  code: '+971', flag: '🇦🇪', iso: 'AE', phoneDigits: 9),
    CountryCode(name: 'Saudi Arabia',          code: '+966', flag: '🇸🇦', iso: 'SA', phoneDigits: 9),
    CountryCode(name: 'Australia',             code: '+61',  flag: '🇦🇺', iso: 'AU', phoneDigits: 9),
    CountryCode(name: 'Germany',               code: '+49',  flag: '🇩🇪', iso: 'DE', phoneDigits: 10),
    CountryCode(name: 'France',                code: '+33',  flag: '🇫🇷', iso: 'FR', phoneDigits: 9),
    CountryCode(name: 'Singapore',             code: '+65',  flag: '🇸🇬', iso: 'SG', phoneDigits: 8),
    CountryCode(name: 'Malaysia',              code: '+60',  flag: '🇲🇾', iso: 'MY', phoneDigits: 9),
    CountryCode(name: 'Pakistan',              code: '+92',  flag: '🇵🇰', iso: 'PK', phoneDigits: 10),
    CountryCode(name: 'Bangladesh',            code: '+880', flag: '🇧🇩', iso: 'BD', phoneDigits: 10),
    CountryCode(name: 'Nepal',                 code: '+977', flag: '🇳🇵', iso: 'NP', phoneDigits: 10),
    CountryCode(name: 'Sri Lanka',             code: '+94',  flag: '🇱🇰', iso: 'LK', phoneDigits: 9),
    CountryCode(name: 'South Africa',          code: '+27',  flag: '🇿🇦', iso: 'ZA', phoneDigits: 9),
    CountryCode(name: 'Brazil',                code: '+55',  flag: '🇧🇷', iso: 'BR', phoneDigits: 11),
    CountryCode(name: 'Japan',                 code: '+81',  flag: '🇯🇵', iso: 'JP', phoneDigits: 10),
    CountryCode(name: 'Qatar',                 code: '+974', flag: '🇶🇦', iso: 'QA', phoneDigits: 8),
    CountryCode(name: 'Kuwait',                code: '+965', flag: '🇰🇼', iso: 'KW', phoneDigits: 8),
    CountryCode(name: 'Oman',                  code: '+968', flag: '🇴🇲', iso: 'OM', phoneDigits: 8),
    CountryCode(name: 'Indonesia',             code: '+62',  flag: '🇮🇩', iso: 'ID', phoneDigits: 11),
    CountryCode(name: 'Philippines',           code: '+63',  flag: '🇵🇭', iso: 'PH', phoneDigits: 10),
    CountryCode(name: 'Nigeria',               code: '+234', flag: '🇳🇬', iso: 'NG', phoneDigits: 10),
    CountryCode(name: 'Kenya',                 code: '+254', flag: '🇰🇪', iso: 'KE', phoneDigits: 9),
  ];
}
