# Métricas de Tiempo de Inicio de la App

## Resumen
Este sistema registra automáticamente el tiempo que toma lanzar la aplicación cada vez que un usuario la abre. La información se guarda en la colección `start-time` de Firestore.

## ¿Qué información se registra?

### Información básica
- **startTime**: Fecha y hora exacta del inicio
- **timestamp**: Timestamp del servidor de Firebase
- **launchDurationMs**: Duración del lanzamiento en milisegundos (desde `main()` hasta el primer frame renderizado)
- **sessionId**: ID único de la sesión
- **userId**: ID del usuario (o 'anonymous' si no está autenticado)

### Información de la app
- **appVersion**: Versión de la aplicación
- **appName**: Nombre de la aplicación
- **packageName**: Nombre del paquete
- **buildNumber**: Número de compilación

### Información del dispositivo

#### Android
- **platform**: 'android'
- **model**: Modelo del dispositivo (ej: Pixel 7)
- **brand**: Marca (ej: Google)
- **androidVersion**: Versión de Android (ej: 13)
- **sdkInt**: SDK version (ej: 33)
- **manufacturer**: Fabricante
- **isPhysicalDevice**: Si es un dispositivo físico o emulador

#### iOS
- **platform**: 'ios'
- **model**: Modelo del dispositivo (ej: iPhone 15 Pro)
- **systemVersion**: Versión del sistema (ej: 17.0)
- **name**: Nombre del dispositivo
- **isPhysicalDevice**: Si es un dispositivo físico o simulador

#### Web
- **platform**: 'web'
- **browserName**: Nombre del navegador
- **userAgent**: User agent del navegador
- **operatingSystem**: Sistema operativo
- **language**: Idioma del navegador
- **vendor**: Proveedor del navegador

### Información de zona horaria
- **timeZone**: Zona horaria del dispositivo
- **timeZoneOffset**: Desplazamiento de zona horaria en minutos

## ¿Cómo obtener métricas?

Usa el método `FirestoreService.getAppStartTimeMetrics()` para obtener estadísticas agregadas:

```dart
// Obtener métricas generales de todos los tiempos
final metrics = await FirestoreService.getAppStartTimeMetrics();

// Obtener métricas solo de Android
final androidMetrics = await FirestoreService.getAppStartTimeMetrics(
  platform: 'android',
);

// Obtener métricas de los últimos 7 días
final recentMetrics = await FirestoreService.getAppStartTimeMetrics(
  lastDays: 7,
);

// Obtener métricas de iOS de los últimos 30 días
final iosMonthlyMetrics = await FirestoreService.getAppStartTimeMetrics(
  platform: 'ios',
  lastDays: 30,
);
```

### Estructura de la respuesta

```dart
{
  'averageLaunchTimeMs': 1250,        // Tiempo promedio de lanzamiento
  'minLaunchTimeMs': 800,             // Tiempo mínimo
  'maxLaunchTimeMs': 2100,            // Tiempo máximo
  'totalLaunches': 150,               // Total de lanzamientos
  'platformBreakdown': {              // Desglose por plataforma
    'android': {
      'averageLaunchTimeMs': 1100,
      'launchCount': 80,
    },
    'ios': {
      'averageLaunchTimeMs': 1450,
      'launchCount': 50,
    },
    'web': {
      'averageLaunchTimeMs': 1200,
      'launchCount': 20,
    },
  },
}
```

## Ejemplo de uso en una pantalla de analytics

```dart
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class AppMetricsScreen extends StatefulWidget {
  @override
  _AppMetricsScreenState createState() => _AppMetricsScreenState();
}

class _AppMetricsScreenState extends State<AppMetricsScreen> {
  Map<String, dynamic>? metrics;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    final data = await FirestoreService.getAppStartTimeMetrics(lastDays: 30);
    setState(() {
      metrics = data;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Métricas de Inicio')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Métricas de Inicio')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tiempo promedio de inicio: ${metrics!['averageLaunchTimeMs']}ms',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Tiempo mínimo: ${metrics!['minLaunchTimeMs']}ms'),
            Text('Tiempo máximo: ${metrics!['maxLaunchTimeMs']}ms'),
            Text('Total de lanzamientos: ${metrics!['totalLaunches']}'),
            SizedBox(height: 16),
            Text(
              'Por plataforma:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ...((metrics!['platformBreakdown'] as Map<String, dynamic>)
                .entries
                .map((entry) => Padding(
                      padding: EdgeInsets.only(left: 16, top: 8),
                      child: Text(
                        '${entry.key}: ${entry.value['averageLaunchTimeMs']}ms '
                        '(${entry.value['launchCount']} lanzamientos)',
                      ),
                    ))),
          ],
        ),
      ),
    );
  }
}
```

## Mejores prácticas

1. **Privacidad**: No se registra información personal identificable más allá del ID de usuario autenticado.

2. **Rendimiento**: El registro es asíncrono y no bloquea el inicio de la app.

3. **Análisis**: Usa los filtros por plataforma y fecha para identificar problemas de rendimiento específicos.

4. **Optimización**: Si los tiempos de inicio son altos, considera:
   - Reducir el trabajo en `main()`
   - Optimizar la inicialización de Firebase
   - Usar lazy loading para componentes pesados
   - Revisar las dependencias innecesarias

## Notas técnicas

- El tiempo se mide desde que se ejecuta `main()` hasta después del primer frame (`addPostFrameCallback`)
- Los errores en el registro no afectan la funcionalidad de la app
- La información del dispositivo ayuda a identificar patrones de rendimiento por modelo/versión
