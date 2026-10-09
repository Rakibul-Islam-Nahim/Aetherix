import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/admin/admin_api.dart';
import '../../core/admin/admin_session.dart';
import '../../core/theme/app_theme.dart';
import 'admin_panel_page.dart';

/// Password gate for the admin panel. Receives the typed password,
/// calls POST /admin/login, and on success navigates to
/// [AdminPanelPage]. Matches the Aetherix theme.
class AdminLoginPage extends ConsumerStatefulWidget {
  const AdminLoginPage({super.key});

  @override
  ConsumerState<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends ConsumerState<AdminLoginPage> {
  final _ctrl = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pw = _ctrl.text;
    if (pw.isEmpty) {
      setState(() => _error = 'Password required');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = ref.read(adminApiProvider);
      final session = ref.read(adminSessionProvider);
      final r = await api.login(pw);
      await session.save(
        token: r.token,
        expiresInMinutes: r.expiresInMinutes,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminPanelPage()),
      );
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.statusCode == 401
            ? 'Invalid password'
            : 'Login failed: ${e.message}';
      });
    } catch (e) {
      setState(() => _error = 'Login failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgSecondary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 18),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const MonoText(
          'ADMIN ACCESS',
          color: AppColors.lime,
          size: 12,
          weight: FontWeight.w800,
          letterSpacing: 2,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: StatusDot('RESTRICTED AREA')),
                  const SizedBox(height: AppSpacing.md),
                  const Center(
                    child: Text(
                      'ADMIN',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 6,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Center(
                    child: MonoText(
                      'ENTER CREDENTIALS TO PROCEED',
                      color: AppColors.textMuted,
                      size: 10,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextField(
                    controller: _ctrl,
                    autofocus: true,
                    obscureText: _obscure,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline, size: 16),
                      hintText: 'PASSWORD',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 16,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      errorText: _error,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    icon: _busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppColors.limeInk,
                            ),
                          )
                        : const Icon(Icons.login, size: 14),
                    label: Text(_busy ? 'AUTHENTICATING…' : 'UNLOCK'),
                    onPressed: _busy ? null : _submit,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: MonoText(
                      'ALL ATTEMPTS ARE LOGGED',
                      color: AppColors.textMuted,
                      size: 9,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
