import '../services/tahfeez_lang.dart';

/// Countries a teacher may pick, so the directory can filter on a fixed
/// value rather than however each teacher happened to spell it.
const tahfeezCountries = <(String code, String ar, String en)>[
  ('SA', 'السعودية', 'Saudi Arabia'),
  ('EG', 'مصر', 'Egypt'),
  ('AE', 'الإمارات', 'UAE'),
  ('KW', 'الكويت', 'Kuwait'),
  ('QA', 'قطر', 'Qatar'),
  ('BH', 'البحرين', 'Bahrain'),
  ('OM', 'عُمان', 'Oman'),
  ('YE', 'اليمن', 'Yemen'),
  ('JO', 'الأردن', 'Jordan'),
  ('PS', 'فلسطين', 'Palestine'),
  ('LB', 'لبنان', 'Lebanon'),
  ('SY', 'سوريا', 'Syria'),
  ('IQ', 'العراق', 'Iraq'),
  ('SD', 'السودان', 'Sudan'),
  ('LY', 'ليبيا', 'Libya'),
  ('TN', 'تونس', 'Tunisia'),
  ('DZ', 'الجزائر', 'Algeria'),
  ('MA', 'المغرب', 'Morocco'),
  ('MR', 'موريتانيا', 'Mauritania'),
  ('SO', 'الصومال', 'Somalia'),
  ('DJ', 'جيبوتي', 'Djibouti'),
  ('TR', 'تركيا', 'Türkiye'),
  ('PK', 'باكستان', 'Pakistan'),
  ('IN', 'الهند', 'India'),
  ('BD', 'بنغلاديش', 'Bangladesh'),
  ('ID', 'إندونيسيا', 'Indonesia'),
  ('MY', 'ماليزيا', 'Malaysia'),
  ('NG', 'نيجيريا', 'Nigeria'),
  ('SN', 'السنغال', 'Senegal'),
  ('NE', 'النيجر', 'Niger'),
  ('ML', 'مالي', 'Mali'),
  ('AF', 'أفغانستان', 'Afghanistan'),
  ('IR', 'إيران', 'Iran'),
  ('US', 'الولايات المتحدة', 'United States'),
  ('GB', 'بريطانيا', 'United Kingdom'),
  ('CA', 'كندا', 'Canada'),
  ('FR', 'فرنسا', 'France'),
  ('DE', 'ألمانيا', 'Germany'),
  ('AU', 'أستراليا', 'Australia'),
  ('OTHER', 'دولة أخرى', 'Other'),
];

String countryName(String code) {
  for (final (c, ar, en) in tahfeezCountries) {
    if (c == code) return TahfeezLang.code == 'ar' ? ar : en;
  }
  return code;
}
