import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Uygulamanın görsel önbelleği — sunucunun `Cache-Control` başlığını yok sayar.
///
/// numistr.org `.htaccess`'i `com_numistr` yanıtlarına `no-store, no-cache` basıyor;
/// flutter_cache_manager 3.4.1 `no-cache` görünce geçerliliği sıfırlar → görsel diskte
/// olsa bile HER gösterimde sunucudan yeniden indirilirdi. Varsayılan yönetici üstelik
/// en çok 200 dosya tutuyor; liste önizlemeleri bunu hızla doldurup eskileri siliyordu
/// (paylaşımlı hostta yükü ikiye katlıyordu, 2026-09-27 ölçümü).
///
/// Görsel URL'leri içerikle sabit (`id` + `wm`; HD adresi imzalı ve süreli, her seferinde
/// farklı) → indirilen dosya 7 gün geçerli sayılır, 30 gün kullanılmayan silinir.
class NumistrImageCache {
  NumistrImageCache._();

  static const key = 'numistrImages';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 1000,
      fileService: FixedValidityFileService(const Duration(days: 7)),
    ),
  );
}

/// HTTP ile indirir, ama geçerlilik süresini sunucu başlığından değil sabit süreden alır.
class FixedValidityFileService extends HttpFileService {
  FixedValidityFileService(this.validity, {super.httpClient});

  final Duration validity;

  @override
  Future<FileServiceResponse> get(String url, {Map<String, String>? headers}) async =>
      FixedValidityResponse(await super.get(url, headers: headers), DateTime.now().add(validity));
}

class FixedValidityResponse implements FileServiceResponse {
  FixedValidityResponse(this._inner, this.validTill);

  final FileServiceResponse _inner;

  @override
  final DateTime validTill;

  @override
  Stream<List<int>> get content => _inner.content;

  @override
  int? get contentLength => _inner.contentLength;

  @override
  int get statusCode => _inner.statusCode;

  @override
  String? get eTag => _inner.eTag;

  @override
  String get fileExtension => _inner.fileExtension;
}
