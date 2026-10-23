# Servidor de vuelos (desarrollo local)

Pasarela sin dependencias externas para conectar la app iOS con Aviationstack o AeroAPI. Requiere Python 3.9 o posterior. Se escucha exclusivamente en `127.0.0.1`; no se publica un servicio en Internet.

## Probar sin clave y sin costo

```sh
python3 server/flight_gateway.py
```

En la app: Ajustes → Fuente de vuelos → Servidor de vuelos → `http://localhost:8765` → Guardar conexión. En Buscar ingrese **AR1490** y la fecha de hoy. El resultado se identifica como demostración y no permite actualizarse como vuelo real.

`localhost` funciona en el simulador de la misma Mac. No apunta a la Mac desde un iPhone físico. Para dispositivos reales hace falta una pasarela HTTPS accesible y autenticada; ese despliegue queda pendiente.

## Aviationstack: proveedor elegido

El servidor carga automáticamente `.env` desde la raíz del proyecto, independientemente del directorio desde donde se ejecute. Las variables del entorno del proceso tienen prioridad. No ejecuta comandos ni interpola contenido del archivo.

```dotenv
AVIATIONSTACK_KEY=su_clave
```

La variable anterior `AEROAPI_KEY` se renombró a `AVIATIONSTACK_KEY` conservando el valor. `.env` está excluido de Git. `.env.example` contiene solo nombres y valores vacíos.

Una vez autorizada la prueba de conexión, el comando para activar el proveedor es:

```sh
python3 server/flight_gateway.py --live --provider aviationstack
```

El adaptador usa HTTPS con `access_key` en los parámetros, según la interfaz del proveedor. No registra la URL autenticada ni reenvía mensajes originales de error. No sigue redirecciones y no vuelve a intentar mediante HTTP sin cifrar.

La conexión gratuita consulta por número de vuelo y filtra localmente los resultados de hoy en Argentina, sin solicitar históricos mediante `flight_date`. Conserva la identidad por fecha/ruta para actualizar el mismo vuelo. El servidor almacena una respuesta durante cinco minutos y limita a diez llamadas externas por ejecución; reiniciarlo reinicia ese contador. No es una garantía de cupo mensual y no detecta consumos desde otros clientes.

La app identifica la fuente como Aviationstack. Sus horarios son horarios de aeropuerto del proveedor: no se presentan como confirmación de eventos de puerta. La distancia y las coordenadas siguen ausentes cuando el proveedor no las entrega.

**Validación pendiente:** la prueba externa con la clave del usuario fue rechazada por la revisión automática antes de ejecutarse. Requiere autorización explícita para enviar esa clave a Aviationstack en una consulta que consume una solicitud del cupo. Se completaron pruebas locales del adaptador, errores, caché, identificación del proveedor y carga del `.env`; no se confirmó todavía la validez de la clave ni la respuesta real.

## FlightAware: alternativa preparada

Para AeroAPI use `AEROAPI_KEY` en el entorno o `.env`, y seleccione explícitamente:

```sh
python3 server/flight_gateway.py --live --provider flightaware
```

Por defecto, sin `--live`, el servidor continúa usando respuestas sintéticas aunque exista cualquier clave. La app nunca recibe claves de proveedores.

## Contrato inicial

- `GET /health`: modo y disponibilidad del proceso; no valida credenciales del proveedor.
- `GET /v1/flights?number=AR1490&date=2026-10-23`: búsqueda por número y día local del aeropuerto de salida.
- `GET /v1/flight?id=IDENTIFICADOR_DEL_PROVEEDOR`: actualización de una operación ya conocida.

La respuesta conserva los campos de AeroAPI y agrega `mode` (`fixture`, `flightaware` o `aviationstack`) y `retrieved_at` (fecha de consulta, no hora de generación del dato por el proveedor). La app convierte esta respuesta a su propio modelo.

Los errores usan HTTP 400 para números inválidos, 422 para fechas fuera de rango, 429 para límites y 503 para falta de clave/autorización. Los errores de proveedor no se copian al cliente para evitar exponer información de autenticación.

## Límites del adaptador FlightAware

- Solo `GET /flights/{ident}` de AeroAPI v4, con `ident_type` y `max_pages=1`. No se siguen enlaces de paginación: la app informa resultados parciales.
- Ventana de búsqueda de hace nueve días a mañana, acotada al rango reciente documentado. No usa el endpoint de históricos ni de programación futura.
- Ajusta la búsqueda UTC para cubrir el día local y filtra por zona del origen; si no hay zona, usa UTC. La app también marca UTC en horarios de aeropuertos sin zona conocida.
- Caché de 60 segundos en memoria, hasta 20 llamadas externas por minuto por proceso y sin reintentos automáticos. Esto no constituye un límite de gasto mensual.
- No hay polling ni alertas. Las consultas se hacen por acciones explícitas: Buscar o Actualizar.
- No consulta coordenadas adicionales. Las rutas sin coordenadas muestran un estado no disponible, sin inventar ubicaciones.
- Los registros sin aeropuertos o tiempos programados de puerta completos se omiten y se contabilizan. No se reemplazan tiempos de puerta por tiempos de pista.
- Se incluyen salida y llegada a puerta, eventos de pista para distinguir estados, puertas/terminales y tipo de avión cuando están disponibles.
- Los desvíos usan identidad por operación y ruta. Si una actualización no identifica un único tramo existente, se conservan los datos previos y se informa el problema.
- La pasarela es local y no tiene autenticación de clientes. Antes de publicarla: agregar identidad/autorización, cuotas por usuario, almacenamiento y supervisión del consumo. No alcanza con cambiar la dirección de escucha.

La cobertura efectiva para aerolíneas argentinas, códigos compartidos, campos completos y latencia sigue sin comprobarse contra los servicios reales.

## Pruebas

```sh
python3 -m unittest discover -s server/tests -v
```

Las pruebas Swift de red usan `URLProtocol` y no salen a Internet. Para la prueba de interfaz del servidor, mantener esta pasarela en modo demostración en el puerto 8765 y ejecutar las pruebas del esquema BoardingPass. La prueba que usa la pasarela se omite si no está disponible en modo demostración.

## Fuentes

Adaptador basado en la [especificación OpenAPI oficial de AeroAPI](https://www.flightaware.com/commercial/aeroapi/resources/aeroapi-openapi.yml), consultada el 2026-10-23. Esta integración es independiente y no utiliza servidores privados de Flighty.

Aviationstack: [documentación](https://docs.apilayer.com/aviationstack/docs/api-documentation) y [FAQ oficial](https://aviationstack.com/faq). La documentación completa redirigió a una página de acceso; los campos del adaptador necesitan corroboración con la primera respuesta autorizada.
