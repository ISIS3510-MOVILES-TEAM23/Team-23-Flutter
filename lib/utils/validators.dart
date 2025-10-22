/// Utilidades de validación para formularios
/// Contiene reglas de validación reutilizables
class Validators {
  /// Valida un email
  /// Retorna null si es válido, String con error si es inválido
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El email es requerido';
    }

    final trimmed = value.trim();

    // Regex simple para email
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(trimmed)) {
      return 'Ingresa un email válido';
    }

    return null; // Válido
  }

  /// Valida una contraseña
  /// Retorna null si es válida, String con error si es inválida
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es requerida';
    }

    if (value.length < 6) {
      return 'Mínimo 6 caracteres';
    }

    return null; // Válida
  }

  /// Valida una contraseña para registro (más estricta)
  static String? validatePasswordSignUp(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es requerida';
    }

    if (value.length < 6) {
      return 'Mínimo 6 caracteres';
    }

    if (value.length > 50) {
      return 'Máximo 50 caracteres';
    }

    // Al menos una letra
    if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
      return 'Debe contener al menos una letra';
    }

    // Al menos un número
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Debe contener al menos un número';
    }

    return null; // Válida
  }

  /// Valida confirmación de contraseña
  static String? validatePasswordConfirmation(String? value, String? password) {
    if (value == null || value.isEmpty) {
      return 'Confirma tu contraseña';
    }

    if (value != password) {
      return 'Las contraseñas no coinciden';
    }

    return null; // Válida
  }

  /// Valida un nombre (para sign up)
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El nombre es requerido';
    }

    final trimmed = value.trim();

    if (trimmed.length < 2) {
      return 'Mínimo 2 caracteres';
    }

    if (trimmed.length > 50) {
      return 'Máximo 50 caracteres';
    }

    // Solo letras, espacios y algunos caracteres especiales
    if (!RegExp(r"^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s'-]+$").hasMatch(trimmed)) {
      return 'Solo letras y espacios';
    }

    return null; // Válido
  }

  /// Valida campo genérico no vacío
  static String? validateNotEmpty(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName es requerido';
    }
    return null;
  }
}

