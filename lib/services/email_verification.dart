
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/auth_model.dart';

class SignUpAuthViewModel {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  SignUpAuthViewModel({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  final String allowedDomain = 'uniandes.edu.co';

  Future<void> register({
    required SignUpForm form,
    required void Function() onSuccess,
    required void Function(String) onError,
  }) async {
    final email = form.email.trim();
    final pass = form.password;
    final name = form.name.trim();

    final domainOk = email.split('@').length == 2 &&
        email.split('@').last.toLowerCase() == allowedDomain.toLowerCase();

    if (!domainOk) {
      onError('Usa tu correo institucional @$allowedDomain');
      return;
    }
    if (pass.length < 6) {
      onError('La contraseña debe tener al menos 6 caracteres');
      return;
    }
    if (name.isEmpty) {
      onError('Ingresa tu nombre');
      return;
    }

    try {
      // 1) Crear en Auth
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );

      final user = cred.user;
      if (user == null) {
        onError('No se pudo crear el usuario');
        return;
      }

      // (opcional) establecer displayName
      await user.updateDisplayName(name);

      // 2) Enviar verificación por link
      await user.sendEmailVerification();

      // 3) Guardar perfil en Firestore (sin password)
      final uid = user.uid;
      await _db.collection('users').doc(uid).set({
        'email': email,
        'name': name,
        'is_verified': false, // lo pondremos en true cuando confirme
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      onSuccess();
    } on FirebaseAuthException catch (e) {
      onError(_mapFirebaseError(e));
    } catch (e) {
      onError('Error al registrar: ${e.toString()}');
    }
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    final code = e.code.toLowerCase();
    if (code == 'email-already-in-use') return 'Este correo ya está registrado.';
    if (code == 'invalid-email') return 'Correo inválido.';
    if (code == 'weak-password') return 'Contraseña débil.';
    return e.message ?? 'Error de autenticación';
  }
}
