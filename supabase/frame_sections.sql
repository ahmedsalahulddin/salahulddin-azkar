-- Puts the ten Mushaf borders under the dashboard, beside the shelves.
--
-- The keys must match MushafFrame.sectionKey exactly ('frame_' + the id):
-- the app looks each one up by that name, and a typo reads as "not
-- configured", which fails open and simply shows the frame.
--
-- Safe to run more than once.
insert into app_sections (key, title, enabled, sort_order) values
  ('frame_none',        'إطار: بدون إطار',      true, 101),
  ('frame_keyline',     'إطار: خط بسيط',        true, 102),
  ('frame_madinah',     'إطار: مصحف المدينة',   true, 103),
  ('frame_chain',       'إطار: سلسلة معيّنات',  true, 104),
  ('frame_interlace',   'إطار: ضفيرة متشابكة',  true, 105),
  ('frame_arabesque',   'إطار: أرابيسك',        true, 106),
  ('frame_stars',       'إطار: نجوم ثمانية',    true, 107),
  ('frame_rosette',     'إطار: شمسات مذهّبة',   true, 108),
  ('frame_filigree',    'إطار: تذهيب مورّق',    true, 109),
  ('frame_illuminated', 'إطار: تذهيب المصحف',   true, 110)
on conflict (key) do nothing;
