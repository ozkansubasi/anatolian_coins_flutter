# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Anatolian Coins** is a Flutter mobile application that provides access to the NumisTR numismatic database. The app features OIDC authentication via Auth0 (with PKCE), offline access capabilities, and a subscription-based feature system.

**Tech Stack:**
- Flutter 3.35.6 / Dart 3.9.2
- State Management: Riverpod 2.5.1
- Navigation: GoRouter 14.2.0
- HTTP Client: Dio 5.7.0
- Authentication: flutter_appauth 6.0.2 (OIDC + PKCE)
- Local Storage: flutter_secure_storage 9.2.2, sqflite 2.3.3
- Image Caching: cached_network_image 3.3.1, flutter_cache_manager 3.4.1

## Common Commands

### Development
```bash
# Get dependencies
flutter pub get

# Run on connected device/emulator
flutter run

# Run on specific device
flutter run -d emulator-XXXX

# Clean build artifacts
flutter clean

# Analyze code
flutter analyze
```

### Testing
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart
```

### Build
```bash
# Build APK (Android)
flutter build apk

# Build App Bundle (Android)
flutter build appbundle

# Build iOS
flutter build ios
```

## Authentication Architecture

The app uses **Auth0 OIDC with PKCE** for secure authentication:

- **Auth Configuration:** `lib/src/core/env.dart` contains Auth0 issuer, client ID, and redirect URLs
- **Auth Repository:** `lib/src/auth/auth_repository.dart` handles login, logout, token refresh
- **Auth Controller:** `lib/src/auth/auth_controller.dart` manages auth state (StateNotifier)
- **Token Storage:** Uses `flutter_secure_storage` via `lib/src/core/secure_storage.dart`
- **Token Injection:** `lib/src/core/token_interceptor.dart` adds Bearer tokens to API requests

**Key Auth Flow:**
1. User initiates login → `auth_repository.signIn()` triggers Auth0 flow
2. Access token + refresh token stored securely
3. Token interceptor automatically adds Bearer token to all API calls
4. Tokens auto-refresh when expired (60-second buffer)
5. GoRouter watches auth state stream and redirects as needed

**Callback URLs (must match Auth0 configuration):**
- Login: `com.anatoliancoins.app://callback`
- Logout: `com.anatoliancoins.app://logout`

## API Architecture

**Base API:** NumisTR REST API at `https://www.numistr.org/api/index.php/v1`

**API Client:** `lib/src/core/api_client.dart`
- Uses Dio with automatic JSON parsing interceptor
- Response type is `ResponseType.plain` (String), then manually parsed to Map
- Token interceptor adds Bearer authentication
- Debug logging for variant endpoints

**Main API Service:** `lib/src/features/variants/variants_api.dart`
- `list()` - Get variants with filters (mint, authority, material, region, year range, pagination)
- `getVariant(articleId)` - Get single variant with images
- `images(articleId)` - Get variant images (supports watermark/absolute URL options)
- `getFirstImageUrl(articleId)` - Convenience method for thumbnail

**API Response Structure:**
```dart
{
  "data": [...],  // Array of items or single object
  "meta": {       // Pagination metadata
    "current_page": 1,
    "total": 100,
    ...
  }
}
```

## Data Models

**Variant** (`lib/src/models/variant.dart`):
- Core fields: `articleId`, `uid`, `slug`, `titleTr`, `titleEn`
- Numismatic data: `regionCode`, `material`, `dateFrom`, `dateTo`
- Extended fields: mint, authority, denomination, obverse/reverse descriptions, findspot, coordinates, source citation
- Field mapping handles multiple API response formats (e.g., `region_code` or `region`, `material_value` or `material` or `metal`)

**VariantImage** (`lib/src/models/variant_image.dart`):
- Image metadata with URL and thumbnail support

## Offline Access System

**Database:** `lib/src/features/offline/offline_database.dart`
- SQLite database using sqflite
- Tables: `variants`, `variant_images`
- Stores metadata + local file paths

**Service:** `lib/src/features/offline/offline_service.dart`
- `downloadVariant(articleId)` - Downloads variant metadata + all images to local storage
- Images stored in: `{AppDocuments}/offline_images/{variantId}/{imageId}.jpg`
- Download progress tracking via callback with `DownloadProgress` state
- `getOfflineVariant()`, `getOfflineImages()` - Retrieve cached data
- `deleteVariant()`, `clearAll()` - Cleanup methods
- `getStats()` - Returns DB stats + disk usage

**State Management:** `OfflineDownloadController` (StateNotifier)
- Tracks download progress for multiple variants simultaneously
- Prevents duplicate downloads

## Subscription System

**Provider:** `lib/src/core/subscription_provider.dart`
- Two tiers: `free` and `pro`
- Features gated by `FeatureLimits` class
- Free limitations: 10 favorites, 1 collection, no offline access, no high-res images
- Pro: Unlimited favorites/collections, offline access, high-res images, coin recognition
- TODO: Backend integration for subscription status check

## Navigation & Routing

**Router:** `lib/src/app_router.dart` using GoRouter
- Auto-refreshes on auth state changes via `GoRouterRefreshStream`
- Routes:
  - `/` - Variant list page (home)
  - `/variant/:id` - Variant detail page
  - `/account` - User account page
  - `/subscription` - Subscription management page

## State Management Patterns

Uses **Riverpod** throughout:
- **Providers** for services/repositories (e.g., `variantsApiProvider`, `authRepositoryProvider`)
- **StateNotifierProvider** for stateful controllers (e.g., `authControllerProvider`, `subscriptionProvider`)
- **ConsumerWidget** for widgets that read providers
- Main app wrapped in `ProviderScope`

## Region Data

`lib/src/core/region_data.dart` contains static region mappings for filtering (Anatolia, Balkans, etc.)

## Important Notes

- **Response Parsing:** API returns plain strings, not JSON. The `ApiClient` manually parses them with a custom interceptor.
- **Field Name Variations:** Variant model handles multiple API field name formats. When adding new fields, check for variations.
- **Auth Token Refresh:** Automatically handled by `AuthRepository.ensureFresh()` with 60-second expiry buffer.
- **Offline Images:** Use `wm: false` parameter to download watermark-free versions for offline storage.
- **Platform Support:** Only Android and iOS are supported (Linux/Windows platform directories have been removed).
