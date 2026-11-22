import 'package:anatolian_coins/src/features/assistant/assistant_api.dart';
import 'package:anatolian_coins/src/features/assistant/assistant_screen.dart';
import 'package:anatolian_coins/src/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kaynak numaraları sunucudan gelir, sıradan türetilmez', () {
    final reply = AssistantReply.fromJson({
      'answer': 'Kistophoros [1, 2] ... Bergama [3].',
      'sources': [
        {
          'title': 'Numizmatik terimler',
          'url': 'https://numistr.org/tr/numizmatik-karsiliklar',
          'refs': [1, 2]
        },
        {
          'title': 'Kistophoros',
          'url': 'https://numistr.org/tr/blog/a',
          'refs': [3]
        },
      ],
    });
    expect(reply.sources[0].refLabel, '[1, 2]');
    expect(reply.sources[1].refLabel, '[3]');
  });

  test('refs olmayan (eski sunucu / araç rotası) kaynak numarasız', () {
    final s = AssistantSource.fromJson(
        {'title': 'T', 'url': 'https://numistr.org/x'});
    expect(s.refs, isEmpty);
    expect(s.refLabel, isNull);
  });

  test('bağlantısız terim satırı korunur, numaralar kaymaz (plugin 1.27.0)', () {
    final reply = AssistantReply.fromJson({
      'answer': '',
      'sources': [
        {
          'title': 'Dekadrahmi',
          'url': '',
          'refs': [1, 2, 4],
          'kind': 'term'
        },
        {
          'title': 'Drahmi',
          'url':
              'https://numistr.org/tr/numizmatik-karsiliklar#:~:text=Drahmi%20%28Drachm%29',
          'refs': [3],
          'kind': 'term'
        },
        {'title': '', 'url': '', 'refs': [5]},
        {
          'title': 'Makale',
          'url': 'https://numistr.org/tr/blog/b',
          'refs': [6]
        },
      ],
    });
    expect(reply.sources.map((s) => s.title), ['Dekadrahmi', 'Drahmi', 'Makale']);
    expect(reply.sources[0].refLabel, '[1, 2, 4]');
    expect(reply.sources[0].isTerm, isTrue);
    expect(reply.sources[0].isLinked, isFalse);
    expect(reply.sources[1].isLinked, isTrue);
    expect(reply.sources[2].isTerm, isFalse);
    expect(reply.sources[2].refLabel, '[6]');
  });

  test('yalnız http(s) adresi bağlantı sayılır', () {
    expect(const AssistantSource(title: 'a', url: 'javascript:alert(1)').isLinked,
        isFalse);
    expect(const AssistantSource(title: 'a', url: '/tr/blog').isLinked, isFalse);
    expect(const AssistantSource(title: 'a', url: 'https://numistr.org/x').isLinked,
        isTrue);
  });

  for (final locale in const [Locale('tr'), Locale('en')]) {
    testWidgets('her kaynak ayrı satır; bağlantısız terim etiketli (${locale.languageCode})',
        (tester) async {
      const sources = [
        AssistantSource(title: 'Dekadrahmi', url: '', refs: [1, 2], kind: 'term'),
        AssistantSource(
            title: 'Drahmi',
            url: 'https://numistr.org/tr/numizmatik-karsiliklar#:~:text=Drahmi',
            refs: [3],
            kind: 'term'),
        AssistantSource(title: 'Makale', url: 'https://numistr.org/tr/blog/b', refs: [4]),
      ];
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('tr')],
        home: Scaffold(
          body: Column(children: [
            for (final s in sources) AssistantSourceRow(source: s, color: Colors.black),
          ]),
        ),
      ));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.byType(Column).first));
      final kb = l10n.translate('assistant_source_kb');
      expect(kb, isNot('assistant_source_kb'));

      expect(find.byType(AssistantSourceRow), findsNWidgets(3));
      // Bağlantılı iki satır dokunulabilir, terim satırı değil.
      expect(find.byType(InkWell), findsNWidgets(2));
      expect(find.byIcon(Icons.open_in_new), findsNWidgets(2));
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
      // Etiket yalnız bağlantısız terim satırında.
      expect(find.textContaining(kb, findRichText: true), findsOneWidget);
      expect(find.textContaining('[1, 2] Dekadrahmi', findRichText: true), findsOneWidget);
      // Satırlar alt alta: her biri bir öncekinin altında.
      final y = [
        for (final e in find.byType(AssistantSourceRow).evaluate())
          tester.getTopLeft(find.byWidget(e.widget)).dy
      ];
      expect(y[0] < y[1] && y[1] < y[2], isTrue);
    });
  }

  test('alt bilgi metni: katalog + yapay zekâ yardımı (22.11.2026)', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final tr = await AppLocalizations.loadTable('tr');
    final en = await AppLocalizations.loadTable('en');
    expect(tr['assistant_disclaimer'],
        startsWith('Yanıtlar NumisTR kataloğundan yapay zekâ yardımıyla oluşturulmaktadır'));
    expect(en['assistant_disclaimer'],
        startsWith('Answers are generated from the NumisTR catalogue with the help of AI'));
  });
}
