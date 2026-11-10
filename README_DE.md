# foxdock-queries

Das Plugin `queries` für FoxDock, das Plugin-System für die IDE von Visual FoxPro 9. Ein Fenster für die .sql-Dateien von FoxQuery: auflisten, für jede Engine prüfen, ausführen und zu einem Katalog kompilieren.

> Auch auf Englisch ([README.md](README.md)) und Spanisch ([README_ES.md](README_ES.md)).

## Installieren

Sie brauchen FoxDock und [FoxPack](https://irwinrodriguez.dev/products/foxpack).

- In FoxDock: **FoxDock > Plugins > Plugin-Center...**, **Verfügbar**, `queries` auswählen und **Installieren** drücken.
- Von der Konsole: `foxpack plugin add queries`.

Wenn `queries` mit Ihrem FoxDock-Installer kam, zeigt das Plugin-Center seine neuen Versionen unter **Aktualisierungen**.

## Das Paket `queries`

**FoxDock > Abfragen** arbeitet mit den `.sql`-Dateien von FoxQuery: den SQL-Abfragen eines Programms,
in Dateien abgelegt und über ihren Namen mit ihren Parametern ausgeführt. Das Fenster listet sie auf, prüft sie für
eine Datenbank, zeigt das SQL, das jede Datenbank bekommt, und führt sie auf den DBF-Tabellen der IDE, auf einer
Verbindung von **Daten** oder auf einem ODBC-Handle aus. Diese Version bringt ihre drei Module: `catalog`, `run` und
`build`, das den Ordner zu einem Katalog `.fq` kompiliert.

| Menüpunkt | Was er tut |
|---|---|
| **Abfragen...** | Das Fenster `FoxDock - Abfragen` (unten). Es gibt nur eines: Ein zweiter Klick holt es nach vorne |
| **Neue Abfrage...** | Ein kleines Fenster: der Name (`customers.by_city`), `read` oder `write` und eine Beschreibung. Es schreibt `queries\<name>.sql` in der Codepage von VFP, mit seinem Kopf und einem Beispiel für einen Parameter, und öffnet die Datei im Editor. Der Name ist ein Buchstabe oder `_`, dann Buchstaben, Ziffern, `_` oder Punkte, ohne Leerzeichen. Die Beschreibung darf mehrere Zeilen haben und kommt in einer Zeile in die `.sql`. Ist sie angelegt, schließt sich das kleine Fenster, und das Fenster sagt es, mit der neuen Abfrage gewählt. Eine vorhandene Datei wird nicht überschrieben: Das kleine Fenster sagt es |
| **Ausführen...** | Das kleine Fenster der im Fenster (unten) gewählten Abfrage, um sie auszuführen. Ist keine gewählt, öffnet es das Fenster, und der Hinweis bittet, eine zu wählen |
| **Prüfen** | Liest den Ordner und prüft ihn für `vfp`: die Dateien, die nicht laden, und was `vfp` nicht ausführen kann, im Fenster **FoxDock - Abfragen prüfen**: wie viele Fehler und Warnungen, der Ordner und eine Zeile für jede (Art, Abfrage, Zeile, Code), darunter der ganze Grund der gewählten. **Bearbeiten** (oder ein Doppelklick, oder Enter) öffnet die `.sql` in dieser Zeile, und **Erneut prüfen** liest den Ordner neu. Ohne etwas zu melden sagt der Hinweis oben rechts in VFP, wie viele Abfragen es gibt |
| **Katalog erstellen...** | Das kleine Fenster, das den Ordner zu einem Katalog `.fq` kompiliert, mit deinem Schlüssel (unten). Die Schaltfläche **Katalog erstellen...** des Fensters öffnet dasselbe |
| **Ausführen auf >** | Wo die Abfragen laufen: **Lokale DBF-Tabellen (vfp)**, die in der Datensitzung 1 der IDE geöffneten Tabellen; jede Verbindung von **FoxDock > Daten > Verbindungen**; und jedes in der IDE offene ODBC-Handle (`SQLCONNECT`, `SQLSTRINGCONNECT`), mit seinem Treiber. Die gewählte trägt ihr Häkchen. Beim Wählen wird der Ordner für ihre Datenbank geprüft, also sprechen das Feld und **Prüfen** von dieser Datenbank. Eine nicht verbundene Verbindung geht zu ihrem **Verbinden...** |
| **Neu laden** | Liest den Ordner neu |

**Der Ordner.** `queries\` neben der `.pjx` des aktiven Projekts; ohne Projekt `queries\` des aktuellen Ordners.
`"options": { "queries": { "folder": "sql" } }` ändert ihn (relativ zum Projekt, oder ein ganzer Pfad). Er wird
gelesen, wenn das Fenster, ein Menüpunkt oder ein Tool ihn zum ersten Mal braucht, nie beim Start der IDE; bei mehr
als 100 `.sql` sagt der Hinweis, dass geladen wird. Gibt es den Ordner nicht, sagt das Fenster es, und
**Neue Abfrage...** legt ihn mit der ersten Abfrage an. **Ändern...** neben dem Ordner wählt einen anderen und
schreibt ihn in `config.json`, das für alle IDEs eines ist: VFP 9 und VFP Advanced lesen dann dieselben Abfragen, von
einer Stelle. Ist die andere IDE offen, sieht sie ihn, sobald das Fenster, ein Menüpunkt oder ein Tool ihn wieder braucht (bei
schon offenem Fenster **Neu laden**).

**Das Fenster.** Der Ordner mit **Ändern...** und **Ordner öffnen** (öffnet ihn im Windows-Explorer); ein Filter, der beim Tippen
filtert; die Liste, eine Abfrage je `.sql` mit ihrer Art; und ein Bereich mit der gewählten: Name, Art,
Beschreibung, ihre Parameter (Name, Typ, `required`, `list`, `default`), `sort`, die Bezeichner, die Datenbanken, für
die sie einen eigenen Abschnitt hat, und was `vfp` zu ihr sagt (`(ok)`, oder die Warnung mit ihrer Zeile). Eine Datei,
die nicht lädt, erscheint mit `!` davor, und ihr Fehler (Code, Zeile, Grund) im Bereich. Die Schaltflächen:
- **Bearbeiten** (auch Enter in der Liste, oder ein Doppelklick): die `.sql` im Editor von VFP, in ihrer Zeile. Wenn
  dieser Editor schließt, wird der Ordner neu gelesen. Speichern ohne Schließen gibt kein Signal: Drück
  **Neu laden**, wenn du es vorher willst.
- **SQL für Datenbank**, mit seinem Pfeil: das SQL der Abfrage für `vfp`, für eine der anderen sechs Datenbanken oder für alle, so wie
  FoxQuery es auflöst, in einem schreibgeschützten Fenster, mit den Parametern `:name` so, wie sie sind. Die
  Schaltfläche und ihr Pfeil öffnen dasselbe Menü.
- **Ausführen auf** (oben rechts): dieselbe Wahl wie **Ausführen auf >**.
- **Ausführen...**: das kleine Fenster der gewählten Abfrage.
- **Prüfen**, **Neue Abfrage...**, **Katalog erstellen...** und **Neu laden**, wie die Menüpunkte.
- **Hilfe**: dieser Abschnitt des Handbuchs, im Browser. Die **Hilfe** von **Neue Abfrage...** führt zu
  [Eine Abfrage schreiben](#eine-abfrage-schreiben).
- **Löschen**: Zuerst fragt es, im kleinen Fenster **FoxDock - Abfrage löschen**: die Abfrage, ihre Datei und dass
  die Datei in den Papierkorb von Windows kommt, aus dem Sie sie zurückholen können. **Löschen** verschiebt sie dorthin,
  und die Abfrage verschwindet aus der Liste; **Abbrechen**, Enter oder Esc lassen alles, wie es war. Eine `.sql`, die
  in einem vom Fenster geöffneten Editor offen ist, wird nicht gelöscht: Das Fenster sagt es, und Sie schließen zuerst
  den Editor.

Eine Schaltfläche, die nichts zu tun hat, ist aus: ohne gewählte Abfrage **Bearbeiten**, **Löschen**, **Ausführen...**
und **SQL für Datenbank**; bei einer defekten **Ausführen...** und **SQL für Datenbank**; ohne `.sql` **Prüfen**;
ohne eine Abfrage, die lädt, **Katalog erstellen...**; und ohne den Ordner **Ordner öffnen**.

Das Fenster schließt sich von selbst, wenn das Projekt schließt, und die Frage von **Löschen** mit ihm. Nichts darin
öffnet einen Dialog von VFP, außer dem zur Wahl eines Ordners, den Sie mit **Ändern...** öffnen: Die Frage ist ein
kleines Fenster von FoxDock, das niemanden aufhält.

**Ausführen...** Das kleine Fenster `FoxDock - <Name> ausführen` entsteht aus dem Kopf der Abfrage: eine Zeile je
Parameter, mit seinem Typ und einem `*`, wenn er `required` ist (`D` ist ein Datum im `SET DATE` der IDE, `T` Datum
und Uhrzeit, `L` ein Kontrollkästchen, `list` ein Text mit Kommas, der Rest ein Text; der `default` steht schon drin);
**Sortierung**, unter den Spalten ihrer Zeile `-- sort:`; ein Feld je Bezeichner, mit dem zuletzt gegebenen Wert (er
steht in `config.json`, `options.queries.idents`; einer, der nicht zu seiner Form passt, etwa `0X` bei `digits 2`, sagt es,
wird nicht gespeichert, und nichts wird ausgeführt); und **Grenze**, höchstens so viele Zeilen (das `queryLimit` von
**Daten > Verbindungen**, 100, wenn es fehlt; `0`, keine Grenze). **Ausführen**:
- eine `read`-Abfrage legt ihre Zeilen in den Cursor `q_<Name>` der Datensitzung 1 (`q_customers_by_city`) und zeigt
  sie in einem schreibgeschützten `BROWSE`, dessen Titel die Abfrage, die Datenbank, die Zeilen und, wenn es mehr
  gab, `die ersten <n>` nennt. Mit einer Spalte und einer Zeile (ein `COUNT(*)`) gibt das kleine Fenster ihren Wert;
- eine `write`-Abfrage fragt vorher, im kleinen Fenster selbst: Die Schaltfläche wird zu **Jetzt ausführen**, und die
  Zeilen ändern sich beim zweiten Klick. Danach sagt das kleine Fenster, wie viele Zeilen sich geändert haben;
- was FoxQuery ablehnt (ein leerer `required`-Parameter, eine Zahl, die keine ist, eine Abfrage der anderen Art),
  steht im kleinen Fenster mit seinem Code (`param_missing`), und nichts wird ausgeführt;
- was fehlschlägt, sagt, wo es ausgeführt wurde (`Nicht ausgeführt auf Lokale DBF-Tabellen (vfp): ...`). Auf den
  lokalen DBF-Tabellen führt VFP das SQL so aus, wie es ist: Eine Abfrage für eine andere Datenbank (eckige Klammern,
  `.dbo.`, `CASE WHEN`) gibt einen Fehler von VFP, etwa `error 1300`, und das kleine Fenster sagt zuerst, vor dem Fehler, dass sie
  ihre Verbindung unter **Ausführen auf** braucht.

**Als Objekt** macht aus den Zeilen der letzten Ausführung eine `Collection` mit einem Objekt je Zeile, in einer
`PUBLIC`-Variablen mit dem daneben geschriebenen Namen (`loCustomersByCity`), für das Befehlsfenster. Eine Variable,
die es schon gibt, wird nicht überschrieben.

Um jede Ausführung herum bleibt die IDE, wie sie war: der gewählte Arbeitsbereich, der Satzzeiger jeder in der
Datensitzung 1 geöffneten Tabelle und `SET DELETED`, `ANSI`, `EXACT` und `TABLEPROMPT`. Auf einer Verbindung oder
einem Handle geht die Grenze an den Server (`MaxRecords`), also kommt eine große Tabelle nicht ganz.

**Katalog erstellen...** Das kleine Fenster `FoxDock - Katalog erstellen` kompiliert den Ordner zu einem Katalog
`.fq`, den dein Programm mit `FQ_LOAD("app.fq", "dein Schlüssel")` lädt (FOXQUERY.md, auf Englisch). Es
hat den Ordner (schreibgeschützt); den Namen der `.fq` (`<Projekt>.fq` neben der `.pjx`; ohne offenes Projekt
`queries.fq` im aktuellen Ordner); den Schlüssel, als Punkte geschrieben; **Merken** und **Vergessen**;
**Verschlüsseln**; **Zum Projekt hinzufügen** (gesetzt, wenn ein Projekt offen ist; sonst aus, und das Fenster sagt,
warum); und **Ersetzen**. Eine `.fq`, die es schon gibt, wird erst überschrieben, wenn **Ersetzen** gesetzt ist: Das
Fenster sagt es beim Öffnen. **Erstellen** kompiliert alle `.sql` des Ordners: Eine, die nicht lädt, hält es an, mit
ihrem Code und ihrer Zeile. Bevor es fertig meldet, lädt es die geschriebene `.fq` getrennt, mit demselben Schlüssel:
Dann sagt das Fenster, wie viele Abfragen, wie viele Bytes, wie lange es dauerte, ob sie verschlüsselt ist und mit
welchem Schlüssel, und die Warnungen der Datenbanken, eine pro Zeile mit ihrer Abfrage (`{offset}` auf `vfp`, zum
Beispiel). Ist die `.fq` in einem Editor offen, kann FoxQuery sie nicht schreiben: `catalog_not_written`, und das
Fenster sagt, dass du diesen Editor schließen sollst. Gibt es den Ordner der `.fq` nicht, derselbe Code, und das
Fenster nennt den Ordner: leg ihn an oder wähl eine `.fq` in einem anderen; FoxQuery legt ihn nicht an. **Ordner öffnen** neben dem Namen der `.fq` öffnet ihren Ordner im Windows-Explorer, mit der `.fq` ausgewählt, wenn es
sie schon gibt. Nichts darin öffnet einen Dialog, auch nicht mit `SET SAFETY ON`.

**Der Schlüssel.** Ohne Schlüssel wird die `.fq` mit dem festen Schlüssel von FoxQuery signiert: Eine versehentlich
geänderte `.fq` lädt nicht, und wer FoxQuery kennt, könnte eine andere signieren. Mit deinem Schlüssel kann das
niemand. **Verschlüsseln** verbirgt außerdem die Abfragen und braucht einen Schlüssel. Mit **Merken** hebt FoxDock den
Schlüssel verschlüsselt mit deinem Windows-Konto (DPAPI) in `secrets\queries-<Projekt>.cred` seines Datenordners
auf, wie die Kennwörter von **Daten > Verbindungen**, und das Fenster bringt ihn beim nächsten Mal mit; **Vergessen**
löscht ihn. Es braucht ein offenes Projekt, denn der Schlüssel gehört zum Projekt. Der Schlüssel steht nie in
`config.json`, in `foxdock.log` oder in einer Antwort an den Agenten.

**Die `.fq` im Projekt.** **Zum Projekt hinzufügen** fügt sie als Datei des Projekts hinzu (`Type x`, eingeschlossen).
Dann packt `BUILD EXE` sie in die `.exe`, und `FQ_LOAD("app.fq")` findet sie dort, auch mit der `.exe` allein in einem
anderen Ordner. In der `.exe` gibt `FILE("app.fq")` `.T.`, auch wenn die Datei nicht auf der Platte ist.

| Option | Standard | |
|---|---|---|
| `folder` | `""` | der Ordner der Abfragen; leer: `queries\` neben dem Projekt |
| `catalog.enabled` | `.T.` | `.F.` schaltet das Modul ab: keine Menüpunkte, kein Fenster, keine Tools |
| `run.enabled` | `.T.` | `.F.` schaltet **Ausführen...**, **Ausführen auf >** und ihre zwei Tools ab; das Fenster funktioniert weiter |
| `idents` | `{}` | der letzte Wert jedes Bezeichners, über seinen Namen (`"idents": { "sort": "name" }`); **Ausführen...** schreibt ihn |
| `build.enabled` | `.T.` | `.F.` schaltet **Katalog erstellen...** (Menüpunkt und Schaltfläche) und sein Tool ab |

FoxDock bringt das FoxQuery mit, das es verwendet, die 1.0.0, als `plugins\queries\QueriesFoxQuery.prg`, und sein
Handbuch ist FOXQUERY.md (auf Englisch): die `.sql`-Dateien, die Makros und alle Fehlercodes. FoxDock
legt diese Kopie nie in `SET PROCEDURE` und ruft nie die Funktionen `FQ_*` auf: Ein `foxquery.prg` deines eigenen
Projekts, in einer anderen Version, funktioniert weiter wie vorher.

Für den Agenten gibt es acht Tools: AGENT-TOOLS_DE.md § 10. Mit der
Rolle 10 kann er dir auch eine Abfrage speichern (`ide_queries_save`): FoxQuery prüft die `.sql`, bevor sie geschrieben
wird, und das Fenster zeigt sie sofort.

### Eine Abfrage schreiben

Eine Abfrage ist eine `.sql`-Textdatei im Ordner `queries\`: oben der Kopf, eine Zeile `-- Schlüssel: Wert` für jede
Angabe; darunter das SQL. **Neue Abfrage...** schreibt eine mit ihrem Kopf, und ihre **Hilfe** führt Sie hierher. Ein
Beispiel mit dem, was man jeden Tag braucht:

```sql
-- name: kunden.einer_stadt
-- description: Die Kunden einer Stadt, nach Namen.
-- kind: read
-- param: stadt C required
-- param: seit D
-- sort: name, id
SELECT id, name, geboren
FROM kunden
WHERE stadt = :stadt {if :seit}AND geboren >= :seit{endif}
ORDER BY {sort name}
```

- **`-- param:`** ist ein Parameter: sein Name, sein Typ (`C N I D T L Y M`) und, wenn Sie wollen, `required`, `list`
  oder `default`. Im SQL steht er als `:name`, und sein Wert wird nie in den Text geklebt.
- **`{if :seit} … {endif}`** kommt nur hinein, wenn der Aufruf `seit` mitgibt.
- **`-- sort:`** nennt die Spalten, nach denen sortiert werden kann; `{sort name}` ist die Reihenfolge, wenn der Aufruf
  keine verlangt.
- **Ein Name, den Ihr Programm ins SQL schreibt** (zum Beispiel eine Spalte): `-- ident: sort letters 1-20`
  deklariert ihn, und `{ident sort}` schreibt seinen Wert so, wie er ist, ohne Anführungszeichen:
  `SELECT id, name FROM customers ORDER BY {ident sort}` läuft als `ORDER BY name`, wenn der Wert `name` ist. Die Form
  (`digits`, `letters`, `alnum` oder `ident` und eine Länge `2` oder ein Bereich `1-20`) ist alles, was der Wert sein
  darf, und er hat nur Buchstaben, Ziffern und `_`.
- **Den Wert setzt Ihr Programm, einmal**: `FQ_SET("sort", "name")` beim Start, für alle Abfragen, die ihn verwenden,
  nie in einem Aufruf (die Reihenfolge, die jeder Aufruf wählt, ist `{sort}`). In FoxDock hat **Ausführen...** ein
  Feld für jeden Bezeichner und merkt sich den letzten Wert.

Der Rest (die Makros jeder Datenbank, die Abschnitte `-- engine:`, alle Fehlercodes) steht in
FOXQUERY.md, auf Englisch.

## Über dieses Handbuch

Dieser Text ist der Abschnitt über `queries` aus dem Plugin-Handbuch von FoxDock. Die Verweise auf andere Abschnitte (§) und auf FOXQUERY und AGENT-TOOLS zeigen auf die Dokumente, die FoxDock in seinem Ordner `docs` installiert.

## Lizenz

MIT. Siehe [LICENSE](LICENSE).
