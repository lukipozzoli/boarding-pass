# Flighty: inventario visual

Fuente: 21 capturas aportadas por el usuario el 2026-10-23. Archivos originales en `/Users/lucianopozzoli/Downloads/IMG_2EC661EAF997-N.jpeg`.

Este inventario registra referencias visuales. El usuario corrigió su selección y pidió todas las funciones; el alcance completo se organiza por etapas en `flighty-investigation.md`. Las capturas no cubren todos los flujos.

## Observaciones

La columna «archivo» indica el sufijo N, no el número de imagen en el chat.

| Archivo | Pantalla | Elementos visibles |
| --- | --- | --- |
| 21 | My Flights | Mapa de ruta detrás de un panel; próximo vuelo con cuenta regresiva, ruta, número, horarios y estado. Accesos My Flights, Friends, Passport y búsqueda. Avisos para activar alertas y calendario. |
| 20 | Add Flight | Entrada por aerolínea, aeropuerto o vuelo; sugerencias de regreso y alternativas; aerolíneas y aeropuerto frecuentes. |
| 19 | Resultados | Campos de búsqueda y fecha, controles de códigos compartidos y aerolínea, lista de vuelos y selector de lista destinataria. No muestra una confirmación de agregado. |
| 18 | Aviso sobre detalle | Diálogo para activar alertas de demoras, cancelaciones y cambios de puerta; opción de postergarlo. |
| 17 | Detalle superior | Número y fecha, ruta, salida de puerta en tiempo relativo, horarios, puntualidad, terminal y puerta. Duración y distancia. |
| 16 | Detalle intermedio | Tarjeta promocional de alertas, código de reserva editable y asiento editable. |
| 15 | Good to Know | Estado de los dos aeropuertos, clima actual de salida, clima de llegada y referencia a zona horaria. Detalles operativos bloqueados por Pro. |
| 14 | Where’s My Plane? | Tipo de aeronave Airbus A320; seguimiento del avión entrante bloqueado. La secuencia difuminada no permite recuperar los vuelos reales. |
| 13 | Detailed Timetable | Distingue horarios programados y estimados de salida y llegada a puerta. Anuncia también predichos y reales. Datos adicionales difuminados. |
| 12 | Passport, panel parcial | Mapa de varias rutas y tarjeta agregada de vuelos, distancia, tiempo, aeropuertos y aerolíneas. |
| 11 | Passport, panel expandido | Tarjetas de totales, demoras acumuladas y aeronave más utilizada. |
| 10 | Passport inferior | Aeronave más utilizada, límite Pro para agregar vuelos de más de 12 meses, historial y controles de presentación/orden. |
| 9 | Past Flights | Lista por año; controles Date, From, To, Airline y Aircraft. Una ruta muestra destino tachado; la causa no se puede determinar con esta captura. |
| 8–1 | Carrusel promocional | Anuncia seguimiento, Live Activities, Dynamic Island, avión entrante, ATC, Friends, alertas y cobertura mundial. Son ejemplos promocionales dentro de la app; no prueban funcionamiento en la cuenta del usuario. |

## Patrones visuales observados

- Mapa de fondo con rutas azules y panel blanco de esquinas redondeadas.
- Paneles visibles a distintas alturas; las capturas no prueban el gesto ni la animación utilizados para cambiar su altura.
- Cabecera del detalle y acciones inferiores permanecen visibles en varias posiciones de desplazamiento.
- Verde para puntualidad, amarillo para puerta y violeta para promociones Pro. El significado de otros estados requiere más evidencia.
- Valor desconocido representado con `--`; no equivale a cero ni a puntualidad confirmada.

## Inferencias útiles si se eligen estas funciones

- Los códigos compartidos podrían corresponder a una misma operación física; no conviene asumir que cada número comercial identifica un avión distinto.
- Un modelo propio de horarios debería distinguir salida/llegada a puerta de despegue/aterrizaje, y conservar por separado valores programados, estimados y reales.
- Reserva y asiento pertenecen al viaje del usuario; los datos operativos pueden compartirse entre usuarios.

Son decisiones propuestas para una implementación propia, no estructuras recuperadas del código de Flighty.

## Límites y pendientes

No se conocen versión de Flighty/iOS, implementación interna, endpoints, proveedores, persistencia, latencia ni algoritmos. No hay Evidence IDs de REA: la evidencia de esta etapa son las imágenes aportadas. Las capturas tampoco verifican navegación interactiva, edición, entrega de alertas ni funcionamiento sin conexión.

Próximo paso: completar la evidencia de los flujos faltantes, especialmente Friends, importaciones, ajustes, estados durante el vuelo y funciones Pro. Las pantallas promocionales no sustituyen esa observación.
