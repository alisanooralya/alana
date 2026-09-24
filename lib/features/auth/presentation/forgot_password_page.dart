import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/features/auth/data/auth_repository.dart';
import 'package:alana/features/auth/data/auth_validators.dart';

import 'widgets/auth_widgets.dart';

/// Halaman lupa password: kirim email tautan reset.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _memuat = false;
  String? _pesanError;
  bool _terkirim = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _kirim() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _pesanError = null;
      _terkirim = false;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _memuat = true);
    try {
      await ref.read(authRepositoryProvider).kirimResetPassword(_email.text);
      if (mounted) setState(() => _terkirim = true);
    } catch (error) {
      if (mounted) setState(() => _pesanError = pesanAuthRamah(error));
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      judul: 'Lupa password',
      subjudul: 'Kami kirim tautan reset ke email kamu.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _kirim(),
              validator: (value) => validasiEmail(value ?? ''),
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          if (_pesanError != null) ...[
            const SizedBox(height: 12),
            AuthErrorText(pesan: _pesanError!),
          ],
          if (_terkirim) ...[
            const SizedBox(height: 12),
            AuthInfoText(
              pesan:
                  'Tautan reset terkirim ke ${_email.text.trim()}. Cek kotak masuk (dan folder spam).',
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _memuat ? null : _kirim,
            child: _memuat
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Kirim tautan reset'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.pushNamed('masuk'),
            child: const Text('Kembali masuk'),
          ),
        ],
      ),
    );
  }
}
