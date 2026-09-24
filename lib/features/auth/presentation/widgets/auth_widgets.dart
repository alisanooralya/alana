import 'package:flutter/material.dart';

/// Kerangka halaman auth: logo, judul, dan isi form.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.judul,
    required this.subjudul,
    required this.child,
  });

  final String judul;
  final String subjudul;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.menu_book, size: 56, color: scheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    'Alana',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    judul,
                    textAlign: TextAlign.center,
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subjudul,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kolom password dengan tombol lihat/sembunyikan.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.validator,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String)? validator;
  final TextInputAction textInputAction;
  final void Function(String)? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _sembunyi = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _sembunyi,
      enableSuggestions: false,
      autocorrect: false,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator == null
          ? null
          : (value) => widget.validator!(value ?? ''),
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline),
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: _sembunyi ? 'Lihat password' : 'Sembunyikan password',
          icon: Icon(
            _sembunyi
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _sembunyi = !_sembunyi),
        ),
      ),
    );
  }
}

/// Tombol "Lanjutkan dengan Google".
class GoogleButton extends StatelessWidget {
  const GoogleButton({
    super.key,
    required this.onPressed,
    required this.memuat,
  });

  final VoidCallback? onPressed;
  final bool memuat;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: memuat ? null : onPressed,
      icon: memuat
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.g_mobiledata, size: 28),
      label: const Text('Lanjutkan dengan Google'),
    );
  }
}

/// Pesan error form (merah, dengan ikon).
class AuthErrorText extends StatelessWidget {
  const AuthErrorText({super.key, required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              pesan,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pesan info/sukses (aksen primer).
class AuthInfoText extends StatelessWidget {
  const AuthInfoText({super.key, required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: scheme.onPrimaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              pesan,
              style: TextStyle(color: scheme.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
