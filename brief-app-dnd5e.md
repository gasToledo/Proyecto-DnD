# Brief funcional: App de fichas de personaje D&D 5e

## 1. Objetivo del proceso
Aplicación de uso personal (no comercial, uso propio y de los jugadores de la mesa) para crear, visualizar y editar fichas de personaje de D&D 5ª edición, aplicando las reglas oficiales de creación y progresión, con seguimiento en tiempo real durante partidas, y generación de retratos vía IA.

## 2. Usuario o destinatario
El usuario y los demás jugadores de su mesa de D&D. Cada uno instala su propia copia de la app; no hay servidor compartido ni se ven los personajes de otros jugadores por defecto (salvo lo previsto en el futuro Modo DM, ver sección 11).

## 3. Flujo paso a paso

### A. Creación de personaje (wizard guiado, con tutorial en el primer personaje)
1. Elegir sistema de progresión de la mesa: XP o Hitos (solo define si se anota el PX como referencia; en ambos casos la subida de nivel es manual vía botón).
2. Configurar reglas opcionales de la mesa (ej. si se usa "Humano variante" u otra regla que otorgue una dote desde el nivel 1).
3. Raza → Clase → Trasfondo.
4. Puntuación de habilidades: elegir método (tirada 4d6 descartando el menor, con dado virtual, o array estándar 15/14/13/12/10/8).
5. Equipo inicial (arma + armadura) → la app calcula CA, carga y bonos automáticamente.
6. Dote inicial, **solo si** la configuración de reglas opcionales lo habilita (ej. Humano variante); si no, este paso se omite y las dotes aparecen recién en subida de nivel (ver sección D).
7. Rasgos pasivos: se calculan y muestran automáticamente según raza/trasfondo/clase (Percepción Pasiva, Visión en la oscuridad, resistencias/inmunidades, etc.), sin input manual del usuario.
8. Hechizos iniciales, si la clase corresponde.
9. Nombre y datos finales → se guarda en el dashboard con imagen genérica por defecto.

### B. Generación de retrato (IA)
1. Desde la ficha, se abre el generador.
2. Se auto-completan datos ya conocidos de la ficha (raza, armadura, arma, etc.), sin volver a preguntarlos.
3. El usuario puede sumar: boceto/imagen de referencia, texto libre adicional, y estilo (predeterminado de una lista, o redactado a mano).
4. Se genera con la herramienta configurada (por defecto Gemini 2.5 Flash Image / "Nano Banana" vía Google AI Studio — gratis, sin tarjeta de crédito; el usuario puede conectar otra cuenta/API si prefiere, ej. ChatGPT Images, Nano Banana Pro).
5. Se pueden generar varias imágenes por personaje; las que el usuario elige se guardan localmente en el dispositivo.

### C. Uso en partida (offline)
1. Interfaz organizada en pestañas/secciones separadas: General, Combate, Hechizos, Inventario, Notas (tanto en mobile como escritorio).
2. En Combate: ajustar PG (daño/curación), marcar hechizos lanzados (descuenta slots automáticamente), cambiar arma equipada (recalcula daño), marcar tiradas de salvación contra muerte (death saves) y condiciones de estado activas.
3. Descanso corto/largo: recalcula automáticamente los recursos recuperados (PG, dados de golpe, usos de habilidades de clase).
4. Guardado automático inmediato con debounce ante cada cambio relevante — sin necesidad de conexión a internet.

### D. Subida de nivel (wizard, activado manualmente por botón)
1. Elegir método de cálculo de PG: tirar el dado de golpe (virtual) o tomar el valor promedio/fijo.
2. Aplicar nuevos rasgos de clase, subclase (si corresponde en ese nivel), nuevos hechizos y slots.
3. En los niveles de Mejora de Característica (ASI: 4, 8, 12, etc.), el usuario elige entre **mejorar características** o **tomar una dote** de la base oficial u homebrew.
4. Actualizar la ficha, incluyendo los rasgos pasivos que puedan sumarse por la dote elegida.

### E. Gestión general
- Dashboard con todos los personajes del usuario (foto, nombre, clase, nivel), con opción de archivar como inactivo/muerto sin eliminarlo.
- Exportación de datos flexible: el usuario puede descargar el archivo de **un solo personaje** (ficha + imágenes guardadas) o hacer un **backup completo de toda la app** (todos los personajes + configuraciones), según lo que necesite en el momento.
- Importación del archivo exportado en otra instalación propia de la app, para continuar el uso en otro dispositivo sin depender de sincronización en la nube.
- Apartado homebrew para razas, clases, hechizos, objetos, armas y armaduras no oficiales, agregado por el usuario cuando el DM lo requiera.

## 4. Inputs necesarios
- Decisiones tomadas durante el wizard de creación (raza, clase, trasfondo, stats, equipo).
- Datos ingresados manualmente para contenido homebrew.
- Boceto/referencia y/o texto de estilo para la generación de imagen (ambos opcionales, combinables).
- Eventos de combate (daño, curación, hechizo lanzado, cambio de arma, condición aplicada, death saves).

## 5. Outputs esperados
- Ficha de personaje completa y editable, con cálculos automáticos (CA, daño, carga, slots de hechizo, recursos por descanso).
- Retratos de personaje generados por IA, guardados localmente.
- Archivo exportable de un personaje individual o de toda la app (backup completo), para portabilidad y respaldo.

## 6. Reglas principales
- Reglas oficiales de D&D 5e como base de datos precargada (razas, clases, hechizos, objetos, dotes, etc.).
- Validación de reglas **no bloqueante**: la app siempre advierte ante una infracción, nunca impide la acción (el DM puede autorizar excepciones puntuales).
- Un personaje = una sola clase (sin multiclase, por ahora — ver sección 9).
- Subida de nivel siempre manual vía botón, sin importar si la mesa usa XP o Hitos; la app no calcula ni compara umbrales de PX automáticamente.
- Todo el módulo esencial (fichas, combate, inventario, hechizos, descansos) debe funcionar el 100% offline.
- Solo la generación de imágenes con IA requiere conexión a internet; se deshabilita automáticamente sin ella, sin afectar el resto de la app.
- Las **dotes** se otorgan por defecto en los niveles de ASI (4, 8, 12...) al subir de nivel; la disponibilidad de una dote desde la creación (nivel 1) es configurable según las reglas opcionales de la mesa (ej. Humano variante).
- Los **rasgos pasivos** (Percepción Pasiva, Visión en la oscuridad, resistencias/inmunidades, rasgos raciales/de trasfondo/clase, y los que otorgue una dote) se calculan y muestran automáticamente en la ficha, sin que el usuario deba ingresarlos a mano.

## 7. Excepciones y casos límite
- Contenido no oficial (armas, armaduras, hechizos, razas) se gestiona en el apartado homebrew, separado de la base oficial.
- Jugadores experimentados pueden desactivar el modo tutorial/wizard guiado desde las opciones de la app.
- El usuario puede conectar su propia cuenta de otra IA de generación de imágenes en vez de usar la opción gratuita por defecto.
- Los personajes archivados (inactivos/muertos) se conservan en el dashboard sin eliminarse.

## 8. Criterios de calidad
- Ningún dato se pierde ante un cierre inesperado de la app durante una partida (guardado inmediato con debounce por evento relevante).
- Los cálculos de daño, CA y demás valores derivados siempre reflejan correctamente el arma/armadura equipada.
- El combate y todo lo esencial de la ficha funcionan sin conexión a internet, sin degradar la experiencia.
- La interfaz es rápida de usar "en caliente" durante una partida: pestañas claras, acciones rápidas de combate accesibles sin navegar la ficha completa.

## 9. Riesgos o ambigüedades pendientes
- Definir la lista concreta de estilos predeterminados para la generación de imágenes (a decidir en etapa de diseño/construcción).
- Definir la estructura técnica final del archivo de exportación/importación (formato JSON, campos exactos incluidos, diferencia entre export individual y backup completo).
- Multiclase y sincronización en la nube entre dispositivos quedan explícitamente fuera del alcance inicial, para evaluar más adelante.
- Falta definir el detalle técnico de la stack multiplataforma (Windows/Linux/Android/iOS) — decisión de la etapa de construcción, no de este brief funcional.
- El Modo DM (sección 11) queda como visión a futuro; sus reglas de funcionamiento detalladas no están definidas todavía.

## 10. Caso de uso validado (ejemplo real)
**Personaje:** Sagan "The Red" — Humano, Guerrero, nivel 1.

1. Wizard de creación (con tutorial activo, primer personaje): elige sistema de progresión (Hitos) → Raza (Humano) → Clase (Guerrero) → Trasfondo → puntuación de habilidades (dados 4d6 o array estándar) → equipo inicial (arma + armadura, CA calculada automáticamente) → sin hechizos en nivel 1 → nombre final.
2. Se guarda en el dashboard con imagen genérica por defecto.
3. Generación de imagen: la app ya conoce que es Humano; el usuario agrega texto ("armadura de cuero curtido, pelo rojo largo, cicatriz en la ceja") y elige un estilo predeterminado o redactado. Se generan varias opciones con Gemini/Nano Banana; se guarda la elegida localmente.
4. En partida: pestaña Combate, se ajustan PG al recibir daño, se marca una condición si corresponde — todo se guarda al instante, sin conexión.
5. Cuando el DM indica que sube de nivel: el jugador toca el botón manual de subir de nivel → wizard de nivel 2 → elige tirar dado de golpe o tomar promedio → se actualizan PG y demás rasgos.

## 11. Visión a futuro (fuera del alcance inicial)
- **Sincronización en la nube** entre dispositivos propios del mismo jugador, como alternativa más cómoda a la exportación/importación manual de archivos.
- **Soporte de multiclase** (por ejemplo, Guerrero 3 / Mago 2), con el cálculo correspondiente de PG, slots de hechizo y prerequisitos.
- **Modo DM**: un modo alternativo de la app pensado para quien dirige la partida, donde en vez de gestionar únicamente personajes propios, se pueda:
  - Crear y gestionar NPCs.
  - Importar los archivos de personaje exportados por los jugadores de la mesa, para tener una vista de referencia de cómo funciona cada uno (stats, equipo, hechizos disponibles) sin necesidad de preguntarles en el momento.

## 12. Siguiente acción recomendada
Con este brief funcional cerrado, el siguiente paso natural es definir la arquitectura técnica: elegir el framework multiplataforma (por ejemplo Flutter o .NET MAUI, dado que cubren Windows, Linux, Android e iOS con un solo código base), diseñar el modelo de datos (esquema de la ficha, formato JSON de exportación individual y de backup completo), y estructurar la base de datos oficial de reglas de 5e antes de empezar a programar el wizard de creación.
