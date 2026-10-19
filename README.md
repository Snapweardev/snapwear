# SNAPWEAR apps

Four existing Flutter app projects organized in one repository:

| App | Directory | Local URL |
| --- | --- | --- |
| Customer | `apps/customer` | http://localhost:8301 |
| Retailer / store | `apps/retailer` | http://localhost:8302 |
| Delivery rider | `apps/rider` | http://localhost:8303 |
| Admin | `apps/admin` | http://localhost:8304 |

## Requirements

Flutter with Dart compatible with each app's `pubspec.yaml` (source environment: Flutter 3.47.5 / Dart 3.13.4), Chrome, and a separately configured Firebase backend. The Flutter SDK itself is not included.

## Run locally

In each app directory, run `flutter pub get`, then the matching command:

```sh
# apps/customer
flutter run -d chrome --web-port=8301 --dart-define=SNAPWEAR_LOCAL_TEST=true
# apps/retailer
flutter run -d chrome --web-port=8302 --dart-define=SNAPWEAR_LOCAL_TEST=true
# apps/rider
flutter run -d chrome --web-port=8303 --dart-define=SNAPWEAR_LOCAL_TEST=true
# apps/admin
flutter run -d chrome --web-port=8304 --dart-define=SNAPWEAR_LOCAL_TEST=true
```

The apps expect local Firebase Authentication on port 9099, Firestore on 8080 and order Functions on 5001 for project `demo-snapwear`. Backend code, security rules, test accounts and database data are not included in this four-app source package. Starting only these apps does not provide working sign-in, catalog or order services. The rider build requires local test mode.

## Firebase configuration

Original Firebase configuration files were excluded. `lib/firebase_options.dart` is a placeholder so the source retains its expected import. For your own Firebase project, run `flutterfire configure` inside each app to generate the appropriate options and platform configuration. Keep your generated project configuration local; never commit service-account keys or signing credentials.

## Publication preparation

This is a separate copy of the four projects used for the local launch, rather than the later customer-only review candidate. Original app folders were not modified. Build artifacts, SDK, dependency caches, machine settings and signing files are excluded. No new code license has been selected.

Verification: the original four app projects launched locally. This sanitized copy has not been rebuilt with independent Firebase configuration, and full order workflows have not been verified.

## Environment file

Copy `.env.example` to `.env` at the repository root, then launch an app with `bash scripts/run_app.sh customer` (or `retailer`, `rider`, `admin`). The script passes the file to Flutter using `--dart-define-from-file`; it does not execute the file as shell code. `.env` is ignored by Git. The template contains safe emulator settings only. Flutter defines are compiled into the client and must never contain server passwords, private keys or service-account credentials. Firebase platform configuration still requires the separate setup above.

## Test cases

From each app directory, run `flutter pub get` then `flutter test --reporter expanded`. Tests run without Firebase credentials or emulators. GitHub Actions runs the four suites on pushes and pull requests.

- Customer: basket add/remove/count behavior, outfit budget/stock/store matching, and responsive branding.
- Retailer and admin: invalid sign-in inputs are rejected before Firebase access, plus responsive branding with the correct role.
- Rider: editable sign-in fields, password masking, and responsive branding.

These are unit and widget tests; backend order, payment and dispatch integration tests are not included.
