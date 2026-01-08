# Black Box (Sistema de Seguridad IoT)

<div align="center">
  <br>
  <img src="https://github.com/user-attachments/assets/8ea81c10-2aa0-4abe-8816-21dea8e584db" height="350" alt="Hardware BlackBox" />
  &nbsp;&nbsp;
  <img src="https://github.com/user-attachments/assets/ec9364c4-34ae-4250-b326-539fc75ab6a4" height="350" alt="App Login" />
  &nbsp;&nbsp;
  <img src="https://github.com/user-attachments/assets/ac386814-0148-41d0-835b-36da5cb2872f" height="350" alt="App Dashboard" />
  <br><br>
</div>

Black Box representa nuestro Segundo Proyecto Integrador y uno de los retos técnicos más ambiciosos que hemos enfrentado.
Este sistema fue desarrollado por un equipo de 4 personas, el objetivo fue crear un ecosistema IoT (Internet de las Cosas) mejorando nuestro proyecto del cuatrimestre anterior (caja fuerte inteligente), donde ademas de mejorar su diseño, a su vez creamos una aplicación móvil nativa que tuviera el control absoluto sobre un dispositivo de hardware físico (una caja fuerte inteligente) ahora a diferencia del cuatrimestre anterior que dependiamos de adafruit, ahora logramos trabajar en su mayoria en la nube, usando servicios como lo son google cloud, mongodb y una raspberry.

## ¿Qué es Black Box?

Es una aplicación nativa para iOS desarrollada en Swift que actúa como el centro de mando de una caja de seguridad de alta tecnología.
La aplicación no solo sirve para abrir o cerrar la caja; es un monitor de seguridad en tiempo real. Gracias a la conexión con sensores físicos, la app nos permite "sentir" lo que le pasa a la caja fuerte desde cualquier lugar del mundo.

## Lo que logramos construir

Este proyecto nos obligó a conectar múltiples capas de tecnología:

* Monitoreo Ambiental: La app muestra en vivo la temperatura y humedad interna de la caja (crucial para guardar documentos o electrónicos sensibles).
* Sistema Anti-Robo (Vibración): Si alguien intenta mover, golpear o forzar la caja física, el sensor de vibración envía una alerta crítica inmediata al iPhone.
* Control Remoto Total: Podemos bloquear y desbloquear el cerrojo electromecánico directamente desde la pantalla del celular, sin necesidad de llaves físicas.
* Auditoría de Seguridad: Cada vez que la caja se abre (ya sea por app, código o llave), el evento queda registrado en una base de datos en la nube (MongoDB Atlas), creando un historial inmutable de "quién, cuándo y cómo" accedió al contenido.

## Stack Tecnológico

La arquitectura del sistema es compleja porque une hardware y software:
* Swift (iOS): Desarrollo nativo usando UIKit para una interfaz fluida y reactiva.
* Google Cloud API: Intermediario que gestiona las peticiones seguras entre el celular y el hardware.
* MongoDB Atlas: Base de datos NoSQL en la nube para el almacenamiento masivo de logs y usuarios.
* Hardware (Backend Físico): Integración con Raspberry Pi y ESP32 que leen los sensores y ejecutan las órdenes de la app.

## Equipo de Desarrollo

Este sistema fue el resultado de la colaboración y el esfuerzo conjunto de nuestro equipo de 4 integrantes para la Universidad Tecnológica de Torreón (UTT).

---
*Proyecto de Integración de Sistemas IoT y Desarrollo Móvil.*
