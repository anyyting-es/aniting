import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/utils/synopsis_utils.dart';

void main() {
  group('cleanSynopsis', () {
    test('handles null and empty', () {
      expect(cleanSynopsis(null), equals(''));
      expect(cleanSynopsis(''), equals(''));
      expect(cleanSynopsis('   \n  '), equals(''));
    });

    test('strips HTML tags and decodes entities', () {
      const input = '<p>Hello <b>World</b>!&quot;It&#039;s anime&amp;manga&quot;</p><br>Second line.';
      final result = cleanSynopsis(input);
      expect(result, contains("Hello World!\"It's anime&manga\""));
      expect(result, contains('Second line.'));
      expect(result.contains('<p>'), isFalse);
      expect(result.contains('<b>'), isFalse);
    });

    test('strips (Source: ...) and [Written by MAL Rewrite]', () {
      const input = '''
The story follows a young hero on a quest.

(Source: Crunchyroll)
[Written by MAL Rewrite]
''';
      final result = cleanSynopsis(input);
      expect(result, equals('The story follows a young hero on a quest.'));
    });

    test('strips Note: and Notes: footers', () {
      const input = '''
A comedic romance series.

Note: Episode 1 aired early at an anime convention.
__Source:__ Official Website
''';
      final result = cleanSynopsis(input);
      expect(result, equals('A comedic romance series.'));
    });

    test('normalizes absurd spaces and excessive linebreaks', () {
      const input = '''
Paragraph 1    with    excessive     spaces.




Paragraph 2 after huge gap.
''';
      final result = cleanSynopsis(input);
      expect(result, equals('Paragraph 1 with excessive spaces.\n\nParagraph 2 after huge gap.'));
    });
  });
}
