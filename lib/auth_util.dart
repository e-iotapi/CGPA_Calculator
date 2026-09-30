import 'package:cgpa_calculator/core/models/programmes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// BITS Pilani campus accounts may use the app, as may owners (below).
/// Enforced again in
/// firestore.rules — a client-side check alone is trivially bypassed.
final RegExp _bitsEmail = RegExp(
  r'^[^@]+@(goa|pilani|dubai|hyderabad)\.bits-pilani\.ac\.in$',
  caseSensitive: false,
);

bool isBitsEmail(String? email) =>
    email != null && _bitsEmail.hasMatch(email.trim());

/// A non-BITS account gets in only as an owner: `owners/{email}` exists and
/// is active (ARCHITECTURE.md §5). Null when Firestore could not say, so a
/// dropped connection does not sign an owner out.
Future<bool?> isOwner(User user, {FirebaseFirestore? db}) async {
  final email = user.email?.trim().toLowerCase();
  if (email == null || email.isEmpty || !user.emailVerified) return false;
  try {
    final doc =
        await (db ?? FirebaseFirestore.instance).doc('owners/$email').get();
    return doc.exists && doc.data()?['active'] == true;
  } on FirebaseException catch (e) {
    // Rules refuse the read for anyone who is not on the list.
    return e.code == 'permission-denied' ? false : null;
  }
}

/// Who may use the app: a BITS campus account, or an owner.
Future<bool?> mayUseApp(User user) async =>
    isBitsEmail(user.email) ? true : isOwner(user);

/// What a BITS address says: f20230802@goa.bits-pilani.ac.in is a first
/// degree, 2023 batch, at Goa.
enum DegreeLevel { first, higher, phd }

typedef BitsAddress = ({DegreeLevel? level, int? year, Campus? campus});

final _address = RegExp(
  r'^([fhp])?(\d{4})?\d*@([a-z]+)\.bits-pilani\.ac\.in$',
  caseSensitive: false,
);

/// The domain alone, for an address whose local part is not a student id
/// (a faculty account like testfaculty@goa...) — the campus is still known
/// even though there is no batch or level to read (BUG-33).
final _domain = RegExp(
  r'@([a-z]+)\.bits-pilani\.ac\.in$',
  caseSensitive: false,
);

/// A batch year Pointer can hold: stored as two digits, so this century,
/// and no later than next year's intake.
bool yearInRange(int year) => year >= 2000 && year <= DateTime.now().year + 1;

/// Reads [email] beside the domain check. Anything it cannot read comes
/// back null, to be asked for; it never fails sign-in and never guesses a
/// campus.
BitsAddress parseBitsAddress(String? email) {
  final trimmed = email?.trim() ?? '';
  final m = _address.firstMatch(trimmed);
  if (m != null) {
    final year = int.tryParse(m.group(2) ?? '');
    return (
      level: switch (m.group(1)?.toLowerCase()) {
        'f' => DegreeLevel.first,
        'h' => DegreeLevel.higher,
        'p' => DegreeLevel.phd,
        _ => null,
      },
      year: year != null && yearInRange(year) ? year : null,
      campus: Campus.named(m.group(3)!.toLowerCase()),
    );
  }
  // Not shaped like a student id (a faculty address, say) — still read the
  // campus off the domain, so onboarding never claims it cannot tell the
  // campus for a BITS address that plainly names one.
  final d = _domain.firstMatch(trimmed);
  return (
    level: null,
    year: null,
    campus: d == null ? null : Campus.named(d.group(1)!.toLowerCase()),
  );
}

/// "Siddharth Mishra" -> "Siddharth". Falls back to the email local part,
/// which for a BITS ID is something like f20220123.
String firstNameOf(User? u) {
  final n = u?.displayName?.trim() ?? '';
  if (n.isNotEmpty) return n.split(RegExp(r'\s+')).first;
  final e = u?.email ?? '';
  final local = e.contains('@') ? e.split('@').first : e;
  return local.isEmpty ? 'there' : local;
}

/// Greeting for the header, e.g. "Good evening, Siddharth".
String greeting() {
  final name = firstNameOf(FirebaseAuth.instance.currentUser);
  final h = DateTime.now().hour;
  final part =
      h < 12
          ? 'Good morning'
          : h < 17
          ? 'Good afternoon'
          : 'Good evening';
  return '$part, $name';
}
