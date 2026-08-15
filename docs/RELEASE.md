# Release

What stands between the current build and a Play listing. Ordered by what blocks
what, not by effort.

---

## Blockers

### 1. Signing — Gradle is wired, the keystore does not exist

`build.gradle.kts` now reads `android/key.properties` when it is present and signs
release with it, falling back to debug keys when it is absent. So the only thing
missing is the keystore itself.

Until it exists, every release build logs:

```
JustPlay: android/key.properties not found — release builds will be signed
with DEBUG keys and cannot be uploaded to Play.
```

The fallback is deliberate — it keeps `flutter build apk --release` working on a
fresh clone and on CI — and it is also a trap, because a debug-signed APK looks
completely normal until Play rejects it. That is why the warning fires on every
such build rather than staying quiet.

**Generating the keystore is yours to do, not mine.** It creates a credential; it
must never be committed, and nobody should paste it into a chat. `.gitignore`
already blocks `*.jks`, `*.keystore` and `key.properties`.

```bash
keytool -genkey -v -keystore upload-keystore.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Store it **outside the repository**. Then `apps/timekiller/android/key.properties`:

```properties
storePassword=<yours>
keyPassword=<yours>
keyAlias=upload
storeFile=C:/path/outside/the/repo/upload-keystore.jks
```

That is the whole change — Gradle already knows what to do with the file. Confirm
it took effect by checking that the warning above no longer appears, then verify
the signature:

```bash
keytool -printcert -jarfile apps/timekiller/build/app/outputs/flutter-apk/app-release.apk
```

**Enrol in Play App Signing.** Google then holds the *app* signing key and you hold
only the *upload* key. That matters: a lost upload key can be reset by Play support,
whereas losing an app signing key with no enrolment means the listing can never be
updated again. Enrol at first upload — it cannot be added conveniently later.

### 2. Nothing has run on real hardware

Every verification so far is the test harness plus a Windows desktop build. The
Android APK compiles, but no build of this app has been seen on a phone. Touch
targets, the drag gestures in solitaire and word search, safe-area insets around
the notch and gesture bar, and real font rendering are all unvalidated.

Do this before anything else cosmetic.

### 3. Store assets and listing copy

None exist for this app. The previous Unity project produced a full set — privacy
policy, listing copy, Data Safety answers, a console answer sheet — under
`GameStudioPlatform/Docs/Store/`. The wording is largely reusable; the screenshots
and feature graphic are not, because the app looks nothing like it did.

---

## Before the first upload

- **Version** — `apps/timekiller/pubspec.yaml` carries `0.1.0+1`. The build number
  after `+` must increase on every upload; both stores reject a reused one.
- **Target audience: 13+, not Families.** Decided, with reasoning, in
  [DECISIONS.md](DECISIONS.md). The declaration must match how the app actually
  presents, so re-read that section before writing listing copy.
- **Data Safety form.** Today the app collects nothing and sends nothing — records
  are local-only. That answer becomes wrong the moment analytics or ads land, and
  a stale Data Safety declaration is a policy violation, not an oversight.
- **App icon.** `@mipmap/ic_launcher` is still Flutter's default. Needed at every
  density plus a 512×512 for the listing.
- **Ship an app bundle, not the APK.** `flutter build apk --release` produces a
  44.5 MB fat APK carrying every ABI. `flutter build appbundle` lets Play split
  it per device, roughly a third of that on any given phone. Install size is one
  of the few things that measurably moves install conversion.
- **R8 shrinking is on**, and it is verified: CI builds release as well as debug,
  and the shrunk build has been installed and launched on an emulator. Worth
  re-checking after adding any plugin, because R8 failures surface at runtime.

---

## Deliberately not blocking

- **iOS.** No Mac, so it ships through Codemagic later and unvalidated by eye —
  an accepted, recorded risk (ARCHITECTURE.md). Android first.
- **Monetisation.** Ads, IAP and subscriptions are not built. A first release with
  no monetisation is a legitimate way to validate retention before tuning revenue.
- **Backend.** Records are local-only. Cloud sync is additive and can follow.
