import 'package:firebase_auth/firebase_auth.dart';

/// Only BITS Pilani campus accounts may use the app. Enforced again in
/// firestore.rules — a client-side check alone is trivially bypassed.
final RegExp _bitsEmail = RegExp(
  r'^[^@]+@(goa|pilani|dubai|hyderabad)\.bits-pilani\.ac\.in$',
  caseSensitive: false,
);

bool isBitsEmail(String? email) =>
    email != null && _bitsEmail.hasMatch(email.trim());

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
