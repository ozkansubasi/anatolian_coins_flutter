import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/auth_controller.dart';
import '../../core/locale_provider.dart';
import '../../core/num_colors.dart';
import '../../core/subscription_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../prokit_ui/numistr_colors.dart';
import 'assistant_provider.dart';

/// ADR-006 Faz 3 — AI Numizmatik Asistanı (mobil istemci).
///
/// Giriş noktaları bilinçli olarak iki tane: sikke detayı ("Asistana sor", sikke adı
/// önceden doldurulur) ve Hesabım. Ana ekrana eklenmedi (A15: ana ekran zaten kalabalık).
/// Kimlik: giriş zorunlu (anonim web çerezi uygulamada yok). Kota sunucuda: üye 40 / Pro 1000.
class AssistantScreen extends ConsumerStatefulWidget {
  final String? initialQuestion;
  const AssistantScreen({super.key, this.initialQuestion});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Soru önceden doldurulur ama GÖNDERİLMEZ: kota kullanıcı dokunmadan harcanmasın.
    final q = widget.initialQuestion?.trim();
    if (q != null && q.isNotEmpty) _controller.text = q;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final lang = ref.read(localeProvider).languageCode;
    ref.read(assistantProvider.notifier).send(text, lang: lang);
    _controller.clear();
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final authenticated = ref.watch(authControllerProvider).authenticated;
    final isPro = ref.watch(subscriptionProvider).isPro;
    final state = ref.watch(assistantProvider);

    ref.listen<AssistantState>(assistantProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        final msg = next.error == 'auth'
            ? l10n.translate('assistant_login_required')
            : l10n.translate('assistant_error_network');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
      if (next.messages.length != (prev?.messages.length ?? 0)) _scrollToEnd();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('assistant_title')),
        centerTitle: true,
        actions: [
          if (state.messages.isNotEmpty)
            IconButton(
              tooltip: l10n.translate('assistant_new_chat'),
              icon: const Icon(Icons.add_comment_outlined),
              onPressed: () => ref.read(assistantProvider.notifier).reset(),
            ),
        ],
      ),
      body: !authenticated
          ? _LoginCta(l10n: l10n)
          : Column(
              children: [
                Expanded(
                  child: state.messages.isEmpty
                      ? _EmptyState(
                          l10n: l10n,
                          onSuggestion: (s) {
                            _controller.text = s;
                            _send();
                          },
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          itemCount:
                              state.messages.length + (state.sending ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i >= state.messages.length)
                              return const _TypingBubble();
                            return _MessageBubble(
                                message: state.messages[i], l10n: l10n);
                          },
                        ),
                ),
                if (state.quotaExceeded && !isPro) _UpsellBanner(l10n: l10n),
                _Footer(
                    l10n: l10n, remaining: state.remainingToday, theme: theme),
                _InputBar(
                  controller: _controller,
                  enabled: !state.sending,
                  hint: l10n.translate('assistant_input_hint'),
                  onSend: _send,
                ),
              ],
            ),
    );
  }
}

class _LoginCta extends StatelessWidget {
  final AppLocalizations l10n;
  const _LoginCta({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy_outlined,
                size: 56, color: context.numColors.accent),
            const SizedBox(height: 16),
            Text(
              l10n.translate('assistant_login_required'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.push('/login'),
              style: FilledButton.styleFrom(backgroundColor: numPrimary),
              child: Text(l10n.translate('login')),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppLocalizations l10n;
  final ValueChanged<String> onSuggestion;
  const _EmptyState({required this.l10n, required this.onSuggestion});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suggestions = [
      l10n.translate('assistant_suggestion_1'),
      l10n.translate('assistant_suggestion_2'),
      l10n.translate('assistant_suggestion_3'),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 24),
        Icon(Icons.smart_toy_outlined,
            size: 56, color: context.numColors.accent),
        const SizedBox(height: 12),
        Text(
          l10n.translate('assistant_empty_title'),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.translate('assistant_subtitle'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
        ),
        const SizedBox(height: 20),
        ...suggestions.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              onPressed: () => onSuggestion(s),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.numColors.accent,
                side: const BorderSide(color: numPrimary),
                alignment: Alignment.centerLeft,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              child: Text(s),
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final AssistantMessage message;
  final AppLocalizations l10n;
  const _MessageBubble({required this.message, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == AssistantRole.user;
    final bg = isUser ? numPrimary : theme.colorScheme.surfaceContainerHighest;
    final fg = isUser ? Colors.white : theme.colorScheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kullanıcının yazdığı düz metin kalır; asistan cevabı sunucudan
              // Markdown gelir (**kalın**, *italik*, liste, bağlantı).
              if (isUser)
                SelectableText(message.text,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: fg, height: 1.35))
              else
                _AssistantMarkdown(text: message.text, color: fg),
              if (message.sources.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.translate('assistant_sources'),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: fg.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: message.sources.take(5).map((s) {
                    return ActionChip(
                      label: Text(
                        s.title.isEmpty ? s.url : s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // Baglanti gibi okunsun: accent (acikta #8B6914, fildisi
                        // zeminde 5,04:1; koyuda #E8C766) -> WCAG AA gecer; alti cizili.
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: context.numColors.accent,
                          decoration: TextDecoration.underline,
                          decorationColor: context.numColors.accent,
                        ),
                      ),
                      avatar: Icon(Icons.open_in_new,
                          size: 14, color: context.numColors.accent),
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        final uri = Uri.tryParse(s.url);
                        if (uri != null)
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantMarkdown extends StatelessWidget {
  final String text;
  final Color color;
  const _AssistantMarkdown({required this.text, required this.color});

  Future<void> _openLink(String? href) async {
    final uri = href == null ? null : Uri.tryParse(href);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body =
        theme.textTheme.bodyMedium?.copyWith(color: color, height: 1.35);
    final sheet = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: body,
      strong: const TextStyle(fontWeight: FontWeight.bold),
      em: const TextStyle(fontStyle: FontStyle.italic),
      listBullet: body,
      h1: theme.textTheme.titleMedium
          ?.copyWith(color: color, fontWeight: FontWeight.bold),
      h2: theme.textTheme.titleSmall
          ?.copyWith(color: color, fontWeight: FontWeight.bold),
      h3: theme.textTheme.titleSmall
          ?.copyWith(color: color, fontWeight: FontWeight.w600),
      blockquote: body?.copyWith(fontStyle: FontStyle.italic),
      blockquoteDecoration: BoxDecoration(
        border: Border(
            left:
                BorderSide(color: numPrimary.withValues(alpha: 0.5), width: 3)),
      ),
      code: body?.copyWith(
          fontFamily: 'monospace',
          backgroundColor: color.withValues(alpha: 0.08)),
      // Kaynak çipleriyle aynı bağlantı görünümü (accent: açıkta #8B6914, koyuda #E8C766).
      a: TextStyle(
        color: context.numColors.accent,
        decoration: TextDecoration.underline,
        decorationColor: context.numColors.accent,
      ),
      blockSpacing: 8,
    );
    return MarkdownBody(
      data: text,
      selectable: true,
      softLineBreak: true,
      styleSheet: sheet,
      onTapLink: (_, href, __) => _openLink(href),
      // Cevaptaki uzak görseller yüklenmez (izlenme/bant genişliği); alt metin gösterilir.
      imageBuilder: (_, __, alt) => Text(alt ?? '', style: body),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: numPrimary),
        ),
      ),
    );
  }
}

class _UpsellBanner extends StatelessWidget {
  final AppLocalizations l10n;
  const _UpsellBanner({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? context.numColors.surface
            : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: numPrimary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(l10n.translate('assistant_quota_upsell'))),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => context.push('/subscription'),
            style: FilledButton.styleFrom(backgroundColor: numPrimary),
            child: Text(l10n.translate('upgrade_to_pro')),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final AppLocalizations l10n;
  final int? remaining;
  final ThemeData theme;
  const _Footer(
      {required this.l10n, required this.remaining, required this.theme});

  @override
  Widget build(BuildContext context) {
    final style = theme.textTheme.labelSmall?.copyWith(color: theme.hintColor);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
      child: Row(
        children: [
          Expanded(
              child:
                  Text(l10n.translate('assistant_disclaimer'), style: style)),
          // Yalnız azaldığında: Pro'nun yüksek günlük sınırında "Bugün kalan:
          // 999" yapay bir tavan gibi okunuyordu.
          if (remaining != null && remaining! <= 20)
            Text(
                l10n.translate('assistant_remaining_today',
                    params: {'n': '$remaining'}),
                style: style),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final String hint;
  final VoidCallback onSend;
  const _InputBar(
      {required this.controller,
      required this.enabled,
      required this.hint,
      required this.onSend});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                maxLength: 1000,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: hint,
                  counterText: '',
                  isDense: true,
                  filled: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              onPressed: enabled ? onSend : null,
              style: IconButton.styleFrom(backgroundColor: numPrimary),
              icon: const Icon(Icons.send, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
