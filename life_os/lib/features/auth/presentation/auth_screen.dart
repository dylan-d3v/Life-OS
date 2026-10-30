import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_controller.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _masterKeyController = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _obscureMasterKey = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _masterKeyController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final masterKey = _masterKeyController.text;

    final controller = ref.read(authControllerProvider.notifier);

    if (_isSignUp) {
      controller.signUp(
        email: email,
        password: password,
        masterKeyPassword: masterKey,
      );
    } else {
      controller.signIn(
        email: email,
        password: password,
        masterKeyPassword: masterKey,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    ref.listen<AsyncValue<void>>(authControllerProvider, (_, state) {
      if (state.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.error.toString()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 460,
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B), // Slate 800
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo / Header
                  const Icon(
                    Icons.shield_outlined,
                    size: 48,
                    color: Color(0xFF38BDF8), // Sky 400
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Life-OS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isSignUp
                        ? 'Crea tu cuenta con privacidad Zero-Knowledge'
                        : 'Accede a tu Segundo Cerebro seguro',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Selector Login / Registro
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => setState(() => _isSignUp = false),
                          style: TextButton.styleFrom(
                            backgroundColor: !_isSignUp
                                ? const Color(0xFF334155)
                                : Colors.transparent,
                            foregroundColor:
                                !_isSignUp ? Colors.white : const Color(0xFF94A3B8),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Iniciar Sesión'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton(
                          onPressed: () => setState(() => _isSignUp = true),
                          style: TextButton.styleFrom(
                            backgroundColor: _isSignUp
                                ? const Color(0xFF334155)
                                : Colors.transparent,
                            foregroundColor:
                                _isSignUp ? Colors.white : const Color(0xFF94A3B8),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Registrarse'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Correo Electrónico',
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.email_outlined,
                          color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || !value.contains('@')) {
                        return 'Ingresa un correo electrónico válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Contraseña de Cuenta',
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.lock_outline,
                          color: Color(0xFF64748B)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: const Color(0xFF64748B),
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.length < 6) {
                        return 'Mínimo 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Master Encryption Password (E2EE)
                  TextFormField(
                    controller: _masterKeyController,
                    obscureText: _obscureMasterKey,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Contraseña Maestra E2EE',
                      helperText: 'Cifra tus datos localmente (Nunca viaja a la nube)',
                      helperMaxLines: 2,
                      helperStyle: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 12,
                      ),
                      prefixIcon: const Icon(Icons.vpn_key_outlined,
                          color: Color(0xFF38BDF8)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureMasterKey
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: const Color(0xFF64748B),
                        ),
                        onPressed: () {
                          setState(
                              () => _obscureMasterKey = !_obscureMasterKey);
                        },
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.length < 8) {
                        return 'La contraseña maestra debe tener al menos 8 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Botón Enviar
                  ElevatedButton(
                    onPressed: authState.isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7), // Sky 600
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: authState.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isSignUp
                                ? 'Crear Cuenta y Bóveda'
                                : 'Iniciar Sesión',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
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

