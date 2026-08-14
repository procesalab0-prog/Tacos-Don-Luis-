# Iconos: tamaños normalizados

Los iconos se recortan al dibujo y se centran en un lienzo cuadrado, igualando
la **altura** para que ninguno se vea más grande que otro cuando van juntos.

## Fila de valores de la portada — lienzo de 256 px

| Archivo | Dibujo |
|---|---|
| `value-fresco.png` | 256 x 214 |
| `value-sabroso.png` | 206 x 215 |
| `value-orgullo.png` | 208 x 215 |

## Iconos de interfaz — lienzo de 192 px, modo LA (gris + alfa)

`iconos/icon-*.png` e `iconos/step-*.png`. Los nueve pasos del seguimiento
están todos a **177 px** de alto. Se usan como máscara CSS, no como `<img>`:
el color lo pone `currentColor`, por eso solo importa el canal alfa.

## Antes de reemplazar uno

Vuelve a normalizarlo contra los de su grupo. En 2.17.3 se sustituyó
`value-fresco.png` por un dibujo nuevo sin normalizarlo, quedó un 30% más chico
que sus compañeros y se notaba a simple vista.

El recorte se hace por umbral sobre una versión reducida de la máscara, no
sobre el alfa crudo: los archivos suelen traer manchitas casi invisibles en las
esquinas que inflan el recuadro y encogen el dibujo.
