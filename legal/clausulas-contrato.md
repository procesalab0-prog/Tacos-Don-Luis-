# Cláusulas de respaldo, disponibilidad y seguridad

Borrador para el contrato entre **ProcesaLab** (el proveedor) y la taquería
(el cliente). No es un contrato completo: son las tres cláusulas que faltaban,
redactadas para pegarse en el que ya existe.

**Esto lo tiene que revisar un abogado antes de firmarse.** Está escrito para
que refleje lo que el sistema de verdad hace, que es la parte que un abogado no
puede saber solo; la forma legal es su terreno.

Un aviso que importa más que el resto: **varias de estas promesas dependen del
plan que se contrate en Supabase.** En el plan gratuito no hay respaldos
automáticos con retención garantizada. Si se firma el compromiso de respaldos
de abajo estando en el plan gratuito, se está firmando algo que no se puede
cumplir. El Anexo A es donde se aterriza eso.

---

## Cómo quedan las partes frente a la ley de datos personales

Antes de las cláusulas conviene dejar sentado esto, porque de aquí cuelga todo
lo demás.

Bajo la Ley Federal de Protección de Datos Personales en Posesión de los
Particulares, **la taquería es la responsable** de los datos de sus clientes
(nombre, teléfono, dirección de entrega) y **ProcesaLab es el encargado**: los
trata por cuenta de la taquería y siguiendo sus instrucciones, no para fines
propios.

Esto no es un tecnicismo. Significa que:

- El aviso de privacidad lo emite la taquería, no ProcesaLab.
- Si un cliente ejerce sus derechos ARCO, se los reclama a la taquería, y
  ProcesaLab está obligado a darle a la taquería lo que necesite para
  responder.
- Ante una filtración, quien tiene que avisar a los clientes es la taquería.
  ProcesaLab le avisa a ella. De ahí la cláusula tercera.

---

## Cláusula primera — Respaldos y recuperación

**1.1** ProcesaLab mantendrá respaldos de la base de datos con la periodicidad
y retención señaladas en el Anexo A.

**1.2** Los respaldos comprenden pedidos, productos, precios, cuentas del
personal y calificaciones. **No comprenden** las imágenes del menú ni el código
de la aplicación, que se conservan por separado en el repositorio del proyecto
y no dependen de la base de datos.

**1.3** Ante una pérdida de información imputable a falla técnica, ProcesaLab
restaurará el respaldo útil más reciente dentro del plazo de recuperación del
Anexo A, contado desde que ProcesaLab tuvo conocimiento del hecho.

**1.4** ProcesaLab no responde por la pérdida de información derivada de que la
taquería o su personal borren o alteren datos desde los paneles de
administración. Esas acciones son legítimas dentro del sistema y el sistema no
distingue una equivocación de una decisión. Se restaurará el respaldo si es
posible, pero como servicio, no como obligación.

**1.5** La taquería puede pedir por escrito una copia de su información, hasta
dos veces al año sin costo, en formato de uso común. ProcesaLab la entregará
dentro de los diez días hábiles siguientes.

**1.6** Terminado el contrato por cualquier causa, ProcesaLab entregará a la
taquería una copia completa de su información dentro de los treinta días
naturales siguientes, y la conservará por noventa días naturales más antes de
borrarla en definitiva. La entrega no está condicionada a que existan adeudos:
la información es de la taquería.

---

## Cláusula segunda — Disponibilidad del servicio

**2.1** ProcesaLab procurará que el sistema esté disponible el porcentaje de
tiempo señalado en el Anexo A, medido por mes calendario.

**2.2** Se entiende por *no disponible* que la página de pedidos no cargue o
que no se puedan registrar pedidos nuevos. No cuenta como no disponibilidad la
lentitud, ni que una función secundaria falle mientras se pueda seguir pidiendo.

**2.3** No se computan como no disponibilidad:

- a) El mantenimiento programado que ProcesaLab avise con veinticuatro horas de
  anticipación, fuera del horario de servicio de la taquería.
- b) Las caídas de los proveedores de infraestructura —hoy Vercel y Supabase—
  cuando sean generales y estén reconocidas públicamente por ellos.
- c) La falta de internet o de energía en el domicilio de la taquería.
- d) El caso fortuito y la fuerza mayor.

**2.4** Sobre el inciso b) conviene ser franco: ProcesaLab no opera esos
servidores y no puede garantizar más de lo que sus proveedores le garantizan a
él. Lo que sí se obliga es a monitorear, avisar y escalar con el proveedor, y a
tener a la taquería informada mientras dure la caída.

**2.5** ProcesaLab mantiene un monitoreo automático que revisa el sistema cada
diez minutos y levanta un aviso cuando deja de responder.

**2.6** Si en un mes la disponibilidad queda por debajo de lo comprometido, la
taquería tendrá derecho a la bonificación del Anexo A, aplicable contra la
mensualidad siguiente. Esa bonificación es la única compensación por
indisponibilidad. ProcesaLab no responde por lucro cesante ni por ventas no
realizadas.

**2.7** Mientras el sistema esté caído, la taquería puede seguir tomando
pedidos por teléfono o WhatsApp. El sistema es un canal de venta, no el único.

---

## Cláusula tercera — Incidentes de seguridad

**3.1** Se entiende por incidente de seguridad todo acceso, uso, alteración,
divulgación, pérdida o destrucción no autorizados de la información de la
taquería o de los datos personales de sus clientes.

**3.2** ProcesaLab notificará a la taquería **dentro de las veinticuatro horas**
siguientes a que tenga conocimiento del incidente, por el medio de contacto del
Anexo A, sin esperar a tener la investigación terminada. Un aviso incompleto a
tiempo vale más que uno completo tarde, porque el plazo para avisarle a los
clientes le corre a la taquería desde que se entera.

**3.3** El aviso contendrá, con lo que se sepa hasta ese momento: qué pasó,
cuándo, qué información pudo verse comprometida, cuántas personas pueden estar
afectadas, qué se ha hecho para contenerlo y qué se recomienda hacer.

**3.4** ProcesaLab entregará un informe final dentro de los quince días hábiles
siguientes, con las causas, el alcance confirmado y las medidas adoptadas para
que no se repita.

**3.5** ProcesaLab dará a la taquería el apoyo técnico que necesite para
cumplir con sus propias obligaciones de notificación frente a los titulares y
ante la autoridad.

**3.6** ProcesaLab se obliga a mantener, cuando menos: cifrado en tránsito en
todo el sistema, acceso a los paneles restringido por cuenta y por rol,
separación entre los datos de la taquería y los de cualquier otro cliente, y
control de acceso a nivel de base de datos que impida que un usuario lea
información que no le corresponde.

**3.7** Si el incidente resulta imputable a que la taquería o su personal
compartieron sus contraseñas o dejaron sesiones abiertas en equipos ajenos, las
obligaciones de notificación de ProcesaLab siguen en pie, pero la
responsabilidad por los daños no.

---

## Anexo A — Parámetros

Estos son los números que hacen falta llenar. Los que se sugieren están
pensados para lo que este sistema puede sostener de verdad, no para verse bien
en el papel.

| Concepto | Sugerido | Depende de |
|---|---|---|
| Periodicidad de respaldo | Diaria | Plan de Supabase |
| Retención de respaldos | 7 días | Plan de Supabase |
| Plazo máximo de recuperación | 8 horas hábiles | — |
| Pérdida máxima de información aceptable | 24 horas | Periodicidad del respaldo |
| Disponibilidad mensual comprometida | 99 % | — |
| Bonificación por incumplimiento | 10 % de la mensualidad por cada punto porcentual abajo, con tope del 50 % | — |
| Plazo de aviso de incidente | 24 horas | — |
| Medio de aviso de incidente | Correo y WhatsApp al contacto designado | — |
| Contacto de la taquería para incidentes | *(nombre, correo y teléfono)* | — |

### Por qué 99 % y no 99.9 %

99 % mensual permite unas siete horas de caída al mes. Suena a poco compromiso,
pero es lo honesto: ProcesaLab no opera Vercel ni Supabase, y en los planes de
entrada ninguno de los dos le firma a él un nivel de servicio que pueda
trasladar. Prometer 99.9 % sería prometer con dinero ajeno.

Si la taquería quiere un número más alto, es una conversación de costos: exige
subir de plan en los dos proveedores y, según cuánto se quiera subir, cambiar
la arquitectura. Se puede, pero se cotiza aparte.

### Lo que hay que confirmar antes de firmar

1. **El plan de Supabase.** Es la condición de la cláusula primera. En el plan
   gratuito no hay respaldos automáticos con retención garantizada, así que la
   periodicidad y la retención del anexo no se pueden sostener. Si se firma
   así, se firma en falso.
2. **Quién recibe el aviso de incidente**, con nombre y datos. Una cláusula de
   notificación sin destinatario cierto no sirve.
3. **Qué dice el aviso de privacidad que ya tiene la taquería** sobre quién
   trata los datos. Si no menciona a un encargado externo, hay que actualizarlo
   para que sea congruente con la cláusula tercera.
