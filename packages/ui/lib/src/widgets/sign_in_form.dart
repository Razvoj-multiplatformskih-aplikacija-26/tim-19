import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Forma za prijavu, ista u mobilnoj aplikaciji i backoffice-u. Ne zna za Bloc: prikazuje [busy] i poruke
/// koje joj da ekran, a unos šalje kroz [onSubmit]. Lozinka se ne pamti nigde.
class SignInForm extends StatefulWidget {
  const SignInForm({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onSubmit,
    this.busy = false,
    this.error,
    this.notice,
  });

  final String title;
  final String subtitle;
  final void Function(String username, String password) onSubmit;
  final bool busy;

  /// Zašto prijava nije uspela (pogrešna lozinka, pogrešna aplikacija, server nije dostupan).
  final String? error;

  /// Zašto je korisnik na prijavi (istekla prijava, odjava).
  final String? notice;

  @override
  State<SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<SignInForm> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _hidden = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.busy) return;
    TextInput.finishAutofillContext();
    widget.onSubmit(_username.text, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: AutofillGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.graphic_eq_rounded, size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text(widget.title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(widget.subtitle, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
                if (widget.notice case final notice?) ...[
                  const SizedBox(height: 16),
                  _Banner(text: notice, color: theme.colorScheme.secondaryContainer),
                ],
                const SizedBox(height: 24),
                TextField(
                  key: const Key('korisnicko-ime'),
                  controller: _username,
                  enabled: !widget.busy,
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Korisničko ime',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('lozinka'),
                  controller: _password,
                  enabled: !widget.busy,
                  obscureText: _hidden,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Lozinka',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _hidden ? 'Prikaži lozinku' : 'Sakrij lozinku',
                      icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _hidden = !_hidden),
                    ),
                  ),
                ),
                if (widget.error case final error?) ...[
                  const SizedBox(height: 16),
                  _Banner(text: error, color: theme.colorScheme.errorContainer),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('prijavi-se'),
                  onPressed: widget.busy ? null : _submit,
                  child: widget.busy
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Prijavi se'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(text),
    ),
  );
}
