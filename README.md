# foxdock-queries

The `queries` plugin of FoxDock, the plugin system for the Visual FoxPro 9 IDE. A window for the .sql files of FoxQuery: list them, check them for each engine, run them and compile them into a catalog.

> Also in Spanish ([README_ES.md](README_ES.md)) and German ([README_DE.md](README_DE.md)).

## Install

You need FoxDock and [FoxPack](https://irwinrodriguez.dev/products/foxpack).

- In FoxDock: **FoxDock > Plugins > Plugin center...**, **Available**, choose `queries` and press **Install**.
- From a console: `foxpack plugin add queries`.

If `queries` came with your FoxDock installer, the plugin center shows its new versions in **Updates**.

## The `queries` package

**FoxDock > Queries** works with the `.sql` files of FoxQuery: the SQL queries of a program, kept in
files and run by their name with their parameters. The window lists them, checks them for an engine and shows the SQL
each engine gets, and runs them on the DBF tables of the IDE, on a connection of **Data** or on an ODBC handle. This
version has its three modules: `catalog`, `run` and `build`, which compiles the folder into a `.fq` catalog.

| Bar | What it does |
|---|---|
| **Queries...** | The window `FoxDock - Queries` (below). There is one: pressed again, it comes to the front |
| **New query...** | A small window: the name (`customers.by_city`), `read` or `write`, and a description. It writes `queries\<name>.sql` in the code page of VFP, with its header and an example of a parameter, and opens it in the editor. The name is a letter or `_`, then letters, digits, `_` or dots, without spaces. The description can take several lines, and it goes to the `.sql` in one. Made, the small window closes, and the window says so with the new query chosen. A file that is there is not overwritten: the small window says so |
| **Run...** | The small window of the query chosen in the window (below), to run it. With no query chosen, it opens the window, and the notice asks you to choose one |
| **Check** | Reads the folder and checks it for `vfp`: the files that do not load and what `vfp` cannot run, in the window **FoxDock - Check**: how many errors and warnings, the folder, and one row for each (type, query, line, code), with the whole reason of the chosen one below it. **Edit** (or a double click, or Enter) opens the `.sql` in that line, and **Check again** reads the folder again. With nothing to say, the notice at the top right of VFP says how many queries there are |
| **Build catalog...** | The small window that compiles the folder into a `.fq` catalog, with your key (below). The button **Build catalog...** of the window opens the same one |
| **Run on >** | Where the queries run: **Local DBF tables (vfp)**, the tables open in data session 1 of the IDE; each connection of **FoxDock > Data > Connections**; and each ODBC handle open in the IDE (`SQLCONNECT`, `SQLSTRINGCONNECT`), with its driver. The one chosen has its mark. Choosing one checks the folder for its engine, so the panel and **Check** speak of that engine. A connection that is not connected goes to its **Connect...** |
| **Reload** | Reads the folder again |

**The folder.** `queries\` next to the `.pjx` of the active project; with no project, `queries\` of the current
folder. `"options": { "queries": { "folder": "sql" } }` changes it (relative to the project, or a whole path). It is
read the first time the window, a bar or a tool needs it, never when the IDE starts; with more than 100 `.sql`, the
notice says that it is loading. If the folder is not there, the window says so, and **New query...** makes it with
the first query. **Change...**, next to the folder, chooses another one and writes it in `config.json`, which is one
for every IDE: VFP 9 and VFP Advanced then read the same queries, from one place. If the other IDE is open, it sees
it as soon as the window, a bar or a tool asks for it again (with the window already open, **Reload**).

**The window.** The folder, with **Change...** and **Open folder** (it opens it in Windows Explorer); a filter that works as you type;
the list, one query per `.sql` with its kind; and a panel with the one chosen: name, kind, description, its
parameters (name, type, `required`, `list`, `default`), `sort`, the idents, the engines it has a section of its own
for, and what `vfp` says of it (`(ok)`, or the warning with its line). A file that does not load comes out with `!`
in front of it, and its error (code, line, reason) in the panel. The buttons:
- **Edit** (also Enter in the list, or a double click): the `.sql` in the VFP editor, in its line. When that editor
  closes, the folder is read again. Saving without closing gives no signal: press **Reload** if you want it before.
- **SQL for engine**, with its arrow: the SQL of the query for `vfp`, for one of the other six engines or for all of them, as
  FoxQuery resolves it, in a read-only window, with the `:name` parameters as they are. The button and its arrow open
  the same menu.
- **Run on** (top right): the same choice as **Run on >**.
- **Run...**: the small window of the query chosen.
- **Check**, **New query...**, **Build catalog...** and **Reload**, as the bars.
- **Help**: this section of the manual, in the browser. The **Help** of **New query...** goes to
  [How to write a query](#how-to-write-a-query).
- **Delete**: first it asks, in the small window **FoxDock - Delete query**: the query, its file, and that the file
  goes to the Windows Recycle Bin, where you can get it back. **Delete** sends it there and the query leaves the
  list; **Cancel**, Enter or Esc leave everything as it was. A `.sql` open in an editor that the window opened is not
  deleted: the window says so, and you close the editor first.

A button with nothing to do is off: without a query chosen, **Edit**, **Delete**, **Run...** and **SQL for engine**;
with a broken one, **Run...** and **SQL for engine**; without any `.sql`, **Check**; without any query that loads,
**Build catalog...**; and without the folder, **Open folder**.

The window closes by itself when the project closes, and the question of **Delete** with it. Nothing in it opens a
VFP dialog, apart from the one of choosing a folder that you open with **Change...**: the question is a small FoxDock
window that waits for nobody.

**Run...** The small window `FoxDock - Run <name>` is made from the header of the query: one row per parameter, with
its type and a `*` when it is `required` (`D` is a date in the `SET DATE` of the IDE, `T` a date and time, `L` a check
box, `list` a text with commas, the rest a text; the `default` comes written); **Sort**, among the columns of its
`-- sort:` line; one box per ident, with the last value given (kept in `config.json`, `options.queries.idents`; one that does not fit its form, such as `0X` for a `digits 2`, says so, is
not kept, and nothing runs); and
**Limit**, the rows at most (the `queryLimit` of **Data > Connections**, 100 if left out; `0`, no limit). **Run**:
- a `read` query leaves its rows in the cursor `q_<name>` of data session 1 (`q_customers_by_city`) and shows them in a
  read-only `BROWSE` whose title says the query, the engine, the rows and, when there were more, `first <n>`. With one
  column and one row (a `COUNT(*)`), the small window gives its value instead;
- a `write` query asks first, in the small window itself: the button becomes **Run it**, and the rows change on the
  second press. Then the small window says how many rows changed;
- what FoxQuery refuses (a `required` parameter left empty, a number that is not one, a query of another kind) comes
  out in the small window with its code (`param_missing`), and nothing runs;
- what fails says where it ran (`Not run on Local DBF tables (vfp): ...`). On the local DBF tables VFP runs the SQL
  as it is, so a query written for another engine (brackets, `.dbo.`, `CASE WHEN`) gives an error of VFP, such as
  `error 1300`, and the small window says first, before the error, that it needs its connection in **Run on**.

**To object** turns the rows of the last run into a `Collection` with one object per row, in a `PUBLIC` variable with
the name written next to it (`loCustomersByCity`), for the Command window. A variable that is there is not
overwritten.

Around a run, the IDE is left as it was: the selected work area, the record pointer of every table open in data
session 1, and `SET DELETED`, `ANSI`, `EXACT` and `TABLEPROMPT`. On a connection or a handle the limit goes to the
server (`MaxRecords`), so a big table does not come whole.

**Build catalog...** The small window `FoxDock - Build catalog` compiles the folder into a `.fq` catalog, what your
program loads with `FQ_LOAD("app.fq", "your key")` (FOXQUERY.md). It has the folder (read only); the
name of the `.fq` (`<project>.fq` next to the `.pjx`; with no project open, `queries.fq` in the current folder); the
key, written as dots; **Remember** and **Forget**; **Encrypt**; **Add to the project** (checked when a project is
open; with none, off, and the window says why); and **Replace it**. A `.fq` that is there is not overwritten until
**Replace it** is checked: the window says so when it opens. **Build** compiles every `.sql` of the folder: one that
does not load stops it, with its code and line. Before it says it is done, it loads the `.fq` it wrote, apart, with
the same key: then the window says how many queries, how many bytes, how long it took, whether it is encrypted and
with which key, and the warnings of the engines, one per line with its query (`{offset}` on `vfp`, for example). If
the `.fq` is open in an editor, FoxQuery cannot write it: `catalog_not_written`, and the window says to close that
editor. If the folder of the `.fq` does not exist, the same code, and the window says which folder, to create it
or to choose a `.fq` in another one: FoxQuery does not make it. **Open folder**, next to the name of the `.fq`, opens its folder in the Windows Explorer, with the `.fq`
chosen if it is there. Nothing in it opens a dialog, with `SET SAFETY ON` too.

**The key.** Without one, the `.fq` is signed with the fixed key of FoxQuery: a `.fq` changed by mistake does not
load, and someone who knows FoxQuery could sign another one. With your key, nobody can. **Encrypt** also hides the
queries, and needs a key. With **Remember**, FoxDock keeps the key encrypted with your Windows account (DPAPI) in
`secrets\queries-<project>.cred` of its data folder, as the passwords of **Data > Connections**, and the window comes
with it the next time; **Forget** removes it. It needs an open project, because the key goes with the project. The
key is never written in `config.json`, in `foxdock.log` or in an answer to the agent.

**The `.fq` in the project.** **Add to the project** adds it as a file of the project (`Type x`, included). Then
`BUILD EXE` puts it inside the `.exe`, and `FQ_LOAD("app.fq")` finds it there, with the `.exe` alone in another
folder. Inside the `.exe`, `FILE("app.fq")` says `.T.` even when the file is not on the disk.

| Option | Default | |
|---|---|---|
| `folder` | `""` | the folder of the queries; empty, `queries\` next to the project |
| `catalog.enabled` | `.T.` | `.F.` switches the module off: no bars, no window, no tools |
| `run.enabled` | `.T.` | `.F.` switches off **Run...**, **Run on >** and their two tools; the window goes on working |
| `idents` | `{}` | the last value of each ident, by its name (`"idents": { "sort": "name" }`); **Run...** writes it |
| `build.enabled` | `.T.` | `.F.` switches off **Build catalog...** (the bar and the button) and its tool |

FoxDock carries the FoxQuery it uses, the 1.0.0, as `plugins\queries\QueriesFoxQuery.prg`, and its manual is
FOXQUERY.md: the `.sql` files, the macros and every error code. FoxDock never puts that copy in
`SET PROCEDURE` and never calls the `FQ_*` functions, so a `foxquery.prg` of your own project, of another version,
goes on working as before.

For the agent there are eight tools: AGENT-TOOLS_EN.md § 10. With agent role 10
it can also save a query for you (`ide_queries_save`): FoxQuery checks the `.sql` before it is written, and the window
shows it at once.

### How to write a query

A query is a plain-text `.sql` in the folder `queries\`: on top, the header, one line `-- key: value` for each thing;
below it, the SQL. **New query...** writes one with its header, and its **Help** brings you here. An example with what
is used every day:

```sql
-- name: customers.of_a_city
-- description: The customers of one city, by name.
-- kind: read
-- param: city C required
-- param: since D
-- sort: name, id
SELECT id, name, born
FROM customers
WHERE city = :city {if :since}AND born >= :since{endif}
ORDER BY {sort name}
```

- **`-- param:`** is a parameter: its name, its type (`C N I D T L Y M`), and if you want `required`, `list` or
  `default`. In the SQL it goes as `:name`, and its value is never pasted into the text.
- **`{if :since} … {endif}`** goes in only when the call gives `since`.
- **`-- sort:`** lists the columns the query can be sorted by; `{sort name}` is the order when the call asks for none.
- **A name that your program writes into the SQL** (a column, for example): `-- ident: sort letters 1-20` declares it,
  and `{ident sort}` writes its value as it is, without quotes: `SELECT id, name FROM customers ORDER BY {ident sort}`
  runs as `ORDER BY name` when the value is `name`. The form (`digits`, `letters`, `alnum` or `ident`, and a length `2`
  or a range `1-20`) is all the value can be, and it only takes letters, digits and `_`.
- **Your program sets the value, once**: `FQ_SET("sort", "name")` when it starts, for every query that uses it, never
  in a call (the order each call chooses is `{sort}`). In FoxDock, **Run...** has a box for each identifier and
  remembers the last value.

The rest (the macros for each engine, the `-- engine:` sections, every error code) is in FOXQUERY.md.

## About this manual

This text is the section about `queries` of the FoxDock plugin manual. The references to other sections (§) and to FOXQUERY and AGENT-TOOLS point to the documents FoxDock installs in its `docs` folder.

## License

MIT. See [LICENSE](LICENSE).
