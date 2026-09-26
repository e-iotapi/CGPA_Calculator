# Pointer

The CGPA calculator for BITS Pilani, Goa and Hyderabad —
[pointer-bits-pilani.pages.dev](https://pointer-bits-pilani.pages.dev/).

Maintained by **Siddharth Mishra** — siddhu.cms@gmail.com ·
[github.com/e-iotapi](https://github.com/e-iotapi)

## What it does

- **Your course list, filled in.** Pick your discipline and batch (dual degrees
  included) and every core course is laid out semester by semester from the official
  charts.
- **SGPA and CGPA as you go**, using the BITS rules for NC, RC, W and GD.
- **Actual and Expected profiles** side by side, to plan what a semester needs.
- **Degree progress and forecasts** under Stats: CDC, electives and credits remaining.
- **Evaluative marks** per course, with best-of rules and a calendar of what is due.
- **The finance offshoot score.**
- **Sign in with your BITS account** and your grades follow you to any browser.
- **Install it** to your home screen from Settings; it works offline.

## How sync works

Hive is the local store (IndexedDB in the browser), so everything works offline.

- On sign-in, the whole local state is pulled from Firestore (`users/{uid}`) before
  startup.
- Any change is pushed back, debounced 1.5 s and guarded by a `rev` counter.
- On conflict **the server wins**; the un-pushed local snapshot is kept in
  `syncMeta['backup']`.
- Signing out wipes local IndexedDB, so a shared browser starts clean.

## Moving grades from the old site

Grades in the old site's IndexedDB are not transferred automatically:

1. Open the old site and press <kbd>F12</kbd> → **Console**.
2. Paste [`tools/export_from_old_site.js`](tools/export_from_old_site.js) and press
   Enter. The JSON is copied to your clipboard.
3. Here, sign in, then **Settings → Import from old site**, paste, and confirm.

A plain IndexedDB export will not work: Hive stores courses as binary records, and the
script decodes them.

## Developing

```bash
flutter pub get
flutter run -d chrome --web-port 5000
flutter test
```

`lib/firebase_options.dart` is generated with `flutterfire configure --platforms=web`.
The web API key is public by design; `firestore.rules` restricts every user to their own
`users/{uid}` document.

Pushes to `master` deploy through `.github/workflows/deploy.yml` to Netlify.

## Licence

Apache License 2.0 — see [`LICENSE`](LICENSE).
