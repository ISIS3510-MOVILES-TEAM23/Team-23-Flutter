# 🛠️ Resumen Técnico Interno: Implementación Hot Items

Este documento es para entender rápidamente qué tocamos en el código y por qué tomamos esas decisiones técnicas en el Sprint 4.

## 1. Caching Strategy (Estrategia de Doble Capa)

**¿Qué hicimos?**
No nos conformamos con guardar datos solo en disco o solo en memoria. Implementamos un sistema híbrido.
1.  **RAM (LRU):** Para navegación instantánea (si sales y vuelves a entrar al producto).
2.  **Disco (Hive):** Para persistencia (si cierras la app o te quedas sin internet).

**📂 Archivos modificados:**
*   `lib/services/similar_products_service.dart`: Aquí instanciamos el `LruCacheService` (memoria) y llamamos al `CacheService` (disco).
*   `lib/services/cache_service.dart`: Agregamos métodos para guardar listas crudas de clicks y ventas en Hive.

**¿Para qué?**
*   Si el usuario navega entre productos de la misma categoría, la respuesta es inmediata (<1ms) gracias a la RAM.
*   Si el usuario cierra la app y vuelve en 2 días sin internet, los datos siguen ahí gracias a Hive.

---

## 2. Concurrencia (Concurrency Strategy)

**¿Qué hicimos?**
Dart es "single-threaded", pero usamos **Futures** para manejar operaciones pesadas de Entrada/Salida (I/O) sin congelar la interfaz. La "concurrencia" aquí se refiere a cómo orquestamos la obtención de datos de múltiples fuentes (Firestore: Posts, Clicks, Ventas) de forma asíncrona.

**📂 Archivos modificados:**
*   `lib/services/similar_products_service.dart`: En el método `getSimilarHotProducts`.
    *   Usamos `await` secuencial para obtener los snapshots de Firestore.
    *   El cálculo matemático (el algoritmo de *hotness*) se ejecuta en el hilo principal *después* de que los datos llegan, asegurando que no bloqueamos la UI mientras esperamos la red.

**¿Para qué?**
Para que el usuario pueda seguir haciendo scroll o viendo la imagen del producto mientras nosotros estamos "matemáticamente" calculando qué productos son populares en segundo plano (en el event loop).

---

## 3. Eventual Connectivity (Modo Offline Inteligente)

**¿Qué hicimos?**
Esta es la parte más interesante. En lugar de mostrar un error o una lista vieja y estática cuando no hay internet, **recalculamos** el ranking en el dispositivo.

**📂 Archivos modificados:**
*   `lib/services/similar_products_service.dart`: Agregamos un bloque `if (isOffline)`.
    *   Ahí dentro, leemos los datos crudos de Hive.
    *   Ejecutamos el **mismo algoritmo** de ordenamiento que usamos online.
*   `lib/widgets/similar_products_section.dart`: Agregamos un indicador visual (Badge "Cached") para avisar al usuario que está viendo datos guardados.

**¿Para qué?**
Para dar una experiencia de usuario "seamless". Si se va el internet, la sección de "Hot Items" sigue funcionando y sigue ordenando los productos por popularidad basada en la última información conocida, en lugar de desaparecer.

---

## 4. Local Storage (Datos Crudos vs Procesados)

**¿Qué hicimos?**
Decidimos **NO** guardar la lista final de "Top 5 Productos". En su lugar, guardamos los "ingredientes" para cocinar esa lista:
1.  Todos los Posts de la categoría.
2.  Todos los eventos de Clicks recientes.
3.  Todas las Ventas recientes.

**📂 Archivos modificados:**
*   `lib/services/cache_service.dart`: Creamos "Cajas" (Boxes) en Hive específicas para `product_click_events` y `sales_data`.

**¿Para qué?**
Si solo guardáramos la lista final, sería estática. Al guardar los datos crudos, si cambiamos el algoritmo mañana (ej: los clicks valen 5 puntos en vez de 3), la app puede aplicar ese cambio offline recalculando con los datos crudos que ya tiene. Nos da flexibilidad total offline.

---

## 5. Micro Optimizations (UI Performance)

**¿Qué hicimos?**
La lista de productos tiene imágenes, sombras y gradientes. Eso es costoso de dibujar para el celular. Optimizamos el renderizado.

**📂 Archivos modificados:**
*   `lib/widgets/similar_products_section.dart`:
    1.  **`const` constructors:** Usamos `const` en todo lo que no cambia (Padding, SizedBox) para que Flutter no lo reconstruya.
    2.  **Pre-cálculo de colores:** Definimos los colores y gradientes en una clase estática `_SimilarProductsColors` para no crear objetos de color en cada frame.
    3.  **`RepaintBoundary`:** Envolvimos cada tarjeta de producto en esto. Si una tarjeta cambia (ej: carga la imagen), no obliga a repintar toda la lista, solo esa tarjeta.

**¿Para qué?**
Para que el scroll horizontal se sienta suave (60fps) incluso en celulares gama baja, y para gastar menos batería al evitar cálculos gráficos innecesarios.

