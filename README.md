# Bunyad — the phone app

The Android and iOS client for [Bunyad](../homeexpense), the construction
expense tracker. Same screens, same words, same design system as the web app;
it talks to the same server over the same REST API.

There is no separate database and no offline store — the app is a client, and
the server it points at is the one you already run.

---

## Point it at your server

Everything about the server lives in **[`lib/global.dart`](lib/global.dart)**,
and nowhere else. Open it and set one line:

```dart
const String kServerUrl = String.fromEnvironment(
  'BUNYAD_SERVER_URL',
  defaultValue: 'http://10.0.2.2:8383',   // ← this
);
```

The default is the Android emulator's route to your own machine, so a backend
started with `mvn spring-boot:run` works with no changes at all.

For anything else, use the address the phone can reach:

| Where Bunyad runs | What to put |
| --- | --- |
| Emulator → your machine | `http://10.0.2.2:8383` |
| iOS simulator → your machine | `http://localhost:8383` |
| A phone on the same Wi-Fi | `http://192.168.1.20:8383` |
| Behind Tomcat with a context path | `http://192.168.1.20:8080/bunyad` |
| Production | `https://bunyad.example.com` |

No trailing slash. The rest of the file builds every endpoint off it, so nothing
else needs touching.

You can also override it per build without editing the file:

```bash
flutter build apk --release --dart-define=BUNYAD_SERVER_URL=https://bunyad.example.com
```

The address the build is pointed at is printed under the sign-in button and on
the account screen, so there is never a doubt about which server a phone is on.

## Run it

```bash
flutter pub get
flutter run
```

Sign in with an account an administrator issued on the web app — the phone
cannot create accounts any more than the browser can.

## Build

```bash
flutter build apk --release
```

```bash
flutter build ipa --release
```

The Android bundle id and the iOS bundle identifier are both
`com.bunyad.expense`.

## How signing in works

The app opens on **Join**. `POST /api/auth/register` creates the account and
returns a token in the same response, so there is no second step — you are
signed in the moment the account exists. Anyone who already has an account takes
the **Sign in** link at the bottom, which calls `POST /api/auth/token` instead.

Self-registered accounts are always plain users. Administrators are only ever
made by other administrators from **People**, and an installation can close
sign-ups altogether with `BUNYAD_REGISTRATION_OPEN=false` — the join screen then
reports that the server is not taking sign-ups.

Either way the app ends up with a **bearer token good for two years**, kept in
the Keychain on iOS and EncryptedSharedPreferences on Android. Every later call
carries it as `Authorization: Bearer …`.

That means a phone signs in once and stays signed in. Two things end a session:

- **Sign out**, on the account screen, which deletes the stored token.
- **A 401 from any call** — the account was deactivated, the password was reset,
  or `BUNYAD_JWT_SECRET` changed on the server. The app drops the token and
  returns to sign-in on its own.

The web app is unaffected by any of this: browsers still get the short-lived
`HttpOnly` cookie they always did.

## What's in it

Every screen and every feature the web app has:

| Screen | What it does |
| --- | --- |
| **Join** | Where the app opens. Name, email and a password of your own — the server creates the account and signs you in with the same call, so the dashboard is next. "Already have an account? Sign in" sits at the bottom. |
| **Sign in** | Email and password, with a way back to Join. A password issued by an administrator must be replaced before anything else opens. |
| **Dashboard** | The greeting, the portfolio totals, and every project — searchable once there are more than three. An administrator sees the whole installation, their own work first, under a "Projects you oversee" divider. |
| **Project** | The total, the team, the stage ladder with each stage's share, "Where the money went" by head, and the expense heads this project suggests. Editing, sharing, leaving and deleting, as your access allows. |
| **Stage** | The expense timeline, newest first, 40 at a time. Add, edit, move and delete expenses; tap a suggestion chip to start one pre-filled. |
| **Expense form** | Name, head (chips or your own), quantity and unit, weight in kg or tons, vendor and contact, amount, date, notes — and photos, from the camera or the gallery. |
| **People** | Administrators only: issue accounts, change roles, deactivate, reset a password, delete. A new password is shown exactly once. |
| **Account** | Who you are, change your password, sign out. |

Viewer access and an administrator's read-only view of somebody else's project
both show the same notice bar as the web app, and every control that would
change something is switched off.

## The icon and the splash

Both are generated from **`icon.png` at the project root** — that one file is
the only thing to replace.

```bash
dart run flutter_launcher_icons
```

```bash
dart run flutter_native_splash:create
```

Everything is white-backed, because the artwork is a transparent PNG and both
platforms need the plate stated rather than inherited:

- **Android** gets an adaptive icon: white background, the artwork inset 18% so
  the trowel's handle survives a circular launcher mask.
- **iOS** gets the icon flattened onto white — the App Store rejects an icon
  with an alpha channel outright.
- **The splash** is white with the logo centred, in light *and* dark mode. The
  app has no dark theme, so a black splash would flash before a white first
  frame.

The app draws that same file in three more places, so the mark on the home
screen is the mark inside the app:

- the **loading screens**, at 128 dp — the exact size the native splash writes
  it out at, so a cold start reads as one continuous screen (native splash →
  boot → dashboard) with nothing jumping;
- the **top bar**, at 30 dp, beside the `BUNYAD` wordmark;
- and nowhere else. The sign-in poster keeps the plain accent square, because a
  full-colour brick wall on the deep blue gradient fights with it.

> Regenerating the splash rewrites `android/app/src/main/res/values-night*/styles.xml`.
> Those files have one hand-edit — `NormalTheme`'s `windowBackground` is pinned
> to `#FFFFFF` instead of `?android:colorBackground` — which keeps dark-mode
> devices from flashing black behind the Flutter view. Re-apply it if you
> regenerate.

## Layout

```
lib/
  global.dart        the server address and every endpoint — the one file to edit
  main.dart          app entry, theme, the router
  core/
    tokens.dart      the Modernist design tokens, ported from design-system.css + app.css
    theme.dart       those tokens wired into a Material theme
    formatting.dart  money, dates and the phrases the screens repeat (the twin of format.js)
  data/
    api_client.dart  Dio, the bearer interceptor, ApiException, the token store
    models.dart      one class per ApiResponses record, in the same order
    repository.dart  every call the app makes, typed
  state/
    session.dart     who is signed in, and nothing else
  ui/
    routes.dart      the same addresses the SPA routes on, minus the hash
    screens/         one file per screen
    sheets/          the forms: project, stage, expense, share
    widgets/         the design system's parts — buttons, tags, chips, sheets, photos

assets/fonts/        Archivo 400/600/800, bundled so the first paint is never the wrong font
```

## Notes

- **Plain HTTP is allowed** on both platforms, because Bunyad is usually on a
  LAN address. Once your server is behind HTTPS, delete
  `android/app/src/main/res/xml/network_security_config.xml` (and its line in
  `AndroidManifest.xml`) and the `NSAppTransportSecurity` block in
  `ios/Runner/Info.plist`. Nothing in the app depends on cleartext.
- **Photos** are uploaded as they are picked, before the expense is saved —
  the same two-step the web app uses. Uploads never attached to a saved expense
  are swept by the server after 24 hours.
- **Images carry the token**, so they cannot be plain URLs; they are fetched
  with the `Authorization` header and cached on disk.
- **Money** is never computed on the phone. Totals, shares and every label like
  "3.5 Marla" or "250 bags · 18 trolleys" come from the server, so the two
  clients can never disagree about a number.

## Tests

```bash
flutter test
```

Covers the formatting rules the screens depend on and the model parsing that
turns the API's wire values into typed data — including that an absent `active`
flag reads as active rather than deactivated.
