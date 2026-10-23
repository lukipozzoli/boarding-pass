# Versión propia: mapa funcional y dependencias

Actualizado: 2026-10-23. Alcance: todas las funciones de viaje identificadas; el usuario no tiene Pro. No se requiere contratarlo para continuar esta investigación.

## Evidencia local observada

Se abrió Flighty mediante la interfaz de macOS y se recorrieron My Flights → perfil → Settings → About → Data Providers, Import Flights y Friends. No se modificaron ajustes, vuelos ni suscripciones.

- **Versión:** 4.11.2 (4848), visible en About.
- **Proveedores declarados:** Apple WeatherKit, Avinor, FAA, FlightAware, FlightStats, IATA y NOAA. La pantalla dice que estos socios contribuyen parcialmente; no identifica contratos, endpoints, productos o campos específicos.
- **Settings:** alertas propias y de amigos, calendario, TripIt, correo, widgets de bloqueo e inicio, unidades, importaciones y datos de cuenta.
- **Import Flights:** Flighty, myFlightRadar24, OpenFlights, App in The Air, LogmyFlight y JetLovers. Se muestra un límite de un año para vuelos pasados sin Pro. No se ejecutaron importaciones.
- **Friends:** filtros Everyone y Today, Add Friend y un estado vacío que permite agregar amigos para ver sus vuelos automáticamente o buscar un vuelo ajeno. No se enviaron invitaciones.
- **macOS:** panel lateral sobre mapa amplio; en las capturas de iPhone, panel inferior sobre mapa. No asumir las mismas dimensiones para ambas plataformas.

Estos son resultados de observación de UI con Computer Use, no de descompilación ni Evidence de REA. Se conserva la versión para distinguir esta instalación de la documentación pública actual.

## Matriz de implementación propuesta

«Documentado» significa descrito por Flighty; no observado en una cuenta Pro. La primera base local ya está implementada: lista, búsqueda por fecha/texto, agregado propio o de amigos, detalle, edición de reserva/asiento, eliminación, mapas de rutas, historial y estadísticas. Usa exclusivamente vuelos ficticios. El resto sigue pendiente.

| Área | Comportamiento objetivo | Evidencia | Dependencias de nuestra versión |
| --- | --- | --- | --- |
| My Flights | Lista, cuenta regresiva, buscar/agregar/eliminar, estados, alternativas y regreso | Capturas; [gestión](https://flighty.com/help/managing-my-flights) | Catálogo y proveedor de vuelos; caché local |
| Detalle | Ruta, aeropuertos, horarios, puerta, terminal, duración, reserva y asiento | Capturas | Datos operativos; datos personales del viaje separados |
| Mapa | Ruta, aeropuertos, posición de avión; historial con frecuencias visuales | Capturas; [leyenda](https://flighty.com/help/meaning-of-past-flights-lines-and-dots) | Motor de mapas; coordenadas y posiciones fechadas |
| Historial y Passport | Vuelos completados, filtros, totales, demoras, aeronaves y tarjetas para compartir | Capturas | Persistencia y cálculo local; enriquecimiento histórico opcional |
| Offline | Mostrar última información conocida con indicación de antigüedad y estimación | [Documentado](https://flighty.com/help/offline-mode) | Caché; fecha de última actualización y estado de conexión |
| Avión entrante | Vincular aeronave física, tramo previo, posición y datos de matrícula | Tarjeta bloqueada; [documentado](https://flighty.com/help/where-is-my-plane) | Identidad de aeronave y rotaciones; manejar cambios de avión |
| Alertas | Cambios de horario/puerta, cancelaciones, desvíos y eventos del viaje; preferencias por vuelo | [Documentado](https://flighty.com/help/flighty-notifications); ajustes observados | Eventos, servidor, APNs y deduplicación |
| Live Activities y widgets | Progreso y estado fuera de la app, Dynamic Island y widgets | Promoción; [documentado](https://flighty.com/help/live-activities-widgets) | Extensión de widgets, ActivityKit y actualizaciones push |
| Aeropuertos y clima | Estado operativo, llegadas/salidas, tendencias, avisos y clima | Capturas; [catálogo](https://flighty.com/pricing) | Datos aeroportuarios y meteorología; cobertura por región |
| Predicciones | Mostrar estimación propia separada de horario oficial; demora y puerta | [Documentado](https://flighty.com/help/delay-predictions) | Historial, modelo propio y validación; no recuperar modelo desde capturas |
| Conexiones | Evaluar conexión y pasos hasta puerta considerando ambos vuelos, terminales y circunstancias | [Documentado](https://flighty.com/help/connection-assistant) | Datos de conexión, aeropuertos y tiempos; reglas y estimaciones verificables |
| Friends | Vuelos ajenos, filtros, preferencias e intercambio automático consentido | UI; [gestión](https://flighty.com/help/managing-friends-flights) | Identidad, permisos, sincronización y eventos |
| Calendario | Importar y sincronizar vuelos, seleccionar calendarios y evitar duplicados | Ajustes; [documentado](https://flighty.com/help/calendar-import) | Acceso autorizado al calendario, reconocimiento y matching |
| Correo y TripIt | Importación automática y resolución de duplicados | Ajustes; [gestión](https://flighty.com/help/managing-my-flights) | Recepción de correo y parsers; integración autorizada con TripIt |
| Importación masiva | Adaptadores por formato y revisión de errores | UI; [documentado](https://flighty.com/help/importing-flights) | Archivos de ejemplo, parsers y validación |
| Perfil y sincronización | Preferencias, datos de cuenta y continuidad entre dispositivos | Ajustes; [ayuda](https://flighty.com/help) | Almacenamiento local y servicio de sincronización |
| Watch | Consulta desde Apple Watch | [Catálogo](https://flighty.com/pricing) | App/extensión específica; flujos todavía sin observar |

El catálogo público también anuncia guías entre puertas y NOTAM interpretados. Su comportamiento detallado sigue pendiente; no se consideran resueltos por incluir sus nombres aquí. Suscripciones, cobros y promociones de Flighty no son requisitos funcionales automáticos para una app propia.

## Reglas recuperadas de documentación

- Los vuelos de amigos no suman a las estadísticas personales y se retiran tras la llegada. Se ofrecen cuatro niveles globales de alerta y una configuración por vuelo. [Fuente](https://flighty.com/help/managing-friends-flights).
- Los vuelos propios completados pasan al historial. [Fuente](https://flighty.com/help/managing-my-flights).
- Las predicciones se muestran junto a los horarios oficiales. Flighty describe aprendizaje automático y seguimiento por matrícula, pero no publica el modelo ni su entrenamiento. [Fuente](https://flighty.com/help/delay-predictions).
- El asistente de conexiones considera tiempos mínimos, terminales, equipaje y circunstancias personales. Todavía no tenemos sus umbrales ni reglas internas. [Fuente](https://flighty.com/help/connection-assistant).

## Diseño propio propuesto

Separar presentación, reglas de viaje, persistencia e integraciones mediante interfaces pequeñas. Los datos simulados y los proveedores reales deben implementar el mismo contrato; cada pantalla debe identificar datos de demostración cuando corresponda.

Entidades iniciales: operación física de vuelo, números comerciales asociados, aeropuerto, aeronave, viaje personal, evento operativo, preferencia de alerta e importación. Los horarios conservan instante UTC, zona del aeropuerto y tipo: programado, estimado, predicho o real. Un dato ausente no se convierte en cero ni en «a tiempo».

La app consulta nuestro servidor para las integraciones que requieran claves privadas. El servidor normaliza cambios y distribuye eventos; la app conserva caché y datos del usuario. Esta es una arquitectura propuesta, no la arquitectura recuperada de Flighty.

Para actualizaciones remotas de Live Activities, Apple documenta el envío desde servidor a APNs con tokens de ActivityKit. [Documentación de Apple](https://developer.apple.com/documentation/ActivityKit/starting-and-updating-live-activities-with-activitykit-push-notifications).

## Selección de datos: pendiente de prueba

FlightAware y FlightStats son candidatos porque aparecen declarados en la app. Eso no demuestra que un plan público de sus APIs reproduzca la cobertura de Flighty.

- FlightAware documenta alertas mediante AeroAPI. [Fuente](https://support.flightaware.com/hc/en-us/articles/33381502369175-How-Do-I-Create-A-Post-Alert-In-AeroAPI).
- Cirium documenta consultas de estados históricos por vuelo, fecha, aeropuerto y ruta. [Fuente](https://developer.cirium.com/apis/cirium-sky-api/historical-flight-status).

Antes de contratar: comprobar vuelos argentinos, códigos compartidos, puerta/terminal, matrícula, rotación, cancelaciones, datos históricos, latencia medida y costo para el volumen esperado. No se contrataron servicios ni se hicieron consultas pagas. Falta verificar disponibilidad contractual y cobertura de cada campo.

## Etapas y condiciones de cierre

1. **Base navegable:** lista, búsqueda, detalle, mapa y viaje personal con datos de demostración; agregado/eliminación y persistencia comprobados.
2. **Datos reales:** adaptador validado con vuelos de muestra, zonas horarias, desconocidos y cambios operativos; elección de proveedor y presupuesto.
3. **Seguimiento:** eventos, alertas, widgets y Live Activities verificados con app en segundo plano y datos desactualizados.
4. **Historial y automatización:** estadísticas, importaciones y sincronización con pruebas de duplicados y conflictos.
5. **Funciones avanzadas:** Friends, Watch, aeropuertos, avión entrante, conexiones y predicciones; cada función requiere su propia evidencia y validación.

La investigación sigue parcial: conocemos pantallas gratuitas, versión local, proveedores declarados y comportamiento documentado. Faltan contratos de datos, flujos Pro observados, eventos reales controlados y algoritmos. No hay análisis binario. Hay una app SwiftUI inicial con persistencia local; no es una implementación completa de Flighty.

Validación de la primera base: compilación y ejecución en iPhone 17 Pro (iOS 26.5), cinco pruebas de dominio/persistencia y una prueba de interfaz completa de búsqueda, agregado, edición, reinicio, conservación de campos, eliminación e ingreso al historial. Todos pasaron. La prueba de interfaz usa almacenamiento separado del normal.

## Segunda iteración: conexión preparada

El usuario confirmó que todavía no tiene proveedor. Se implementó una pasarela local de desarrollo con adaptador para AeroAPI y un cliente iOS configurable, sin activar consultas reales. La pasarela usa respuestas sintéticas por defecto; la aplicación y las estadísticas identifican su fuente. La clave del proveedor solo se admitiría en el entorno del servidor.

Se agregó búsqueda explícita por número/fecha, actualización manual de operaciones identificadas, conservación de reserva/asiento al actualizar, horarios reales separados, estados de rodaje/en vuelo/llegada a puerta, fecha de última consulta, manejo de datos faltantes, paginación parcial, errores de conexión y límites de solicitudes. La caché y el límite local de consultas reducen consumo; no sustituyen un presupuesto contratado.

La cobertura real, calidad en Argentina, credenciales, costos y despliegue autenticado siguen pendientes. No se validó contra una cuenta real ni se activaron alertas. El mapa remoto queda sin ruta cuando no hay coordenadas; no se hicieron consultas extra para obtenerlas. Ventana, límites y ejecución: [servidor de desarrollo](../server/README.md).

Validación: 13 pruebas Swift del dominio/cliente/persistencia, seis pruebas Python de la pasarela y dos pruebas de interfaz en el simulador; todas pasaron. La prueba de red usa la pasarela local en modo sintético, verifica la etiqueta de demostración y el agregado. Las pruebas de actualización operativa usan respuestas interceptadas, no una cuenta real. La revisión final de la prueba asíncrona compiló sin advertencias.

## Configuración de Aviationstack

El usuario obtuvo una clave y confirmó que es de Aviationstack. Se renombró la variable local a `AVIATIONSTACK_KEY` sin mostrar ni cambiar su valor, y se agregó carga automática del `.env`. El servidor conserva el modo sintético por defecto y permite seleccionar Aviationstack o FlightAware explícitamente al activar consultas reales.

Se incorporó el adaptador Aviationstack, procedencia por proveedor, errores de plan/cupo, caché y límite de diez consultas externas por ejecución. La interpretación de los horarios de Aviationstack se distingue de los eventos de puerta de AeroAPI. Pasaron 14 pruebas Swift y 12 Python; la app compila sin advertencias.

La única consulta externa propuesta fue rechazada por la revisión automática antes de ejecutarse: enviar la clave a Aviationstack en la URL requiere autorización explícita para esa consulta concreta. No se envió la clave ni se consumió el cupo. La validez de la clave y el formato real de respuesta siguen sin verificar. No repetir por otra herramienta sin autorización.
