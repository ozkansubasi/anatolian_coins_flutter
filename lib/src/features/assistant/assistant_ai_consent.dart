import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/num_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../prokit_ui/numistr_colors.dart';
import '../settings/settings_provider.dart';

/// AI Asistan — üçüncü taraf yapay zekâ bilgilendirmesi ve açık izin (14 Kas 2026).
///
/// Apple App Review 5.1.2(i): kişisel verinin üçüncü taraf yapay zekâyla paylaşılacağı açıkça
/// söylenmeli ve önceden izin alınmalı. Asistana yazılan mesajlar yanıt için Google (Gemini) ve
/// Anthropic'e (Claude) gider. İzin ilk mesajdan önce bir kez sorulur; verilmeden hiçbir mesaj
/// gönderilmez. Sikke fotoğrafları bu hizmetlere gitmez (tanıma kendi sunucumuzda).
bool hasAssistantAiConsent(SharedPreferences prefs) =>
    prefs.getBool(SettingsKeys.assistantAiConsent) ?? false;

/// İzin yoksa pencereyi gösterir; kabul edilirse kaydeder. Sonuç: gönderilebilir mi?
Future<bool> ensureAssistantAiConsent(BuildContext context, SharedPreferences prefs) async {
  if (hasAssistantAiConsent(prefs)) return true;
  final accepted = await showModalBottomSheet<bool>(
    context: context,
    // Alt çubuk "Kabul et" düğmesini örtmesin (TestFlight 0.6.4+32'de koleksiyon panelinde görüldü).
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const AssistantAiConsentSheet(),
  );
  if (accepted == true) {
    await prefs.setBool(SettingsKeys.assistantAiConsent, true);
    return true;
  }
  return false;
}

class AssistantAiConsentSheet extends StatelessWidget {
  const AssistantAiConsentSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final accent = context.numColors.accent;

    Widget point(IconData icon, String key) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: accent),
              const SizedBox(width: 10),
              Expanded(child: Text(l10n.translate(key), style: theme.textTheme.bodyMedium)),
            ],
          ),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.smart_toy_outlined, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(l10n.translate('assistant_ai_consent_title'),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 12),
          Text(l10n.translate('assistant_ai_consent_body'), style: theme.textTheme.bodyMedium),
          const SizedBox(height: 14),
          point(Icons.chat_bubble_outline, 'assistant_ai_consent_sent'),
          point(Icons.no_photography_outlined, 'assistant_ai_consent_photos'),
          point(Icons.person_off_outlined, 'assistant_ai_consent_personal'),
          point(Icons.history, 'assistant_ai_consent_storage'),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => context.push('/privacy-policy'),
              child: Text(l10n.translate('assistant_ai_consent_policy')),
            ),
          ),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.translate('assistant_ai_consent_decline')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(backgroundColor: numPrimary),
                child: Text(l10n.translate('assistant_ai_consent_accept'), textAlign: TextAlign.center),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
