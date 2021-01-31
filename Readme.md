# Flashloans

## Run Script for found arbitrage oportunity

### Que es un Flashloan?
```
Un flashloan o por su traducción al español prestamo express,  
es un prestamo que se hace en blockchain en este caso en la blockchain de ethereum y se paga en la misma transaccion,  
se revierte el prestamo en caso de que el solicitante no pueda pagar el monto prestado + el fee.  
Algunos DEX piden una garantia para poder prestar la cantidad deseada.
```
### Para que se usa un Flashloan?
```
Los flashloans se utilizan como un metodo para generar ganancias en criptomonedas,  
se compra barato en un DEX y se vende caro en otro.
Ej: En el DEX1 el precio del token A es igual a 10$, en el DEX2  
el precio del token A es igual a 11$, entonces se pide un prestamo en el DEX1 por  
la Cantidad de 100 tokens A (1,000$), se recibe el prestamo nos vamos al DEX2  
y vendemos esos 100 tokens A a un precio de 11$ (1,100$)  
con el dinero resultado de la operación volvemos al DEX1 y  
pagamos el presatmos de los 100 tokens A (1,000$) quedandonos  
con una ganancia de 100$ a esto se le conoce como Arbitrage.
```
### Que es el Arbitrage?
```
En terminos simples el arbitrage es hacer una diferencia de dinero.
Ejemplo: Puedes comprar articulos desde china a un precio bajo  
y despues vender esos articulos con un precio más alto en otra parte del mundo.
```
### Factores a tomar en cuenta.
```
* Hay diferentes estrategias de arbitrage, en este script se usa una estrategia de par simple.
Que consiste en comprar tokens cuando son baratos y liquidar en otro DEX cuando son más caros.
* Se debe tener el eth suficiente para pagar el gas de las transacciones.
* Si el script detecta que hay un profit se ejecuta la transaccion si no hay profit no pasa la transaccion.
* Se pueden cambiar los pares de tokens por otros de tu interes.
* Se pueden interactuar con otros DEX.
```
## Siguientes Pasos.
...