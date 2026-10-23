# Boarding Pass

Primera versión iOS propia inspirada en los flujos observados de Flighty. SwiftUI + MapKit, iOS 17 o posterior. No usa código ni servicios privados de Flighty.

## Ejecutar

Abra `BoardingPass.xcodeproj`, seleccione el esquema **BoardingPass** y un simulador de iPhone. No requiere paquetes externos, claves API ni firma para el simulador. Para un iPhone físico, configure su equipo de desarrollo en Xcode.

## Disponible en esta etapa

- Mis vuelos con panel expandible y mapa de rutas.
- Búsqueda local por número, aerolínea, ciudad o aeropuerto y fecha.
- Agregado a lista propia o lista local de vuelos de amigos, con prevención de duplicados.
- Detalle con horarios locales, estado, puerta, aeronave, edición de reserva y asiento y eliminación confirmada.
- Historial y pasaporte con estadísticas de vuelos completados propios.
- Compartir un resumen de demostración mediante el menú del sistema.
- Conexión configurable a una pasarela de vuelos: búsqueda por número/fecha y actualización manual conservando reserva y asiento. Adaptadores de Aviationstack y AeroAPI preparados, todavía sin validar con una cuenta real.
- Etiquetas por fuente y separación del historial de demostración y del proveedor.
- Guardado JSON atómico en Application Support. Los datos persisten al cerrar la app; una lista vacía no vuelve a poblarse.

Por defecto todos los vuelos son ficticios y la interfaz lo indica. El usuario eligió Aviationstack y configuró su clave en `.env`. El adaptador está preparado; la consulta externa de validación sigue pendiente de autorización explícita. Puede probar el recorrido de red sin clave con la [pasarela local](server/README.md). El mapa usa cartografía de Apple, que puede necesitar conexión. Las rutas no representan trayectorias reales. Las fixtures incluyen vuelos de hoy, dentro de tres días y viajes anteriores. Los estados de muestra no avanzan automáticamente con el reloj.

## Pendiente

Validación de datos reales y elección de proveedor, alertas, Live Activities, widgets, importación, sincronización, intercambio automático entre amigos, Watch, meteorología, condiciones aeroportuarias, avión entrante, conexiones y predicciones. El alcance completo sigue documentado en `docs/flighty-functional-plan.md`.

## Estructura

- `BoardingPass/Core`: modelos, catálogo ficticio, estadísticas y contrato de persistencia.
- `BoardingPass/FlightStore.swift`: operaciones de listas y coordinación del guardado.
- `BoardingPass/Features`: pantallas por función.
- `BoardingPass/Components`: mapa y elementos visuales reutilizables.
- `Tests`: pruebas del dominio y persistencia con Swift Testing.
- `UITests`: flujo de agregado, edición, reinicio y eliminación con XCTest. Usa un archivo separado del almacenamiento normal.

## Verificar

Pruebas del dominio:

```sh
swift test
```

Pruebas de interfaz (seleccione un simulador instalado). Para incluir la prueba de red, inicie antes `python3 server/flight_gateway.py`; se omite si la pasarela no está disponible o está en modo real:

```sh
xcodebuild test -project BoardingPass.xcodeproj -scheme BoardingPass -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -parallel-testing-enabled NO
```

El adaptador actual cubre vuelos recientes por número, no todo el catálogo mundial ni históricos. Registros sin horarios de puerta completos se omiten con aviso, y las rutas sin coordenadas muestran un estado no disponible. Más límites y pasos de activación en `server/README.md`.
