# Investigación de Flighty

Fecha: 2026-10-23.
Objetivo: definir una aplicación iOS propia a partir de evidencia del comportamiento de Flighty.

## Evidencia disponible

- El directorio del proyecto no contiene implementación.
- La búsqueda inicial no localizó Flighty. El usuario confirmó que está instalada en su Mac e iPhone; falta resolver la ruta de la instalación.
- No hay herramientas REA anunciadas en esta sesión. No se modificó la configuración.
- Fuente pública consultada: https://flighty.com/ (2026-10-23).
- El usuario aportó 21 capturas de iPhone. Análisis visual: [inventario de pantallas](flighty-screenshots.md). No se ejecutó ni descompiló Flighty.
- Actualización: se abrió Flighty en macOS y se observaron ajustes, versión, proveedores, importaciones y Friends. Véase [mapa funcional y dependencias](flighty-functional-plan.md). Sí hay observación de ejecución de UI; no hay descompilación.

La web describe seguimiento de vuelos, alertas, información de puerta y equipaje, seguimiento del avión entrante, predicciones de demoras, importación de viajes, funciones sociales e historial. Son declaraciones del fabricante; no se verificaron ejecutando la app. No hay Evidence IDs de REA todavía.

## Preguntas y estado

| Pregunta | Evidencia necesaria | Estado |
| --- | --- | --- |
| ¿Qué funciones ofrece? | Documentación pública y app | Parcial: documentación pública |
| ¿Cómo son sus pantallas y navegación? | Capturas o grabaciones de flujos concretos | Parcial: inicio, búsqueda, detalle y Passport visibles; transiciones sin verificar |
| ¿Cómo cambia un vuelo durante el viaje? | Observación de estados y eventos | Pendiente |
| ¿Qué guarda localmente y qué requiere red? | Artefacto local o capturas de tráfico autorizadas | Pendiente |
| ¿Qué permite conocer el paquete distribuido? | Archivo .ipa o .app con versión identificada | Pendiente |
| ¿Qué fuente de datos usará la versión propia? | Requisitos de cobertura y evaluación de proveedores | Pendiente |

## Primera secuencia de observación

1. Inicio y permisos solicitados.
2. Buscar y agregar un vuelo por número y fecha.
3. Abrir el detalle: horarios, zonas horarias, estado, terminal y puerta.
4. Explorar mapa, avión entrante y avisos de demora.
5. Consultar un vuelo pasado y las estadísticas.

Registrar versión de Flighty, versión de iOS, acciones y resultados visibles. Separar cada observación de las inferencias sobre su implementación.

## Propuesta provisional para la versión propia

El usuario corrigió su selección y pidió todas las funciones. El objetivo es una versión propia con cobertura funcional completa; las capturas son evidencia parcial y no un catálogo exhaustivo.

Orden de trabajo propuesto:

1. Lista, búsqueda y agregado de vuelos; mapa y detalle; reserva y asiento.
2. Datos operativos reales, horarios y cambios de estado; clima, condiciones aeroportuarias y avión entrante.
3. Alertas, Live Activities, Dynamic Island y widgets.
4. Historial, Passport, estadísticas y exportación para compartir.
5. Friends, sincronización e importación de viajes desde calendario, correo y TripIt.

Estas etapas organizan el trabajo; no recortan el alcance. Confirmar los flujos que todavía no aparecen en las capturas mediante observación adicional. Evaluar fuentes de datos y costos antes de comprometer cobertura, latencia o precisión equivalentes a Flighty. El sistema de suscripción y sus bloqueos no se consideran necesarios automáticamente para una versión propia: falta definir el modelo de distribución.

El comportamiento de servidores, fuentes de datos y modelos de predicción sigue siendo desconocido. Inspeccionar el cliente no garantiza recuperar esos sistemas.
