// lib/services/storage_service.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../firebase_options.dart'; // generado por `flutterfire configure`

class StorageService {
  StorageService._internal()
      : _picker = ImagePicker(),
        _storage = FirebaseStorage.instanceFor(
          bucket: DefaultFirebaseOptions.currentPlatform.storageBucket,
        );

  static final StorageService _instance = StorageService._internal();

  factory StorageService() => _instance;

  final ImagePicker _picker;

  final FirebaseStorage _storage;

  // Reglas de validación locales (alineadas con tus Storage Rules)
  static const int _maxBytes = 5 * 1024 * 1024; // 5 MB
  static final RegExp _allowedExt =
      RegExp(r'\.(jpe?g|png)$', caseSensitive: false);
  static final RegExp _allowedMime =
      RegExp(r'^image/(jpeg|jpg|png)$', caseSensitive: false);

  /// Abre la galería, sube al bucket y devuelve el downloadURL (o null si se cancela)
  Future<String?> uploadFromGallery({
    required String ownerUid,
    required String productId,
  }) async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (x == null) return null; // usuario canceló
    return _uploadXFile(ownerUid: ownerUid, productId: productId, xfile: x);
  }

  /// Abre la cámara, sube al bucket y devuelve el downloadURL (o null si se cancela)
  Future<String?> uploadFromCamera({
    required String ownerUid,
    required String productId,
  }) async {
    final x = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (x == null) return null; // usuario canceló
    return _uploadXFile(ownerUid: ownerUid, productId: productId, xfile: x);
  }

  /// Borra un archivo en Storage a partir del downloadURL
  Future<void> deleteByUrl(String downloadUrl) async {
    final ref = _storage.refFromURL(downloadUrl);
    await ref.delete();
  }

  /// Método genérico para subir una imagen desde un File
  Future<String?> uploadImage(
    File file,
    String folder,
  ) async {
    try {
      final String fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String path = 'public/$folder/$fileName';
      
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
      );
      
      final snap = await ref.putFile(file, metadata);
      final url = await snap.ref.getDownloadURL();
      
      return url;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  // ------------------- internos -------------------

  Future<String> _uploadXFile({
    required String ownerUid,
    required String productId,
    required XFile xfile,
  }) async {
    final file = File(xfile.path);

    // Pre-checks para evitar rechazos por reglas
    final String mime = xfile.mimeType ?? 'image/jpeg';
    if (!_allowedMime.hasMatch(mime)) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'invalid-argument',
        message: 'Solo se permiten JPG/PNG (MIME: $mime).',
      );
    }

    final int len = await file.length();
    if (len >= _maxBytes) {
      final mb = (len / (1024 * 1024)).toStringAsFixed(2);
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'invalid-argument',
        message: 'La imagen supera 5MB ($mb MB).',
      );
    }

    final String ext = _ext(xfile.path);
    if (!_allowedExt.hasMatch(ext)) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'invalid-argument',
        message: 'Extensión no permitida: $ext (usa .jpg/.jpeg/.png).',
      );
    }

    final String fileName = 'img_${DateTime.now().millisecondsSinceEpoch}$ext';
    final String path = 'public/products/$ownerUid/$productId/$fileName';
    // Logs útiles durante desarrollo:
    // ignore: avoid_print
    print('Subiendo a: $path (mime: $mime, size: ${len}B)');

    final ref = _storage.ref().child(path);

    final metadata = SettableMetadata(
      contentType: mime,
      customMetadata: {
        // Claves útiles si en reglas las chequeas con metadata['ownerUid']
        'ownerUid': ownerUid,
        'productId': productId,
      },
    );

    final snap = await ref.putFile(file, metadata).whenComplete(() => null);
    final url = await snap.ref.getDownloadURL();
    // ignore: avoid_print
    print('URL subida: $url');
    return url;
  }

  static String _ext(String path) {
    final i = path.lastIndexOf('.');
    return i == -1 ? '.jpg' : path.substring(i).toLowerCase();
  }
}
