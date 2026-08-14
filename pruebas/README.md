# Pruebas de la aplicación

Escenarios automatizados con Playwright. Sirven para comprobar que un cambio
no rompió lo que ya funcionaba, sin tener que revisar a ojo cuatro portales.

## Cómo correrlas

Desde la raíz del repositorio, con un servidor estático en el puerto 8850:

```bash
python3 -m http.server 8850 &
node pruebas/1-estructura.js    # desbordes y objetivos táctiles, 4 portales x 4 anchos
node pruebas/2-pedidos.js       # crear pedido, servidor caído, sin red, doble toque
node pruebas/3-acceso.js        # contraseña incorrecta en admin y repartidor
node pruebas/4-seguimiento.js   # pedido inexistente y caída de red durante el seguimiento
```

## Qué vigila cada una

**1-estructura** — que ninguna página se mueva de lado a 320, 360, 390 y 430 px,
que no haya botones ni enlaces por debajo de 44 px de alto, y que no falte
ningún archivo. Las tres causas del desborde a 320 px que se corrigieron en
2.19.0 se detectan aquí.

**2-pedidos** — el camino completo hasta el folio, y tres formas de fallar:
error 500, sin conexión y triple toque en "Hacer pedido". Esta última confirma
que no se crean pedidos duplicados.

**3-acceso** — que equivocarse de contraseña muestre un mensaje en español.
En admin ese mensaje no existía hasta 2.19.0.

**4-seguimiento** — que un enlace de un pedido que no existe avise y limpie el
token, y que una caída de red avise pero conserve el token y siga reintentando.

## Dos trampas al escribir escenarios nuevos

- **El token de seguimiento debe ser hexadecimal.** `/^[a-f0-9]{64}$/`. Un token
  con otras letras se descarta antes de llamar al servidor, y la prueba mide
  algo que nunca ocurrió.
- **Hay que simular la sucursal.** Si `/rest/v1/branches` devuelve vacío, la app
  aborta la carga y no llega a ejecutarse lo que se quería probar. Las pruebas
  2 y 4 traen una simulación mínima que sí funciona; conviene copiarla.
