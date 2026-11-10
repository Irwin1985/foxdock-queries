*==================================================================
* QueriesTools.prg: las tools del paquete «queries» para el agente. Las
* cuatro que leen, con cualquier rol:
*
*   ide_queries_list    las consultas de la carpeta, con su cabecera, y los
*                       errores de carga
*   ide_queries_get     el texto de un .sql y su cabecera leída
*   ide_queries_check   la carpeta y CheckEngine(engine): errores y avisos
*   ide_queries_sql     el texto resuelto para un motor, sin ejecutar
*
* y las dos del módulo run:
*
*   ide_queries_run       una read por nombre sobre dbf, una conexión de data
*                         (agentCanRead) o handle:<n>; cualquier rol
*   ide_queries_execute   una write por nombre (rol 10; en una conexión,
*                         allowWrite y CheckWrite con wholeTable)
*
* y la del módulo build:
*
*   ide_queries_build     el .fq del proyecto con la clave recordada (rol 10);
*                         la clave no entra ni sale por la tool
*
* y ide_queries_save: un .sql en CP1252, después de que
* FoxQuery lo cargue limpio (CheckFile de la copia); no pisa sin overwrite (rol 10).
*
* Heredan de IdeTool (plugins\foxagent\IdeTools.prg). El agente nunca manda
* SQL: solo el nombre de una consulta. Los errores van con el código de
* FoxQuery tal cual (ErrCode). Una tool del módulo apagado no existe: el
* módulo no la añade.
*==================================================================

#DEFINE QT_NO_HOST "FoxDock is not mounted (after CLEAR ALL it sleeps until a FoxDock menu bar or key is pressed)"

DEFINE CLASS IdeQueriesTool AS IdeTool
	cParamsWhy = ""

	*-- El código, una sola vez. El motivo de FoxQuery ya lo trae delante
	*-- («catalog_key_required: an encrypted...»): el error de la tool es
	*-- «CATALOG_KEY_REQUIRED: an encrypted...», con el criterio de WithCode de build.
	FUNCTION ErrCode(tcCode, tcMessage)
		RETURN DODEFAULT(tcCode, THIS.OneWhy(tcCode, tcMessage))
	ENDFUNC

	*-- El motivo sin el código, si lo trae: delante («código: motivo») o en medio, como FoxQuery dice un error de
	*-- carga («fichero(línea): código: motivo»).
	PROCEDURE OneWhy
		LPARAMETERS tcCode, tcWhy
		LOCAL lcCode, lcWhy, lnAt
		lcCode = TRANSFORM(tcCode)
		lcWhy = TRANSFORM(tcWhy)
		lnAt = IIF(EMPTY(lcCode), 0, ATC(lcCode + ": ", lcWhy))
		IF lnAt > 0
			lcWhy = LEFT(lcWhy, lnAt - 1) + SUBSTR(lcWhy, lnAt + LEN(lcCode) + 2)
		ENDIF
		RETURN lcWhy
	ENDPROC

	*-- Una negativa de run, también en foxdock.log (como las de
	*-- ide_data_db_execute): el código de FoxQuery o de data y el motivo.
	PROCEDURE Refused
		LPARAMETERS tcCode, tcWhy
		LOCAL loH
		loH = THIS.Host()
		IF !ISNULL(loH)
			loH.LogWarn("queries: the agent was refused " + THIS.ToolName + ": " + TRANSFORM(tcCode) + ": " + THIS.OneWhy(tcCode, tcWhy))
		ENDIF
		RETURN THIS.ErrCode(tcCode, tcWhy)
	ENDPROC
	PROCEDURE Module
		LOCAL loP
		IF ISNULL(THIS.Host())
			RETURN .NULL.
		ENDIF
		loP = _screen.oFoxDock.PluginById("queries")
		IF ISNULL(loP)
			RETURN .NULL.
		ENDIF
		RETURN loP.Module("catalog")
	ENDPROC

	PROCEDURE NotThere
		IF ISNULL(THIS.Host())
			RETURN THIS.Err(QT_NO_HOST)
		ENDIF
		RETURN THIS.Err("The queries package, or its module 'catalog', is not loaded in this IDE (FoxDock > Plugins, " + ;
			"and options.queries.catalog.enabled in config.json).")
	ENDPROC

	*-- La carpeta leída, o el error (folder_not_found) con la carpeta.
	PROCEDURE NoFolder
		LPARAMETERS toR
		IF VARTYPE(toR) # "O"
			RETURN THIS.Err("The FoxQuery query store of the queries package could not be made: the log of FoxDock says why.")
		ENDIF
		RETURN THIS.ErrCode("folder_not_found", "The folder of the queries does not exist: " + toR.cFolder + ;
			" (queries\ next to the .pjx of the active project, or of the current folder; options.queries.folder in " + ;
			"config.json changes it). FoxDock > Queries > New query... makes it with the first query.")
	ENDPROC

	*-- Una consulta cargada (un QueryDef) como objeto JSON: name, kind,
	*-- description, params, sort, idents, variants.
	PROCEDURE DefObject
		LPARAMETERS toJ, toS, toD
		LOCAL loO, loA, loP, loX, lnI, loI
		loO = toJ.MakeObject()
		toJ.Put(loO, "name", toD.cName)
		toJ.Put(loO, "kind", toD.cKind)
		toJ.Put(loO, "description", toD.cDescription)
		loA = toJ.MakeArray()
		FOR EACH loP IN toD.oParams FOXOBJECT
			loX = toJ.MakeObject()
			toJ.Put(loX, "name", loP.cName)
			toJ.Put(loX, "type", loP.cType)
			toJ.Put(loX, "required", loP.lRequired)
			toJ.Put(loX, "list", loP.lList)
			IF loP.lHasDefault
				toJ.Put(loX, "default", TRANSFORM(loP.vDefault))
			ENDIF
			loA.Add(loX)
		ENDFOR
		toJ.Put(loO, "params", loA)
		loA = toJ.MakeArray()
		FOR lnI = 1 TO toD.nSort
			loA.Add(toD.aSortList[lnI])
		ENDFOR
		toJ.Put(loO, "sort", loA)
		loA = toJ.MakeArray()
		FOR EACH loI IN toD.oIdents FOXOBJECT
			loX = toJ.MakeObject()
			toJ.Put(loX, "name", loI.cName)
			toJ.Put(loX, "form", toS.IdentForm(loI))
			loA.Add(loX)
		ENDFOR
		toJ.Put(loO, "idents", loA)
		loA = toJ.MakeArray()
		FOR lnI = 1 TO toD.oVariants.Count
			loA.Add(toD.oVariants.GetKey(lnI))
		ENDFOR
		toJ.Put(loO, "variants", loA)
		RETURN loO
	ENDPROC

	*-- El módulo build, o .NULL.
	PROCEDURE BuildModule
		LOCAL loP
		IF ISNULL(THIS.Host())
			RETURN .NULL.
		ENDIF
		loP = _screen.oFoxDock.PluginById("queries")
		IF ISNULL(loP)
			RETURN .NULL.
		ENDIF
		RETURN loP.Module("build")
	ENDPROC

	*-- El módulo run, o .NULL.
	PROCEDURE RunModule
		LOCAL loP
		IF ISNULL(THIS.Host())
			RETURN .NULL.
		ENDIF
		loP = _screen.oFoxDock.PluginById("queries")
		IF ISNULL(loP)
			RETURN .NULL.
		ENDIF
		RETURN loP.Module("run")
	ENDPROC

	*-- params (un objeto JSON escrito como texto) y sort, a un Empty por nombre.
	*-- .NULL. con la negativa en cParamsWhy.
	PROCEDURE ParamsFrom
		LPARAMETERS toContext
		LOCAL lcParams, loJ, loC, loPar, lnI, loErr, lcWhy, lcSort
		lcParams = THIS.PText(toContext, "params")
		loPar = CREATEOBJECT("Empty")
		lcWhy = ""
		IF !EMPTY(lcParams)
			loJ = THIS.J()
			loC = loJ.Parse(lcParams)
			IF loC.Count = 0
				THIS.cParamsWhy = "params is not a JSON object of parameters by name: " + lcParams
				RETURN .NULL.
			ENDIF
			FOR lnI = 1 TO loC.Count
				TRY
					ADDPROPERTY(loPar, loC.GetKey(lnI), loC.Item(lnI))
				CATCH TO loErr
					lcWhy = "'" + loC.GetKey(lnI) + "' is not a parameter name"
				ENDTRY
				IF !EMPTY(lcWhy)
					THIS.cParamsWhy = lcWhy + " (params: " + lcParams + ")"
					RETURN .NULL.
				ENDIF
			ENDFOR
		ENDIF
		lcSort = THIS.PText(toContext, "sort")
		IF !EMPTY(lcSort)
			ADDPROPERTY(loPar, "sort", lcSort)
		ENDIF
		RETURN loPar
	ENDPROC

	*-- Errores o avisos (cFile, nLine, cCode, cText) como array JSON.
	PROCEDURE Issues
		LPARAMETERS toJ, toC
		LOCAL loA, loI, loX
		loA = toJ.MakeArray()
		FOR EACH loI IN toC FOXOBJECT
			loX = toJ.MakeObject()
			toJ.Put(loX, "file", loI.cFile)
			toJ.Put(loX, "line", loI.nLine)
			toJ.Put(loX, "code", loI.cCode)
			toJ.Put(loX, "message", THIS.OneWhy(loI.cCode, loI.cText))
			loA.Add(loX)
		ENDFOR
		RETURN loA
	ENDPROC
ENDDEFINE


DEFINE CLASS IdeQueriesListTool AS IdeQueriesTool
	ToolName = "ide_queries_list"
	ToolDescription = "The FoxQuery queries of this Visual FoxPro IDE (FoxDock > Queries): the .sql files of the folder of " + ;
		"the project (queries\ next to the .pjx of the active project, or of the current folder; options.queries.folder " + ;
		"changes it), or of 'folder'. For each query that loads: name, kind (read or write), description, params (name, " + ;
		"type, required, list, default), sort, idents (name, form) and variants (the engines with an -- engine: section). " + ;
		"The files that do not load go in 'errors' (file, line, code, message: the code is FoxQuery's). Reads only."

	FUNCTION DefineParameters()
		THIS.AddParam("folder", "string", "A folder of .sql files to read instead of the one of the project; it is read " + ;
			"apart and does not change what FoxDock > Queries shows.", .F.)
	ENDFUNC

	FUNCTION Run(toContext)
		LOCAL loM, loS, loR, lcFolder, loJ, loD, loA, loE
		loM = THIS.Module()
		IF ISNULL(loM)
			RETURN THIS.NotThere()
		ENDIF
		lcFolder = THIS.PText(toContext, "folder")
		IF EMPTY(lcFolder)
			=loM.EnsureLoaded()
			loR = loM.oResult
			loS = loM.Store()
		ELSE
			loS = loM.NewStore()
			loR = loM.Scan(ADDBS(FULLPATH(lcFolder)), loS, .F.)
		ENDIF
		IF ISNULL(loR) OR !loR.lExists
			IF ISNULL(loR)
				loR = CREATEOBJECT("Empty")
				ADDPROPERTY(loR, "cFolder", loM.Folder())
			ENDIF
			RETURN THIS.NoFolder(loR)
		ENDIF
		loJ = THIS.J()
		loD = loJ.MakeObject()
		loA = loJ.MakeArray()
		FOR EACH loE IN loR.oEntries FOXOBJECT
			IF !loE.lBroken
				loA.Add(THIS.DefObject(loJ, loS, loE.oDef))
			ENDIF
		ENDFOR
		loJ.Put(loD, "folder", loR.cFolder)
		loJ.Put(loD, "files", loR.nFiles)
		loJ.Put(loD, "count", loA.Count)
		loJ.Put(loD, "queries", loA)
		loJ.Put(loD, "errors", THIS.Issues(loJ, loR.oErrors))
		RETURN THIS.Done(loD)
	ENDFUNC
ENDDEFINE


DEFINE CLASS IdeQueriesGetTool AS IdeQueriesTool
	ToolName = "ide_queries_get"
	ToolDescription = "One FoxQuery query of the folder of the project (FoxDock > Queries), by its name: its header " + ;
		"as FoxQuery read it (name, kind, description, params, sort, idents, variants), its file and the text of the " + ;
		".sql as it is on disk. A file that does not load says so (broken, error). Reads only."

	FUNCTION DefineParameters()
		THIS.AddParam("name", "string", "The name of the query, as ide_queries_list gives it (customers.by_city).", .T.)
	ENDFUNC

	FUNCTION Run(toContext)
		LOCAL loM, loE, loJ, loD, lcName
		loM = THIS.Module()
		IF ISNULL(loM)
			RETURN THIS.NotThere()
		ENDIF
		IF !loM.EnsureLoaded()
			RETURN THIS.NoFolder(loM.oResult)
		ENDIF
		lcName = THIS.PText(toContext, "name")
		loE = loM.Entry(lcName)
		IF ISNULL(loE)
			RETURN THIS.ErrCode("query_not_found", "There is no query called " + lcName + " in " + loM.cFolder + ".")
		ENDIF
		loJ = THIS.J()
		IF loE.lBroken
			loD = loJ.MakeObject()
			loJ.Put(loD, "name", loE.cName)
			loJ.Put(loD, "broken", .T.)
			loJ.Put(loD, "error", loE.cError)
		ELSE
			loD = THIS.DefObject(loJ, loM.Store(), loE.oDef)
			loJ.Put(loD, "broken", .F.)
		ENDIF
		loJ.Put(loD, "file", loE.cFile)
		loJ.Put(loD, "text", FILETOSTR(loE.cFile))
		RETURN THIS.Done(loD)
	ENDFUNC
ENDDEFINE


DEFINE CLASS IdeQueriesCheckTool AS IdeQueriesTool
	ToolName = "ide_queries_check"
	ToolDescription = "Reads the folder of the queries of the project again and checks them for an engine, as FoxDock > " + ;
		"Queries > Check does: the files that do not load (errors) and what that engine cannot run (warnings), each with " + ;
		"file, line, code and message. Engines: vfp, sqlserver, mysql, mariadb, postgresql, firebird, sqlite. Reads only."

	FUNCTION DefineParameters()
		THIS.AddParam("engine", "string", "The engine; vfp if left out.", .F.)
	ENDFUNC

	FUNCTION Run(toContext)
		LOCAL loM, loS, loR, lcEngine, loJ, loD, loW, lnW, lnN
		loM = THIS.Module()
		IF ISNULL(loM)
			RETURN THIS.NotThere()
		ENDIF
		IF !loM.Load(.T.)
			RETURN THIS.NoFolder(loM.oResult)
		ENDIF
		loR = loM.oResult
		loS = loM.Store()
		lcEngine = LOWER(EVL(THIS.PText(toContext, "engine"), "vfp"))
		loW = CREATEOBJECT("Collection")
		IF lcEngine == loM.cEngine
			loW = loR.oWarnings
		ELSE
			lnN = loS.CheckEngine(lcEngine)
			IF lnN < 0
				RETURN THIS.ErrCode(loS.cLastErrorCode, loS.cLastError)
			ENDIF
			FOR lnW = 1 TO loS.nWarnings
				loM.AddIssue(loW, loR.cFolder + JUSTFNAME(loS.aWarnings[lnW, 2]), loS.aWarnings[lnW, 3], loS.aWarnings[lnW, 1], ;
					loS.aWarnings[lnW, 4])
			ENDFOR
			=loS.CheckEngine(loM.cEngine)
		ENDIF
		loJ = THIS.J()
		loD = loJ.MakeObject()
		loJ.Put(loD, "folder", loR.cFolder)
		loJ.Put(loD, "engine", lcEngine)
		loJ.Put(loD, "files", loR.nFiles)
		loJ.Put(loD, "queries", loR.nQueries)
		loJ.Put(loD, "errors", THIS.Issues(loJ, loR.oErrors))
		loJ.Put(loD, "warnings", THIS.Issues(loJ, loW))
		RETURN THIS.Done(loD)
	ENDFUNC
ENDDEFINE


DEFINE CLASS IdeQueriesSqlTool AS IdeQueriesTool
	ToolName = "ide_queries_sql"
	ToolDescription = "The SQL text of one FoxQuery query of the project for an engine, resolved by FoxQuery and NOT run: " + ;
		"the -- engine: section if it has one, the macros of that engine, and the :name parameters as they are. With " + ;
		"'params', the {if} blocks, the {sort} and the lists come resolved with those values. Reads only."

	FUNCTION DefineParameters()
		THIS.AddParam("name", "string", "The name of the query.", .T.)
		THIS.AddParam("engine", "string", "vfp, sqlserver, mysql, mariadb, postgresql, firebird or sqlite; vfp if left out.", .F.)
		THIS.AddParam("params", "string", "Optional: a JSON object with the parameters by name, as text " + ;
			"({" + ["] + "city" + ["] + ":" + ["] + "Oslo" + ["] + "}).", .F.)
	ENDFUNC

	FUNCTION Run(toContext)
		LOCAL loM, loS, lcName, lcEngine, lcParams, loPar, loC, lnI, lvSql, loJ, loD, loErr, lcWhy
		lcWhy = ""
		loM = THIS.Module()
		IF ISNULL(loM)
			RETURN THIS.NotThere()
		ENDIF
		IF !loM.EnsureLoaded()
			RETURN THIS.NoFolder(loM.oResult)
		ENDIF
		loS = loM.Store()
		lcName = THIS.PText(toContext, "name")
		lcEngine = LOWER(EVL(THIS.PText(toContext, "engine"), "vfp"))
		lcParams = THIS.PText(toContext, "params")
		IF EMPTY(lcParams)
			lvSql = loS.Sql(lcName, lcEngine)
		ELSE
			loJ = THIS.J()
			loC = loJ.Parse(lcParams)
			*-- Params() es un objeto de FoxNone, o .NULL. sin FoxNone en la máquina:
			*-- entonces un Empty, que FoxQuery lee igual (sus propiedades).
			loPar = loS.Params()
			IF VARTYPE(loPar) # "O"
				loPar = CREATEOBJECT("Empty")
			ENDIF
			IF loC.Count = 0
				RETURN THIS.Err("params is not a JSON object of parameters by name: " + lcParams)
			ENDIF
			FOR lnI = 1 TO loC.Count
				TRY
					ADDPROPERTY(loPar, loC.GetKey(lnI), loC.Item(lnI))
				CATCH TO loErr
					lcWhy = "'" + loC.GetKey(lnI) + "' is not a parameter name"
				ENDTRY
				IF !EMPTY(lcWhy)
					RETURN THIS.ErrCode("param_name_invalid", lcWhy + " (params: " + lcParams + ")")
				ENDIF
			ENDFOR
			lvSql = loS.Sql(lcName, lcEngine, "", loPar)
		ENDIF
		IF VARTYPE(lvSql) # "C"
			RETURN THIS.ErrCode(loS.cLastErrorCode, loS.cLastError)
		ENDIF
		loJ = THIS.J()
		loD = loJ.MakeObject()
		loJ.Put(loD, "name", lcName)
		loJ.Put(loD, "engine", lcEngine)
		loJ.Put(loD, "sql", lvSql)
		RETURN THIS.Done(loD)
	ENDFUNC
ENDDEFINE


DEFINE CLASS IdeQueriesRunTool AS IdeQueriesTool
	ToolName = "ide_queries_run"
	ToolDescription = "Runs one READ query of the project (FoxDock > Queries) by its name, with its parameters, and returns " + ;
		"its rows as JSON, as ide_data_db_query does (fields in lower case, text without its padding, dates in ISO 8601, " + ;
		"null). 'on' says where: dbf (the DBF tables of data session 1 of the IDE), the id of a connection of FoxDock > " + ;
		"Data > Connections (only with agentCanRead true), or handle:<n> (an ODBC handle open in the IDE). The agent never " + ;
		"sends SQL: FoxQuery resolves the text, and a read that writes or locks is refused before it reaches the engine. " + ;
		"Returns name, on, engine, rowCount, returned, truncated and rows. The area, the record pointers and the settings " + ;
		"of the IDE stay as they were."

	FUNCTION DefineParameters()
		THIS.AddParam("name", "string", "The name of a read query (ide_queries_list gives them).", .T.)
		THIS.AddParam("on", "string", "dbf, the id of a connection (ide_data_db_connections), or handle:<n>; dbf if left out.", .F.)
		THIS.AddParam("params", "string", "Optional: a JSON object with the parameters by name, as text.", .F.)
		THIS.AddParam("sort", "string", "Optional: the order, among the columns of its -- sort: line (name DESC).", .F.)
		THIS.AddParam("maxRows", "number", "How many rows at most, from 1 to 1000; 1000 if left out.", .F.)
	ENDFUNC

	FUNCTION Run(toContext)
		LOCAL loM, loPar, lnMax, lcName, lcRows, loJ, loD, lcMeta
		loM = THIS.RunModule()
		IF ISNULL(loM)
			RETURN THIS.Err("The queries package, or its module 'run', is not loaded in this IDE (FoxDock > Plugins, " + ;
				"and options.queries.run.enabled in config.json).")
		ENDIF
		loPar = THIS.ParamsFrom(toContext)
		IF ISNULL(loPar)
			RETURN THIS.ErrCode("param_name_invalid", THIS.cParamsWhy)
		ENDIF
		lnMax = INT(THIS.PNum(toContext, "maxRows"))
		lnMax = IIF(lnMax <= 0 OR lnMax > 1000, 1000, lnMax)
		lcName = THIS.PText(toContext, "name")
		IF !loM.Exec(lcName, EVL(THIS.PText(toContext, "on"), "dbf"), loPar, lnMax, "run", .F., .T.)
			RETURN THIS.Refused(loM.cLastCode, loM.cLastError)
		ENDIF
		lcRows = loM.RowsJson(loM.cLastCursor, lnMax)
		loM.CloseLast()
		loJ = THIS.J()
		loD = loJ.MakeObject()
		loJ.Put(loD, "name", lcName)
		loJ.Put(loD, "on", loM.NormalKey(EVL(THIS.PText(toContext, "on"), "dbf")))
		loJ.Put(loD, "engine", loM.cLastEngine)
		loJ.Put(loD, "rowCount", loM.nLastTotal)
		loJ.Put(loD, "returned", loM.nLastRows)
		loJ.Put(loD, "truncated", loM.lLastTruncated)
		lcMeta = loJ.Stringify(loD)
		RETURN THIS.Ok(LEFT(lcMeta, LEN(lcMeta) - 1) + [,"rows":] + lcRows + "}")
	ENDFUNC
ENDDEFINE


DEFINE CLASS IdeQueriesExecuteTool AS IdeQueriesTool
	ToolName = "ide_queries_execute"
	lActsOnIde = .T.
	ToolDescription = "Runs one WRITE query of the project (FoxDock > Queries) by its name, with its parameters, and " + ;
		"returns the rows it changed. 'on' as in ide_queries_run: dbf, the id of a connection (only with agentCanRead " + ;
		"and allowWrite true), or handle:<n>. The agent never sends SQL: FoxQuery resolves the text, and it goes one " + ;
		"statement at a time; an UPDATE or a DELETE without WHERE, a DROP or a TRUNCATE only with wholeTable true. " + ;
		"Returns name, on, engine and rowsAffected."

	FUNCTION DefineParameters()
		THIS.AddParam("name", "string", "The name of a write query.", .T.)
		THIS.AddParam("on", "string", "dbf, the id of a connection, or handle:<n>; dbf if left out.", .F.)
		THIS.AddParam("params", "string", "Optional: a JSON object with the parameters by name, as text.", .F.)
		THIS.AddParam("wholeTable", "boolean", "true to let it change or remove every row of a table.", .F.)
	ENDFUNC

	FUNCTION Run(toContext)
		LOCAL loM, loPar, lcName, loJ, loD
		loM = THIS.RunModule()
		IF ISNULL(loM)
			RETURN THIS.Err("The queries package, or its module 'run', is not loaded in this IDE (FoxDock > Plugins, " + ;
				"and options.queries.run.enabled in config.json).")
		ENDIF
		loPar = THIS.ParamsFrom(toContext)
		IF ISNULL(loPar)
			RETURN THIS.ErrCode("param_name_invalid", THIS.cParamsWhy)
		ENDIF
		lcName = THIS.PText(toContext, "name")
		IF !loM.Exec(lcName, EVL(THIS.PText(toContext, "on"), "dbf"), loPar, 0, "execute", THIS.PBool(toContext, "wholeTable"), .T.)
			RETURN THIS.Refused(loM.cLastCode, loM.cLastError)
		ENDIF
		loJ = THIS.J()
		loD = loJ.MakeObject()
		loJ.Put(loD, "name", lcName)
		loJ.Put(loD, "on", loM.NormalKey(EVL(THIS.PText(toContext, "on"), "dbf")))
		loJ.Put(loD, "engine", loM.cLastEngine)
		loJ.Put(loD, "rowsAffected", loM.nLastAffected)
		_screen.oFoxDock.AgentDid("changed " + TRANSFORM(loM.nLastAffected) + " row(s) with the query " + lcName + " on " + ;
			loM.NormalKey(EVL(THIS.PText(toContext, "on"), "dbf")))
		RETURN THIS.Done(loD)
	ENDFUNC
ENDDEFINE


DEFINE CLASS IdeQueriesBuildTool AS IdeQueriesTool
	ToolName = "ide_queries_build"
	lActsOnIde = .T.
	ToolDescription = "Compiles the queries folder of the project (FoxDock > Queries) into a .fq catalog, as FoxDock > " + ;
		"Queries > Build catalog... does, with the key the programmer remembered for the active project (Remember in " + ;
		"that window). Without a remembered key it compiles with the fixed key of FoxQuery and says so (keyed: false). " + ;
		"The key never goes through this tool, in or out. 'fq' is the <project>.fq next to the .pjx if left out; a .fq " + ;
		"that is there is overwritten, because the agent asked for it. Before it says it is done, it loads the .fq it " + ;
		"wrote. Returns fq, queries, bytes, encrypted, keyed, addedToProject and warnings (what an engine cannot run)."

	FUNCTION DefineParameters()
		THIS.AddParam("fq", "string", "The .fq to write; left out, <project>.fq next to the .pjx of the active project.", .F.)
		THIS.AddParam("encrypt", "boolean", "true to encrypt the queries in the .fq (it needs a remembered key).", .F.)
	ENDFUNC

	FUNCTION Run(toContext)
		LOCAL loM, lcFq, lcKey, llEnc, loJ, loD, loW, lcW
		loM = THIS.BuildModule()
		IF ISNULL(loM)
			RETURN THIS.Err("The queries package, or its module 'build', is not loaded in this IDE (FoxDock > Plugins, " + ;
				"and options.queries.build.enabled in config.json).")
		ENDIF
		lcFq = THIS.PText(toContext, "fq")
		IF EMPTY(lcFq)
			IF EMPTY(loM.ProjectFile())
				RETURN THIS.Refused("no_project", "there is no project open in the IDE, and no fq was given: open the project, or pass fq")
			ENDIF
			lcFq = loM.DefaultFq()
		ENDIF
		lcKey = loM.ReadKey()
		llEnc = THIS.PBool(toContext, "encrypt")
		IF !loM.Build(lcFq, lcKey, llEnc, .T., !EMPTY(loM.ProjectFile()))
			RETURN THIS.Refused(loM.cLastCode, loM.cLastError)
		ENDIF
		lcKey = ""
		loJ = THIS.J()
		loD = loJ.MakeObject()
		loJ.Put(loD, "fq", loM.cLastFq)
		loJ.Put(loD, "queries", loM.nLastQueries)
		loJ.Put(loD, "bytes", loM.nLastBytes)
		loJ.Put(loD, "encrypted", loM.lLastEncrypted)
		loJ.Put(loD, "keyed", loM.lLastKeyed)
		loJ.Put(loD, "addedToProject", loM.cLastAdded == "added")
		loW = loJ.MakeArray()
		FOR EACH lcW IN loM.oLastWarnings
			loW.Add(lcW)
		ENDFOR
		loJ.Put(loD, "warnings", loW)
		_screen.oFoxDock.AgentDid("built " + JUSTFNAME(loM.cLastFq) + " with " + TRANSFORM(loM.nLastQueries) + " queries" + ;
			IIF(loM.lLastKeyed, ", with the remembered key", ", with the fixed key of FoxQuery"))
		RETURN THIS.Done(loD)
	ENDFUNC
ENDDEFINE


DEFINE CLASS IdeQueriesSaveTool AS IdeQueriesTool
	ToolName = "ide_queries_save"
	lActsOnIde = .T.
	ToolDescription = "Writes one query of the project (FoxDock > Queries) as queries\<name>.sql, in the code page of VFP " + ;
		"(CP1252), after FoxQuery loads it clean: 'sql' is the whole file, its header (-- name:, -- description:, -- kind:, " + ;
		"-- param:, -- sort:, -- ident:) and its SQL. The -- name: of the header is what counts, and it has to be 'name' " + ;
		"(HEADER_NAME_MISMATCH if not). With errors nothing is written, and they come back with FoxQuery's code and line. " + ;
		"A .sql that is there is not overwritten without overwrite true (FILE_EXISTS). The Queries window and the list of " + ;
		"ide_queries_list are updated. Returns name, file, kind and replaced."

	FUNCTION DefineParameters()
		THIS.AddParam("name", "string", "The name of the query, which is the name of the file without .sql (customers.by_city). " + ;
			"A new one is a letter or _, then letters, digits, _ or dots (NAME_INVALID if not).", .T.)
		THIS.AddParam("sql", "string", "The whole .sql: the header lines that start with -- and then the SQL.", .T.)
		THIS.AddParam("overwrite", "boolean", "true to replace a .sql that is there.", .F.)
	ENDFUNC

	FUNCTION Run(toContext)
		LOCAL loM, lcName, lcSql, llWas, loJ, loD, loDef, loS
		loM = THIS.Module()
		IF ISNULL(loM)
			RETURN THIS.NotThere()
		ENDIF
		lcName = THIS.PText(toContext, "name")
		lcSql = THIS.Ansi(THIS.PRaw(toContext, "sql"))
		IF EMPTY(lcName) OR EMPTY(lcSql)
			RETURN THIS.Refused("param_missing", "ide_queries_save needs name and sql")
		ENDIF
		llWas = FILE(loM.Folder() + lcName + ".sql")
		IF !loM.SaveQuery(lcName, lcSql, THIS.PBool(toContext, "overwrite"))
			RETURN THIS.Refused(loM.cLastCode, loM.cLastError)
		ENDIF
		loS = loM.Store()
		loDef = IIF(ISNULL(loS), .NULL., loS.Get(lcName))
		loJ = THIS.J()
		loD = loJ.MakeObject()
		loJ.Put(loD, "name", lcName)
		loJ.Put(loD, "file", loM.cLastFile)
		loJ.Put(loD, "kind", IIF(ISNULL(loDef), "", loDef.cKind))
		loJ.Put(loD, "replaced", llWas)
		_screen.oFoxDock.AgentDid(IIF(llWas, "replaced ", "wrote ") + loM.cLastFile)
		RETURN THIS.Done(loD)
	ENDFUNC

	*-- El texto tal cual llegó (sin ALLTRIM: un .sql guarda sus líneas).
	PROTECTED PROCEDURE PRaw
		LPARAMETERS toContext, tcName
		LOCAL luV
		luV = ""
		IF PEMSTATUS(toContext.Parameters, tcName, 5)
			luV = GETPEM(toContext.Parameters, tcName)
		ENDIF
		RETURN IIF(VARTYPE(luV) == "C", luV, "")
	ENDPROC

	*-- En CP1252, con CRLF: el Bridge ya da el texto en la página de códigos del IDE (como a
	*-- las tools de data y de designer); si aun así llega en UTF-8 que va y vuelve, se
	*-- convierte, como lee DataJson.ReadFile un .json. Las líneas, con CRLF, y un CRLF al final.
	PROTECTED PROCEDURE Ansi
		LPARAMETERS tcText
		LOCAL lcT, lcA
		lcT = tcText
		lcA = STRCONV(lcT, 11, CPCURRENT(), 1)
		IF !(lcA == lcT) AND STRCONV(lcA, 9, CPCURRENT(), 1) == lcT
			lcT = lcA
		ENDIF
		lcT = STRTRAN(lcT, CHR(13) + CHR(10), CHR(10))
		lcT = STRTRAN(lcT, CHR(13), CHR(10))
		lcT = STRTRAN(lcT, CHR(10), CHR(13) + CHR(10))
		IF !EMPTY(lcT) AND !(RIGHT(lcT, 2) == CHR(13) + CHR(10))
			lcT = lcT + CHR(13) + CHR(10)
		ENDIF
		RETURN lcT
	ENDPROC
ENDDEFINE
