# Resumen de Implementación: Hot Items & Optimizaciones (Sprint 4)

Este documento sirve como índice para localizar la documentación específica de las estrategias técnicas implementadas en la funcionalidad de **Hot Items**.

| Estrategia Técnica | Archivo de Documentación | Implementación en Código (Hot Items) |
|-------------------|--------------------------|--------------------------------------|
| **Caching Strategy** | `docs/viva_voce_4/wiki_doc/caching_strategy.md` | Se detalla el sistema **Dual-Layer** (LRU en RAM + Hive en Disco) implementado en `SimilarProductsService` para balancear velocidad y persistencia. |
| **Concurrency Strategy** | `docs/viva_voce_4/wiki_doc/concurrency_strategy.md` | Explica cómo se usan `Futures` en paralelo para agregar señales de popularidad (clicks, ventas) sin bloquear el hilo principal. |
| **Eventual Connectivity** | `docs/viva_voce_4/wiki_doc/eventual_connectivity_strategy.md` | Describe el escenario offline donde el algoritmo de "hotness" se ejecuta localmente usando datos raw cacheados, garantizando funcionalidad sin internet. |
| **Local Storage** | `docs/viva_voce_4/wiki_doc/local_storage_strategy.md` | Define qué datos específicos (eventos de clicks, ventas históricas) se guardan en Hive para permitir el recálculo offline. |
| **Micro Optimizations** | `docs/viva_voce_4/wiki_doc/micro_optimizations_report.md` | Reporte de optimizaciones de renderizado (consts, RepaintBoundary, pre-cálculo de colores) aplicadas en `SimilarProductsSection`. |

