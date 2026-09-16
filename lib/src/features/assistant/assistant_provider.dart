import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'assistant_api.dart';

enum AssistantRole { user, assistant }

class AssistantMessage {
  final AssistantRole role;
  final String text;
  final List<AssistantSource> sources;
  final String route;
  final DateTime at;

  AssistantMessage({
    required this.role,
    required this.text,
    this.sources = const [],
    this.route = '',
    DateTime? at,
  }) : at = at ?? DateTime.now();
}

class AssistantState {
  final List<AssistantMessage> messages;
  final bool sending;
  final int? conversationId;
  final int? remainingToday;
  /// 'auth' | 'network' | null — ekran l10n anahtarına çevirir
  final String? error;
  final bool quotaExceeded;

  const AssistantState({
    this.messages = const [],
    this.sending = false,
    this.conversationId,
    this.remainingToday,
    this.error,
    this.quotaExceeded = false,
  });

  AssistantState copyWith({
    List<AssistantMessage>? messages,
    bool? sending,
    int? conversationId,
    int? remainingToday,
    String? error,
    bool clearError = false,
    bool? quotaExceeded,
  }) {
    return AssistantState(
      messages: messages ?? this.messages,
      sending: sending ?? this.sending,
      conversationId: conversationId ?? this.conversationId,
      remainingToday: remainingToday ?? this.remainingToday,
      error: clearError ? null : (error ?? this.error),
      quotaExceeded: quotaExceeded ?? this.quotaExceeded,
    );
  }
}

/// Sohbet durumu uygulama oturumu boyunca yaşar (ekrandan çıkıp dönünce kalır);
/// `reset()` yeni sohbet başlatır. Sunucu konuşmayı `conversation_id` ile saklar,
/// cihazda kalıcı depolama yok (ADR-005 çevrimdışı kapsamı dışında).
class AssistantNotifier extends StateNotifier<AssistantState> {
  final AssistantApi _api;
  AssistantNotifier(this._api) : super(const AssistantState());

  Future<void> send(String text, {required String lang}) async {
    final message = text.trim();
    if (message.isEmpty || state.sending) return;

    state = state.copyWith(
      messages: [...state.messages, AssistantMessage(role: AssistantRole.user, text: message)],
      sending: true,
      clearError: true,
    );

    try {
      final reply = await _api.chat(
        message: message,
        conversationId: state.conversationId,
        lang: lang,
      );
      state = state.copyWith(
        messages: [
          ...state.messages,
          AssistantMessage(
            role: AssistantRole.assistant,
            text: reply.answer,
            sources: reply.sources,
            route: reply.route,
          ),
        ],
        sending: false,
        conversationId: reply.conversationId ?? state.conversationId,
        remainingToday: reply.remainingToday ?? state.remainingToday,
        quotaExceeded: reply.quotaExceeded,
      );
    } on AssistantAuthRequiredException {
      state = state.copyWith(sending: false, error: 'auth');
    } catch (_) {
      state = state.copyWith(sending: false, error: 'network');
    }
  }

  void reset() => state = const AssistantState();
}

final assistantProvider = StateNotifierProvider<AssistantNotifier, AssistantState>((ref) {
  return AssistantNotifier(ref.read(assistantApiProvider));
});
