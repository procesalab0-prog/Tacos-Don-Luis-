# Preparación de la prueba piloto — Tacos Don Luis

Revisión: 2 de octubre de 2026, hora de Ciudad de México.

## Estado después de las correcciones — 2 de octubre de 2026

Stripe, Apple Pay y Google Pay quedan fuera de esta entrega por decisión del usuario. La información de pasarelas más abajo se conserva como referencia para después.

Aplicado en Supabase:
- Reglas de caja que calculan el corte en el servidor con ventas del turno y efectivo de repartidores recibido en caja, excluyendo pedidos demo.
- Liquidaciones calculadas desde las entregas, sin confiar en importes enviados por el teléfono; protección de importes al cerrarlas.
- Asignación/reasignación atómica mediante `assign_delivery`, y las incidencias actualizan el pedido a `failed_delivery`.
- Cocina no puede cambiar importes, direcciones ni datos de pago. Se conserva la promesa de pedidos programados.
- Adjuntar evidencia de entrega mediante RPC con autorización, ruta del repartidor y comprobación de archivo subido.
- Historial automático de cambios de estado; pago obligatorio para entregar pedidos de tarjeta/transferencia.
- El inventario automático queda deshabilitado sin borrar sus datos.

Incluido en la publicación 2.26.0:
- Escape de nombres, notas y direcciones en repartidor; apertura de rutas con coordenadas guardadas.
- Recuperación de sesiones guardadas corruptas en personal; avisos al fallar la actualización.
- Corte por turno, confirmación manual de pago recibido y uso de la asignación atómica.
- Horario de Visítanos y tiempo de checkout vienen de la configuración.
- Ajustes visuales compartidos, portada más compacta y animaciones breves con respeto a reducción de movimiento.
- Google Maps, búsqueda de direcciones y geocodificación preparados. Clave e ID vacíos: sigue operativo Leaflet hasta configurar Google. Instrucciones en `GOOGLE-MAPS.md`.

Publicado en Supabase con autorización del usuario:
- Nueva `create-guest-order`: cantidades enteras, opciones vinculadas al producto, validación de horarios y ubicación/zona, escritura de pedido/productos/modificaciones/puntos en una sola transacción, y límite básico de seis pedidos por teléfono en diez minutos.
- La función `create-guest-order` se publicó como versión 10 con autorización explícita. Pasó la prueba HTTP real en una sucursal temporal demo: total $51, dos líneas, reintento sin duplicado y rechazo de cantidad fraccionaria. Los pedidos de prueba se eliminaron y la sucursal quedó inactiva, conservando su historial de auditoría.
- `create_guest_order_atomic` ya existe en Supabase, con ejecución reservada a `service_role`; la función de pedidos activa ya lo llama.

Validación realizada:
- Sintaxis de los scripts de los tres portales y de la nueva función: correcta.
- Pruebas de caja por turno, escape HTML y liquidación de entrega tardía: correctas.
- Diez casos de la función nueva con servicios simulados: correctos; no sustituyen un ensayo del endpoint real.
- Prueba SQL real en transacción revertida: creación, duplicado, error parcial, promesa, caja, incidencia, reasignación, liquidación, cocina y acceso al RPC correctos. No quedaron pedidos ni movimientos de prueba.
- Navegador: portada, menú, carrito, checkout, y accesos de administración/repartidor. Faltan sesiones reales por rol y ensayo en teléfonos del personal.
- El asesor de seguridad no detectó exposición pública del nuevo RPC. Persisten avisos de funciones intencionalmente accesibles y protección de contraseñas filtradas deshabilitada; revisar antes del piloto.

La auditoría original que sigue registra los hallazgos antes de esta intervención. Su lista no reemplaza el estado actualizado de arriba.

## Alcance y evidencia

Se revisaron los archivos de cliente, administración/cocina y repartidor, las funciones de creación y seguimiento, las políticas y funciones desplegadas en Supabase y el flujo público en navegador hasta el checkout. El menú cargó datos reales: 19 productos. Los accesos de administración y repartidor se mostraron correctamente. No aparecieron errores de consola en el recorrido público consultado.

No se crearon pedidos, cuentas, cobros ni movimientos de caja durante esta revisión. No se ingresó a las pantallas internas con cuentas de cada rol. Falta un ensayo completo con personal autorizado y la versión publicada; esta revisión no certifica el funcionamiento integral del piloto.

Supabase está activo. Las tablas públicas tienen RLS habilitado. Hay protección de duplicados mediante índice único de `client_request_id`; los pedidos se calculan en el servidor. En la consulta había 38 pedidos, ninguno sin productos; esto no demuestra atomicidad frente a fallas futuras. No se exportaron datos personales de clientes.

## Lista priorizada

### Resolver antes de manejar dinero o pedidos reales

Decisión de alcance: Inventario se retira del panel porque el negocio no lo utilizará. No se cargarán insumos ni recetas para el piloto. Se quitó su pantalla, navegación y consultas de datos del panel local; pendiente publicar esta versión.

- [ ] **P0 — Evitar ejecución de HTML aportado por clientes en el repartidor.** `repartidor/index.html`, funciones `card`, `renderDetail` y `renderShift`, insertan nombres, direcciones y notas en `innerHTML` sin escape. La función de pedidos limita longitudes pero no escapa HTML. Riesgo de ejecución de contenido en una sesión de personal. Usar nodos de texto o escape consistente y verificar entradas con caracteres HTML. Hallazgo de código, sin ejecutar un ataque.
- [ ] **P0 — Corregir el corte de caja.** `admin/index.html`, `cashAction`, suma todos los pedidos completados en efectivo cargados en el panel, sin limitar al turno abierto. Un segundo corte puede volver a sumar ventas anteriores. Calcular en servidor por cobro/turno y conciliar con liquidaciones, devoluciones y efectivo contado.
- [ ] **Fuera del piloto — Corregir inventario si se retoma en el futuro.** Las funciones desplegadas `app_private.sync_order_inventory` y `app_private.apply_inventory_movement_to_stock` modifican el stock por el mismo consumo: la primera descuenta directamente y registra un movimiento; el trigger de movimientos vuelve a descontar. La cancelación repone también por ambos caminos. Ejemplo derivado del código: stock 10, consumo 2, resultado 6 en vez de 8. Elegir una sola fuente de actualización y probar confirmación, cancelación y reintentos. Actualmente hay cero insumos y cero recetas.
- [ ] **P0 — Separar permisos de cocina y caja en servidor.** La política de UPDATE de `orders` admite cocina en toda la fila; no se observó un trigger que limite cambios de monto/pago. El menú restringido no basta. Autorizar cambios de estado concretos por rol y rechazar modificaciones de precio/cobro desde cocina. Ensayar con cuentas distintas.
- [ ] **P0 — Guardar el pedido completo en una operación atómica.** La función desplegada `create-guest-order` inserta cabecera, productos, modificadores y puntos en pasos separados. Un reintento puede encontrar la cabecera antes de que se complete; errores de modificadores e historial se ignoran. Guardar todo en una transacción y devolver confirmación solo al terminar.
- [ ] **P0 — Definir y completar la verificación de pagos.** El checkout ofrece efectivo, transferencia y tarjeta al recibir; el pago en línea figura como PRÓXIMAMENTE. No se encontró una acción de confirmación de transferencia/tarjeta en el panel revisado. Al completar un pedido para recoger no se cambia `payment_status`; el repartidor solo marca automáticamente efectivo como pagado. Hacer explícito quién verifica, cuándo se cobra y qué bloquea la entrega. Probar con terminal real; no considerar Clip simulado un cobro.



### Pago en línea y rediseño de todas las páginas — alcance solicitado

- [ ] **P1 — Incorporar pago en línea con Apple Pay y Google Pay.** Seleccionar una pasarela que soporte ambos para la cuenta del negocio en México y comprobar disponibilidad por dispositivo, navegador y tarjeta. Definir comisiones, alta del comercio y dominio antes de habilitar cobros reales. Este requisito está pendiente; la opción actual PRÓXIMAMENTE y Clip simulado no lo cumplen.
- [ ] **P1 — Confirmar cobros desde el servidor.** Crear el cobro con el total calculado por el servidor y actualizar el pedido mediante notificaciones verificadas de la pasarela. Contemplar pago aprobado, rechazado, cancelado, pendiente, reintentos, notificaciones repetidas y reembolso. No marcar un pedido pagado solo por volver a la pantalla de éxito.
- [ ] **P1 — Rediseño coherente de todas las páginas.** Incluye inicio, menú, carrito, checkout, confirmación, seguimiento, cuenta, administración, cocina, reportes, configuración y portal del repartidor. Mantener logo y estilo Don Luis, unificar tipografía, espaciado, botones y estados. Dar prioridad a móvil para cliente/repartidor y tablet para cocina. En repartidor priorizar dirección y pin, importe por cobrar, recogida, entrega, incidencias y liquidación. Simplificar el checkout: resumen de pedido, envío y total; sección clara de pago en línea; botones de Apple Pay/Google Pay únicamente cuando estén disponibles; alternativa de tarjeta y opciones presenciales acordadas con el negocio. Mostrar progreso, resultado y recuperación de errores, con prioridad móvil. No mostrar botones de billeteras sin integración funcional.
- [ ] **Ensayo de pagos.** Verificar Apple Pay en un dispositivo compatible, Google Pay en uno compatible y alternativa de tarjeta; pérdida de conexión después del cobro, pedido duplicado, conciliación y reembolso. Usar primero el entorno de pruebas de la pasarela; los cobros reales requieren activación del comercio.

### Evaluación de pasarelas — 2 de octubre de 2026

**Recomendación técnica: Stripe**, pendiente de aceptación del negocio y alta/aprobación de su cuenta. Su documentación confirma Apple Pay y Google Pay para México y ofrece Express Checkout Element para integrarlos en el diseño de la app. Registrar dominio en pruebas y producción; activar métodos y comprobar dispositivos compatibles. La disponibilidad de los botones depende de la billetera, navegador y tarjeta del comprador. Configurar cobros en MXN.

| Opción | Evidencia encontrada | Decisión propuesta |
|---|---|---|
| Stripe | Confirma ambas billeteras para México. Tarifa estándar de tarjeta nacional: 3.6% + $3 MXN por operación exitosa; comisiones excluyen IVA; sin mensualidad estándar de Payments. | Primera opción para desarrollar y probar. |
| Mercado Pago | Publica integración Apple Pay, pero la guía exige contacto comercial para habilitarla. No se confirmó con la documentación consultada una integración Google Pay equivalente para esta cuenta/checkout mexicano. | Alternativa si el negocio obtiene confirmación de ambas billeteras. |
| Clip | La información encontrada sobre Apple Pay se refiere a terminal/contactless. No se confirmó soporte web de Apple Pay y Google Pay en Checkout Clip. | No asumir que el soporte de terminal cumple el requisito de pago dentro de la app. |

Ejemplos calculados con tarifa estándar de Stripe para tarjeta nacional, antes de IVA sobre la comisión: pedido de $200 MXN → $10.20; $300 → $13.80; $500 → $21.00. Para 1,000 pedidos de $200: $10,200 MXN de comisiones antes de IVA. Tarjetas internacionales, conversión y productos adicionales pueden tener otras tarifas; confirmar el precio final al activar.

Pendientes: alta de la cuenta del negocio y datos bancarios/fiscales requeridos por la pasarela, aprobación para cobros reales, dominio HTTPS, registro de dominio, credenciales de pruebas y producción, webhooks verificados, flujo atómico pedido/pago, conciliación, reembolsos y ensayo Apple Pay/Google Pay. No se abrió ninguna cuenta ni se activaron cobros.

Fuentes oficiales:
- https://support.stripe.com/questions/supported-payment-methods-in-mexico
- https://stripe.com/mx/pricing
- https://docs.stripe.com/elements/express-checkout-element
- https://www.mercadopago.com.mx/developers/es/docs/apple-pay/overview?scope=prod
- https://www.payclip.com/why-clip/products-and-services

### Resolver antes de abrir el piloto a clientes

- [ ] **P1 — Google Maps al arranque del piloto.** Migrar selección del punto y búsqueda de direcciones a Google Maps/Places; conservar referencias y confirmar pin. Cargar el mapa al elegir entrega, restringir claves y APIs, establecer cuotas y alertas. Reserva orientativa acordada: US$10–20 al mes, sujeta a uso y tarifas al activar. No se ha creado cuenta de facturación ni activado el servicio. Tarifas: https://developers.google.com/maps/billing-and-pricing/pricing
- [ ] **P1 — Usar el pin en la navegación del repartidor.** `renderDetail` abre una búsqueda con la dirección textual e ignora `delivery_address.latitude/longitude`. Priorizar coordenadas confirmadas, con dirección como respaldo. Confirmar colonia, número e interior.
- [ ] **P1 — Validar cobertura y horario en el servidor.** `create-guest-order` valida zona activa, pero no comprueba que coordenadas pertenezcan a esa zona ni aplica `weekly_schedule`. El navegador sí consulta horario/distancia. Añadir validación de coordenadas, radio, zona y horario; probar un domicilio fuera de cobertura y un pedido fuera de horario.
- [ ] **P1 — Revisar horarios reales.** El lunes está configurado 18:00–13:59, que cruza al día siguiente. Confirmar intención con el negocio. En el recorrido público también hubo tiempos distintos: inicio mostraba recoger 25 min y checkout 15–20 min; el texto de horario del bloque Visítanos no coincidía con el horario semanal del viernes. Unificar mensajes con la configuración vigente.
- [ ] **P1 — Conservar la hora de pedidos programados.** `confirmarAceptar` reemplaza `promised_at` por ahora + minutos y el panel no consulta `scheduled_for`. Mostrar la hora reservada, conservarla y separar estos pedidos de la preparación inmediata.
- [ ] **P1 — Resolver incidencias y reasignación de reparto.** La RPC desplegada `driver_advance_assignment` marca incidencia en la asignación pero no actualiza el estado del pedido. El cliente puede seguir viendo en camino. La asignación se guarda en dos solicitudes independientes y hay un índice único por pedido: un fallo intermedio puede impedir reintentar y la reasignación requiere un flujo específico. Implementar despacho atómico, resolución de incidencia y cambio de repartidor.
- [ ] **P1 — Liquidaciones calculadas en servidor.** El repartidor envía importes, folios y cantidades calculados en su navegador. La política INSERT observada verifica que sea su usuario, sin validar ahí que los importes correspondan a entregas. Recalcular desde las entregas y cerrar contra efectivo recibido, sin doble cobro. Revisar también el tratamiento de tarjeta pendiente como ya pagada en `renderShift`.
- [ ] **P1 — Limitar pedidos automatizados.** La función pública de pedidos no muestra rate limit, CAPTCHA ni límites por dispositivo/IP en el código revisado. Añadir protección contra spam proporcional al piloto, sin bloquear pedidos invitados legítimos.
- [ ] **P1 — Validar cantidades y personalizaciones en servidor.** El servidor acepta cantidades fraccionarias y comprueba disponibilidad de modificadores, pero no su relación con el producto, selección obligatoria ni duplicados. Al guardar dos líneas del mismo producto usa `find(product_id)` y puede asociar las opciones de la primera a ambas. Usar identificador de línea y validar grupos/elecciones.
- [ ] **P1 — Congelar una versión coherente.** `create-guest-order` local difiere de la versión 9 desplegada, que añade canje de puntos y validación de métodos de pago. El cliente local no envía `loyaltyPoints`. `README.md` y `DESPLIEGUES.md` también están atrasados. Sincronizar fuentes, despliegue web y Supabase antes de publicar cambios.
- [ ] **P1 — Mostrar caída de conexión al personal.** El panel captura fallos de actualización de pedidos solo con `console.error`; puede parecer actualizado mientras muestra datos viejos. Mostrar conexión, última actualización y reintento. El panel consulta cada 10 s y el repartidor cada 12 s; no hay evidencia aquí de avisos push en segundo plano. Probar audio y suspensión del teléfono/tablet.

### Carga operativa y ensayo final

- [ ] Confirmar alcance de lealtad. Inventario queda fuera del piloto por decisión del negocio; no cargar recetas ni existencias. La automatización de inventario permanece en Supabase, actualmente sin recetas, y requiere desactivarse o corregirse antes de reutilizar ese módulo.
- [ ] Confirmar menú, precios, agotados, horarios, envío, mínimo, contacto de WhatsApp, cuenta de transferencias y disponibilidad de terminal para entregas.
- [ ] Revisar cuentas individuales de dueño, caja, cocina y repartidor; recuperación de acceso, sesiones vencidas y permisos entre cuentas. Supabase advierte que la protección contra contraseñas filtradas está desactivada. Sus advertencias sobre funciones SECURITY DEFINER requieren revisar autorización, no deshabilitarlas sin análisis; la RPC de reparto sí comprueba usuario y membresía activa.
- [ ] Probar cliente invitado y con cuenta: recoger/entrega, efectivo/transferencia/tarjeta, combo repetido, dos productos iguales con notas distintas, producto agotado entre carrito y envío, puntos, cancelación y reseña.
- [ ] Probar envío incierto: doble toque, corte de señal después de guardar, reintento, recarga, dos pestañas y confirmación sin duplicados. Las pruebas existentes usan servicios simulados y rutas de Playwright de un entorno `/opt` distinto; no se ejecutaron en esta revisión.
- [ ] Hacer ensayo con cuentas reales del personal: aceptar → preparar → listo → asignar → recoger → entregar → liquidar → corte; además rechazar, cancelar, incidencia y reasignar.
- [ ] Verificar dominio HTTPS, acceso al enlace público, Android/iPhone, PWA instalada, permisos de ubicación/cámara, tablet de cocina, despliegue web exacto, copia de respaldo y procedimiento de restauración.
- [ ] Nombrar responsable de supervisión, capacidad máxima de pedidos y plan de pausa/WhatsApp si falla la app. Registrar tiempos, pedidos perdidos, cobros y diferencias por turno.

## Criterio de salida

Empezar con un grupo pequeño y horario acotado después de cerrar los P0, resolver los P1 del alcance elegido y aprobar un ensayo integral. No abrir un piloto público solo porque el menú y checkout cargan correctamente.

## Fuentes de la revisión

- Cliente: `pedir/index.html`, `loadPublicData`, `hacerPedido`, `weeklyScheduleStatus` y checkout.
- Operación: `admin/index.html`, `loadLiveOrders`, `cashAction`, `confirmarAceptar`, `confirmarAsignacion` y `avanzar`.
- Repartidor: `repartidor/index.html`, `renderDetail`, `renderShift`, `solicitarLiquidacion` y `advance`.
- Supabase: funciones desplegadas, políticas e índices consultados en lectura; sin cambios de esquema ni datos.
- Service worker: `sw.js`; las respuestas de Supabase no se cachean y los portales de personal se excluyen del cache.

