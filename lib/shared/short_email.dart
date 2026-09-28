/// A BITS address without its domain: `f20190001@goa`. Rows show emails in
/// this form (UI.md T9.1, as the user chose).
String shortEmail(String e) => e.split('.bits-pilani.ac.in').first;
