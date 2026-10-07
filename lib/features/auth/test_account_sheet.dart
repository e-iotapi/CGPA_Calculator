import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/env/test_accounts.g.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:flutter/material.dart';

/// Staging only (owner, 2026-10-06): pick a test account, type its
/// password. Reached only behind `isTestEnv`, so production drops it.
Future<({String email, String password})?> pickTestAccount(
  BuildContext context,
) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (_) => const _TestAccountSheet(),
);

class _TestAccountSheet extends StatefulWidget {
  const _TestAccountSheet();

  @override
  State<_TestAccountSheet> createState() => _TestAccountSheetState();
}

class _TestAccountSheetState extends State<_TestAccountSheet> {
  final _password = TextEditingController();
  String? _email;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _go() {
    if (_password.text.isEmpty) return;
    Navigator.pop(context, (email: _email!, password: _password.text));
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final email = _email;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              email ?? 'Test accounts',
              style: TypeScale.title.copyWith(fontSize: 18, color: p.text),
            ),
            const SizedBox(height: Space.sm),
            if (email == null)
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final e in testAccounts.entries)
                      ListTile(
                        title: Text(e.key),
                        subtitle: Text(e.value),
                        onTap: () => setState(() => _email = e.value),
                      ),
                  ],
                ),
              )
            else ...[
              TextField(
                controller: _password,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Password'),
                onSubmitted: (_) => _go(),
              ),
              const SizedBox(height: Space.md),
              PrimaryButton(label: 'Sign in', onPressed: _go),
              TextButton(
                onPressed: () => setState(() => _email = null),
                child: const Text('Another account'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
