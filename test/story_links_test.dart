import 'package:anatolian_coins/src/features/articles/story_links.dart';
import 'package:anatolian_coins/src/models/article.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hikâye bağlantıları ve günün hikâyesi modeli (28 Kas 2026, API 1.31.0).
void main() {
  Map<String, dynamic> yazi(int id, String baslik) => {
        'id': id,
        'title': baslik,
        'intro': 'Giriş',
        'category': 'Sikke Odağı',
        'category_id': 39,
        'created': '2026-10-17 19:43:11',
      };

  group('Article (günün hikâyesi)', () {
    test('coin + reason okunur', () {
      final a = Article.fromJson({
        ...yazi(34036, 'İskender'),
        'reason': 'today',
        'coin': {'id': 21188, 'title': 'Price 1353', 'thumb_url': 'https://www.numistr.org/index.php?view=gorsel&id=1'},
      });
      expect(a.reason, 'today');
      expect(a.coin?.id, 21188);
      expect(a.coin?.title, 'Price 1353');
      expect(a.coin?.thumbUrl, startsWith('https://'));
      expect(Article.fromJson(a.toJson()).coin?.id, 21188);
    });

    test('eski API: coin ve reason yok → null', () {
      final a = Article.fromJson(yazi(1, 'x'));
      expect(a.coin, isNull);
      expect(a.reason, isNull);
    });

    test('geçersiz sikke → null, https olmayan görsel atılır', () {
      expect(StoryCoin.tryParse({'id': 0, 'title': 'x'}), isNull);
      expect(StoryCoin.tryParse('21188'), isNull);
      expect(Article.fromJson({...yazi(1, 'x'), 'coin': null}).coin, isNull);
      final c = StoryCoin.tryParse({'id': 5, 'title': ' a ', 'thumb_url': 'http://x/y.jpg'});
      expect(c?.thumbUrl, isNull);
      expect(c?.title, 'a');
    });
  });

  group('StoryLinks', () {
    Widget sar(Widget w) => MaterialApp(home: Scaffold(body: w));

    testWidgets('boş liste → hiçbir şey çizilmez', (tester) async {
      await tester.pumpWidget(sar(StoryLinks(stories: const [], onOpen: (_) {})));
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('yazılar listelenir, dokununca kimlik döner', (tester) async {
      final acilan = <int>[];
      final liste = [Article.fromJson(yazi(13038, 'Büyük İskender Tetradrahmisi')), Article.fromJson(yazi(34036, 'İskender ve ardılları'))];
      await tester.pumpWidget(sar(StoryLinks(stories: liste, onOpen: acilan.add)));
      expect(find.text('Büyük İskender Tetradrahmisi'), findsOneWidget);
      expect(find.text('Sikke Odağı'), findsNWidgets(2));
      await tester.tap(find.byKey(const ValueKey('story-34036')));
      expect(acilan, [34036]);
    });

    testWidgets('sıkı biçim: başlık var, kategori yok', (tester) async {
      await tester.pumpWidget(sar(StoryLinks(
        stories: [Article.fromJson(yazi(34066, 'Kydnos'))],
        onOpen: (_) {},
        compact: true,
        heading: 'Bu kentin hikâyeleri',
      )));
      expect(find.text('Bu kentin hikâyeleri'), findsOneWidget);
      expect(find.text('Sikke Odağı'), findsNothing);
    });
  });
}
