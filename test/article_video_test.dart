import 'package:anatolian_coins/src/models/article.dart';
import 'package:flutter_test/flutter_test.dart';

// API 1.30.0 `videos` → ArticleVideo (uygulamada küçük resim kartı).
void main() {
  final ham = <String, dynamic>{
    'youtube_id': 'dQw4w9WgXcQ',
    'format': 'shorts',
    'title': ' Zela ',
    'credit': 'Berlin · Brahms',
    'duration_sec': 52,
    'thumbnail_url': 'https://www.numistr.org/images/videolar/dQw4w9WgXcQ.jpg',
    'watch_url': 'https://www.youtube.com/shorts/dQw4w9WgXcQ',
    'published_at': '2026-11-27T16:30:00Z',
  };

  test('alanlar okunur', () {
    final v = ArticleVideo.tryParse(ham)!;
    expect(v.youtubeId, 'dQw4w9WgXcQ');
    expect(v.isShorts, isTrue);
    expect(v.title, 'Zela');
    expect(v.durationLabel, '0:52');
    expect(v.thumbnailUrl, startsWith('https://www.numistr.org/'));
  });

  test('16:9 video ve eksik alanlar', () {
    final v = ArticleVideo.tryParse({...ham, 'format': 'video', 'duration_sec': null, 'thumbnail_url': null,
      'watch_url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'})!;
    expect(v.isShorts, isFalse);
    expect(v.durationLabel, isNull);
    expect(v.thumbnailUrl, isNull);
  });

  test('geçersiz kimlik ya da YouTube dışı adres reddedilir', () {
    expect(ArticleVideo.tryParse({...ham, 'youtube_id': 'abc'}), isNull);
    expect(ArticleVideo.tryParse({...ham, 'watch_url': 'https://evil.example/shorts/dQw4w9WgXcQ'}), isNull);
    expect(ArticleVideo.tryParse('çöp'), isNull);
    expect(ArticleVideo.tryParse({...ham, 'thumbnail_url': 'http://x/y.jpg'})!.thumbnailUrl, isNull);
  });

  test('Article: videos yoksa boş, varsa geçersizler atılır', () {
    final temel = {'id': 1, 'title': 't', 'category': 'c', 'category_id': 2, 'created': '2026-11-26 10:00:00'};
    expect(Article.fromJson(temel).videos, isEmpty);
    final a = Article.fromJson({...temel, 'videos': [ham, {'youtube_id': 'x'}]});
    expect(a.videos.length, 1);
    expect(Article.fromJson(a.toJson()).videos.single.youtubeId, 'dQw4w9WgXcQ');
  });
}
