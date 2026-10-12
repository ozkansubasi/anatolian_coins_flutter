import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nb_utils/nb_utils.dart' hide ContextExtensions;
import '../../auth/auth_controller.dart';
import '../../auth/resend_verification.dart';
import '../../core/num_colors.dart';
import '../../l10n/app_localizations.dart';

/// A23 — "Doğrulama e-postasını yeniden gönder" düğmesi.
///
/// Kayıt sonrası doğrulama panelinde ve girişteki "e-posta doğrulanmadı"
/// hatasında kullanılır. Gönderimden sonra sunucunun bildirdiği süre kadar
/// geri sayar; sonuç düğmenin altında tek satır olarak gösterilir. Günlük
/// tavan dolduysa düğme bu ekran açık kaldıkça kapalı kalır.
class ResendVerificationButton extends ConsumerStatefulWidget {
  const ResendVerificationButton({
    super.key,
    required this.email,
    required this.password,
    this.enabled = true,
  });

  /// Gönderim anındaki e-posta / şifre (form alanlarından okunur).
  final String Function() email;
  final String Function() password;

  /// Üst ekran başka bir işle meşgulken (giriş sürüyor) kapatmak için.
  final bool enabled;

  @override
  ConsumerState<ResendVerificationButton> createState() => _ResendVerificationButtonState();
}

class _ResendVerificationButtonState extends ConsumerState<ResendVerificationButton> {
  bool _busy = false;
  bool _blocked = false;
  int _cooldown = 0;
  Timer? _timer;
  String? _messageKey;
  bool _messageIsError = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _messageKey = null;
    });

    final r = await ref
        .read(authControllerProvider.notifier)
        .resendVerificationEmail(widget.email().trim(), widget.password());

    if (!mounted) return;

    var cooldown = 0;
    var blocked = false;
    final String key;
    final bool isError;
    switch (r.status) {
      case ResendVerificationStatus.sent:
        key = 'verify_email_resent';
        isError = false;
        cooldown = r.retryAfterSeconds;
      case ResendVerificationStatus.alreadyVerified:
        key = 'verify_email_already_verified';
        isError = false;
      case ResendVerificationStatus.rateLimited:
        isError = true;
        if (r.retryAfterSeconds <= ResendVerificationResult.shortWaitLimit) {
          key = 'verify_email_resend_too_soon';
          cooldown = r.retryAfterSeconds;
        } else {
          key = 'verify_email_resend_limited';
          blocked = true;
        }
      case ResendVerificationStatus.failed:
        key = r.errorKey ?? 'verify_email_resend_failed';
        isError = true;
    }

    setState(() {
      _busy = false;
      _blocked = blocked;
      _messageKey = key;
      _messageIsError = isError;
    });
    if (cooldown > 0) _startCooldown(cooldown);
  }

  void _startCooldown(int seconds) {
    _timer?.cancel();
    setState(() => _cooldown = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.numColors;
    final canTap = widget.enabled && !_busy && !_blocked && _cooldown <= 0;

    final label = _cooldown > 0
        ? l10n.translate('verify_email_resend_wait', params: {'seconds': '$_cooldown'})
        : l10n.translate('verify_email_resend');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: canTap ? _resend : null,
            icon: _busy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(c.accent),
                    ),
                  )
                : const Icon(Icons.forward_to_inbox_outlined),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: c.accent,
              side: BorderSide(color: canTap ? c.accent : c.border),
              shape: RoundedRectangleBorder(borderRadius: radius(12)),
            ),
          ),
        ),
        if (_messageKey != null) ...[
          8.height,
          Text(
            l10n.translate(_messageKey!),
            style: secondaryTextStyle(
              size: 13,
              color: _messageIsError ? Colors.red.shade700 : c.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
