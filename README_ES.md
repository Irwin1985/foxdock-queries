# foxdock-queries

El plugin `queries` de FoxDock, el sistema de plugins para el IDE de Visual FoxPro 9. Una ventana para los .sql de FoxQuery: listarlos, comprobarlos para cada motor, ejecutarlos y compilarlos en un catálogo.

> También en inglés ([README.md](README.md)) y en alemán ([README_DE.md](README_DE.md)).

## Instalar

Hacen falta FoxDock y [FoxPack](https://irwinrodriguez.dev/products/foxpack).

- En FoxDock: **FoxDock > Plugins > Centro de plugins...**, **Disponibles**, elige `queries` y pulsa **Instalar**.
- Desde una consola: `foxpack plugin add queries`.

Si `queries` vino con tu instalador de FoxDock, el centro de plugins enseña sus versiones nuevas en **Actualizaciones**.

## El paquete `queries`

**FoxDock > Consultas** trabaja con los `.sql` de FoxQuery: las consultas SQL de un programa,
guardadas en ficheros y ejecutadas por su nombre con sus parámetros. La ventana las lista, las comprueba para un
motor, enseña el SQL que le llega a cada motor y las ejecuta en las tablas DBF del IDE, en una conexión de **Datos**
o en un handle de ODBC. Esta versión trae sus tres módulos: `catalog`, `run` y `build`, que compila la carpeta en un
catálogo `.fq`.

| Barra | Qué hace |
|---|---|
| **Consultas...** | La ventana `FoxDock - Consultas` (abajo). Hay una sola: si la pulsas otra vez, viene delante |
| **Nueva consulta...** | Una ventanita: el nombre (`customers.by_city`), `read` o `write`, y una descripción. Escribe `queries\<nombre>.sql` en la página de códigos de VFP, con su cabecera y un ejemplo de parámetro, y lo abre en el editor. El nombre es una letra o `_`, y después letras, dígitos, `_` o puntos, sin espacios. La descripción admite varias líneas, y va al `.sql` en una. Hecha, la ventanita se cierra, y la ventana lo dice con la consulta nueva elegida. Un fichero que ya existe no se pisa: lo dice la ventanita |
| **Ejecutar...** | La ventanita de la consulta elegida en la ventana (abajo), para ejecutarla. Sin ninguna elegida, abre la ventana, y el aviso te pide que elijas una |
| **Comprobar** | Lee la carpeta y la comprueba para `vfp`: los ficheros que no cargan y lo que `vfp` no puede ejecutar, en la ventana **FoxDock - Comprobar consultas**: cuántos errores y avisos, la carpeta, y una fila por cada uno (tipo, consulta, línea, código), con el motivo entero del elegido debajo. **Editar** (o un doble clic, o Intro) abre el `.sql` en esa línea, y **Comprobar otra vez** vuelve a leer la carpeta. Sin nada que decir, el aviso de arriba a la derecha de VFP dice cuántas consultas hay |
| **Generar catálogo...** | La ventanita que compila la carpeta en un catálogo `.fq`, con tu clave (abajo). El botón **Generar catálogo...** de la ventana abre la misma |
| **Ejecutar en >** | Dónde se ejecutan las consultas: **Tablas DBF locales (vfp)**, las tablas abiertas en la sesión de datos 1 del IDE; cada conexión de **FoxDock > Datos > Conexiones**; y cada handle de ODBC abierto en el IDE (`SQLCONNECT`, `SQLSTRINGCONNECT`), con su driver. La elegida lleva su marca. Al elegir una, la carpeta se comprueba para su motor, así que el panel y **Comprobar** hablan de ese motor. Una conexión sin conectar va a su **Conectar...** |
| **Recargar** | Vuelve a leer la carpeta |

**La carpeta.** `queries\` junto al `.pjx` del proyecto activo; sin proyecto, `queries\` de la carpeta actual.
`"options": { "queries": { "folder": "sql" } }` la cambia (relativa al proyecto, o una ruta entera). Se lee la
primera vez que la ventana, una barra o una tool la piden, nunca al arrancar el IDE; con más de 100 `.sql`, el
aviso dice que está cargando. Si la carpeta no existe, la ventana lo dice, y **Nueva consulta...** la crea con la
primera consulta. **Cambiar...**, junto a la carpeta, elige otra y la escribe en `config.json`, que es uno para todos
los IDE: VFP 9 y VFP Advanced leen entonces las mismas consultas, de un solo sitio. Si el otro IDE está abierto, la ve
en cuanto la ventana, una barra o una tool vuelven a pedirla (con la ventana ya abierta, **Recargar**).

**La ventana.** La carpeta, con **Cambiar...** y **Abrir carpeta** (la abre en el Explorador de Windows); un filtro que va filtrando
mientras escribes; la lista, una consulta por `.sql` con su tipo; y un panel con la elegida: nombre, tipo,
descripción, sus parámetros (nombre, tipo, `required`, `list`, `default`), `sort`, los identificadores, los motores
para los que tiene una sección propia, y lo que dice `vfp` de ella (`(ok)`, o el aviso con su línea). Un fichero que
no carga sale con `!` delante, y su error (código, línea, motivo) en el panel. Los botones:
- **Editar** (también Intro en la lista, o un doble clic): el `.sql` en el editor de VFP, en su línea. Cuando se
  cierra ese editor, la carpeta se vuelve a leer. Guardar sin cerrar no avisa de nada: pulsa **Recargar** si lo
  quieres antes.
- **SQL para el motor**, con su flecha: el SQL de la consulta para `vfp`, para uno de los otros seis motores o para todos, como
  lo resuelve FoxQuery, en una ventana de solo lectura, con los parámetros `:nombre` tal cual. El botón y su flecha
  abren el mismo menú.
- **Ejecutar en** (arriba a la derecha): la misma elección que **Ejecutar en >**.
- **Ejecutar...**: la ventanita de la consulta elegida.
- **Comprobar**, **Nueva consulta...**, **Generar catálogo...** y **Recargar**, como las barras.
- **Ayuda**: esta sección del manual, en el navegador. La **Ayuda** de **Nueva consulta...** lleva a
  [Cómo se escribe una consulta](#cómo-se-escribe-una-consulta).
- **Borrar**: antes pregunta, en la ventanita **FoxDock - Borrar consulta**: la consulta, su fichero, y que el fichero
  va a la Papelera de reciclaje de Windows, de donde se puede recuperar. **Borrar** lo manda allí y la consulta sale
  de la lista; **Cancelar**, Intro o Esc lo dejan todo como estaba. Un `.sql` abierto en un editor que abrió la
  ventana no se borra: la ventana lo dice, y cierras antes el editor.

Un botón que no tiene nada que hacer está apagado: sin una consulta elegida, **Editar**, **Borrar**, **Ejecutar...** y
**SQL para el motor**; con una rota, **Ejecutar...** y **SQL para el motor**; sin ningún `.sql`, **Comprobar**; sin
ninguna consulta que cargue, **Generar catálogo...**; y sin la carpeta, **Abrir carpeta**.

La ventana se cierra sola al cerrarse el proyecto, y la pregunta de **Borrar** con ella. Nada en ella abre un
diálogo de VFP, salvo el de elegir carpeta que abres tú con **Cambiar...**: la pregunta es una ventanita de FoxDock
que no para a nadie.

**Ejecutar...** La ventanita `FoxDock - Ejecutar <nombre>` se hace con la cabecera de la consulta: una fila por
parámetro, con su tipo y un `*` si es `required` (`D` es una fecha con el `SET DATE` del IDE, `T` una fecha con hora,
`L` una casilla, `list` un texto con comas, lo demás un texto; el `default` viene escrito); **Orden**, entre las
columnas de su línea `-- sort:`; un cuadro por identificador, con el último valor que se le dio (se guarda en
`config.json`, `options.queries.idents`; uno que no encaja con su forma, como `0X` en un `digits 2`, lo dice, no se guarda
y no se ejecuta nada); y **Límite**, las filas como mucho (el `queryLimit` de **Datos >
Conexiones**, 100 si no lo hay; `0`, sin límite). **Ejecutar**:
- una consulta `read` deja sus filas en el cursor `q_<nombre>` de la sesión de datos 1 (`q_customers_by_city`) y las
  enseña en un `BROWSE` de solo lectura cuyo título dice la consulta, el motor, las filas y, si había más, `las
  primeras <n>`. Con una columna y una fila (un `COUNT(*)`), la ventanita da su valor;
- una consulta `write` pregunta antes, en la propia ventanita: el botón pasa a **Ejecutarla**, y las filas cambian al
  pulsarlo la segunda vez. Después la ventanita dice cuántas filas cambiaron;
- lo que FoxQuery rechaza (un parámetro `required` vacío, un número que no lo es, una consulta del otro tipo) sale en
  la ventanita con su código (`param_missing`), y no se ejecuta nada;
- lo que falla dice dónde se ejecutó (`No se ha ejecutado en Tablas DBF locales (vfp): ...`). En las tablas DBF
  locales VFP ejecuta la SQL tal cual, así que una consulta escrita para otro motor (corchetes, `.dbo.`, `CASE WHEN`)
  da un error de VFP, como el `error 1300`, y la ventanita dice primero, antes del error, que necesita su conexión en **Ejecutar en**.

**A objeto** convierte las filas de la última ejecución en una `Collection` con un objeto por fila, en una variable
`PUBLIC` con el nombre escrito al lado (`loCustomersByCity`), para la ventana de comandos. Una variable que ya existe
no se pisa.

Alrededor de cada ejecución el IDE queda como estaba: el área de trabajo elegida, el puntero de cada tabla abierta en
la sesión de datos 1, y `SET DELETED`, `ANSI`, `EXACT` y `TABLEPROMPT`. En una conexión o un handle el límite va al
servidor (`MaxRecords`), así que una tabla grande no llega entera.

**Generar catálogo...** La ventanita `FoxDock - Generar catálogo` compila la carpeta en un catálogo `.fq`, el que tu
programa carga con `FQ_LOAD("app.fq", "tu clave")` (FOXQUERY.md, en inglés). Trae la carpeta (de solo
lectura); el nombre del `.fq` (`<proyecto>.fq` junto al `.pjx`; sin proyecto abierto, `queries.fq` en la carpeta
actual); la clave, escrita como puntos; **Recordar** y **Olvidar**; **Cifrar**; **Añadir al proyecto** (marcada si hay
un proyecto abierto; si no, apagada, y la ventanita dice por qué); y **Reemplazarlo**. Un `.fq` que ya existe no se
pisa hasta que se marca **Reemplazarlo**: la ventanita lo dice al abrirse. **Generar** compila todos los `.sql` de la
carpeta: uno que no carga lo para, con su código y su línea. Antes de decir que está hecho, carga aparte el `.fq` que
escribió, con la misma clave: entonces la ventanita dice cuántas consultas, cuántos bytes, cuánto tardó, si va cifrado
y con qué clave, y los avisos de los motores, uno por línea con su consulta (`{offset}` en `vfp`, por ejemplo). Si el
`.fq` está abierto en un editor, FoxQuery no puede escribirlo: `catalog_not_written`, y la ventanita dice que cierres
ese editor. Si la carpeta del `.fq` no existe, el mismo código, y la ventanita dice qué carpeta, que la crees o
que elijas un `.fq` en otra: FoxQuery no la crea. **Abrir carpeta**, al lado del nombre del `.fq`, abre su carpeta en el Explorador de Windows, con el
`.fq` elegido si ya existe. Nada en ella abre un diálogo, tampoco con `SET SAFETY ON`.

**La clave.** Sin clave, el `.fq` va firmado con la clave fija de FoxQuery: un `.fq` cambiado por error no carga, y
quien conozca FoxQuery podría firmar otro. Con tu clave, nadie. **Cifrar** además oculta las consultas, y necesita
clave. Con **Recordar**, FoxDock guarda la clave cifrada con tu cuenta de Windows (DPAPI) en
`secrets\queries-<proyecto>.cred` de su carpeta de datos, como las contraseñas de **Datos > Conexiones**, y la
ventanita la trae puesta la próxima vez; **Olvidar** la borra. Necesita un proyecto abierto, porque la clave va con el
proyecto. La clave nunca se escribe en `config.json`, en `foxdock.log` ni en una respuesta al agente.

**El `.fq` en el proyecto.** **Añadir al proyecto** lo añade como fichero del proyecto (`Type x`, incluido). Así
`BUILD EXE` lo mete dentro del `.exe`, y `FQ_LOAD("app.fq")` lo encuentra ahí, con el `.exe` solo en otra carpeta.
Dentro del `.exe`, `FILE("app.fq")` da `.T.` aunque el fichero no esté en el disco.

| Opción | Por defecto | |
|---|---|---|
| `folder` | `""` | la carpeta de las consultas; vacía, `queries\` junto al proyecto |
| `catalog.enabled` | `.T.` | `.F.` apaga el módulo: ni barras, ni ventana, ni tools |
| `run.enabled` | `.T.` | `.F.` apaga **Ejecutar...**, **Ejecutar en >** y sus dos tools; la ventana sigue funcionando |
| `idents` | `{}` | el último valor de cada identificador, por su nombre (`"idents": { "sort": "name" }`); lo escribe **Ejecutar...** |
| `build.enabled` | `.T.` | `.F.` apaga **Generar catálogo...** (la barra y el botón) y su tool |

FoxDock lleva el FoxQuery que usa, la 1.0.0, como `plugins\queries\QueriesFoxQuery.prg`, y su manual es
FOXQUERY.md (en inglés): los `.sql`, las macros y todos los códigos de error. FoxDock nunca pone esa
copia en `SET PROCEDURE` ni llama a las funciones `FQ_*`, así que un `foxquery.prg` de tu proyecto, de otra versión,
sigue funcionando como antes.

Para el agente hay ocho tools: AGENT-TOOLS_ES.md § 10. Con el rol 10
también te puede guardar una consulta (`ide_queries_save`): FoxQuery comprueba el `.sql` antes de escribirlo, y la
ventana lo enseña en el acto.

### Cómo se escribe una consulta

Una consulta es un `.sql` de texto en la carpeta `queries\`: arriba, la cabecera, una línea `-- clave: valor` por
cosa; debajo, la SQL. **Nueva consulta...** escribe una con su cabecera, y su **Ayuda** te trae aquí. Un ejemplo con
lo que se usa a diario:

```sql
-- name: clientes.de_una_ciudad
-- description: Los clientes de una ciudad, por nombre.
-- kind: read
-- param: ciudad C required
-- param: desde D
-- sort: nombre, id
SELECT id, nombre, alta
FROM clientes
WHERE ciudad = :ciudad {if :desde}AND alta >= :desde{endif}
ORDER BY {sort nombre}
```

- **`-- param:`** es un parámetro: su nombre, su tipo (`C N I D T L Y M`), y si quieres `required`, `list` o
  `default`. En la SQL va como `:nombre`, y su valor nunca se pega en el texto.
- **`{if :desde} … {endif}`** entra solo cuando la llamada da `desde`.
- **`-- sort:`** dice las columnas por las que se puede ordenar; `{sort nombre}` es el orden si la llamada no pide otro.
- **Un nombre que tu programa escribe en la SQL** (una columna, por ejemplo): `-- ident: sort letters 1-20` lo declara,
  y `{ident sort}` escribe su valor tal cual, sin comillas: `SELECT id, name FROM customers ORDER BY {ident sort}` se
  ejecuta como `ORDER BY name` cuando el valor es `name`. La forma (`digits`, `letters`, `alnum` o `ident`, y una
  longitud `2` o un rango `1-20`) es lo único que puede ser el valor, y solo lleva letras, dígitos y `_`.
- **El valor lo fija tu programa, una vez**: `FQ_SET("sort", "name")` al arrancar, para todas las consultas que lo
  usan, nunca en una llamada (el orden que elige cada llamada es `{sort}`). En FoxDock, **Ejecutar...** tiene un
  cuadro por identificador y recuerda el último valor.

Lo demás (las macros de cada motor, las secciones `-- engine:`, todos los códigos de error) está en
FOXQUERY.md, en inglés.

## Sobre este manual

Este texto es la sección sobre `queries` del manual de plugins de FoxDock. Las referencias a otras secciones (§) y a FOXQUERY y AGENT-TOOLS apuntan a los documentos que FoxDock instala en su carpeta `docs`.

## Licencia

MIT. Está en [LICENSE](LICENSE).
