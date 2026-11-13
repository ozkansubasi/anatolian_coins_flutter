// M36 (13 Kas 2026): 429'da GET kısa bekleyip bir kez yeniden denenir; uzun süre
// (günlük tavan) ya da süre bilgisi yoksa denenmez. iPhone'da kaydırmada 429 gelince
// liste siliniyordu (12 Kas).
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anatolian_coins/src/core/rate_limit_retry.dart';

/// Sırayla yanıt veren sahte HTTP katmanı.
class _SeqAdapter implements HttpClientAdapter {
  _SeqAdapter(this.responses);

  final List<(int, String, Map<String, List<String>>)> responses;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final (status, body, headers) = responses[calls < responses.length ? calls : responses.length - 1];
    calls++;
    return ResponseBody.fromString(body, status, headers: {
      Headers.contentTypeHeader: ['application/json; charset=utf-8'],
      ...headers,
    });
  }

  @override
  void close({bool force = false}) {}
}

const _ok = (200, '{"data":[]}', <String, List<String>>{});

(Dio, _SeqAdapter, List<Duration>) _make(List<(int, String, Map<String, List<String>>)> seq) {
  final adapter = _SeqAdapter(seq);
  final dio = Dio(BaseOptions(baseUrl: 'https://x/v1', responseType: ResponseType.plain))
    ..httpClientAdapter = adapter;
  final slept = <Duration>[];
  dio.interceptors.add(RateLimitRetryInterceptor(dio, sleep: (d) async => slept.add(d)));
  return (dio, adapter, slept);
}

void main() {
  test('429 + Retry-After 3 → 3 sn bekler, bir kez yeniden dener, başarır', () async {
    final (dio, adapter, slept) = _make([
      (429, '{"errors":[{"code":429}]}', {'retry-after': ['3']}),
      _ok,
    ]);
    final res = await dio.get('/variants');
    expect(res.statusCode, 200);
    expect(adapter.calls, 2);
    expect(slept, [const Duration(seconds: 3)]);
  });

  test('süre gövdede (errors[0].retry_after) → okunur', () async {
    final (dio, adapter, slept) = _make([
      (429, '{"errors":[{"code":429,"error_code":"RATE_LIMITED","retry_after":5}]}', {}),
      _ok,
    ]);
    await dio.get('/variants/1/images');
    expect(adapter.calls, 2);
    expect(slept, [const Duration(seconds: 5)]);
  });

  test('ikinci 429 → üçüncü deneme yok, hata yukarı', () async {
    final (dio, adapter, _) = _make([
      (429, '{}', {'retry-after': ['1']}),
      (429, '{}', {'retry-after': ['1']}),
      _ok,
    ]);
    final e = await dio.get('/variants').then<Object?>((_) => null, onError: (Object e) => e);
    expect(isRateLimited(e!), isTrue);
    expect(adapter.calls, 2);
  });

  test('uzun bekleme (günlük tavan) → denenmez', () async {
    final (dio, adapter, slept) = _make([
      (429, '{"errors":[{"retry_after":40000}]}', {'retry-after': ['40000']}),
      _ok,
    ]);
    final e = await dio.get('/variants').then<Object?>((_) => null, onError: (Object e) => e);
    expect(isRateLimited(e!), isTrue);
    expect(adapter.calls, 1);
    expect(slept, isEmpty);
  });

  test('süre bilgisi yok (eski API) → denenmez', () async {
    final (dio, adapter, _) = _make([(429, '{"errors":[{"code":429}]}', {}), _ok]);
    await expectLater(dio.get('/variants'), throwsA(isA<DioException>()));
    expect(adapter.calls, 1);
  });

  test('POST yeniden denenmez (yan etkili olabilir)', () async {
    final (dio, adapter, _) = _make([(429, '{}', {'retry-after': ['1']}), _ok]);
    await expectLater(dio.post('/recognize'), throwsA(isA<DioException>()));
    expect(adapter.calls, 1);
  });

  test('0 sn → en az 1 sn beklenir; 429 dışı hata dokunulmaz', () async {
    final (dio, _, slept) = _make([(429, '{}', {'retry-after': ['0']}), _ok]);
    await dio.get('/variants');
    expect(slept, [const Duration(seconds: 1)]);

    final (dio2, adapter2, _) = _make([(500, '{}', {'retry-after': ['1']}), _ok]);
    await expectLater(dio2.get('/variants'), throwsA(isA<DioException>()));
    expect(adapter2.calls, 1);
  });
}
