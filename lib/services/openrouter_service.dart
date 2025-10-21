import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Servicio para analizar imágenes de productos con IA usando OpenRouter
class OpenRouterService {
  static const String _baseUrl = 'https://openrouter.ai/api/v1';
  
  // Modelos disponibles con visión (free tier)
  static const String _defaultModel = 'meta-llama/llama-4-maverick:free';
  static const List<String> availableModels = [
    'qwen/qwen2.5-vl-72b-instruct:free',
    'mistralai/mistral-small-3.2-24b-instruct:free',
    'google/gemma-3-27b-it:free',
    'meta-llama/llama-4-maverick:free',
  ];

  String? _apiKey;

  OpenRouterService() {
    _apiKey = dotenv.env['OPENROUTER_API_KEY'];
    if (_apiKey == null || _apiKey!.isEmpty) {
      debugPrint('⚠️ [OpenRouter] API key no configurada en .env');
    }
  }

  /// Analiza una imagen de producto y retorna sugerencias para el formulario
  Future<ProductSuggestions> analyzeProductImage({
    required String imageUrl,
    required List<String> availableCategories,
    String? model,
  }) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('OpenRouter API key no configurada. Revisa tu archivo .env');
    }

    final selectedModel = model ?? _defaultModel;
    
    debugPrint('🤖 [OpenRouter] Analizando imagen con modelo: $selectedModel');
    debugPrint('📸 [OpenRouter] URL de imagen: $imageUrl');

    // Construir el prompt con las categorías disponibles
    final categoriesText = availableCategories.join(', ');
    final prompt = '''
Analiza esta imagen de un producto que un estudiante universitario quiere vender en un marketplace.

Categorías disponibles: $categoriesText

Por favor, proporciona la siguiente información en formato JSON EXACTO (sin markdown, solo el JSON):

{
  "title": "Título corto y descriptivo del producto (máximo 60 caracteres)",
  "description": "Descripción detallada del producto, incluyendo estado, características relevantes y por qué un estudiante lo compraría (máximo 300 caracteres)",
  "category": "Una de las categorías disponibles que mejor se ajuste",
  "price": precio_sugerido_en_dolares_como_numero
}

Responde SOLO con el JSON, sin explicaciones adicionales.
''';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://campus-marketplace.app',
          'X-Title': 'Campus Marketplace',
        },
        body: jsonEncode({
          'model': selectedModel,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': prompt,
                },
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': imageUrl,
                  },
                },
              ],
            },
          ],
          'temperature': 0.7,
          'max_tokens': 500,
        }),
      );

      debugPrint('📡 [OpenRouter] Status: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        final errorBody = response.body;
        debugPrint('❌ [OpenRouter] Error response: $errorBody');
        throw Exception('OpenRouter API error: ${response.statusCode} - $errorBody');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = data['choices']?[0]?['message']?['content'] as String?;
      
      if (content == null || content.isEmpty) {
        throw Exception('No se recibió respuesta del modelo');
      }

      debugPrint('📝 [OpenRouter] Respuesta: $content');

      // Extraer JSON de la respuesta (por si viene con markdown)
      String jsonContent = content.trim();
      
      // Remover markdown code blocks si existen
      if (jsonContent.startsWith('```json')) {
        jsonContent = jsonContent.substring(7);
      } else if (jsonContent.startsWith('```')) {
        jsonContent = jsonContent.substring(3);
      }
      
      if (jsonContent.endsWith('```')) {
        jsonContent = jsonContent.substring(0, jsonContent.length - 3);
      }
      
      jsonContent = jsonContent.trim();

      // Parsear el JSON
      final suggestions = jsonDecode(jsonContent) as Map<String, dynamic>;
      
      return ProductSuggestions.fromJson(suggestions, availableCategories);
    } catch (e, stackTrace) {
      debugPrint('❌ [OpenRouter] Error: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Analiza múltiples imágenes (usa solo la primera por ahora)
  Future<ProductSuggestions> analyzeMultipleImages({
    required List<String> imageUrls,
    required List<String> availableCategories,
    String? model,
  }) async {
    if (imageUrls.isEmpty) {
      throw Exception('No hay imágenes para analizar');
    }
    
    // Por ahora, analizar solo la primera imagen
    // En el futuro se puede mejorar para analizar todas
    return analyzeProductImage(
      imageUrl: imageUrls.first,
      availableCategories: availableCategories,
      model: model,
    );
  }
}

/// Clase que representa las sugerencias generadas por la IA
class ProductSuggestions {
  final String title;
  final String description;
  final String category;
  final double price;

  ProductSuggestions({
    required this.title,
    required this.description,
    required this.category,
    required this.price,
  });

  factory ProductSuggestions.fromJson(
    Map<String, dynamic> json,
    List<String> availableCategories,
  ) {
    // Extraer y validar los campos
    String title = (json['title'] as String? ?? '').trim();
    String description = (json['description'] as String? ?? '').trim();
    String category = (json['category'] as String? ?? '').trim();
    double price = 0.0;

    // Parsear precio
    final priceValue = json['price'];
    if (priceValue is num) {
      price = priceValue.toDouble();
    } else if (priceValue is String) {
      price = double.tryParse(priceValue) ?? 0.0;
    }

    // Validar categoría (debe estar en las disponibles)
    if (!availableCategories.any((c) => 
        c.toLowerCase() == category.toLowerCase())) {
      // Si no coincide exactamente, buscar la más similar
      category = availableCategories.firstWhere(
        (c) => c.toLowerCase().contains(category.toLowerCase()),
        orElse: () => availableCategories.isNotEmpty 
            ? availableCategories.first 
            : '',
      );
    } else {
      // Usar el nombre exacto de la categoría disponible
      category = availableCategories.firstWhere(
        (c) => c.toLowerCase() == category.toLowerCase(),
      );
    }

    // Límites de caracteres
    if (title.length > 60) {
      title = '${title.substring(0, 57)}...';
    }
    
    if (description.length > 300) {
      description = '${description.substring(0, 297)}...';
    }

    return ProductSuggestions(
      title: title,
      description: description,
      category: category,
      price: price,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'price': price,
    };
  }

  @override
  String toString() {
    return 'ProductSuggestions(title: $title, category: $category, price: \$$price)';
  }
}

