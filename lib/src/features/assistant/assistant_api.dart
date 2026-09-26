import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';

/// ADR-006 Faz 3 — AI Numizmatik Asistanı istemcisi.
///
/// Sunucu: plg_webservices_numistr `/v1/assistant/chat` (ADR-003). Web widget'ı
/// (Module/numistr-chatbot-widget/numistr-chatbot.js) ile aynı sözleşme:
///   POST {message, conversation_id?, lang} → {answer, conversation_id, sources[], quota{remaining_today}, route}
/// Kimlik Bearer ile gelir (TokenInterceptor); üye 40 / Pro 1000 mesaj-gün sunucuda uygulanır.
/// Anonim kimlik web'de çerezle çalışır; uygulamada çerez yok → giriş zorunlu (ekran CTA gösterir).
class AssistantSource {
  final String title;
  final String url;

  /// Cevap metninde bu kaynağı gösteren [n] numaraları (plugin 1.16.1+).
  /// Sıradan TÜRETİLMEZ: terim parçaları tek sözlük bağlantısında birleştiği
  /// için ilk makale metinde [3] iken listede ikinci olabilir.
  final List<int> refs;

  const AssistantSource({
    required this.title,
    required this.url,
    this.refs = const [],
  });

  /// Metindeki biçimle aynı etiket: "[1]", "[1, 2]"; numarasız kaynakta null.
  String? get refLabel => refs.isEmpty ? null : '[${refs.join(', ')}]';

  factory AssistantSource.fromJson(Map<String, dynamic> j) => AssistantSource(
        title: (j['title'] ?? '').toString(),
        url: (j['url'] ?? '').toString(),
        refs: [
          if (j['refs'] is List)
            for (final r in j['refs'] as List)
              if (r is num) r.toInt(),
        ],
      );
}

class AssistantReply {
  final String answer;
  final int? conversationId;
  final List<AssistantSource> sources;
  final int? remainingToday;
  final String
      route; // coin_search | explain | site | quota | rate_limit | other ...

  const AssistantReply({
    required this.answer,
    required this.conversationId,
    required this.sources,
    required this.remainingToday,
    required this.route,
  });

  bool get quotaExceeded => route == 'quota';
  bool get rateLimited => route == 'rate_limit';

  factory AssistantReply.fromJson(Map<String, dynamic> j) {
    final rawSources = j['sources'];
    final sources = <AssistantSource>[];
    if (rawSources is List) {
      for (final s in rawSources) {
        if (s is Map<String, dynamic>) {
          final src = AssistantSource.fromJson(s);
          if (src.url.isNotEmpty) sources.add(src);
        }
      }
    }
    int? remaining;
    final quota = j['quota'];
    if (quota is Map && quota['remaining_today'] is num) {
      remaining = (quota['remaining_today'] as num).toInt();
    }
    return AssistantReply(
      answer: (j['answer'] ?? '').toString(),
      conversationId: j['conversation_id'] is num
          ? (j['conversation_id'] as num).toInt()
          : int.tryParse('${j['conversation_id'] ?? ''}'),
      sources: sources,
      remainingToday: remaining,
      route: (j['route'] ?? '').toString(),
    );
  }
}

class AssistantAuthRequiredException implements Exception {}

class AssistantApi {
  final ApiClient _client;
  AssistantApi(this._client);

  Future<AssistantReply> chat({
    required String message,
    int? conversationId,
    required String lang,
  }) async {
    try {
      final res = await _client.dio.post(
        '/assistant/chat',
        data: {
          'message': message,
          if (conversationId != null) 'conversation_id': conversationId,
          'lang': lang == 'en' ? 'en' : 'tr',
        },
        options: Options(contentType: Headers.jsonContentType),
      );
      final data = res.data;
      if (data is Map<String, dynamic>) return AssistantReply.fromJson(data);
      throw Exception('unexpected response');
    } on DioException catch (e) {
      debugPrint('[Assistant] ${e.response?.statusCode} ${e.message}');
      if (e.response?.statusCode == 401) throw AssistantAuthRequiredException();
      // 429: sunucu adil kullanım — gövde JSON ise mesajı olduğu gibi göster
      final body = e.response?.data;
      if (e.response?.statusCode == 429 && body is Map<String, dynamic>) {
        return AssistantReply(
          answer: (body['answer'] ?? body['message'] ?? '').toString(),
          conversationId: conversationId,
          sources: const [],
          remainingToday: 0,
          route: 'rate_limit',
        );
      }
      rethrow;
    }
  }
}

final assistantApiProvider = Provider<AssistantApi>((ref) {
  return AssistantApi(ref.read(apiClientProvider));
});
