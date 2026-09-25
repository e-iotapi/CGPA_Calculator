# cgpa_calculator

CGPA Calculator

CGPA Calculator For BITS: Track & Compare for BITS Pilani
The ultimate CGPA Calculator designed exclusively for students of BITS Pilani. Say goodbye to manual, error-prone calculations. Our app provides an effortless and accurate way to track your academic progress throughout your journey at BITS.

This CGPA Calculator simplifies your life by automating the entire tracking process. With a user-friendly interface tailored for BITSians, you can instantly compute your CGPA, maintain a history of your grades, and plan for future semesters with confidence. It's the essential academic tool for every BITS Pilani student.

Key Features:
Automatic Course Lists: Courses are automatically added based on your selected discipline at BITS, saving you time.

Compare CGPA Scenarios: Plan your academic goals by comparing your potential CGPA across two different grade profiles.

Minor Offshoot Calculator: Plan your minor by viewing and comparing different grade scenarios.

Smart Sorting: Easily organize and view your courses sorted by grades or credits to better understand your performance.

Multiple Themes: Personalize your experience by choosing from a variety of themes to suit your style.

Add Electives Easily: A powerful search option allows you to find and add your elective courses in seconds.

Struggling to calculate your CGPA on your iPhone as a BITS Pilani student? Look no further! This easy-to-use web app brings the power of CGPA Calculation directly to iOS devices -no App Store download needed! Just open your browser, enter your grades, and get instant, accurate results. Designed by BITSian, for BITSians-now available everywhere, hassle-free.

App Links-

https://play.google.com/store/apps/details?id=com.srijen.cgpa_calculator, (500+ downloads in Play Store)

iOS and Web-
https://cgpa-calculator-bits.vercel.app/, (50+ Users in Web)

---

## About this fork

Maintained by **Siddharth Mishra** — siddhu.cms@gmail.com · [github.com/e-iotapi](https://github.com/e-iotapi)

This is a **web-only fork** of [Srijen-Raja/CGPA_Calculator](https://github.com/Srijen-Raja/CGPA_Calculator),
originally created by **Srijen Raja** (srijenapps@gmail.com) and licensed under the
Apache License 2.0. The original `LICENSE` is retained unchanged. Credit for the
underlying calculator belongs to the original author; the sync, auth and web-deployment
work in this fork is by the maintainer above.

### What's different

The upstream app stores everything locally in Hive, which on the web means IndexedDB —
scoped to one browser on one device. This fork adds **Google sign-in and cloud sync**, so
your grades follow you to any browser:

- Hive stays the local cache, so the UI and calculation logic are untouched.
- On sign-in, the whole local state is pulled from Firestore (`users/{uid}`) before startup.
- Any change to a Hive box is pushed back, debounced 1.5s, guarded by a `rev` counter.
- On conflict **the server wins**, and the un-pushed local snapshot is kept in `syncMeta['backup']`.
- Signing out wipes local IndexedDB, so a shared browser starts clean for the next user.

The Android, iOS, macOS, Windows and Linux targets have been removed along with their
native-only dependencies. This fork builds for the web only.

### Migrating from the old site

Your existing grades live in the old site's IndexedDB and are **not** transferred
automatically. To bring them across:

1. Open the old site and press <kbd>F12</kbd> → **Console**.
2. Paste the contents of [`tools/export_from_old_site.js`](tools/export_from_old_site.js) and press Enter.
   The JSON is copied to your clipboard.
3. On this site, sign in, then go to **Settings → Import from old site**, paste, and confirm.

A plain export of IndexedDB will *not* work: Hive stores `Course` objects as binary
records, so the script decodes them before exporting.

### Developing

```bash
flutter pub get
flutter run -d chrome --web-port 5000
```

Firebase config (`lib/firebase_options.dart`) is generated with
`flutterfire configure --platforms=web`. The web API key is public by design — access is
controlled by `firestore.rules`, which restricts every user to their own `users/{uid}`
document.

Deploys run from `.github/workflows/deploy.yml` on push to `master`, building the web
bundle and publishing it to Netlify.
