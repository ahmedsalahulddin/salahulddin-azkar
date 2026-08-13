import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/services/section_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The property that matters most here is that the app never hides anything
/// because it could not reach the server.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SectionConfig.settings.value = {};
  });

  group('fails open', () {
    test('with no configuration at all, every section shows', () {
      for (final key in ['adhkar', 'quran', 'library', 'anything']) {
        expect(SectionConfig.isVisible(key), isTrue,
            reason: '$key must show when nothing is configured');
      }
    });

    test('a section missing from the configuration still shows', () async {
      SharedPreferences.setMockInitialValues({
        '@noor_section_config': jsonEncode([
          {'key': 'adhkar', 'title': 'الأذكار', 'enabled': false, 'sort_order': 1},
        ]),
      });
      await SectionConfig.load();

      expect(SectionConfig.isVisible('adhkar'), isFalse);
      // Never configured, so it is not hidden.
      expect(SectionConfig.isVisible('quran'), isTrue);
    });

    test('a corrupt cache does not hide anything', () async {
      SharedPreferences.setMockInitialValues(
          {'@noor_section_config': 'not json at all'});
      await SectionConfig.load();

      expect(SectionConfig.isVisible('adhkar'), isTrue);
      expect(SectionConfig.isVisible('quran'), isTrue);
    });
  });

  group('reading the configuration', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({
        '@noor_section_config': jsonEncode([
          {'key': 'quran', 'title': 'القرآن', 'enabled': true, 'sort_order': 1},
          {'key': 'adhkar', 'title': 'الأذكار', 'enabled': true, 'sort_order': 2},
          {'key': 'videos', 'title': 'مرئيات', 'enabled': false, 'sort_order': 3},
        ]),
      });
      await SectionConfig.load();
    });

    test('hidden sections are hidden, visible ones are not', () {
      expect(SectionConfig.isVisible('quran'), isTrue);
      expect(SectionConfig.isVisible('adhkar'), isTrue);
      expect(SectionConfig.isVisible('videos'), isFalse);
    });

    test('order comes from the configuration, not the built-in list', () {
      // Quran is listed second in the app but first here.
      expect(SectionConfig.orderOf('quran', 99), 1);
      expect(SectionConfig.orderOf('adhkar', 99), 2);
    });

    test('an unknown section keeps its built-in position', () {
      expect(SectionConfig.orderOf('library', 42), 42);
    });
  });

  test('a signed-out reader is never an admin', () async {
    expect(await SectionConfig.isAdmin(), isFalse);
  });
}
