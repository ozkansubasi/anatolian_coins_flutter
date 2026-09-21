import 'package:flutter/material.dart';
import '../core/network_utils.dart';
import '../core/num_colors.dart';

/// Utility class for showing user-friendly error dialogs
class ErrorDialogs {
  /// Show a recognition error dialog with appropriate icon and retry option
  static Future<bool?> showRecognitionError(
    BuildContext context, {
    required dynamic error,
    VoidCallback? onRetry,
  }) async {
    final errorInfo = _getErrorInfo(error);

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          errorInfo.icon,
          color: errorInfo.iconColor,
          size: 48,
        ),
        title: Text(errorInfo.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              errorInfo.message,
              textAlign: TextAlign.center,
            ),
            if (errorInfo.hint != null) ...[
              const SizedBox(height: 12),
              Text(
                errorInfo.hint!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: context.numColors.textMuted,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Kapat'),
          ),
          if (errorInfo.canRetry && onRetry != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
                onRetry();
              },
              child: const Text('Tekrar Dene'),
            ),
        ],
      ),
    );
  }

  /// Show a simple error snackbar
  static void showErrorSnackBar(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onRetry,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        action: onRetry != null
            ? SnackBarAction(
                label: 'Tekrar Dene',
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// Show no internet connection dialog
  static Future<bool?> showNoInternetDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.cloud_off,
          color: context.numColors.textMuted,
          size: 48,
        ),
        title: const Text('Bağlantı Yok'),
        content: const Text(
          'İnternet bağlantısı bulunamadı.\n\nSikke tanıma için internet bağlantısı gereklidir.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tamam'),
          ),
          ElevatedButton(
            onPressed: () async {
              final hasConnection = await NetworkUtils.hasInternetConnection();
              if (context.mounted) {
                Navigator.pop(context, hasConnection);
              }
            },
            child: const Text('Bağlantıyı Kontrol Et'),
          ),
        ],
      ),
    );
  }

  /// Show service unavailable dialog
  static Future<void> showServiceUnavailableDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.cloud_off,
          color: Colors.orange,
          size: 48,
        ),
        title: const Text('Servis Kullanılamıyor'),
        content: const Text(
          'Sikke tanıma servisi şu anda bakımda veya geçici olarak kapalı.\n\nLütfen birkaç dakika sonra tekrar deneyin.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  /// Show quota exceeded dialog
  static Future<void> showQuotaExceededDialog(
    BuildContext context, {
    VoidCallback? onUpgrade,
  }) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.lock_clock,
          color: Colors.amber,
          size: 48,
        ),
        title: const Text('Tarama Limiti Doldu'),
        content: const Text(
          'Bu ay için ücretsiz tarama hakkınız doldu.\n\nYüksek kapasiteli tarama ve daha fazlası için Pro\'ya yükseltin!',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Daha Sonra'),
          ),
          if (onUpgrade != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onUpgrade();
              },
              child: const Text('Pro\'ya Yükselt'),
            ),
        ],
      ),
    );
  }

  /// Show auth required dialog
  static Future<bool?> showAuthRequiredDialog(
    BuildContext context, {
    VoidCallback? onLogin,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.person_outline,
          color: Colors.blue,
          size: 48,
        ),
        title: const Text('Giriş Gerekli'),
        content: const Text(
          'Sikke tanıma özelliğini kullanmak için giriş yapmalısınız.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true);
              onLogin?.call();
            },
            child: const Text('Giriş Yap'),
          ),
        ],
      ),
    );
  }

  /// Get error info based on error type
  static _ErrorInfo _getErrorInfo(dynamic error) {
    if (error is RecognitionError) {
      switch (error.type) {
        case RecognitionErrorType.noInternet:
          return _ErrorInfo(
            icon: Icons.wifi_off,
            iconColor: Colors.grey,
            title: 'Bağlantı Hatası',
            message: error.userMessage,
            canRetry: true,
          );
        case RecognitionErrorType.serviceUnavailable:
          return _ErrorInfo(
            icon: Icons.cloud_off,
            iconColor: Colors.orange,
            title: 'Servis Kullanılamıyor',
            message: error.userMessage,
            hint: 'Servis bakımda olabilir.',
            canRetry: true,
          );
        case RecognitionErrorType.timeout:
          return _ErrorInfo(
            icon: Icons.timer_off,
            iconColor: Colors.orange,
            title: 'Zaman Aşımı',
            message: error.userMessage,
            canRetry: true,
          );
        case RecognitionErrorType.quotaExceeded:
          return _ErrorInfo(
            icon: Icons.lock_clock,
            iconColor: Colors.amber,
            title: 'Limit Doldu',
            message: error.userMessage,
            canRetry: false,
          );
        case RecognitionErrorType.authRequired:
          return _ErrorInfo(
            icon: Icons.person_outline,
            iconColor: Colors.blue,
            title: 'Giriş Gerekli',
            message: error.userMessage,
            canRetry: false,
          );
        case RecognitionErrorType.invalidImage:
          return _ErrorInfo(
            icon: Icons.broken_image,
            iconColor: Colors.red,
            title: 'Geçersiz Görsel',
            message: error.userMessage,
            hint: 'Desteklenen formatlar: JPG, PNG',
            canRetry: false,
          );
        case RecognitionErrorType.unknown:
          return _ErrorInfo(
            icon: Icons.error_outline,
            iconColor: Colors.red,
            title: 'Hata',
            message: error.userMessage,
            canRetry: true,
          );
      }
    }

    // Default error info
    return _ErrorInfo(
      icon: Icons.error_outline,
      iconColor: Colors.red,
      title: 'Tanıma Başarısız',
      message: NetworkUtils.getUserFriendlyMessage(error),
      canRetry: true,
    );
  }
}

class _ErrorInfo {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String? hint;
  final bool canRetry;

  _ErrorInfo({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.hint,
    required this.canRetry,
  });
}

/// Widget to show when offline
class OfflineMessage extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const OfflineMessage({
    super.key,
    this.title = 'Bağlantı Yok',
    this.message = 'Bu özellik için internet bağlantısı gereklidir.',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 64,
              color: context.numColors.hint,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.numColors.textMuted),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar Dene'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Loading indicator with cancel option
class RecognitionLoadingDialog extends StatelessWidget {
  final VoidCallback? onCancel;

  const RecognitionLoadingDialog({
    super.key,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text(
            'Sikke analiz ediliyor...',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Bu birkaç saniye sürebilir',
            style: TextStyle(color: context.numColors.textMuted, fontSize: 12),
          ),
          if (onCancel != null) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: onCancel,
              child: const Text('İptal'),
            ),
          ],
        ],
      ),
    );
  }

  /// Show as a dialog
  static Future<void> show(
    BuildContext context, {
    VoidCallback? onCancel,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RecognitionLoadingDialog(onCancel: onCancel),
    );
  }

  /// Dismiss the dialog
  static void dismiss(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }
}
