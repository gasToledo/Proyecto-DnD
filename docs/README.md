# Documentación de Milantus

Este índice es la entrada única a la documentación mantenida del proyecto.
`README.md` presenta el producto; `CLAUDE.md` contiene las reglas breves para
trabajar en el repositorio. Los detalles viven acá, una sola vez.

## Arquitectura

- [Modo DM](arquitectura/modo-dm.md): vínculo entre cuentas, autorización,
  campañas, capítulos, combate y PNJ.
- [Multiclase](arquitectura/multiclase.md): propuesta de diseño, sin
  implementar; modelo, migración y fases.
- [dnd_engine](../packages/dnd_engine/README.md): motor de reglas, modelos y
  catálogo dirigido por datos.

## Desarrollo

- [Contenido y reglas](desarrollo/contenido-y-reglas.md): fuentes válidas,
  precedencia, estructura del catálogo, generadores y verificaciones.
- [Diseño web](desarrollo/diseno-web.md): lenguaje visual, componentes,
  responsividad y accesibilidad.
- [Textos de la interfaz](desarrollo/textos.md): voz, glosario de términos,
  etiquetas de acciones y mensajes de error.
- [Versionado y changelog](desarrollo/versionado-y-changelog.md): versión
  visible, flujo de releases y formato obligatorio de cambios.

## Operaciones

- [Despliegue autoalojado](operaciones/despliegue.md): instalación, CI/CD,
  recuperación, seguridad y respaldos.

## Auditorías

- [Contenido SRD/EFA — septiembre de 2026](auditorias/contenido-srd-efa-2026-09.md):
  fotografía fechada del trabajo de contenido. No es un backlog ni una fuente
  normativa.

## Convención

- Cada tema tiene un único documento vigente.
- Los nombres de carpetas y archivos usan minúsculas y guiones, sin espacios.
- Una guía explica el estado actual. Una auditoría registra un resultado
  fechado y no se sigue ampliando como diario de cambios.
- Todo pendiente debe citar la ruta o prueba que demuestra que sigue abierto.
- Si el código y una guía discrepan, manda el código y se corrige la guía en el
  mismo cambio.
- Cada versión publicada tiene una entrada en
  [CHANGELOG.md](../CHANGELOG.md), con las categorías Nuevo, Modificado y
  Eliminado.
- Manuales, transcripciones y planes privados viven en
  `referencias-locales/`, que Git ignora. No se enlazan como requisito para
  clonar, compilar o mantener el proyecto.
- Git conserva el historial técnico; `CHANGELOG.md` resume el impacto visible
  de cada versión.
