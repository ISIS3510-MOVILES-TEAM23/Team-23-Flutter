// lib/screens/verification_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class VerificationScreen extends StatefulWidget {
  final String email;
  const VerificationScreen({super.key, required this.email});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  bool _checking = false;
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Future<void> _resend() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await user.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Correo reenviado')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al reenviar: $e')),
      );
    }
  }

  Future<void> _checkVerified() async {
    setState(() => _checking = true);
    try {
      await _auth.currentUser?.reload();
      final refreshed = _auth.currentUser;
      final ok = refreshed?.emailVerified ?? false;

      if (ok) {
        await _db.collection('users').doc(refreshed!.uid).set(
          {'is_verified': true},
          SetOptions(merge: true),
        );
        if (!mounted) return;
        context.go('/home');
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aún no aparece verificado. Revisa tu correo y vuelve a intentar.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al verificar: $e')),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verifica tu correo')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text('Te enviamos un correo de verificación a:\n${widget.email}',
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _checking ? null : _checkVerified,
              child: _checking
                  ? const CircularProgressIndicator()
                  : const Text('Ya verifiqué mi correo'),
            ),
            TextButton(
              onPressed: _checking ? null : _resend,
              child: const Text('Reenviar correo'),
            ),
          ],
        ),
      ),
    );
  }
}
