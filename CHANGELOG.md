# Changelog

## 0.4.0

### Añadido

- Vista de lista, vista compacta y vista de tabla, además del tablero Kanban.
- Agrupación por cualquier campo de selección única o por iteraciones.
- Creación de tarjetas y adición de issues y pull requests existentes.
- Selección múltiple con acciones en lote para mover, asignar, cerrar y reabrir.
- Vistas guardadas con búsqueda, filtros y orden.
- Edición de título, descripción, etiquetas y milestone desde el detalle.
- Resumen de checks, contador de comentarios y milestone en las tarjetas.
- Estimaciones numéricas con total por columna y filtro de iteración actual.
- Atajos de teclado y mejoras de accesibilidad en móvil.
- Orden de columnas: original, alfabético, por cantidad de tarjetas o manual.
- Orden de tarjetas dentro de cada columna: original, alfabético, número de issue, fecha de creación o actualización reciente, con opción de invertir el orden.
- Preferencias de visualización y orden guardadas en el dispositivo.
- Desinstalación con `./install.sh --uninstall` en Linux.

### Mejorado

- Caché en memoria por proyecto y búsqueda con retardo para tableros grandes.
- Aviso cuando el proyecto supera el máximo de tarjetas cargadas.
- Cálculo único de tarjetas filtradas, contadores y columnas por cada reconstrucción del tablero.
- Acciones de tarjeta compartidas entre todas las vistas.

## 0.3.0

### Añadido

- Perfiles múltiples: cambiar de cuenta, añadir cuenta y ver el perfil activo.
- Escaneo de proyectos vinculados a repositorios.
- Menú contextual con clic derecho en escritorio.
- Arrastre inmediato con ratón; pulsación larga en táctil.
- Abrir el proyecto activo en GitHub.
- Información de versión y comprobación de actualizaciones desde el perfil.
- Workflow de releases para Linux, Windows y macOS.

### Corregido

- Carrera al cambiar de proyecto o cancelar el login.
- Estado del tablero desincronizado tras cerrar, reabrir o asignar desde el detalle.
- Fechas de comentarios inválidas.
- Paginación de tableros con más de 100 elementos.

## 0.2.0

- Tablero Kanban, detalle de issues/PRs, temas y columnas personalizables.
