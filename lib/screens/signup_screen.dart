// lib/screens/signup_screen.dart
import 'package:campus_marketplace/services/auth_service.dart';
import 'package:campus_marketplace/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  String email = '';
  String password = '';
  String confirmPassword = '';
  final AuthService authService = AuthService();

  bool _isUniandes(String e) =>
      e.trim().toLowerCase().endsWith('@uniandes.edu.co');

  String _mapFirebaseError(FirebaseAuthException e) {
    final code = e.code.toLowerCase();
    if (code == 'email-already-in-use') return 'Este correo ya está registrado.';
    if (code == 'invalid-email') return 'Correo inválido.';
    if (code == 'weak-password') return 'Contraseña débil.';
    return e.message ?? 'Error de autenticación';
  }

  Future<void> _signup() async {
    final scaffold = ScaffoldMessenger.of(context);

    if (!_isUniandes(email)) {
      scaffold.showSnackBar(
        const SnackBar(content: Text('Usa tu correo @uniandes.edu.co')),
      );
      return;
    }
    if (password != confirmPassword) {
      scaffold.showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    if (password.length < 6) {
      scaffold.showSnackBar(
        const SnackBar(content: Text('La contraseña debe tener al menos 6 caracteres')),
      );
      return;
    }

    try {
      scaffold.showSnackBar(
        const SnackBar(content: Text('Creating account...')),
      );

      // 1) Crear usuario en Firebase Auth
      final credential = await authService.signUpWithEmailAndPassword(email.trim(), password);
      final user = credential?.user;

      if (user == null) {
        scaffold.hideCurrentSnackBar();
        scaffold.showSnackBar(const SnackBar(content: Text('Sign up failed')));
        return;
      }

      // 2) Enviar email de verificación (link nativo)
      await user.sendEmailVerification();

      // 3) Crear documento de usuario (si no existe) y marcar is_verified=false
      await FirestoreService.createUser();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'is_verified': false}, SetOptions(merge: true));

      scaffold.hideCurrentSnackBar();

      // 4) Ir a pantalla donde el usuario confirma que ya verificó su email
      if (mounted) {
        context.push('/verification', extra: {'email': email.trim()});
      }
    } on FirebaseAuthException catch (e) {
      scaffold.hideCurrentSnackBar();
      scaffold.showSnackBar(SnackBar(content: Text(_mapFirebaseError(e))));
    } catch (e) {
      scaffold.hideCurrentSnackBar();
      scaffold.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 100),
              const SizedBox(height: 120, width: 120),
              const Text(
                'MERCANDES',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'Sign Up',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                onChanged: (value) => email = value,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                onChanged: (value) => password = value,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                onChanged: (value) => confirmPassword = value,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _signup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Sign Up',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('Or'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  // Puedes decidir si omitir verificación por email en Google Sign-In
                  authService.signInWithGoogle();
                },
                icon: Image.network(
                  'http://pngimg.com/uploads/google/google_PNG19635.png',
                  height: 24.0,
                ),
                label: const Text('Sign up with Google'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Colors.grey),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account?"),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Sign In'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
