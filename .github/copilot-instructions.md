# M2DG Mobile App — Copilot Instructions

## Project Overview
**M2DG** is a Flutter mobile app for court sports game management with Supabase backend. The app handles court queuing, challenges, player matchmaking, and anti-cheat check-in verification.

**Tech Stack:** Flutter 3.5.3 | Supabase (auth + DB) | GoRouter (navigation) | Geolocator (location)

---

## Architecture Patterns

### 1. **Services Layer** (Supabase + Business Logic)
Services in `/lib/services/` encapsulate all Supabase database operations and cross-entity logic:
- `GameSessionService` — game lifecycle, score tracking, player stats updates
- `CheckInService` — location-based check-in with cooldown enforcement + distance validation
- `NotificationService` — user notifications with type-specific templates
- `ChallengeService` — challenge creation and player matching
- `CourtQueueService` — court wait queue management

**Pattern:** Static methods or const constructors; services accept `SupabaseClient` dependency; use `try/catch` + `rethrow` for errors; print debug logs.

Example: `CheckInService.checkIn()` validates cooldown (20 min), GPS accuracy (75m), and distance to court before recording check-in.

### 2. **Models** (`/lib/models/`)
Data models with `fromJson()` / `toJson()` factory constructors for Supabase JSON mapping. No business logic in models.

Example: `GameSession` tracks game ID, scores, status, teams; `UserProfile` mirrors Supabase `profiles` table schema.

### 3. **Screens** (`/lib/screens/`)
StatefulWidget pages handle UI state, navigation, and service calls. Use `GoRouter` for navigation.

**Required States for Each Screen:**
- Loading state (while fetching data)
- Empty state (no data found)
- Error state with retry button
- Success state with polished mobile layout

Navigation via named routes: `context.goNamed('signIn')` or `context.go('/courts')`.

### 4. **Navigation** (GoRouter in `main.dart`)
Router observes `_authStateNotifier` to redirect unauthenticated users to `/sign-in`. Auth state synced with Supabase `onAuthStateChange` listener. Named routes map to screen pages.

---

## Critical Business Rules

### Anti-Cheat Check-In Validation
Location verification is **server-authoritative**. Client sends GPS position; `CheckInService` validates:
1. **Cooldown:** Last check-in + 20 min elapsed?
2. **Distance:** Calculated distance ≤ court radius (typically 100m)?
3. **GPS Accuracy:** ≤ 75m (tunable for Android)?
4. **Timestamp sanity:** No future dates or >1 hour stale?

**Never trust client location.** Always validate server-side in Edge Functions.

### Security (from `ENGINEERING_RULES.md`)
- **RLS enforced** on all tables (user_id-based row filtering)
- All endpoints rate-limited
- CAPTCHA on signup, signin, password reset
- Player stats updated atomically when game ends
- Suspicious activity logged to `security_events`

### UX Rules
- Cooldown timer shown as `MM:SS` countdown
- Streaks counted once per day
- Notifications use motivational copy, never spammy

---

## Development Workflow

### Build & Run
```bash
cd apps/mobile
flutter pub get
flutter run
```

### Lint & Analyze
```bash
flutter analyze
```
Uses `flutter_lints` from `analysis_options.yaml`.

### Commit Message Format
```
feat(feature_name): description
fix(feature_name): description
ui(feature_name): description
```

### Finish-to-Launch Rule
**Do not move to next feature until current screen is launch-ready:**
- ✅ All three states (loading, empty, error) implemented
- ✅ Mobile layout polished & responsive
- ✅ No analyzer errors
- ✅ Navigation working
- ✅ No debug toggles visible in release builds

---

## Key Directories & Files

| Path | Purpose |
|------|---------|
| `lib/main.dart` | App entry, Supabase init, GoRouter setup |
| `lib/services/` | Business logic + Supabase queries |
| `lib/models/` | Data classes with JSON serialization |
| `lib/screens/` | UI pages (must implement loading/empty/error states) |
| `lib/widgets/` | Reusable UI components |
| `lib/core/config/env.dart` | Environment config (Supabase URL, key) |
| `pubspec.yaml` | Dependencies (Supabase, GoRouter, Geolocator, etc.) |
| `/docs/database_setup.sql` | Full DB schema (tables, RLS policies, indexes) |
| `/docs/ENGINEERING_RULES.md` | Security & validation rules |
| `/docs/WORKFLOW_RULES.md` | Build discipline & agent output standards |

---

## Common Patterns

### Error Handling in Services
```dart
try {
  final response = await supabase.from('table').select().single();
  return Model.fromJson(response);
} catch (e) {
  print('Error operation: $e');
  rethrow;
}
```

### Screen Loading/Empty/Error States
```dart
if (isLoading) return Center(child: CircularProgressIndicator());
if (error != null) return ErrorWidget(message: error, onRetry: refresh);
if (data.isEmpty) return EmptyStateWidget();
return ListView(children: data.map(...).toList());
```

### Supabase Client Access
Global `supabase` client initialized in `main.dart`:
```dart
final supabase = Supabase.instance.client;
```
Import it in services/screens: `final supabase = Supabase.instance.client;`

---

## When Making Changes

1. **Always preserve existing tests & RLS policies.** Never disable RLS "just to test."
2. **Update server-side validations in Edge Functions** — don't rely on client validation.
3. **Small, focused PRs per feature.** One purpose per commit.
4. **Follow Finish-to-Launch rule:** complete loading/empty/error states before moving on.
5. **Reference `/docs/` files as source of truth** for feature specs and database design.

---

## Quick Reference: Common Imports

```dart
// Navigation
import 'package:go_router/go_router.dart';

// Supabase
import 'package:supabase_flutter/supabase_flutter.dart';

// Location
import 'package:geolocator/geolocator.dart';

// Environment
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Local models
import 'package:mobile/models/user_profile.dart';
import 'package:mobile/services/game_session_service.dart';
```

---

## Testing Notes
- Use `flutter test` for widget tests (example: `test/widget_test.dart`)
- No special test infrastructure for Supabase calls yet; focus on UI behavior & state management
- Manual testing with emulator/device required for location-based features

---

**Last Updated:** January 2026 | **Dart 3.5.3** | **Flutter Latest**
