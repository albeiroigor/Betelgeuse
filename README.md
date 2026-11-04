# Betelgeuse

Betelgeuse es una aplicación de escritorio para trabajar con **GitHub Projects v2** sin pasar por el navegador. Tus proyectos se ven como un tablero Kanban, una lista, una vista compacta o una tabla, y desde ahí puedes mover tarjetas, crear issues y pull requests, editarlos y organizar el día a día.

Está hecha con Flutter y no tiene servidor ni backend. La app habla directamente con la API GraphQL de GitHub y guarda el token en el llavero del sistema. Todo lo que es local —columnas, colores, filtros y vistas guardadas— se queda en tu equipo.

## Qué puedes hacer

### Organizar el tablero

- Cambia entre vista de tablero, lista, compacta y tabla.
- Agrupa por cualquier campo de selección única o por iteraciones: Status, prioridad, tamaño, sprint… Si el proyecto tiene un campo `Status`, se usa por defecto.
- Ordena las columnas por orden de GitHub, alfabético, cantidad de tarjetas o manualmente, y las tarjetas por título, número, creación o actualización reciente.
- Guarda la búsqueda, los filtros y el orden actuales como una vista con nombre.

### Trabajar con tarjetas

- Crea tarjetas nuevas o añade issues y pull requests existentes con una URL o `owner/repo#número`.
- Arrastra entre columnas para cambiar el estado, o usa el menú de cada tarjeta.
- Selecciona varias tarjetas y muévelas, asígnalas o ciérralas de una vez.
- Busca por título, repositorio o etiqueta y filtra por abiertos, cerrados o solo los tuyos.
- Filtra por la iteración actual y suma un campo numérico (por ejemplo, puntos de historia) por columna.

### Ver el detalle

- Comenta, cierra o reabre issues y pull requests.
- Edita el título, la descripción, las etiquetas y el milestone.
- Consulta el estado de los checks, la decisión de revisión, el milestone, las etiquetas y los comentarios.
- Asignaciones y enlace directo a GitHub.

### Cuentas y apariencia

- Varias cuentas de GitHub guardadas de forma segura.
- Temas claros y oscuros.
- Atajos de teclado en escritorio.

## Instalación

### Linux

Descarga el `.tar.gz` del último release, extráelo y ejecuta el instalador:

```sh
./install.sh
```

No necesita `sudo`: copia la aplicación a `~/.local/opt/betelgeuse`, instala los iconos y crea el lanzador en `~/.local/bin`.

Para desinstalarla:

```sh
./install.sh --uninstall
```

### Windows

Descarga el `.zip`, extráelo y ejecuta `betelgeuse.exe`.

### macOS

Descarga el `.zip` para Apple Silicon, extráelo y abre `Betelgeuse.app`. El paquete no está firmado ni notarizado, así que si macOS lo bloquea, ábrelo con clic derecho → **Abrir**.

## Compilar desde el código

Necesitas Flutter estable. En Linux, además, las dependencias nativas habituales de Flutter:

```sh
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libsecret-1-dev
```

El login usa el flujo de dispositivo de GitHub, así que necesitas el Client ID de una OAuth App propia:

1. Entra en **GitHub → Settings → Developer settings → OAuth Apps → New OAuth App**.
2. Activa **Enable Device Flow**. La URL de callback no se usa en este flujo; puedes poner `https://github.com`.
3. Copia el Client ID (el secreto no hace falta).

Después:

```sh
flutter pub get
flutter run --dart-define=BETELGEUSE_CLIENT_ID=tu_client_id
```

La app pedirá los permisos `project`, `repo` y `read:org`.

Si quieres que compruebe si hay versiones nuevas, añade también el repositorio:

```sh
flutter run \
  --dart-define=BETELGEUSE_CLIENT_ID=tu_client_id \
  --dart-define=APP_REPOSITORY=owner/repo
```

## Atajos de teclado

| Tecla | Acción |
| --- | --- |
| `/` | Enfocar la búsqueda |
| `n` | Crear una tarjeta |
| `r` | Recargar el proyecto |
| `Esc` | Limpiar la selección o la búsqueda |
| `1`–`9` | Mover la selección a esa columna |

## Límites y decisiones

- La app está pensada para Projects v2. Para mergear pull requests, revisar código, ver diffs o gestionar ramas, abre GitHub: eso no está incluido.
- Se cargan hasta 1000 tarjetas por proyecto (10 páginas de 100). Si el proyecto es más grande, la app lo avisa y conviene filtrar.
- En las tarjetas se muestran hasta 3 etiquetas y 5 responsables; el detalle trae más información.
- No hay backend, telemetría ni sincronización propia. El token se guarda con el almacenamiento seguro del sistema y las peticiones van directamente a `api.github.com`.

## Desarrollo

```sh
flutter analyze
flutter test
```

Los tests son de widgets y unidad; usan un token falso y no hacen peticiones a GitHub.

El código está organizado por responsabilidades:

- `lib/github/` — cliente GraphQL y modelos de datos.
- `lib/features/board/` — tablero, vistas y preferencias.
- `lib/features/detail/` — detalle de una tarjeta.
- `lib/features/login/` y `lib/features/profile/` — sesión y cuentas.
- `lib/core/` — perfiles, temas, enlaces y comprobación de versiones.

## Licencia

Betelgeuse se distribuye bajo la GNU General Public License v3.0. La licencia completa está en [LICENSE](LICENSE).
