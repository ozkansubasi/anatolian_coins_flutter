import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/auth_controller.dart';
import '../../core/navigation.dart';
import '../../core/num_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../prokit_ui/numistr_colors.dart';
import 'account_deletion_api.dart';
import 'account_deletion_service.dart';

/// Hesabı uygulama içinden silme (App Store 5.1.1(v), Play hesap silme politikası).
///
/// Silme HEMEN olur (kullanıcı kararı): ne silinip ne kaldığı yazılır, mağaza
/// aboneliği varsa iptal edilmediği uyarılır, kullanıcı onay kelimesini yazınca
/// düğme açılır. Başarıda bu cihaz da temizlenir, oturum yerelde kapanır ve
/// Ana Sayfa'ya dönülür.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  static const confirmFieldKey = Key('delete_account_confirm_field');
  static const submitKey = Key('delete_account_submit');

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _confirm = TextEditingController();
  bool _busy = false;
  AccountDeletionResult? _error;

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    // Silme bitince bu ekran yığından çıkar; bildirim ve yönlendirme önceden alınır.
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await ref.read(accountDeletionServiceProvider).deleteAccount();

    if (result.isDeleted) {
      router.go('/');
      messenger.showSnackBar(SnackBar(content: Text(l10n.translate('delete_account_done'))));
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.numColors;
    final auth = ref.watch(authControllerProvider);
    final store = ref.watch(activeStoreSubscriptionProvider).valueOrNull;
    final webSubscription = ref.watch(webSubscriptionActiveProvider);
    final word = l10n.translate('delete_account_confirm_word');
    final canDelete =
        !_busy && auth.authenticated && confirmWordMatches(_confirm.text, word);
    final error = _error;

    return PopScope(
      // Silme sürerken geri gidilmez (istek yarıda bırakılmasın).
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          scrolledUnderElevation: 0,
          title: Text(l10n.translate('delete_account')),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.translate('delete_account_intro'),
                  style: TextStyle(
                    color: c.text,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                _ListCard(
                  icon: Icons.delete_outline_rounded,
                  title: l10n.translate('delete_account_removed_title'),
                  items: [
                    l10n.translate('delete_account_removed_account'),
                    l10n.translate('delete_account_removed_recognition'),
                    l10n.translate('delete_account_removed_assistant'),
                    l10n.translate('delete_account_removed_student'),
                    l10n.translate('delete_account_removed_device'),
                  ],
                ),
                const SizedBox(height: 12),
                _ListCard(
                  icon: Icons.inventory_2_outlined,
                  title: l10n.translate('delete_account_kept_title'),
                  items: [
                    l10n.translate('delete_account_kept_invoices'),
                    l10n.translate('delete_account_kept_stats'),
                  ],
                ),
                if (store != null) ...[
                  const SizedBox(height: 12),
                  _StoreSubscriptionWarning(store: store),
                ],
                if (webSubscription) ...[
                  const SizedBox(height: 12),
                  _Note(
                    icon: Icons.language_rounded,
                    text: l10n.translate('delete_account_web_sub_note'),
                  ),
                ],
                if (auth.isAppleAccount) ...[
                  const SizedBox(height: 12),
                  _Note(
                    icon: Icons.apple,
                    text: l10n.translate('delete_account_apple_note'),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  l10n.translate('delete_account_type_to_confirm',
                      params: {'word': word}),
                  style: TextStyle(
                    color: c.text,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: DeleteAccountScreen.confirmFieldKey,
                  controller: _confirm,
                  enabled: !_busy,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: canDelete ? (_) => _submit() : null,
                  style: TextStyle(color: c.text, letterSpacing: 1.5),
                  decoration: InputDecoration(
                    hintText: word,
                    hintStyle: TextStyle(color: c.hint, letterSpacing: 1.5),
                    filled: true,
                    fillColor: c.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: c.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: c.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: c.accent, width: 1.5),
                    ),
                  ),
                ),
                if (error != null && error.errorKey != null) ...[
                  const SizedBox(height: 12),
                  _Note(
                    icon: Icons.error_outline_rounded,
                    text: l10n.translate(error.errorKey!, params: error.errorParams),
                    emphasize: true,
                  ),
                ],
                if (!auth.authenticated && !_busy) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/login'),
                    icon: const Icon(Icons.login_rounded),
                    label: Text(l10n.translate('sign_in')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.accent,
                      side: BorderSide(color: c.accent),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: DeleteAccountScreen.submitKey,
                  onPressed: canDelete ? _submit : null,
                  icon: _busy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: c.hint),
                        )
                      : const Icon(Icons.delete_forever_rounded),
                  label: Text(l10n.translate(
                      _busy ? 'delete_account_deleting' : 'delete_account_button')),
                  // M22 "sil" belirteci: bitüm kahvesi zemin, krem yazı, bronz çerçeve
                  // (hazır Material kırmızısı yerine uygulama paleti).
                  style: FilledButton.styleFrom(
                    backgroundColor: numMarkClear,
                    foregroundColor: numMarkOnDark,
                    disabledBackgroundColor: c.surface,
                    disabledForegroundColor: c.hint,
                    side: BorderSide(
                        color: canDelete ? numAccent : c.border, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy ? null : context.popOrGoHome,
                  style: TextButton.styleFrom(foregroundColor: c.accent),
                  child: Text(l10n.translate('delete_account_keep')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

/// Hesabım ekranındaki kartlarla aynı kabuk (ince altın çerçeve, gölge yok).
final _cardShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(14),
  side: BorderSide(color: numPrimary.withAlpha(70)),
);

/// Başlık + madde listesi (silinecekler / saklananlar).
class _ListCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> items;

  const _ListCard({required this.icon, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final c = context.numColors;
    return Material(
      color: c.card,
      shape: _cardShape,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: numPrimary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 7, left: 4, right: 10),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: c.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(color: c.textMuted, fontSize: 14, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Mağaza aboneliği uyarısı: hesap silmek onu iptal etmez; "Aboneliği Yönet"
/// aboneliğin alındığı mağazanın yönetim sayfasını açar.
class _StoreSubscriptionWarning extends StatelessWidget {
  final ManagedStore store;

  const _StoreSubscriptionWarning({required this.store});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.numColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: numAccent.withAlpha(30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: numAccent, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: c.accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.translate('delete_account_store_sub_title'),
                      style: TextStyle(
                        color: c.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.translate(store == ManagedStore.appStore
                          ? 'delete_account_store_sub_app_store'
                          : 'delete_account_store_sub_play'),
                      style: TextStyle(color: c.text, fontSize: 14, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => launchUrl(manageSubscriptionUrl(store),
                  mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(l10n.translate('manage_subscription')),
              style: TextButton.styleFrom(foregroundColor: c.accent),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kısa bilgi ya da hata notu.
class _Note extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool emphasize;

  const _Note({required this.icon, required this.text, this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    final c = context.numColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: emphasize ? numAccent : c.border,
          width: emphasize ? 1.2 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: emphasize ? c.text : c.textMuted,
                fontSize: 13.5,
                height: 1.4,
                fontWeight: emphasize ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
