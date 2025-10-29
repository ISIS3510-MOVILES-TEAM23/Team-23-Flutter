import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/user_repository.dart';
import '../services/connectivity_service.dart';

class SignupViewModel extends ChangeNotifier {
  final AuthRepository _authRepository;
  final UserRepository _userRepository;
  final ConnectivityService _connectivity = ConnectivityService();

  SignupViewModel({
    AuthRepository? authRepository,
    UserRepository? userRepository,
  })  : _authRepository = authRepository ?? AuthRepository(),
        _userRepository = userRepository ?? UserRepository();

  String name = '';
  String email = '';
  String password = '';
  String confirmPassword = '';
  String? major;
  bool isLoading = false;
  String? errorMessage;
  bool isOffline = false;

  void setName(String value) {
    name = value;
  }

  void setEmail(String value) {
    email = value;
  }

  void setPassword(String value) {
    password = value;
  }

  void setConfirmPassword(String value) {
    confirmPassword = value;
  }

  void setMajor(String? value) {
    major = value;
    notifyListeners();
  }

  bool isUniandes(String e) =>
      e.trim().toLowerCase().endsWith('@uniandes.edu.co');

  String mapFirebaseError(FirebaseAuthException e) {
    final code = e.code.toLowerCase();
    if (code == 'email-already-in-use') return 'Este correo ya está registrado.';
    if (code == 'invalid-email') return 'Correo inválido.';
    if (code == 'weak-password') return 'Contraseña débil.';
    return e.message ?? 'Error de autenticación';
  }

  Future<User?> signup() async {
    // Scenario 2: Validate internet connection before signup
    isOffline = !_connectivity.isConnected;

    if (isOffline) {
      errorMessage = 'Internet connection required to create account. Please connect and try again.';
      notifyListeners();
      throw Exception(errorMessage);
    }

    if (name.trim().isEmpty) {
      throw Exception('El nombre es requerido');
    }
    if (major == null || major!.isEmpty) {
      throw Exception('La carrera es requerida');
    }
    if (!isUniandes(email)) {
      throw Exception('Usa tu correo @uniandes.edu.co');
    }
    if (password != confirmPassword) {
      throw Exception('Passwords do not match');
    }
    if (password.length < 6) {
      throw Exception('La contraseña debe tener al menos 6 caracteres');
    }

    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      // 1) Crear usuario en Firebase Auth
      final credential = await _authRepository.signUpWithEmailAndPassword(
        email.trim(),
        password,
      );
      final user = credential?.user;

      if (user == null) {
        throw Exception('Sign up failed');
      }

      // 2) Enviar email de verificación (link nativo)
      await user.sendEmailVerification();

      // 3) Crear documento de usuario (si no existe) y marcar is_verified=false
      await _userRepository.createUser();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
            'name': name.trim(),
            'major': major,
            'is_verified': false
          }, SetOptions(merge: true));

      isLoading = false;
      notifyListeners();

      return user;
    } catch (e) {
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // ========== GOOGLE SIGN IN - COMMENTED OUT ==========
  // Future<void> signInWithGoogle() async {
  //   try {
  //     isLoading = true;
  //     notifyListeners();

  //     await _authRepository.signInWithGoogle();

  //     isLoading = false;
  //     notifyListeners();
  //   } catch (e) {
  //     isLoading = false;
  //     notifyListeners();
  //     rethrow;
  //   }
  // }
  // ========== END GOOGLE SIGN IN ==========
}

