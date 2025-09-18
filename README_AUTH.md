# Auth0 ile OIDC (PKCE) — Kurulum

## 1) Auth0 App (Native)
- Allowed Callback URLs: `com.anatoliancoins.app://callback`
- Allowed Logout URLs: `com.anatoliancoins.app://logout`
- Advanced Settings → OAuth → **Allow Offline Access**: ON

## 2) Flutter config
`lib/src/core/env.dart`:
- issuer: `https://dev-ja5k8sumb7005j4n.us.auth0.com`
- clientId: `5AFSce7JEdmyxBrwjwEI7IcnRnvXKF8c`

## 3) Çalıştırma
```bash
flutter create .
flutter clean
flutter pub get
flutter run -d emulator-XXXX
