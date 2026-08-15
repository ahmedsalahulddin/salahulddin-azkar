-- Puts the greeting cards under the dashboard, beside the shelves and the
-- borders. Keys must match GreetingCard.sectionKey exactly ('card_' + the id):
-- a key that does not match reads as "not configured", which fails open and
-- simply shows the card, so a typo here is a switch that silently does
-- nothing.
--
-- Safe to run more than once.
insert into app_sections (key, title, enabled, sort_order) values
  ('card_morning', 'كرت: صَبَاحُ الخَيْرِ', true, 201),
  ('card_evening', 'كرت: مَسَاءُ الخَيْرِ', true, 202),
  ('card_friday', 'كرت: جُمُعَةٌ مُبَارَكَة', true, 203),
  ('card_reminder', 'كرت: ذَكِّرْ', true, 204),
  ('card_goodnight', 'كرت: تُصْبِحُ عَلَى خَيْر', true, 205),
  ('card_dua', 'كرت: دُعَاءٌ لَكَ', true, 206),
  ('card_ramadan', 'كرت: رَمَضَانُ مُبَارَك', true, 207),
  ('card_laylat-alqadr', 'كرت: لَيْلَةُ القَدْر', true, 208),
  ('card_eid-fitr', 'كرت: عِيدُ فِطْرٍ مُبَارَك', true, 209),
  ('card_eid-adha', 'كرت: عِيدُ أَضْحَى مُبَارَك', true, 210),
  ('card_hajj', 'كرت: حَجٌّ مَبْرُور', true, 211),
  ('card_hijri-year', 'كرت: عَامٌ هِجْرِيٌّ سَعِيد', true, 212),
  ('card_newborn', 'كرت: مَبْرُوكٌ المَوْلُود', true, 213),
  ('card_recovery', 'كرت: شَفَاكَ اللهُ وَعَافَاك', true, 214),
  ('card_marriage', 'كرت: بَارَكَ اللهُ لَكُمَا', true, 215),
  ('card_success', 'كرت: مَبْرُوكٌ النَّجَاح', true, 216),
  ('card_condolence', 'كرت: عَظَّمَ اللهُ أَجْرَكُم', true, 217),
  ('card_thanks', 'كرت: جَزَاكَ اللهُ خَيْرًا', true, 218)
on conflict (key) do nothing;
