import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompt_core/domain/entities/script.dart';

void main() {
  group('Script Entity', () {
    test('should create a valid script', () {
      final script = Script(
        id: '123',
        title: 'Test Script',
        content: 'This is a test script content.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(script.id, '123');
      expect(script.title, 'Test Script');
      expect(script.content, 'This is a test script content.');
      expect(script.wordCount, 6);
    });

    test('should calculate estimated read time correctly', () {
      final script = Script(
        id: '123',
        title: 'Test Script',
        content: List.generate(200, (_) => 'word').join(' '),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Assuming average reading speed of 150 words per minute
      expect(script.estimatedReadTime.inMinutes, 1);
    });
  });
}
