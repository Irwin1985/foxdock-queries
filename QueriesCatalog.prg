*==================================================================
* QueriesCatalog.prg: el módulo «catalog» del paquete «queries» de FoxDock.
*
*   Queries >  Queries...      la ventana FoxDock - Queries (QueriesForm, abajo)
*              New query...    una ventanita: nombre, read o write, descripción
*              Check           la carpeta cargada y CheckEngine del motor: la
*                              ventana FoxDock - Check (QueriesCheckForm), con
*                              tipo, consulta, línea y código, y el motivo entero
*                              de la elegida; Edit o doble clic, el .sql en esa
*                              línea
*              Reload          vuelve a leer la carpeta
*   tools      ide_queries_list, ide_queries_get, ide_queries_check e
*              ide_queries_sql (leen, cualquier rol), e ide_queries_save
*              (actúa, rol 10), en QueriesTools.prg
*
* LA CARPETA: queries\ junto al .pjx del proyecto activo; sin proyecto,
* queries\ de la carpeta actual; options.queries.folder la cambia (relativa al
* proyecto, o a la carpeta actual sin proyecto; o una ruta entera).
*
* LA CARGA: la primera vez que la ventana, una barra o una tool lo piden,
* nunca al arrancar; con más de 100 .sql, un aviso antes y otro después.
* SIEMPRE LA CARPETA, NO EL .fq: la copia de FoxQuery no enumera lo cargado
* (oQueries es PROTECTED y no hay Names()), así que la lista sale de la
* cabecera «-- name:» de cada .sql y cada consulta se pide con Get(name).
*
* UN .sql QUE NO CARGA: LoadFolder es todo o nada. Si falla, cada fichero se
* comprueba con CheckFile de la copia en un almacén aparte, para saber su
* error, y los buenos se cargan uno a uno con LoadFile; la lista enseña los
* rotos con su fichero.
*
* EDIT: oHost.Editor.Open(file, line); al cerrarse ESE editor (el wh que
* dio el editor que se acaba de abrir, nunca el nombre: llega sin ruta), ese
* fichero se vuelve a leer (ReloadFile). Guardar sin cerrar no da ninguna
* señal.
*
* FoxQuery, por las clases de la copia del paquete (QueriesPlugin.Store() y
* NEWOBJECT con CodeFile("lib\foxquery\foxquery.prg")); nunca FQ_* ni SET PROCEDURE a
* ella. Ningún diálogo: lo que hay que decir va a la ventana, al aviso y al
* log.
*==================================================================

#DEFINE CRLF CHR(13) + CHR(10)
*-- Los motores de FoxQuery, en su orden (FQ_ENGINE_ORDER de la copia, que
*-- no los publica).
#DEFINE QC_ENGINES "vfp,sqlserver,mysql,mariadb,postgresql,firebird,sqlite"
#DEFINE QC_MANY 100
*-- SHFileOperation a la Papelera de reciclaje, sin nada en pantalla: FOF_SILENT (0x4),
*-- FOF_NOCONFIRMATION (0x10), FOF_ALLOWUNDO (0x40) y FOF_NOERRORUI (0x400).
#DEFINE QC_FOF_RECYCLE 1108

DEFINE CLASS QueriesCatalog AS Custom
	cId = "catalog"
	oHost = .NULL.
	oForm = .NULL.         && la ventana FoxDock - Queries, una sola
	oNewForm = .NULL.      && la ventanita de New query...
	oOpened = .NULL.       && los editores que abrió el paquete: wh -> fichero
	oResult = .NULL.       && lo último que se leyó de la carpeta (Scan)
	oCheckForm = .NULL.    && la ventana de Check
	oChecks = .NULL.       && lo último de Check: cFile, nLine, cCode, cText, cWhat y cQuery
	oDeleteForm = .NULL.   && la pregunta de Delete
	cFolder = ""           && la carpeta cargada
	lLoaded = .F.
	cProjectDir = ""       && si no está vacío, la carpeta del «proyecto» (los tests)
	cClosing = ""          && el proyecto que se está cerrando: ya no cuenta
	lShow = .T.            && .F.: ni ventanas, ni BROWSE, ni editor (los casos)
	cEngine = "vfp"        && el motor de Run on; sin el módulo run, vfp
	cPick = ""             && lo que «elige» Change... sin enseñar GETDIR (los casos, lShow = .F.)
	cCfgStamp = ""         && tamaño, fecha y hora de config.json la última vez que se releyó la carpeta
	cLastError = ""
	cLastCode = ""
	cLastSaid = ""         && lo último que dijo New query... o Check
	cLastSql = ""          && el texto de SQL for engine
	cLastSqlFile = ""
	cLastCheckCode = ""    && el código del último CheckText ("" si cargó limpio)
	nLastCheckLine = 0
	oLastCheck = .NULL.    && sus errores (AddIssue)
	cLastFile = ""         && el último .sql que escribió SaveQuery
	cLastEdit = ""         && fichero|línea del último Edit (los casos, sin editor)
	nLoadMs = 0

	PROCEDURE Init
		LPARAMETERS toHost
		This.oHost = toHost
		This.oOpened = CREATEOBJECT("Collection")
	ENDPROC

	PROCEDURE Destroy
		This.CloseAll()
	ENDPROC

	*-- Al apagar el módulo, al cerrar el proyecto o al desmontar FoxDock.
	PROCEDURE CloseAll
		LOCAL loErr
		TRY
			IF VARTYPE(This.oForm) == "O"
				This.oForm.oModule = .NULL.
				This.oForm.Release()
			ENDIF
			IF VARTYPE(This.oNewForm) == "O"
				This.oNewForm.oModule = .NULL.
				This.oNewForm.Release()
			ENDIF
			IF VARTYPE(This.oCheckForm) == "O"
				This.oCheckForm.oModule = .NULL.
				This.oCheckForm.Release()
			ENDIF
			IF VARTYPE(This.oDeleteForm) == "O"
				This.oDeleteForm.oModule = .NULL.
				This.oDeleteForm.Release()
			ENDIF
		CATCH TO loErr
		ENDTRY
		This.oForm = .NULL.
		This.oNewForm = .NULL.
		This.oCheckForm = .NULL.
		This.oDeleteForm = .NULL.
	ENDPROC

	PROCEDURE Plugin
		RETURN This.oHost.PluginById("queries")
	ENDPROC

	PROCEDURE T
		LPARAMETERS tcKey, tv1, tv2, tv3, tv4
		RETURN This.oHost.Translate(tcKey, tv1, tv2, tv3, tv4)
	ENDPROC

	PROCEDURE E
		LPARAMETERS tcKey, tv1, tv2, tv3, tv4
		RETURN This.oHost.TranslateEn(tcKey, tv1, tv2, tv3, tv4)
	ENDPROC

	*-- El almacén del paquete (QueriesPlugin.Store, por NEWOBJECT).
	PROCEDURE Store
		LOCAL loP
		loP = This.Plugin()
		RETURN IIF(ISNULL(loP), .NULL., loP.Store())
	ENDPROC

	*-- Un almacén nuevo de la copia, aparte del del paquete.
	PROCEDURE NewStore
		LOCAL loP
		loP = This.Plugin()
		RETURN NEWOBJECT("QueryStore", loP.CodeFile("lib\foxquery\foxquery.prg"))
	ENDPROC

	*-- Sus barras, por trozos (el paquete rellena el submenú con FillWith y
	*-- pone las de run y build en medio): «top», Queries... y New query...,
	*-- «check», Check, y «reload», Reload.
	PROCEDURE FillMenuPart
		LPARAMETERS tcPopup, tnBar, tcPart
		LOCAL loP
		loP = This.Plugin()
		DO CASE
			CASE tcPart == "top"
				tnBar = loP.DefineBar(tcPopup, tnBar + 1, This.T("queries.bar.window"), "OpenWindow", "", This.T("queries.bar.window.message"))
				tnBar = loP.DefineBar(tcPopup, tnBar + 1, This.T("queries.bar.new"), "NewQuery", "", This.T("queries.bar.new.message"))
			CASE tcPart == "check"
				tnBar = loP.DefineBar(tcPopup, tnBar + 1, This.T("queries.bar.check"), "CheckBar", "", This.T("queries.bar.check.message"))
			CASE tcPart == "reload"
				tnBar = loP.DefineBar(tcPopup, tnBar + 1, This.T("queries.bar.reload"), "ReloadBar", "", This.T("queries.bar.reload.message"))
		ENDCASE
		RETURN tnBar
	ENDPROC

	*-- El módulo build, o .NULL. (apagado).
	PROCEDURE BuildModule
		LOCAL loP
		loP = This.Plugin()
		RETURN IIF(ISNULL(loP), .NULL., loP.Module("build"))
	ENDPROC

	*-- El módulo run, o .NULL. (apagado).
	PROCEDURE RunModule
		LOCAL loP
		loP = This.Plugin()
		RETURN IIF(ISNULL(loP), .NULL., loP.Module("run"))
	ENDPROC

	*-- Las tools del módulo (QueriesTools.prg, que el paquete pone en SET PROCEDURE).
	PROCEDURE GetAgentTools
		LPARAMETERS toTools
		toTools.Add(CREATEOBJECT("IdeQueriesListTool"))
		toTools.Add(CREATEOBJECT("IdeQueriesGetTool"))
		toTools.Add(CREATEOBJECT("IdeQueriesCheckTool"))
		toTools.Add(CREATEOBJECT("IdeQueriesSqlTool"))
		toTools.Add(CREATEOBJECT("IdeQueriesSaveTool"))
		RETURN 5
	ENDPROC

	*--------------------------------------------------------------
	* La carpeta.
	*--------------------------------------------------------------
	PROCEDURE ProjectDir
		IF !EMPTY(This.cProjectDir)
			RETURN ADDBS(This.cProjectDir)
		ENDIF
		IF _VFP.Projects.Count > 0
			IF !(UPPER(_VFP.ActiveProject.Name) == UPPER(This.cClosing))
				RETURN ADDBS(JUSTPATH(_VFP.ActiveProject.Name))
			ENDIF
		ENDIF
		RETURN ""
	ENDPROC

	*-- VFP 9 y VFPA comparten config.json, pero cada uno lo tiene en memoria desde que
	*-- arrancó, y Cambiar... en uno no llegaría al otro ni con Recargar. options.queries.folder
	*-- se relee del fichero cuando este cambia (tamaño, fecha y hora), y siempre con tlAlways
	*-- (Recargar). Solo esa opción.
	PROCEDURE RereadFolder
		LPARAMETERS tlAlways
		LOCAL loO, lcStamp
		loO = This.oHost.Options
		lcStamp = loO.FileStamp()
		IF tlAlways OR !(lcStamp == This.cCfgStamp)
			This.cCfgStamp = lcStamp
			=loO.Reread("queries", "folder")
		ENDIF
	ENDPROC

	PROCEDURE Folder
		LOCAL lcOpt, lcBase
		This.RereadFolder(.F.)
		lcOpt = ALLTRIM(TRANSFORM(This.oHost.Options.Get("queries", "folder", "")))
		lcBase = This.ProjectDir()
		IF EMPTY(lcBase)
			lcBase = ADDBS(SET("DEFAULT") + CURDIR())
		ENDIF
		DO CASE
			CASE EMPTY(lcOpt)
				RETURN lcBase + "queries\"
			CASE ":" $ lcOpt OR LEFT(lcOpt, 2) == "\\"
				RETURN ADDBS(lcOpt)
		ENDCASE
		RETURN ADDBS(lcBase + lcOpt)
	ENDPROC

	*--------------------------------------------------------------
	* La carga. Load: la carpeta en el almacén del paquete, la primera vez
	* o con tlForce. Devuelve si la carpeta existe y se leyó.
	*--------------------------------------------------------------
	PROCEDURE Load
		LPARAMETERS tlForce
		LOCAL lcFolder, loS, loR, lnT0
		IF tlForce
			This.RereadFolder(.T.)
		ENDIF
		lcFolder = This.Folder()
		IF This.lLoaded AND !tlForce AND UPPER(lcFolder) == UPPER(This.cFolder)
			RETURN .T.
		ENDIF
		loS = This.Store()
		IF ISNULL(loS)
			This.cLastError = "the FoxQuery query store could not be made (the log says why)"
			This.cLastCode = "store_failed"
			RETURN .F.
		ENDIF
		lnT0 = SECONDS()
		loR = This.Scan(lcFolder, loS, .T.)
		This.nLoadMs = INT((SECONDS() - lnT0) * 1000)
		This.oResult = loR
		This.cFolder = lcFolder
		This.lLoaded = loR.lExists
		IF loR.lExists
			This.oHost.Log("queries: " + lcFolder + " read: " + TRANSFORM(loR.nFiles) + " .sql, " + TRANSFORM(loR.nQueries) + ;
				" loaded, " + TRANSFORM(loR.oErrors.Count) + " error(s), " + TRANSFORM(loR.oWarnings.Count) + " warning(s) for " + ;
				This.cEngine + " (" + TRANSFORM(This.nLoadMs) + " ms)")
		ELSE
			This.oHost.Log("queries: the folder " + lcFolder + " does not exist")
		ENDIF
		IF VARTYPE(This.oForm) == "O"
			This.oForm.Refill()
		ENDIF
		RETURN loR.lExists
	ENDPROC

	PROCEDURE EnsureLoaded
		RETURN This.Load(.F.)
	ENDPROC

	*-- Lee una carpeta en toStore y devuelve lo que hay (un Empty):
	*--   cFolder, lExists, nFiles, nQueries, oEntries (una por .sql, en orden:
	*--   cName, cKind, cFile, lBroken, cError, nLine, oDef), oErrors y
	*--   oWarnings (cada uno: cFile, nLine, cCode, cText).
	*-- tlTell: los avisos de «Loading N queries...» con muchas.
	PROCEDURE Scan
		LPARAMETERS tcFolder, toStore, tlTell
		LOCAL loR, lnF, lnI, lcFile, llOk, loOne, lcName, loE, loDef, lnB, lnW
		LOCAL ARRAY laF[1]
		loR = CREATEOBJECT("Empty")
		ADDPROPERTY(loR, "cFolder", ADDBS(tcFolder))
		ADDPROPERTY(loR, "lExists", DIRECTORY(tcFolder, 1))
		ADDPROPERTY(loR, "nFiles", 0)
		ADDPROPERTY(loR, "nQueries", 0)
		ADDPROPERTY(loR, "oEntries", CREATEOBJECT("Collection"))
		ADDPROPERTY(loR, "oErrors", CREATEOBJECT("Collection"))
		ADDPROPERTY(loR, "oWarnings", CREATEOBJECT("Collection"))
		IF !loR.lExists
			RETURN loR
		ENDIF
		lnF = ADIR(laF, loR.cFolder + "*.sql", "", 1)
		IF lnF > 1
			=ASORT(laF, 1, -1, 0, 1)
		ENDIF
		loR.nFiles = lnF
		IF tlTell AND lnF > QC_MANY
			This.oHost.NotifyKey("queries.loading", lnF)
		ENDIF
		llOk = toStore.LoadFolder(loR.cFolder)
		IF !llOk
			*-- Los rotos, uno a uno: CheckFile de la copia lee cada .sql sin tocar lo
			*-- cargado; los buenos entran con LoadFile, en el orden de la carpeta. Lo
			*-- que falle aún (un nombre repetido entre ficheros) también va, con el
			*-- código de FoxQuery.
			loOne = This.NewStore()
			FOR lnI = 1 TO lnF
				lcFile = loR.cFolder + laF[lnI, 1]
				IF !This.BrokenErrors(loR, lcFile, loOne) AND !toStore.LoadFile(lcFile)
					This.AddIssue(loR.oErrors, lcFile, This.LineOf(toStore, lcFile), toStore.cLastErrorCode, toStore.cLastError)
				ENDIF
			ENDFOR
		ENDIF
		loR.nQueries = toStore.nQueries
		IF toStore.nQueries > 0 AND toStore.CheckEngine(This.cEngine) >= 0
			FOR lnW = 1 TO toStore.nWarnings
				This.AddIssue(loR.oWarnings, loR.cFolder + JUSTFNAME(toStore.aWarnings[lnW, 2]), toStore.aWarnings[lnW, 3], ;
					toStore.aWarnings[lnW, 1], toStore.aWarnings[lnW, 4])
			ENDFOR
		ENDIF
		FOR lnI = 1 TO lnF
			lcFile = loR.cFolder + laF[lnI, 1]
			lcName = This.HeaderName(lcFile)
			loE = CREATEOBJECT("Empty")
			ADDPROPERTY(loE, "cName", EVL(lcName, JUSTSTEM(lcFile)))
			ADDPROPERTY(loE, "cFile", lcFile)
			ADDPROPERTY(loE, "lBroken", .F.)
			ADDPROPERTY(loE, "cKind", "")
			ADDPROPERTY(loE, "cError", "")
			ADDPROPERTY(loE, "nLine", 1)
			ADDPROPERTY(loE, "oDef", .NULL.)
			loDef = IIF(EMPTY(lcName), .NULL., toStore.Get(lcName))
			lnB = This.FirstIssue(loR.oErrors, lcFile)
			DO CASE
				CASE lnB > 0
					loE.lBroken = .T.
					loE.cError = This.IssueText(loR.oErrors.Item(lnB))
					loE.nLine = loR.oErrors.Item(lnB).nLine
				CASE ISNULL(loDef)
					loE.lBroken = .T.
					loE.cError = "not loaded: " + toStore.cLastErrorCode + " " + toStore.cLastError
				OTHERWISE
					loE.cKind = loDef.cKind
					loE.nLine = MAX(1, loDef.nLine)
					loE.oDef = loDef
			ENDCASE
			loR.oEntries.Add(loE)
		ENDFOR
		IF tlTell AND lnF > QC_MANY
			This.oHost.NotifyKey("queries.loaded", loR.nQueries, lnF)
		ENDIF
		RETURN loR
	ENDPROC

	*-- Un fichero, por CheckFile de la copia en un almacén aparte (toOne, vacío: no
	*-- toca el del paquete). Roto: sus errores a toR.oErrors y .T.; limpio, .F.
	PROTECTED PROCEDURE BrokenErrors
		LPARAMETERS toR, tcFile, toOne
		LOCAL lnI
		IF toOne.CheckFile(tcFile)
			RETURN .F.
		ENDIF
		FOR lnI = 1 TO toOne.nLoadErrors
			This.AddIssue(toR.oErrors, tcFile, toOne.aLoadErrors[lnI, 3], toOne.aLoadErrors[lnI, 1], toOne.aLoadErrors[lnI, 4])
		ENDFOR
		IF toOne.nLoadErrors = 0
			This.AddIssue(toR.oErrors, tcFile, 1, toOne.cLastErrorCode, toOne.cLastError)
		ENDIF
		RETURN .T.
	ENDPROC

	*-- La línea del último error de carga de tcFile en toS (1 si no la dice).
	PROTECTED PROCEDURE LineOf
		LPARAMETERS toS, tcFile
		LOCAL lnI
		FOR lnI = toS.nLoadErrors TO 1 STEP -1
			IF UPPER(JUSTFNAME(TRANSFORM(toS.aLoadErrors[lnI, 2]))) == UPPER(JUSTFNAME(tcFile))
				RETURN IIF(VARTYPE(toS.aLoadErrors[lnI, 3]) == "N", toS.aLoadErrors[lnI, 3], 1)
			ENDIF
		ENDFOR
		RETURN 1
	ENDPROC

	PROCEDURE AddIssue
		LPARAMETERS toC, tcFile, tnLine, tcCode, tcText
		LOCAL loI
		loI = CREATEOBJECT("Empty")
		ADDPROPERTY(loI, "cFile", tcFile)
		ADDPROPERTY(loI, "nLine", IIF(VARTYPE(tnLine) == "N", tnLine, 0))
		ADDPROPERTY(loI, "cCode", TRANSFORM(tcCode))
		ADDPROPERTY(loI, "cText", TRANSFORM(tcText))
		toC.Add(loI)
	ENDPROC

	*-- El primero de toC que es de tcFile, o 0.
	PROCEDURE FirstIssue
		LPARAMETERS toC, tcFile
		LOCAL lnI
		FOR lnI = 1 TO toC.Count
			IF UPPER(toC.Item(lnI).cFile) == UPPER(tcFile)
				RETURN lnI
			ENDIF
		ENDFOR
		RETURN 0
	ENDPROC

	*-- «código, line N: motivo», como lo dice FoxQuery.
	PROCEDURE IssueText
		LPARAMETERS toI
		RETURN toI.cCode + ", line " + TRANSFORM(toI.nLine) + ": " + STRTRAN(toI.cText, toI.cCode + ": ", "", 1, 1)
	ENDPROC

	*-- El valor de la primera línea «-- name:» de un .sql, o "" (lo que FoxQuery
	*-- lee: «--», espacios, la clave hasta los dos puntos).
	PROCEDURE HeaderName
		LPARAMETERS tcFile
		LOCAL laL[1], lnN, lnI, lcT, lcBody
		lnN = ALINES(laL, FILETOSTR(tcFile))
		FOR lnI = 1 TO lnN
			lcT = ALLTRIM(laL[lnI], 1, " ", CHR(9))
			IF !(LEFT(lcT, 2) == "--")
				IF EMPTY(lcT)
					LOOP
				ENDIF
				EXIT
			ENDIF
			lcBody = ALLTRIM(SUBSTR(lcT, 3), 1, " ", CHR(9))
			IF LOWER(LEFT(lcBody, 5)) == "name:"
				lcBody = ALLTRIM(SUBSTR(lcBody, 6), 1, " ", CHR(9))
				IF "--" $ lcBody
					lcBody = RTRIM(LEFT(lcBody, AT("--", lcBody) - 1))
				ENDIF
				RETURN lcBody
			ENDIF
		ENDFOR
		RETURN ""
	ENDPROC

	*-- Un texto de .sql comprobado por FoxQuery antes de escribirlo: a un fichero
	*-- temporal <tcName>.sql (FoxQuery pide que el «-- name:» sea el nombre del
	*-- fichero: header_name_mismatch) y CheckFile en un almacén aparte. "" si carga
	*-- limpio; si no, «código, line N: motivo», y cLastCheckCode, nLastCheckLine y
	*-- oLastCheck (todos los errores, como AddIssue).
	PROCEDURE CheckText
		LPARAMETERS tcName, tcText
		LOCAL lcFile, loOne, lnI, loErr, lcWhy
		This.cLastCheckCode = ""
		This.nLastCheckLine = 0
		This.oLastCheck = CREATEOBJECT("Collection")
		IF EMPTY(tcName) OR !(CHRTRAN(tcName, '\/:*?"<>|', "") == tcName)
			This.cLastCheckCode = "name_invalid"
			RETURN "name_invalid, line 1: '" + TRANSFORM(tcName) + "' cannot be the name of a file"
		ENDIF
		lcFile = ADDBS(SYS(2023)) + tcName + ".sql"
		lcWhy = ""
		TRY
			STRTOFILE(tcText, lcFile, 0)
		CATCH TO loErr
			lcWhy = "error " + TRANSFORM(loErr.ErrorNo) + ": " + loErr.Message
		ENDTRY
		IF EMPTY(lcWhy) AND !FILE(lcFile)
			lcWhy = "no file " + tcName + ".sql could be written"
		ENDIF
		IF !EMPTY(lcWhy)
			This.cLastCheckCode = "name_invalid"
			RETURN "name_invalid, line 1: " + lcWhy
		ENDIF
		loOne = This.NewStore()
		IF !loOne.CheckFile(lcFile)
			FOR lnI = 1 TO loOne.nLoadErrors
				This.AddIssue(This.oLastCheck, tcName + ".sql", loOne.aLoadErrors[lnI, 3], loOne.aLoadErrors[lnI, 1], loOne.aLoadErrors[lnI, 4])
			ENDFOR
			IF This.oLastCheck.Count = 0
				This.AddIssue(This.oLastCheck, tcName + ".sql", 1, loOne.cLastErrorCode, loOne.cLastError)
			ENDIF
			This.cLastCheckCode = This.oLastCheck.Item(1).cCode
			This.nLastCheckLine = This.oLastCheck.Item(1).nLine
			lcWhy = This.IssueText(This.oLastCheck.Item(1))
		ENDIF
		ERASE (lcFile)
		RETURN lcWhy
	ENDPROC

	*-- Los errores del último CheckText: «line N: motivo» el primero (su código va
	*-- delante, en el de la tool) y «; código, line N: motivo» los demás.
	PROCEDURE CheckErrors
		LOCAL lcOut, lnI, loI
		lcOut = ""
		FOR lnI = 1 TO This.oLastCheck.Count
			loI = This.oLastCheck.Item(lnI)
			lcOut = lcOut + IIF(lnI = 1, "", "; " + loI.cCode + ", ") + "line " + TRANSFORM(loI.nLine) + ": " + ;
				STRTRAN(loI.cText, loI.cCode + ": ", "", 1, 1)
		ENDFOR
		RETURN lcOut
	ENDPROC

	*-- ide_queries_save. tcText (CP1252) a <carpeta>\<tcName>.sql si FoxQuery lo
	*-- carga limpio; sin tlOverwrite no pisa (file_exists). La lista, al día. .T. o .F.
	*-- con cLastCode y cLastError.
	PROCEDURE SaveQuery
		LPARAMETERS tcName, tcText, tlOverwrite
		LOCAL lcName, lcFolder, lcTarget, lcWhy, llWas, lcSafety
		This.cLastCode = ""
		This.cLastError = ""
		lcName = ALLTRIM(TRANSFORM(tcName))
		lcWhy = This.CheckText(lcName, tcText)
		IF !EMPTY(lcWhy)
			This.cLastCode = This.cLastCheckCode
			This.cLastError = IIF(This.cLastCode == "name_invalid", SUBSTR(lcWhy, AT(", ", lcWhy) + 2), This.CheckErrors())
			RETURN .F.
		ENDIF
		lcFolder = This.Folder()
		lcTarget = lcFolder + lcName + ".sql"
		llWas = FILE(lcTarget)
		*-- Un fichero nuevo lleva un nombre de consulta (IsQueryName); uno que ya está se
		*-- puede reescribir con el nombre que tenga.
		IF !llWas AND !This.IsQueryName(lcName)
			This.cLastCode = "name_invalid"
			This.cLastError = "'" + lcName + "' is not a query name: a letter or _, then letters, digits, _ or dots (customers.by_city)"
			RETURN .F.
		ENDIF
		IF llWas AND !tlOverwrite
			This.cLastCode = "file_exists"
			This.cLastError = lcTarget + " is already there: pass overwrite true to replace it"
			RETURN .F.
		ENDIF
		IF !DIRECTORY(lcFolder, 1)
			MKDIR (lcFolder)
		ENDIF
		lcSafety = SET("SAFETY")
		SET SAFETY OFF
		STRTOFILE(tcText, lcTarget, 0)
		SET SAFETY &lcSafety
		This.cLastFile = lcTarget
		This.oHost.Log("queries: " + lcTarget + IIF(llWas, " replaced", " written") + " (" + TRANSFORM(LEN(tcText)) + " bytes, CP1252)")
		=This.Load(.T.)
		RETURN .T.
	ENDPROC

	*-- Un nombre para una consulta nueva: la regla de los nombres de FoxQuery
	*-- con puntos, QueryText.IsName de la copia: una letra o _, y después
	*-- letras (también las acentuadas), dígitos, _ o puntos sueltos. FoxQuery
	*-- carga igual un .sql con espacios en el nombre; FoxDock no lo crea.
	PROCEDURE IsQueryName
		LPARAMETERS tcName
		LOCAL loP, loText
		loP = This.Plugin()
		loText = NEWOBJECT("QueryText", loP.CodeFile("lib\foxquery\foxquery.prg"))
		RETURN loText.IsName(ALLTRIM(TRANSFORM(tcName)), .T.)
	ENDPROC

	*-- Un texto en una línea: los saltos de línea y los tabuladores, espacios, y nunca
	*-- dos seguidos. Una descripción con un salto de línea partiría la cabecera del
	*-- .sql: lo de la segunda línea ya no empieza por «--» y FoxQuery lo leería como SQL.
	PROCEDURE OneLine
		LPARAMETERS tcText
		LOCAL lcT
		lcT = CHRTRAN(TRANSFORM(tcText), CHR(13) + CHR(10) + CHR(9), "   ")
		DO WHILE "  " $ lcT
			lcT = STRTRAN(lcT, "  ", " ")
		ENDDO
		RETURN ALLTRIM(lcT)
	ENDPROC

	*-- Una entrada de lo leído por su nombre (sin distinguir mayúsculas), o .NULL.
	PROCEDURE Entry
		LPARAMETERS tcName
		LOCAL loE
		IF ISNULL(This.oResult)
			RETURN .NULL.
		ENDIF
		FOR EACH loE IN This.oResult.oEntries FOXOBJECT
			IF LOWER(loE.cName) == LOWER(ALLTRIM(TRANSFORM(tcName)))
				RETURN loE
			ENDIF
		ENDFOR
		RETURN .NULL.
	ENDPROC

	*-- Lo que dice el motor de una consulta: "" (ok) o el aviso con su línea.
	PROCEDURE EngineSays
		LPARAMETERS toE
		LOCAL lnI
		lnI = This.FirstIssue(This.oResult.oWarnings, toE.cFile)
		RETURN IIF(lnI = 0, "", This.IssueText(This.oResult.oWarnings.Item(lnI)))
	ENDPROC

	*-- El texto del panel de una consulta, en el idioma de FoxDock.
	PROCEDURE PanelText
		LPARAMETERS tcName
		LOCAL loE, loD, lcT, loP, loI, lnI, lcList, lcSays, loS
		loE = This.Entry(tcName)
		IF ISNULL(loE)
			RETURN ""
		ENDIF
		IF loE.lBroken
			RETURN "! " + JUSTFNAME(loE.cFile) + CRLF + CRLF + loE.cError
		ENDIF
		loD = loE.oDef
		loS = This.Store()
		lcT = loD.cName + "    " + loD.cKind + CRLF + loD.cDescription + CRLF + CRLF + This.T("queries.panel.params") + CRLF
		IF loD.oParams.Count = 0
			lcT = lcT + "  " + This.T("queries.panel.none") + CRLF
		ENDIF
		FOR EACH loP IN loD.oParams FOXOBJECT
			lcT = lcT + "  " + PADR(loP.cName, 14) + " " + loP.cType + IIF(loP.lRequired, "  required", "") + ;
				IIF(loP.lList, "  list", "") + IIF(loP.lHasDefault, "  default " + TRANSFORM(loP.vDefault), "") + CRLF
		ENDFOR
		lcList = ""
		FOR lnI = 1 TO loD.nSort
			lcList = lcList + IIF(EMPTY(lcList), "", ", ") + loD.aSortList[lnI]
		ENDFOR
		lcT = lcT + This.T("queries.panel.sort") + " " + EVL(lcList, "-") + CRLF
		lcList = ""
		FOR EACH loI IN loD.oIdents FOXOBJECT
			lcList = lcList + IIF(EMPTY(lcList), "", ", ") + loI.cName + " (" + loS.IdentForm(loI) + ")"
		ENDFOR
		lcT = lcT + This.T("queries.panel.idents") + " " + EVL(lcList, "-") + CRLF
		lcList = ""
		FOR lnI = 1 TO loD.oVariants.Count
			lcList = lcList + IIF(EMPTY(lcList), "", ", ") + loD.oVariants.GetKey(lnI)
		ENDFOR
		lcT = lcT + This.T("queries.panel.variants") + " " + EVL(lcList, "-") + CRLF + CRLF
		lcSays = This.EngineSays(loE)
		lcT = lcT + This.T("queries.panel.for", This.cEngine) + " " + IIF(EMPTY(lcSays), "(ok)", lcSays) + CRLF
		RETURN lcT
	ENDPROC

	*--------------------------------------------------------------
	* Las barras.
	*--------------------------------------------------------------
	PROCEDURE OpenWindow
		LOCAL loP
		=This.EnsureLoaded()
		IF VARTYPE(This.oForm) # "O"
			loP = This.Plugin()
			This.oForm = NEWOBJECT("QueriesForm", loP.CodeFile("QueriesCatalog.prg"), "", This)
		ENDIF
		IF This.lShow
			This.oForm.Show()
		ENDIF
		RETURN This.oForm
	ENDPROC

	*-- Con la ventana se va la pregunta de Delete, que habla de su consulta elegida.
	PROCEDURE FormGone
		This.oForm = .NULL.
		IF VARTYPE(This.oDeleteForm) == "O"
			This.oDeleteForm.Release()
		ENDIF
	ENDPROC

	PROCEDURE NewFormGone
		This.oNewForm = .NULL.
	ENDPROC

	PROCEDURE CheckFormGone
		This.oCheckForm = .NULL.
	ENDPROC

	PROCEDURE DeleteFormGone
		This.oDeleteForm = .NULL.
	ENDPROC

	PROCEDURE OpenNew
		LOCAL loP
		IF VARTYPE(This.oNewForm) # "O"
			loP = This.Plugin()
			This.oNewForm = NEWOBJECT("QueriesNewForm", loP.CodeFile("QueriesCatalog.prg"), "", This)
		ENDIF
		IF This.lShow
			This.oNewForm.Show()
		ENDIF
		RETURN This.oNewForm
	ENDPROC

	PROCEDURE Reload
		RETURN This.Load(.T.)
	ENDPROC

	*-- Edit: el .sql en el editor de VFP, en su línea; se apunta el wh.
	PROCEDURE EditQuery
		LPARAMETERS tcName
		LOCAL loE
		loE = This.Entry(tcName)
		IF ISNULL(loE)
			RETURN .F.
		ENDIF
		RETURN This.OpenFile(loE.cFile, loE.nLine)
	ENDPROC

	PROCEDURE OpenFile
		LPARAMETERS tcFile, tnLine
		LOCAL llOk, lcInfo, lnWh
		This.cLastEdit = tcFile + "|" + TRANSFORM(tnLine)
		IF !This.lShow
			RETURN .T.
		ENDIF
		llOk = This.oHost.Editor.Open(tcFile, MAX(1, tnLine))
		lcInfo = This.oHost.Editor.Info()
		lnWh = VAL(STREXTRACT(lcInfo, ["wh":], [,]))
		IF lnWh > 0 AND LOWER(JUSTFNAME(STREXTRACT(lcInfo, ["file":"], ["]))) == LOWER(JUSTFNAME(tcFile))
			This.Remember(lnWh, tcFile)
		ENDIF
		RETURN llOk
	ENDPROC

	PROCEDURE Remember
		LPARAMETERS tnWh, tcFile
		LOCAL lcKey
		lcKey = TRANSFORM(tnWh)
		IF This.oOpened.GetKey(lcKey) > 0
			This.oOpened.Remove(lcKey)
		ENDIF
		This.oOpened.Add(tcFile, lcKey)
		This.oHost.Log("queries: " + tcFile + " opened in the editor (wh " + lcKey + ")")
	ENDPROC

	*-- El editor de un .sql que abrió el paquete se cerró: se vuelve a leer.
	PROCEDURE EditorClosed
		LPARAMETERS tnWh
		LOCAL lcKey, lcFile
		lcKey = TRANSFORM(tnWh)
		IF This.oOpened.GetKey(lcKey) = 0
			RETURN .F.
		ENDIF
		lcFile = This.oOpened.Item(lcKey)
		This.oOpened.Remove(lcKey)
		=This.ReloadFile(lcFile)
		RETURN .T.
	ENDPROC

	*-- Solo ese fichero, con LoadFile de la copia: su consulta entra o se
	*-- reemplaza en su sitio, y su entrada, sus errores y sus avisos se ponen al
	*-- día; los demás siguen como estaban. Si no carga, pasa a los rotos con su
	*-- código y su línea (la consulta de antes sigue en el almacén hasta Reload).
	*-- La carpeta entera (Load) solo si no hay nada cargado, si es un .fq, si el
	*-- fichero es nuevo o si su «-- name:» cambió. .T. si se leyó solo ese.
	PROCEDURE ReloadFile
		LPARAMETERS tcFile
		LOCAL loS, loE, loR, lnI, lcName, lnT0, llOk, lnB
		loS = This.Store()
		loR = This.oResult
		loE = .NULL.
		IF This.lLoaded AND !ISNULL(loS) AND VARTYPE(loR) == "O" AND EMPTY(loS.cCatalog)
			FOR lnI = 1 TO loR.oEntries.Count
				IF UPPER(loR.oEntries.Item(lnI).cFile) == UPPER(tcFile)
					loE = loR.oEntries.Item(lnI)
				ENDIF
			ENDFOR
		ENDIF
		lcName = IIF(FILE(tcFile), This.HeaderName(tcFile), "")
		IF ISNULL(loE) OR !(LOWER(lcName) == LOWER(loE.cName))
			This.oHost.Log("queries: " + tcFile + " was closed in the editor: the folder is read again")
			=This.Load(.T.)
			RETURN .F.
		ENDIF
		lnT0 = SECONDS()
		llOk = loS.LoadFile(tcFile)
		*-- Lo de ese fichero sale de los errores y los avisos; lo nuevo entra.
		FOR lnI = loR.oErrors.Count TO 1 STEP -1
			IF UPPER(loR.oErrors.Item(lnI).cFile) == UPPER(tcFile)
				loR.oErrors.Remove(lnI)
			ENDIF
		ENDFOR
		FOR lnI = loR.oWarnings.Count TO 1 STEP -1
			IF UPPER(loR.oWarnings.Item(lnI).cFile) == UPPER(tcFile)
				loR.oWarnings.Remove(lnI)
			ENDIF
		ENDFOR
		IF llOk
			FOR lnI = 1 TO loS.nWarnings
				IF UPPER(JUSTFNAME(TRANSFORM(loS.aWarnings[lnI, 2]))) == UPPER(JUSTFNAME(tcFile))
					This.AddIssue(loR.oWarnings, tcFile, loS.aWarnings[lnI, 3], loS.aWarnings[lnI, 1], loS.aWarnings[lnI, 4])
				ENDIF
			ENDFOR
			loE.oDef = loS.Get(lcName)
			loE.lBroken = ISNULL(loE.oDef)
			loE.cKind = IIF(loE.lBroken, "", loE.oDef.cKind)
			loE.nLine = IIF(loE.lBroken, 1, MAX(1, loE.oDef.nLine))
			loE.cError = IIF(loE.lBroken, "not loaded: " + loS.cLastErrorCode + " " + loS.cLastError, "")
		ELSE
			FOR lnI = 1 TO loS.nLoadErrors
				This.AddIssue(loR.oErrors, tcFile, loS.aLoadErrors[lnI, 3], loS.aLoadErrors[lnI, 1], loS.aLoadErrors[lnI, 4])
			ENDFOR
			IF loS.nLoadErrors = 0
				This.AddIssue(loR.oErrors, tcFile, 1, loS.cLastErrorCode, loS.cLastError)
			ENDIF
			lnB = This.FirstIssue(loR.oErrors, tcFile)
			loE.lBroken = .T.
			loE.cKind = ""
			loE.oDef = .NULL.
			loE.cError = This.IssueText(loR.oErrors.Item(lnB))
			loE.nLine = loR.oErrors.Item(lnB).nLine
		ENDIF
		loR.nQueries = loS.nQueries
		This.nLoadMs = INT((SECONDS() - lnT0) * 1000)
		This.oHost.Log("queries: " + tcFile + " was closed in the editor: only that file is read again, " + ;
			IIF(llOk, "loaded", "broken: " + loE.cError) + " (" + TRANSFORM(This.nLoadMs) + " ms)")
		IF VARTYPE(This.oForm) == "O"
			This.oForm.Refill()
		ENDIF
		RETURN .T.
	ENDPROC

	*-- New query...: tcName validado por FoxQuery (cargado solo en un almacén
	*-- aparte), el .sql en CP1252 con su cabecera, sin pisar. .T. si lo hizo.
	PROCEDURE MakeQuery
		LPARAMETERS tcName, tcKind, tcDescription
		LOCAL lcName, lcKind, lcDesc, lcFolder, lcTarget, lcText, llOk, lcWhy
		lcName = ALLTRIM(TRANSFORM(tcName))
		lcKind = LOWER(ALLTRIM(TRANSFORM(tcKind)))
		lcDesc = This.OneLine(tcDescription)
		lcFolder = This.Folder()
		IF EMPTY(lcName)
			RETURN This.Said("queries.new.needName")
		ENDIF
		lcText = "-- name: " + lcName + CRLF + "-- description: " + EVL(lcDesc, lcName) + CRLF + "-- kind: " + lcKind + CRLF + ;
			"-- A parameter, one line each (take the first -- away): name, type (C N I D T L Y M), required, list, default" + CRLF + ;
			"-- -- param: city C required" + CRLF + ;
			"-- A name that the program sets once (FQ_SET), as {ident sort} in the SQL, like the column to sort by:" + CRLF + ;
			"-- -- ident: sort letters 1-20" + CRLF + ;
			IIF(lcKind == "write", "UPDATE customers SET name = name WHERE 1 = 0", "SELECT * FROM customers") + CRLF
		*-- Comprobado por CheckFile de la copia sobre un fichero temporal, sin carpeta.
		lcWhy = This.CheckText(lcName, lcText)
		IF This.cLastCheckCode == "name_invalid"
			RETURN This.Said("queries.new.badFile", lcName, SUBSTR(lcWhy, AT(": ", lcWhy) + 2))
		ENDIF
		IF !This.IsQueryName(lcName)
			RETURN This.Said("queries.new.badName", lcName)
		ENDIF
		IF !EMPTY(lcWhy)
			lcWhy = This.oLastCheck.Item(1).cCode + ": " + STRTRAN(This.oLastCheck.Item(1).cText, This.oLastCheck.Item(1).cCode + ": ", "", 1, 1)
			RETURN This.Said("queries.new.invalid", lcName, lcWhy)
		ENDIF
		lcTarget = lcFolder + lcName + ".sql"
		IF FILE(lcTarget)
			RETURN This.Said("queries.new.exists", lcTarget)
		ENDIF
		IF !DIRECTORY(lcFolder, 1)
			MKDIR (lcFolder)
		ENDIF
		STRTOFILE(lcText, lcTarget, 0)
		=This.Load(.T.)
		=This.OpenFile(lcTarget, 1)
		*-- Lo dice una vez. La ventanita se cierra al hacerla (su cmdMake): con la
		*-- ventana FoxDock - Queries, en su pie y con la nueva elegida (y el log),
		*-- y sin ella, el aviso.
		This.cLastSaid = This.T("queries.new.made", lcTarget)
		IF VARTYPE(This.oForm) == "O"
			This.oHost.Log("queries: " + This.E("queries.new.made", lcTarget))
			=This.oForm.SelectQuery(lcName)
			This.oForm.lblSay.Caption = This.cLastSaid
		ELSE
			This.oHost.NotifyKey("queries.new.made", lcTarget)
		ENDIF
		RETURN .T.
	ENDPROC

	*-- Delete. CanDelete: si la consulta se puede borrar, con
	*-- lo que hay que decir en cLastSaid (la pregunta, o por qué no). No se borra un .sql
	*-- abierto en un editor que abrió el paquete: al guardarlo, VFP lo volvería a escribir.
	PROCEDURE CanDelete
		LPARAMETERS tcName
		LOCAL loE
		This.cLastCode = ""
		This.cLastError = ""
		loE = This.Entry(tcName)
		IF ISNULL(loE)
			This.cLastCode = "query_not_found"
			RETURN This.Told("queries.delete.missing", ALLTRIM(TRANSFORM(tcName)))
		ENDIF
		IF This.IsOpen(loE.cFile)
			This.cLastCode = "file_open"
			RETURN This.Told("queries.delete.open", loE.cFile)
		ENDIF
		This.cLastSaid = This.T("queries.delete.ask", loE.cName)
		RETURN .T.
	ENDPROC

	*-- Delete pregunta antes, para que un clic sin querer no borre nada: la
	*-- ventanita FoxDock - Delete query, con la consulta, su fichero y adónde va,
	*-- y Delete y Cancel; Cancel es el de Intro y Esc, y el que tiene el foco.
	*-- No es un MESSAGEBOX: no para a nadie, y los casos y el agente la contestan
	*-- con sus botones. .T. si preguntó; .F., y en cLastSaid por qué no, si la
	*-- consulta no se puede borrar.
	PROCEDURE AskDelete
		LPARAMETERS tcName
		LOCAL loP, loE
		IF !This.CanDelete(tcName)
			RETURN .F.
		ENDIF
		loE = This.Entry(tcName)
		IF VARTYPE(This.oDeleteForm) # "O"
			loP = This.Plugin()
			This.oDeleteForm = NEWOBJECT("QueriesDeleteForm", loP.CodeFile("QueriesCatalog.prg"), "", This)
		ENDIF
		This.oDeleteForm.Ask(loE.cName, loE.cFile)
		IF This.lShow
			This.oDeleteForm.Show()
			This.oDeleteForm.cmdNo.SetFocus()
		ENDIF
		This.oHost.Log("queries: asked whether to delete " + loE.cName + " (" + loE.cFile + ")")
		RETURN .T.
	ENDPROC

	*-- El .sql de la consulta a la Papelera de reciclaje (se recupera desde allí; nunca
	*-- un ERASE), y la carpeta otra vez. .T. si ya no está.
	PROCEDURE DeleteQuery
		LPARAMETERS tcName
		LOCAL loE, lcFile, lnRc
		IF !This.CanDelete(tcName)
			RETURN .F.
		ENDIF
		loE = This.Entry(tcName)
		lcFile = loE.cFile
		lnRc = This.Recycle(lcFile)
		IF lnRc # 0 OR FILE(lcFile)
			This.cLastCode = "delete_failed"
			This.cLastError = IIF(lnRc # 0, "SHFileOperation gave " + TRANSFORM(lnRc), "the file is still there")
			RETURN This.Told("queries.delete.failed", lcFile, This.cLastError)
		ENDIF
		=This.Told("queries.delete.done", loE.cName, lcFile)
		=This.Load(.T.)
		IF VARTYPE(This.oForm) == "O"
			This.oForm.lblSay.Caption = This.cLastSaid
		ENDIF
		RETURN .T.
	ENDPROC

	*-- Si un editor que abrió el paquete tiene ese fichero (oOpened: wh -> fichero).
	PROCEDURE IsOpen
		LPARAMETERS tcFile
		LOCAL lnI
		FOR lnI = 1 TO This.oOpened.Count
			IF UPPER(This.oOpened.Item(lnI)) == UPPER(tcFile)
				RETURN .T.
			ENDIF
		ENDFOR
		RETURN .F.
	ENDPROC

	*-- SHFileOperation (FO_DELETE con FOF_ALLOWUNDO): el fichero a la Papelera, sin
	*-- diálogos. La estructura de 32 bits va empaquetada a 1 byte (shellapi.h):
	*-- hwnd, wFunc, pFrom, pTo (4 cada uno), fFlags (2), fAnyOperationsAborted,
	*-- hNameMappings y lpszProgressTitle (4 cada uno): 30 bytes. pFrom es un puntero a
	*-- la ruta con dos CHR(0) al final, en memoria propia. Devuelve lo que da Windows
	*-- (0, hecho) o -1 sin memoria.
	PROTECTED PROCEDURE Recycle
		LPARAMETERS tcFile
		LOCAL lcFrom, lnMem, lcOp, lnRc
		DECLARE INTEGER SHFileOperation IN shell32 AS FdQueriesFileOp STRING @ cFileOp
		DECLARE INTEGER GlobalAlloc IN kernel32 AS FdQueriesAlloc INTEGER nFlags, INTEGER nBytes
		DECLARE INTEGER GlobalFree IN kernel32 AS FdQueriesFree INTEGER nMem
		DECLARE RtlMoveMemory IN kernel32 AS FdQueriesPoke INTEGER nDest, STRING cSource, INTEGER nLength
		lcFrom = tcFile + CHR(0) + CHR(0)
		lnMem = FdQueriesAlloc(0x40, LEN(lcFrom))
		IF lnMem = 0
			RETURN -1
		ENDIF
		=FdQueriesPoke(lnMem, lcFrom, LEN(lcFrom))
		lcOp = BINTOC(0, "4RS") + BINTOC(3, "4RS") + BINTOC(lnMem, "4RS") + BINTOC(0, "4RS") + ;
			BINTOC(QC_FOF_RECYCLE, "2RS") + BINTOC(0, "4RS") + BINTOC(0, "4RS") + BINTOC(0, "4RS")
		lnRc = FdQueriesFileOp(@lcOp)
		=FdQueriesFree(lnMem)
		This.oHost.Log("queries: " + tcFile + IIF(lnRc = 0, " sent to the Recycle Bin", " not sent to the Recycle Bin (SHFileOperation " + TRANSFORM(lnRc) + ")"))
		RETURN lnRc
	ENDPROC

	*-- Lo que dice la ventana (cLastSaid, en el idioma de FoxDock, y en inglés al log);
	*-- devuelve .F. para los RETURN de una negativa.
	PROCEDURE Told
		LPARAMETERS tcKey, tv1, tv2
		This.cLastSaid = This.T(tcKey, tv1, tv2)
		This.oHost.Log("queries: " + This.E(tcKey, tv1, tv2))
		RETURN .F.
	ENDPROC

	*-- Lo que dice New query... o Check, en el idioma de FoxDock (y en inglés al
	*-- log); devuelve .F. para los RETURN de una negativa.
	PROCEDURE Said
		LPARAMETERS tcKey, tv1, tv2
		This.cLastSaid = This.T(tcKey, tv1, tv2)
		This.oHost.Log("queries: " + This.E(tcKey, tv1, tv2))
		IF VARTYPE(This.oNewForm) == "O"
			This.oNewForm.edtSay.Value = This.cLastSaid
		ENDIF
		RETURN .F.
	ENDPROC

	*-- Check: la carpeta otra vez y CheckEngine; cada error y cada aviso, a
	*-- oChecks y a la ventana FoxDock - Check (QueriesCheckForm). Sin nada que
	*-- decir, el aviso, y la ventana, si estaba abierta, se queda vacía y lo
	*-- dice. El pie de la ventana FoxDock - Queries dice lo mismo. Devuelve
	*-- cuántas filas, o -1 sin carpeta.
	PROCEDURE CheckFolder
		LOCAL loR, loI, lnN, loP
		IF !This.Load(.T.)
			This.oHost.NotifyKey("queries.noFolder", This.Folder())
			RETURN -1
		ENDIF
		loR = This.oResult
		This.oChecks = CREATEOBJECT("Collection")
		FOR EACH loI IN loR.oErrors FOXOBJECT
			This.AddCheck(loI, "error")
		ENDFOR
		FOR EACH loI IN loR.oWarnings FOXOBJECT
			This.AddCheck(loI, "warning")
		ENDFOR
		lnN = This.oChecks.Count
		IF lnN = 0
			This.cLastSaid = This.T("queries.check.clean", loR.nQueries, This.cEngine)
			This.oHost.NotifyKey("queries.check.clean", loR.nQueries, This.cEngine)
		ELSE
			This.cLastSaid = This.T("queries.check.title", loR.oErrors.Count, loR.oWarnings.Count, This.cEngine)
			This.oHost.Log("queries: Check: " + This.E("queries.check.title", loR.oErrors.Count, loR.oWarnings.Count, This.cEngine))
			IF VARTYPE(This.oCheckForm) # "O"
				loP = This.Plugin()
				This.oCheckForm = NEWOBJECT("QueriesCheckForm", loP.CodeFile("QueriesCatalog.prg"), "", This)
			ENDIF
		ENDIF
		IF VARTYPE(This.oCheckForm) == "O"
			This.oCheckForm.Fill()
			IF This.lShow
				This.oCheckForm.Show()
			ENDIF
		ENDIF
		IF VARTYPE(This.oForm) == "O"
			This.oForm.lblSay.Caption = This.cLastSaid
		ENDIF
		RETURN lnN
	ENDPROC

	*-- Una fila de Check: lo de FoxQuery, si es error o aviso, y la consulta del fichero
	*-- (su «-- name:», o el nombre del fichero sin .sql si no se pudo leer).
	PROCEDURE AddCheck
		LPARAMETERS toI, tcWhat
		LOCAL loC, loE, lcQuery
		lcQuery = JUSTSTEM(toI.cFile)
		FOR EACH loE IN This.oResult.oEntries FOXOBJECT
			IF UPPER(loE.cFile) == UPPER(toI.cFile)
				lcQuery = loE.cName
				EXIT
			ENDIF
		ENDFOR
		loC = CREATEOBJECT("Empty")
		ADDPROPERTY(loC, "cFile", toI.cFile)
		ADDPROPERTY(loC, "nLine", toI.nLine)
		ADDPROPERTY(loC, "cCode", toI.cCode)
		ADDPROPERTY(loC, "cText", STRTRAN(toI.cText, toI.cCode + ": ", "", 1, 1))
		ADDPROPERTY(loC, "cWhat", tcWhat)
		ADDPROPERTY(loC, "cQuery", lcQuery)
		This.oChecks.Add(loC)
	ENDPROC

	*-- Edit en la ventana de Check (o doble clic, o Intro): el .sql de esa fila, en su línea.
	PROCEDURE OpenCheck
		LPARAMETERS tnRow
		LOCAL loC
		IF VARTYPE(This.oChecks) # "O" OR VARTYPE(tnRow) # "N" OR !BETWEEN(tnRow, 1, This.oChecks.Count)
			RETURN .F.
		ENDIF
		loC = This.oChecks.Item(tnRow)
		RETURN This.OpenFile(loC.cFile, loC.nLine)
	ENDPROC

	*-- SQL for engine >: el texto de una consulta para un motor ("" o «all»: los
	*-- siete), con los :name tal cual, en una ventana de texto de solo lectura.
	PROCEDURE ShowSql
		LPARAMETERS tcName, tcEngine
		LOCAL loS, lcEngines, lnI, lcE, lcT, lvSql, lcFile, lcDir, lcSafety
		=This.EnsureLoaded()
		loS = This.Store()
		lcEngines = IIF(EMPTY(tcEngine) OR LOWER(tcEngine) == "all", QC_ENGINES, LOWER(ALLTRIM(tcEngine)))
		lcT = ""
		FOR lnI = 1 TO GETWORDCOUNT(lcEngines, ",")
			lcE = GETWORDNUM(lcEngines, lnI, ",")
			lvSql = loS.Sql(tcName, lcE)
			lcT = lcT + IIF(EMPTY(lcT), "", CRLF) + "-- " + tcName + " for " + lcE + CRLF + ;
				IIF(VARTYPE(lvSql) == "C", lvSql, "-- " + loS.cLastErrorCode + ": " + loS.cLastError) + CRLF
		ENDFOR
		This.cLastSql = lcT
		lcDir = This.oHost.DataDir + "queries\"
		IF !DIRECTORY(lcDir, 1)
			MKDIR (lcDir)
		ENDIF
		lcFile = lcDir + CHRTRAN(tcName, "\/:*?<>|" + ["], "_________") + "." + IIF(GETWORDCOUNT(lcEngines, ",") > 1, "all", lcEngines) + ".sql"
		lcSafety = SET("SAFETY")
		SET SAFETY OFF
		STRTOFILE(lcT, lcFile, 0)
		SET SAFETY &lcSafety
		This.cLastSqlFile = lcFile
		This.oHost.Log("queries: SQL of " + tcName + " for " + STRTRAN(lcEngines, ",", ", ") + " in " + lcFile)
		IF This.lShow
			MODIFY FILE (lcFile) NOEDIT NOWAIT
		ENDIF
		RETURN lcT
	ENDPROC

	PROCEDURE Engines
		RETURN QC_ENGINES
	ENDPROC

	*-- Change...: la carpeta de las consultas para todos los IDE (VFP 9 y VFPA
	*-- arrancan en carpetas distintas): options.queries.folder de config.json, que
	*-- es uno para todos. Una carpeta que no existe no se pone; "" vuelve a la de
	*-- siempre (queries\ junto al proyecto). .T. si cambió; lo que se dice, en
	*-- cLastSaid (y al pie de la ventana).
	PROCEDURE SetFolder
		LPARAMETERS tcFolder
		LOCAL lcDir
		lcDir = ALLTRIM(TRANSFORM(tcFolder))
		IF !EMPTY(lcDir)
			lcDir = ADDBS(lcDir)
			IF !DIRECTORY(lcDir, 1)
				=This.Told("queries.folder.missing", lcDir)
				IF VARTYPE(This.oForm) == "O"
					This.oForm.lblSay.Caption = This.cLastSaid
				ENDIF
				RETURN .F.
			ENDIF
		ENDIF
		This.oHost.Options.Set("queries", "folder", lcDir)
		=This.Load(.T.)
		=This.Told(IIF(EMPTY(lcDir), "queries.folder.default", "queries.folder.set"), This.Folder())
		IF VARTYPE(This.oForm) == "O"
			This.oForm.lblSay.Caption = This.cLastSaid
		ENDIF
		RETURN .T.
	ENDPROC

	*-- La carpeta que elige la persona con Change... (GETDIR: lo pide ella con el botón,
	*-- como el GETFILE de JSON to cursor); sin enseñar nada (los casos), cPick. "" si cancela.
	PROCEDURE PickFolder
		LOCAL lcStart
		IF !This.lShow
			RETURN This.cPick
		ENDIF
		lcStart = This.Folder()
		IF !DIRECTORY(lcStart, 1)
			lcStart = ADDBS(SET("DEFAULT") + CURDIR())
		ENDIF
		RETURN GETDIR(lcStart, This.T("queries.folder.pick"), This.T("queries.folder.title"), 81)
	ENDPROC

	*-- Help: la sección del manual de la ventana en el navegador (OpenHelp de
	*-- FoxDock, como las ventanas de data); tcKey, el texto del idioma con su
	*-- anclaje.
	PROCEDURE ShowHelp
		LPARAMETERS tcKey
		RETURN This.oHost.OpenHelp("PLUGINS", This.T(tcKey))
	ENDPROC

	*-- Al abrir o cerrar un proyecto la carpeta cambia: lo leído ya no vale, y
	*-- la ventana se cierra con el proyecto que se cierra.
	PROCEDURE ProjectChanged
		LPARAMETERS tcClosing
		This.lLoaded = .F.
		IF !EMPTY(tcClosing)
			This.cClosing = tcClosing
			IF VARTYPE(This.oForm) == "O"
				This.oHost.Log("queries: the window closes with the project " + tcClosing)
				This.oForm.Release()
			ENDIF
			This.cClosing = ""
		ELSE
			IF VARTYPE(This.oForm) == "O"
				=This.Load(.T.)
			ENDIF
		ENDIF
	ENDPROC
ENDDEFINE


*------------------------------------------------------------------
* La ventana FoxDock - Queries, modeless como Explore... de data: la carpeta,
* la lista con su filtro, el panel de la consulta elegida y los botones.
*------------------------------------------------------------------
DEFINE CLASS QueriesForm AS Form
	AutoCenter = .T.
	MinButton = .F.
	MaxButton = .T.
	ShowWindow = 0
	WindowType = 0
	BorderStyle = 3
	*-- 850 de ancho: con Delete en la fila de botones, «Nueva consulta...» y
	*-- «Generar catálogo...» se cortaban en español con menos.
	Width = 850
	Height = 470
	MinWidth = 850
	MinHeight = 470
	Name = "FoxDockQueries"
	oModule = .NULL.

	ADD OBJECT lblFolder AS Label WITH Caption = "Folder:", Left = 10, Top = 14, AutoSize = .T.
	*-- Change...: la carpeta para todos los IDE.
	ADD OBJECT txtFolder AS TextBox WITH Left = 70, Top = 10, Width = 414, Height = 24, ReadOnly = .T., Anchor = 11
	ADD OBJECT cmdChangeFolder AS CommandButton WITH Caption = "Change...", Left = 490, Top = 9, Width = 90, Height = 26, Anchor = 9
	ADD OBJECT cmdOpenFolder AS CommandButton WITH Caption = "Open folder", Left = 586, Top = 9, Width = 90, Height = 26, Anchor = 9
	*-- Run on: sin el módulo run, el motor fijo en una etiqueta; con él, el combo.
	ADD OBJECT lblEngine AS Label WITH Caption = "Run on: vfp", Left = 686, Top = 14, Width = 154, Height = 18, Anchor = 9
	ADD OBJECT cboRunOn AS ComboBox WITH Left = 686, Top = 10, Width = 154, Height = 24, Style = 2, Anchor = 9, Visible = .F., ;
		ColumnCount = 2, ColumnWidths = "300,0"
	ADD OBJECT lblFilter AS Label WITH Caption = "Filter:", Left = 10, Top = 46, AutoSize = .T.
	ADD OBJECT txtFilter AS TextBox WITH Left = 70, Top = 42, Width = 220, Height = 24, Value = ""
	ADD OBJECT lblCount AS Label WITH Caption = "", Left = 300, Top = 46, Width = 540, Height = 18, Anchor = 11
	ADD OBJECT lstQueries AS ListBox WITH Left = 10, Top = 74, Width = 290, Height = 310, ColumnCount = 2, ;
		ColumnWidths = "220,50", Anchor = 7
	ADD OBJECT edtPanel AS EditBox WITH Left = 308, Top = 74, Width = 532, Height = 310, ReadOnly = .T., ScrollBars = 2, ;
		Value = "", Anchor = 15
	ADD OBJECT cmdEdit AS CommandButton WITH Caption = "Edit", Left = 10, Top = 392, Width = 80, Height = 28, Anchor = 6
	ADD OBJECT cmdDelete AS CommandButton WITH Caption = "Delete", Left = 96, Top = 392, Width = 80, Height = 28, Anchor = 6
	ADD OBJECT cmdRun AS CommandButton WITH Caption = "Run...", Left = 182, Top = 392, Width = 84, Height = 28, Anchor = 6, Visible = .F.
	*-- SQL for engine, con su flecha pegada para que se vea que abre un menú:
	*-- las dos mitades lo abren. La flecha, la «6» de Marlett.
	ADD OBJECT cmdSql AS CommandButton WITH Caption = "SQL for engine", Left = 272, Top = 392, Width = 114, Height = 28, Anchor = 6
	ADD OBJECT cmdSqlMenu AS CommandButton WITH Caption = "6", FontName = "Marlett", FontSize = 9, Left = 386, Top = 392, Width = 20, ;
		Height = 28, Anchor = 6
	ADD OBJECT cmdCheck AS CommandButton WITH Caption = "Check", Left = 412, Top = 392, Width = 80, Height = 28, Anchor = 6
	ADD OBJECT cmdNew AS CommandButton WITH Caption = "New query...", Left = 498, Top = 392, Width = 110, Height = 28, Anchor = 6
	ADD OBJECT cmdBuild AS CommandButton WITH Caption = "Build catalog...", Left = 614, Top = 392, Width = 120, Height = 28, Anchor = 6, Visible = .F.
	ADD OBJECT cmdReload AS CommandButton WITH Caption = "Reload", Left = 740, Top = 392, Width = 80, Height = 28, Anchor = 6
	ADD OBJECT lblSay AS Label WITH Caption = "", Left = 10, Top = 428, Width = 640, Height = 34, WordWrap = .T., Anchor = 14
	*-- Help: la sección de la ventana en el manual, en el idioma de FoxDock.
	ADD OBJECT cmdHelp AS CommandButton WITH Caption = "Help", Left = 660, Top = 432, Width = 90, Height = 28, Anchor = 12
	ADD OBJECT cmdClose AS CommandButton WITH Caption = "Close", Left = 760, Top = 432, Width = 80, Height = 28, Cancel = .T., Anchor = 12

	PROCEDURE Init
		LPARAMETERS toModule
		This.oModule = toModule
		This.Texts()
		This.Refill()
	ENDPROC

	PROCEDURE Destroy
		IF VARTYPE(This.oModule) == "O"
			This.oModule.FormGone()
		ENDIF
		This.oModule = .NULL.
	ENDPROC

	PROCEDURE Texts
		LOCAL loM
		loM = This.oModule
		This.Caption = loM.T("queries.window.title")
		This.lblFolder.Caption = loM.T("queries.window.folder")
		This.cmdOpenFolder.Caption = loM.T("queries.window.openFolder")
		This.cmdChangeFolder.Caption = loM.T("queries.window.changeFolder")
		This.lblEngine.Caption = loM.T("queries.window.runOn", loM.cEngine)
		This.lblFilter.Caption = loM.T("queries.window.filter")
		This.cmdEdit.Caption = loM.T("queries.window.edit")
		This.cmdDelete.Caption = loM.T("queries.window.delete")
		This.cmdSql.Caption = loM.T("queries.window.sql")
		This.cmdCheck.Caption = loM.T("queries.window.check")
		This.cmdNew.Caption = loM.T("queries.window.new")
		This.cmdReload.Caption = loM.T("queries.window.reload")
		This.cmdClose.Caption = loM.T("queries.window.close")
		This.cmdHelp.Caption = loM.T("queries.window.help")
		This.cmdRun.Caption = loM.T("queries.window.run")
		This.cmdBuild.Caption = loM.T("queries.window.build")
		This.cmdBuild.Visible = !ISNULL(loM.BuildModule())
		This.FillRunOn()
		This.CountText()
	ENDPROC

	*-- Con el módulo run, el combo Run on y el botón Run...; sin él, la
	*-- etiqueta del motor fijo.
	PROCEDURE FillRunOn
		LOCAL loRun, loX, lnI
		loRun = This.oModule.RunModule()
		This.lblEngine.Visible = ISNULL(loRun)
		This.cboRunOn.Visible = !ISNULL(loRun)
		This.cmdRun.Visible = !ISNULL(loRun)
		IF ISNULL(loRun)
			RETURN
		ENDIF
		This.cboRunOn.Clear()
		lnI = 0
		loList = loRun.Executors()
		FOR EACH loX IN loList FOXOBJECT
			lnI = lnI + 1
			This.cboRunOn.AddItem(loX.cCaption)
			This.cboRunOn.List(lnI, 2) = loX.cKey
			IF loX.cKey == loRun.cOn
				This.cboRunOn.ListIndex = lnI
			ENDIF
		ENDFOR
		IF This.cboRunOn.ListIndex < 1 AND This.cboRunOn.ListCount > 0
			This.cboRunOn.ListIndex = 1
		ENDIF
	ENDPROC

	PROCEDURE cboRunOn.InteractiveChange
		LOCAL loRun
		loRun = Thisform.oModule.RunModule()
		IF !ISNULL(loRun) AND This.ListIndex > 0
			=loRun.RunOnBar(This.List(This.ListIndex, 2))
		ENDIF
	ENDPROC

	PROCEDURE cmdBuild.Click
		LOCAL loB
		loB = Thisform.oModule.BuildModule()
		IF !ISNULL(loB)
			=loB.OpenBuild()
		ENDIF
	ENDPROC

	PROCEDURE cmdRun.Click
		LOCAL loRun
		loRun = Thisform.oModule.RunModule()
		IF !ISNULL(loRun) AND !EMPTY(Thisform.Chosen())
			=loRun.OpenRun(Thisform.Chosen())
		ENDIF
	ENDPROC

	*-- Lo leído de la carpeta, a la lista (con el filtro), y el panel.
	PROCEDURE Refill
		LOCAL loM, lcWas
		loM = This.oModule
		lcWas = This.Chosen()
		This.txtFolder.Value = loM.Folder()
		IF !loM.lLoaded
			This.lstQueries.Clear()
			This.edtPanel.Value = ""
			This.lblSay.Caption = loM.T("queries.window.noFolder", loM.Folder())
			This.CountText()
			This.ButtonStates()
			RETURN
		ENDIF
		This.lblSay.Caption = ""
		This.ApplyFilter(lcWas)
	ENDPROC

	PROCEDURE ApplyFilter
		LPARAMETERS tcKeep
		LOCAL loM, loE, lcF, lnRow
		loM = This.oModule
		This.lstQueries.Clear()
		lcF = LOWER(ALLTRIM(This.txtFilter.Value))
		IF loM.lLoaded
			FOR EACH loE IN loM.oResult.oEntries FOXOBJECT
				IF EMPTY(lcF) OR lcF $ LOWER(loE.cName)
					This.lstQueries.AddItem(IIF(loE.lBroken, "! ", "") + loE.cName)
					lnRow = This.lstQueries.NewIndex
					This.lstQueries.List(lnRow, 2) = loE.cKind
					IF !EMPTY(tcKeep) AND LOWER(loE.cName) == LOWER(tcKeep)
						This.lstQueries.ListIndex = lnRow
					ENDIF
				ENDIF
			ENDFOR
		ENDIF
		IF This.lstQueries.ListIndex < 1 AND This.lstQueries.ListCount > 0
			This.lstQueries.ListIndex = 1
		ENDIF
		This.CountText()
		This.ShowPanel()
	ENDPROC

	PROCEDURE CountText
		LOCAL loM
		loM = This.oModule
		This.lblCount.Caption = IIF(loM.lLoaded, loM.T("queries.window.count", This.lstQueries.ListCount, ;
			loM.oResult.oEntries.Count), "")
	ENDPROC

	*-- La consulta elegida, sin el «! » de una rota; "" si ninguna.
	PROCEDURE Chosen
		IF This.lstQueries.ListIndex < 1
			RETURN ""
		ENDIF
		RETURN ALLTRIM(STRTRAN(This.lstQueries.List(This.lstQueries.ListIndex, 1), "! ", "", 1, 1))
	ENDPROC

	*-- Elige una por su nombre (los casos, y el agente).
	PROCEDURE SelectQuery
		LPARAMETERS tcName
		LOCAL lnI
		FOR lnI = 1 TO This.lstQueries.ListCount
			IF LOWER(ALLTRIM(STRTRAN(This.lstQueries.List(lnI, 1), "! ", "", 1, 1))) == LOWER(tcName)
				This.lstQueries.ListIndex = lnI
				This.ShowPanel()
				RETURN .T.
			ENDIF
		ENDFOR
		RETURN .F.
	ENDPROC

	PROCEDURE ShowPanel
		This.edtPanel.Value = This.oModule.PanelText(This.Chosen())
		This.ButtonStates()
	ENDPROC

	*-- Cada botón, encendido solo si tiene algo que hacer:
	*-- Edit y Delete, con una consulta elegida (también una rota: se arregla o se
	*-- borra); Run... y SQL for engine >, con una que carga; Check, con algún .sql;
	*-- Build catalog..., con alguna consulta cargada; Open folder, con la carpeta.
	*-- New query..., Reload y Close, siempre.
	PROCEDURE ButtonStates
		LOCAL loM, loE, llChosen, llLoads
		loM = This.oModule
		loE = IIF(EMPTY(This.Chosen()), .NULL., loM.Entry(This.Chosen()))
		llChosen = !ISNULL(loE)
		llLoads = llChosen AND !loE.lBroken
		This.cmdEdit.Enabled = llChosen
		This.cmdDelete.Enabled = llChosen
		This.cmdRun.Enabled = llLoads
		This.cmdSql.Enabled = llLoads
		This.cmdSqlMenu.Enabled = llLoads
		This.cmdCheck.Enabled = loM.lLoaded AND loM.oResult.oEntries.Count > 0
		This.cmdBuild.Enabled = loM.lLoaded AND loM.oResult.nQueries > 0
		This.cmdOpenFolder.Enabled = DIRECTORY(loM.Folder(), 1)
	ENDPROC

	*-- Delete: la pregunta (AskDelete, su ventanita); lo que no se puede borrar, al pie.
	PROCEDURE cmdDelete.Click
		LOCAL loM, lcName
		loM = Thisform.oModule
		lcName = Thisform.Chosen()
		IF EMPTY(lcName)
			RETURN
		ENDIF
		IF loM.AskDelete(lcName)
			Thisform.lblSay.Caption = ""
		ELSE
			Thisform.lblSay.Caption = loM.cLastSaid
		ENDIF
	ENDPROC

	PROCEDURE lstQueries.InteractiveChange
		Thisform.ShowPanel()
	ENDPROC

	PROCEDURE lstQueries.KeyPress
		LPARAMETERS nKeyCode, nShiftAltCtrl
		IF nKeyCode = 13
			NODEFAULT
			Thisform.cmdEdit.Click()
		ENDIF
	ENDPROC

	PROCEDURE lstQueries.DblClick
		Thisform.cmdEdit.Click()
	ENDPROC

	PROCEDURE txtFilter.InteractiveChange
		Thisform.ApplyFilter(Thisform.Chosen())
	ENDPROC

	PROCEDURE txtFilter.KeyPress
		LPARAMETERS nKeyCode, nShiftAltCtrl
		IF nKeyCode = 13
			NODEFAULT
			Thisform.lstQueries.SetFocus()
		ENDIF
	ENDPROC

	PROCEDURE cmdEdit.Click
		IF !EMPTY(Thisform.Chosen())
			=Thisform.oModule.EditQuery(Thisform.Chosen())
		ENDIF
	ENDPROC

	PROCEDURE cmdSqlMenu.Click
		Thisform.cmdSql.Click()
	ENDPROC

	*-- SQL for engine: un menú en el sitio, con los siete motores y todos.
	PROCEDURE cmdSql.Click
		LOCAL lcName, lcList, lnI, lnBar
		lcName = Thisform.Chosen()
		IF EMPTY(lcName)
			RETURN
		ENDIF
		lcList = Thisform.oModule.Engines()
		DEFINE POPUP popFDQSql SHORTCUT RELATIVE FROM MROW(), MCOL()
		FOR lnI = 1 TO GETWORDCOUNT(lcList, ",")
			DEFINE BAR lnI OF popFDQSql PROMPT GETWORDNUM(lcList, lnI, ",")
		ENDFOR
		DEFINE BAR lnI OF popFDQSql PROMPT "\-"
		DEFINE BAR lnI + 1 OF popFDQSql PROMPT Thisform.oModule.T("queries.window.allEngines")
		ON SELECTION POPUP popFDQSql DEACTIVATE POPUP popFDQSql
		ACTIVATE POPUP popFDQSql
		lnBar = BAR()
		RELEASE POPUPS popFDQSql
		DO CASE
			CASE lnBar >= 1 AND lnBar <= GETWORDCOUNT(lcList, ",")
				=Thisform.oModule.ShowSql(lcName, GETWORDNUM(lcList, lnBar, ","))
			CASE lnBar = GETWORDCOUNT(lcList, ",") + 2
				=Thisform.oModule.ShowSql(lcName, "all")
		ENDCASE
	ENDPROC

	PROCEDURE cmdCheck.Click
		=Thisform.oModule.CheckFolder()
	ENDPROC

	PROCEDURE cmdNew.Click
		=Thisform.oModule.OpenNew()
	ENDPROC

	PROCEDURE cmdReload.Click
		=Thisform.oModule.Reload()
	ENDPROC

	*-- Open folder: la carpeta en el Explorador de Windows (ShellExecute), o lo
	*-- dice si no existe.
	PROCEDURE cmdOpenFolder.Click
		LOCAL lcDir
		lcDir = Thisform.oModule.Folder()
		IF !DIRECTORY(lcDir, 1)
			Thisform.lblSay.Caption = Thisform.oModule.T("queries.window.noFolder", lcDir)
			RETURN
		ENDIF
		DECLARE INTEGER ShellExecute IN shell32 AS FdQueriesShellExecute INTEGER hWnd, STRING cOperation, STRING cFile, ;
			STRING cParameters, STRING cDirectory, INTEGER nShowCmd
		IF !(LOWER(GETENV("FOXDOCK_SHELL_OPEN")) == "off")
			=FdQueriesShellExecute(_screen.HWnd, "open", lcDir, "", lcDir, 1)
		ENDIF
		Thisform.oModule.oHost.Log("queries: " + lcDir + " opened with Windows")
	ENDPROC

	PROCEDURE cmdHelp.Click
		=Thisform.oModule.ShowHelp("queries.help.anchor")
	ENDPROC

	PROCEDURE cmdChangeFolder.Click
		LOCAL lcDir
		lcDir = Thisform.oModule.PickFolder()
		IF !EMPTY(lcDir)
			=Thisform.oModule.SetFolder(lcDir)
		ENDIF
	ENDPROC

	PROCEDURE cmdClose.Click
		Thisform.Release()
	ENDPROC
ENDDEFINE


*------------------------------------------------------------------
* New query...: el nombre, read o write, la descripción, y Make.
*------------------------------------------------------------------
DEFINE CLASS QueriesNewForm AS Form
	AutoCenter = .T.
	MinButton = .F.
	MaxButton = .F.
	ShowWindow = 0
	WindowType = 0
	BorderStyle = 2
	Width = 460
	Height = 270
	Name = "FoxDockQueriesNew"
	oModule = .NULL.

	ADD OBJECT lblName AS Label WITH Caption = "Name:", Left = 10, Top = 14, AutoSize = .T.
	ADD OBJECT txtName AS TextBox WITH Left = 110, Top = 10, Width = 340, Height = 24, Value = "", MaxLength = 120
	ADD OBJECT lblKind AS Label WITH Caption = "Kind:", Left = 10, Top = 46, AutoSize = .T.
	ADD OBJECT optKind AS OptionGroup WITH Left = 106, Top = 40, Width = 200, Height = 28, ButtonCount = 2, BorderStyle = 0, Value = 1
	*-- La descripción, en un cuadro de varias líneas para escribirla y leerla.
	*-- Al .sql va en una sola (MakeQuery, OneLine).
	ADD OBJECT lblDescription AS Label WITH Caption = "Description:", Left = 10, Top = 80, AutoSize = .T.
	ADD OBJECT edtDescription AS EditBox WITH Left = 110, Top = 76, Width = 340, Height = 62, Value = "", MaxLength = 250, ScrollBars = 2
	ADD OBJECT edtSay AS EditBox WITH Left = 10, Top = 148, Width = 440, Height = 76, ReadOnly = .T., ScrollBars = 2, Value = ""
	*-- Help: cómo se escribe una consulta, con parámetros y con
	*-- tabla o base de datos variables.
	ADD OBJECT cmdHelp AS CommandButton WITH Caption = "Help", Left = 10, Top = 234, Width = 90, Height = 28
	ADD OBJECT cmdMake AS CommandButton WITH Caption = "Make", Left = 280, Top = 234, Width = 80, Height = 28, Default = .T.
	ADD OBJECT cmdClose AS CommandButton WITH Caption = "Close", Left = 370, Top = 234, Width = 80, Height = 28, Cancel = .T.

	PROCEDURE Init
		LPARAMETERS toModule
		LOCAL loM
		This.oModule = toModule
		loM = toModule
		This.Caption = loM.T("queries.new.title")
		This.lblName.Caption = loM.T("queries.new.name")
		This.lblKind.Caption = loM.T("queries.new.kind")
		This.lblDescription.Caption = loM.T("queries.new.description")
		This.cmdMake.Caption = loM.T("queries.new.make")
		This.cmdHelp.Caption = loM.T("queries.window.help")
		This.cmdClose.Caption = loM.T("queries.window.close")
		This.optKind.Buttons(1).Caption = "read"
		This.optKind.Buttons(2).Caption = "write"
		This.optKind.Buttons(1).AutoSize = .T.
		This.optKind.Buttons(2).AutoSize = .T.
		*-- Los dos en la misma fila: el OptionGroup los pone uno debajo de otro, y el
		*-- segundo quedaba cortado por la altura del grupo.
		This.optKind.Buttons(1).Top = 5
		This.optKind.Buttons(2).Top = 5
		This.optKind.Buttons(1).Left = 5
		This.optKind.Buttons(2).Left = 80
		This.edtSay.Value = loM.T("queries.new.where", loM.Folder())
	ENDPROC

	PROCEDURE Destroy
		IF VARTYPE(This.oModule) == "O"
			This.oModule.NewFormGone()
		ENDIF
		This.oModule = .NULL.
	ENDPROC

	PROCEDURE cmdHelp.Click
		=Thisform.oModule.ShowHelp("queries.help.write.anchor")
	ENDPROC

	*-- Hecha, la ventanita se cierra y lo dice la ventana
	*-- FoxDock - Queries, o el aviso (MakeQuery); si no, su panel dice por qué.
	PROCEDURE cmdMake.Click
		IF Thisform.oModule.MakeQuery(Thisform.txtName.Value, IIF(Thisform.optKind.Value = 2, "write", "read"), ;
				Thisform.edtDescription.Value)
			Thisform.Release()
			RETURN
		ENDIF
		Thisform.edtSay.Value = Thisform.oModule.cLastSaid
	ENDPROC

	PROCEDURE cmdClose.Click
		Thisform.Release()
	ENDPROC
ENDDEFINE


*------------------------------------------------------------------
* FoxDock - Check: lo que dijo
* CheckFolder (oChecks del módulo). Arriba, el resumen y la carpeta; la lista,
* una fila por error o aviso (tipo, consulta, línea, código); debajo, el motivo
* entero de la elegida y su fichero. Edit (o doble clic, o Intro): el .sql en esa
* línea. Check again: la carpeta otra vez. Modeless, sin diálogos.
*------------------------------------------------------------------
DEFINE CLASS QueriesCheckForm AS Form
	AutoCenter = .T.
	MinButton = .F.
	MaxButton = .T.
	ShowWindow = 0
	WindowType = 0
	BorderStyle = 3
	Width = 720
	Height = 400
	MinWidth = 560
	MinHeight = 320
	Name = "FoxDockQueriesCheck"
	oModule = .NULL.

	ADD OBJECT lblSummary AS Label WITH Caption = "", Left = 10, Top = 10, Width = 700, Height = 18, FontBold = .T., Anchor = 11
	ADD OBJECT lblWhere AS Label WITH Caption = "", Left = 10, Top = 30, Width = 700, Height = 18, Anchor = 11
	ADD OBJECT lblHeadWhat AS Label WITH Caption = "Type", Left = 14, Top = 56, Width = 76, Height = 16
	ADD OBJECT lblHeadQuery AS Label WITH Caption = "Query", Left = 94, Top = 56, Width = 256, Height = 16
	ADD OBJECT lblHeadLine AS Label WITH Caption = "Line", Left = 354, Top = 56, Width = 56, Height = 16
	ADD OBJECT lblHeadCode AS Label WITH Caption = "Code", Left = 414, Top = 56, Width = 290, Height = 16
	ADD OBJECT lstChecks AS ListBox WITH Left = 10, Top = 74, Width = 700, Height = 180, ColumnCount = 4, ;
		ColumnWidths = "80,260,60,280", ColumnLines = .T., Anchor = 15
	ADD OBJECT edtWhy AS EditBox WITH Left = 10, Top = 262, Width = 700, Height = 86, ReadOnly = .T., ScrollBars = 2, Value = "", ;
		Anchor = 14
	ADD OBJECT cmdEdit AS CommandButton WITH Caption = "Edit", Left = 10, Top = 360, Width = 90, Height = 28, Anchor = 6
	ADD OBJECT cmdAgain AS CommandButton WITH Caption = "Check again", Left = 106, Top = 360, Width = 130, Height = 28, Anchor = 6
	ADD OBJECT cmdClose AS CommandButton WITH Caption = "Close", Left = 620, Top = 360, Width = 90, Height = 28, Cancel = .T., Anchor = 12

	PROCEDURE Init
		LPARAMETERS toModule
		LOCAL loM
		This.oModule = toModule
		loM = toModule
		This.Caption = loM.T("queries.checkw.title")
		This.lblHeadWhat.Caption = loM.T("queries.checkw.what")
		This.lblHeadQuery.Caption = loM.T("queries.checkw.query")
		This.lblHeadLine.Caption = loM.T("queries.checkw.line")
		This.lblHeadCode.Caption = loM.T("queries.checkw.code")
		This.cmdEdit.Caption = loM.T("queries.window.edit")
		This.cmdAgain.Caption = loM.T("queries.checkw.again")
		This.cmdClose.Caption = loM.T("queries.window.close")
	ENDPROC

	PROCEDURE Destroy
		IF VARTYPE(This.oModule) == "O"
			This.oModule.CheckFormGone()
		ENDIF
		This.oModule = .NULL.
	ENDPROC

	*-- Lo último de Check, a la lista; la primera fila, elegida.
	PROCEDURE Fill
		LOCAL loM, loC, lnRow
		loM = This.oModule
		This.lstChecks.Clear()
		IF VARTYPE(loM.oChecks) == "O"
			FOR EACH loC IN loM.oChecks FOXOBJECT
				This.lstChecks.AddItem(loM.T("queries.checkw." + loC.cWhat))
				lnRow = This.lstChecks.NewIndex
				This.lstChecks.List(lnRow, 2) = loC.cQuery
				This.lstChecks.List(lnRow, 3) = IIF(loC.nLine > 0, TRANSFORM(loC.nLine), "")
				This.lstChecks.List(lnRow, 4) = loC.cCode
			ENDFOR
		ENDIF
		This.lblSummary.Caption = loM.cLastSaid
		This.lblWhere.Caption = loM.T("queries.checkw.where", loM.oResult.oEntries.Count, loM.Folder())
		IF This.lstChecks.ListCount > 0
			This.lstChecks.ListIndex = 1
		ENDIF
		This.ShowWhy()
	ENDPROC

	*-- El motivo entero de la fila elegida, con su consulta, su línea y su fichero.
	PROCEDURE ShowWhy
		LOCAL loM, loC, lnRow
		loM = This.oModule
		lnRow = This.lstChecks.ListIndex
		IF lnRow < 1 OR VARTYPE(loM.oChecks) # "O" OR lnRow > loM.oChecks.Count
			This.edtWhy.Value = ""
			This.cmdEdit.Enabled = .F.
			RETURN
		ENDIF
		loC = loM.oChecks.Item(lnRow)
		This.edtWhy.Value = loM.T("queries.checkw.at", loM.T("queries.checkw." + loC.cWhat), loC.cQuery, loC.nLine, loC.cCode) + ;
			CHR(13) + CHR(10) + loC.cText + CHR(13) + CHR(10) + CHR(13) + CHR(10) + loC.cFile
		This.cmdEdit.Enabled = .T.
	ENDPROC

	PROCEDURE lstChecks.InteractiveChange
		Thisform.ShowWhy()
	ENDPROC

	PROCEDURE lstChecks.DblClick
		Thisform.cmdEdit.Click()
	ENDPROC

	PROCEDURE lstChecks.KeyPress
		LPARAMETERS nKeyCode, nShiftAltCtrl
		IF nKeyCode = 13
			NODEFAULT
			Thisform.cmdEdit.Click()
		ENDIF
	ENDPROC

	PROCEDURE cmdEdit.Click
		=Thisform.oModule.OpenCheck(Thisform.lstChecks.ListIndex)
	ENDPROC

	PROCEDURE cmdAgain.Click
		=Thisform.oModule.CheckFolder()
	ENDPROC

	PROCEDURE cmdClose.Click
		Thisform.Release()
	ENDPROC
ENDDEFINE


*------------------------------------------------------------------
* FoxDock - Delete query: la pregunta de Delete. La
* consulta, su fichero y adónde va; Delete, y Cancel, que es el de Intro y Esc y
* tiene el foco: un clic sin querer en Delete de la ventana no borra nada. No es
* un MESSAGEBOX: modeless, encima de las demás, y se contesta con sus
* botones (los casos y el agente, igual).
*------------------------------------------------------------------
DEFINE CLASS QueriesDeleteForm AS Form
	AutoCenter = .T.
	MinButton = .F.
	MaxButton = .F.
	ShowWindow = 0
	WindowType = 0
	BorderStyle = 2
	AlwaysOnTop = .T.
	Width = 440
	Height = 150
	Name = "FoxDockQueriesDelete"
	oModule = .NULL.
	cName = ""

	ADD OBJECT lblAsk AS Label WITH Caption = "", Left = 10, Top = 12, Width = 420, Height = 18, FontBold = .T.
	ADD OBJECT lblWhat AS Label WITH Caption = "", Left = 10, Top = 38, Width = 420, Height = 64, WordWrap = .T.
	ADD OBJECT cmdYes AS CommandButton WITH Caption = "Delete", Left = 250, Top = 112, Width = 85, Height = 28
	ADD OBJECT cmdNo AS CommandButton WITH Caption = "Cancel", Left = 345, Top = 112, Width = 85, Height = 28, Cancel = .T., Default = .T.

	PROCEDURE Init
		LPARAMETERS toModule
		This.oModule = toModule
		This.Caption = toModule.T("queries.delete.title")
	ENDPROC

	PROCEDURE Destroy
		IF VARTYPE(This.oModule) == "O"
			This.oModule.DeleteFormGone()
		ENDIF
		This.oModule = .NULL.
	ENDPROC

	*-- La pregunta, para esa consulta (otra vez Delete con otra elegida: la de esa).
	PROCEDURE Ask
		LPARAMETERS tcName, tcFile
		LOCAL loM
		loM = This.oModule
		This.cName = tcName
		This.lblAsk.Caption = loM.T("queries.delete.ask", tcName)
		This.lblWhat.Caption = loM.T("queries.delete.what", tcFile)
		This.cmdYes.Caption = loM.T("queries.delete.yes")
		This.cmdNo.Caption = loM.T("queries.delete.no")
		This.cmdYes.Visible = .T.
	ENDPROC

	*-- Borrada, se cierra (el pie de la ventana lo dice); si Windows no pudo, lo dice
	*-- aquí y queda Close.
	PROCEDURE cmdYes.Click
		LOCAL loM
		loM = Thisform.oModule
		IF loM.DeleteQuery(Thisform.cName)
			Thisform.Release()
			RETURN
		ENDIF
		Thisform.lblWhat.Caption = loM.cLastSaid
		This.Visible = .F.
		Thisform.cmdNo.Caption = loM.T("queries.window.close")
	ENDPROC

	PROCEDURE cmdNo.Click
		Thisform.Release()
	ENDPROC
ENDDEFINE
