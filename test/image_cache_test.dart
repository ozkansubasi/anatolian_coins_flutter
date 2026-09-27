import 'package:anatolian_coins/src/core/image_cache.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sunucunun `no-cache` yanıtını taklit eder: flutter_cache_manager'ın kendi yanıtı
/// bunda geçerliliği sıfırlar (görsel her gösterimde yeniden indirilirdi).
class _NoCacheResponse implements FileServiceResponse {
  @override
  Stream<List<int>> get content => Stream.value([1, 2, 3]);
  @override
  int? get contentLength => 3;
  @override
  int get statusCode => 200;
  @override
  DateTime get validTill => DateTime.now();
  @override
  String? get eTag => 'e1';
  @override
  String get fileExtension => '.jpeg';
}

void main() {
  test('geçerlilik sunucu başlığından değil sabit süreden', () {
    final until = DateTime.now().add(const Duration(days: 7));
    final r = FixedValidityResponse(_NoCacheResponse(), until);
    expect(r.validTill, until);
  });

  test('diğer alanlar olduğu gibi aktarılır', () async {
    final r = FixedValidityResponse(_NoCacheResponse(), DateTime.now());
    expect(r.statusCode, 200);
    expect(r.contentLength, 3);
    expect(r.eTag, 'e1');
    expect(r.fileExtension, '.jpeg');
    expect(await r.content.first, [1, 2, 3]);
  });
}
