*==================================================================
* QueriesRun.prg: el módulo «run» del paquete «queries» de FoxDock.
*
*   Queries >  Run...          la ventanita de parámetros de la consulta elegida
*                              en la ventana FoxDock - Queries (QueriesRunForm)
*              Run on >        una barra por ejecutor, marcada la elegida
*   tools      ide_queries_run (lee, cualquier rol) e ide_queries_execute
*              (actúa, rol 10 o más), en QueriesTools.prg
*
* LOS EJECUTORES, por su clave:
*   dbf          las tablas DBF de la sesión de datos 1 (QueryLocal, motor vfp)
*   conn:<id>    una conexión de data > Connections (DataConnections.Find para
*                el motor y las banderas, Live para el objeto de FoxRemote); la
*                no conectada sale en la lista, y elegida lleva a su Connect...
*   handle:<n>   un handle de ASQLHANDLES() abierto por el usuario (QueryOdbc; el
*                motor lo pregunta al driver)
* Sin el módulo connections de data quedan DBF y los handles. El elegido vale
* para la sesión del IDE (cOn), no va a config.json.
*
* EL PAQUETE REPONE LA SESIÓN 1, porque la copia de FoxQuery no repone
* SELECT() ni los punteros: alrededor de cada llamada se guardan y se reponen
* el área seleccionada, el puntero de cada tabla abierta en la sesión 1 y SET
* DELETED, ANSI, EXACT y TABLEPROMPT, como DataTable.
*
* EL TOPE: sobre ODBC y FoxRemote, CURSORSETPROP("MaxRecords", n + 1)
* en la sesión 1 alrededor de Run, y repuesto; sobre DBF, el corte después. La
* fila de más dice truncated y no se queda en el cursor.
*
* EL AGENTE NUNCA MANDA SQL: solo el nombre de una consulta y sus
* parámetros. Para él, el texto que resuelve FoxQuery pasa además por la guarda
* del plugin (QueriesSqlGuard, abajo: Check para leer, CheckWrite para escribir) antes
* de ejecutarse, y una conexión de data necesita agentCanRead (y allowWrite
* para escribir), como las ide_data_db_*.
*
* Ningún diálogo: la confirmación de una write y las negativas, en la
* ventanita.
*==================================================================

#DEFINE CRLF CHR(13) + CHR(10)

DEFINE CLASS QueriesRun AS Custom
	cId = "run"
	oHost = .NULL.
	oForm = .NULL.          && la ventanita de Run..., una sola
	cOn = "dbf"             && el ejecutor elegido (la sesión del IDE)
	lShow = .T.             && .F.: ni ventanas ni BROWSE (los casos)
	cLastError = ""
	cLastCode = ""
	cLastSaid = ""
	cLastCursor = ""
	cLastTitle = ""
	cLastEngine = ""
	nLastRows = 0
	nLastTotal = 0
	lLastTruncated = .F.
	nLastAffected = -1
	vLastValue = .NULL.
	lLastScalar = .F.

	PROCEDURE Init
		LPARAMETERS toHost
		This.oHost = toHost
	ENDPROC

	PROCEDURE Destroy
		This.CloseAll()
	ENDPROC

	PROCEDURE CloseAll
		LOCAL loErr
		TRY
			IF VARTYPE(This.oForm) == "O"
				This.oForm.oModule = .NULL.
				This.oForm.Release()
			ENDIF
		CATCH TO loErr
		ENDTRY
		This.oForm = .NULL.
	ENDPROC

	PROCEDURE FormGone
		This.oForm = .NULL.
	ENDPROC

	PROCEDURE Plugin
		RETURN This.oHost.PluginById("queries")
	ENDPROC

	PROCEDURE Catalog
		LOCAL loP
		loP = This.Plugin()
		RETURN IIF(ISNULL(loP), .NULL., loP.Module("catalog"))
	ENDPROC

	*-- El módulo connections de data, o .NULL. (apagado, o data sin cargar).
	PROCEDURE Conns
		LOCAL loD
		loD = This.oHost.PluginById("data")
		RETURN IIF(ISNULL(loD), .NULL., loD.Module("connections"))
	ENDPROC

	PROCEDURE T
		LPARAMETERS tcKey, tv1, tv2, tv3, tv4
		RETURN This.oHost.Translate(tcKey, tv1, tv2, tv3, tv4)
	ENDPROC

	PROCEDURE E
		LPARAMETERS tcKey, tv1, tv2, tv3, tv4
		RETURN This.oHost.TranslateEn(tcKey, tv1, tv2, tv3, tv4)
	ENDPROC

	PROCEDURE CopyFile
		LOCAL loP
		loP = This.Plugin()
		RETURN loP.CodeFile("lib\foxquery\foxquery.prg")
	ENDPROC

	*-- El fichero de QueriesSqlGuard (este), en la caché del código.
	PROCEDURE GuardFile
		LOCAL loP
		loP = This.Plugin()
		RETURN loP.CodeFile("QueriesRun.prg")
	ENDPROC

	*-- Las barras: «run», Run... (detrás de New query...); «runon», un separador
	*-- y Run on > (detrás de Check). El paquete las pide en ese orden.
	PROCEDURE FillMenuPart
		LPARAMETERS tcPopup, tnBar, tcPart
		LOCAL loP, loX, lnI, lcSub, loList, lcCmd
		loP = This.Plugin()
		DO CASE
			CASE tcPart == "run"
				tnBar = loP.DefineBar(tcPopup, tnBar + 1, This.T("queries.bar.run"), "RunBar", "", This.T("queries.bar.run.message"))
			CASE tcPart == "runon"
				tnBar = loP.DefineBar(tcPopup, tnBar + 1, "", "", "", "")
				lcSub = tcPopup + "R"
				tnBar = loP.DefineSubmenu(tcPopup, tnBar + 1, This.T("queries.bar.runOn"), lcSub)
				loList = This.Executors()
				lnI = 0
				FOR EACH loX IN loList FOXOBJECT
					lnI = lnI + 1
					=loP.DefineBar(lcSub, lnI, CHRTRAN(loX.cCaption, "[]\", "()/"), "RunOnBar", loX.cKey, This.T("queries.bar.runOn.message", loX.cCaption))
					IF loX.cKey == This.cOn
						lcCmd = "SET MARK OF BAR " + TRANSFORM(lnI) + " OF " + lcSub + " TO .T."
						&lcCmd
					ENDIF
				ENDFOR
		ENDCASE
		RETURN tnBar
	ENDPROC

	PROCEDURE GetAgentTools
		LPARAMETERS toTools
		IF ISNULL(This.Catalog())
			RETURN 0
		ENDIF
		toTools.Add(CREATEOBJECT("IdeQueriesRunTool"))
		toTools.Add(CREATEOBJECT("IdeQueriesExecuteTool"))
		RETURN 2
	ENDPROC

	*--------------------------------------------------------------
	* Los ejecutores.
	*--------------------------------------------------------------
	PROCEDURE Executors
		LOCAL loList, loX, loC, loConn, lnH, lnI, loOdbc
		LOCAL ARRAY laH[1]
		loList = CREATEOBJECT("Collection")
		loList.Add(This.NewExec("dbf", This.T("queries.runOn.dbf"), "vfp", "dbf"))
		loC = This.Conns()
		IF !ISNULL(loC)
			FOR EACH loConn IN loC.oList FOXOBJECT
				loList.Add(This.NewExec("conn:" + loConn.cId, loConn.cName + " (" + loConn.cEngine + ")" + ;
					IIF(loC.IsConnected(loConn.cId), "", This.T("queries.runOn.notConnected")), loConn.cEngine, "conn"))
			ENDFOR
		ENDIF
		lnH = ASQLHANDLES(laH)
		FOR lnI = 1 TO lnH
			loOdbc = NEWOBJECT("QueryOdbc", This.CopyFile(), "", laH[lnI])
			loList.Add(This.NewExec("handle:" + TRANSFORM(laH[lnI]), This.T("queries.runOn.handle", laH[lnI], ;
				EVL(loOdbc.cDriver, "?") + IIF(EMPTY(loOdbc.cEngine), "", ", " + loOdbc.cEngine)), loOdbc.cEngine, "handle"))
		ENDFOR
		RETURN loList
	ENDPROC

	PROTECTED PROCEDURE NewExec
		LPARAMETERS tcKey, tcCaption, tcEngine, tcKind
		LOCAL loX
		loX = CREATEOBJECT("Empty")
		ADDPROPERTY(loX, "cKey", tcKey)
		ADDPROPERTY(loX, "cCaption", tcCaption)
		ADDPROPERTY(loX, "cEngine", tcEngine)
		ADDPROPERTY(loX, "cKind", tcKind)
		RETURN loX
	ENDPROC

	*-- La clave de un ejecutor como la da el usuario o el agente: dbf (o vfp), el
	*-- id de una conexión (o conn:<id>), handle:<n>.
	PROCEDURE NormalKey
		LPARAMETERS tcOn
		LOCAL lcOn
		lcOn = LOWER(ALLTRIM(TRANSFORM(tcOn)))
		DO CASE
			CASE EMPTY(lcOn) OR INLIST(lcOn, "dbf", "vfp")
				RETURN "dbf"
			CASE LEFT(lcOn, 5) == "conn:" OR LEFT(lcOn, 7) == "handle:"
				RETURN lcOn
		ENDCASE
		RETURN "conn:" + lcOn
	ENDPROC

	*-- El ejecutor de una clave, como lo enseña Run on
	*-- («Tablas DBF locales (vfp)», «Ventas (sqlserver)»), y su clase (dbf, conn, handle);
	*-- .NULL. si no existe.
	PROCEDURE ExecutorOf
		LPARAMETERS tcKey
		LOCAL loX, loList
		loList = This.Executors()
		FOR EACH loX IN loList FOXOBJECT
			IF loX.cKey == tcKey
				RETURN loX
			ENDIF
		ENDFOR
		RETURN .NULL.
	ENDPROC

	PROCEDURE CaptionOf
		LPARAMETERS tcKey
		LOCAL loX
		loX = This.ExecutorOf(tcKey)
		RETURN IIF(ISNULL(loX), TRANSFORM(tcKey), loX.cCaption)
	ENDPROC

	*-- El motor de un ejecutor ("" si no existe).
	PROCEDURE EngineOf
		LPARAMETERS tcKey
		LOCAL loX, loList
		loList = This.Executors()
		FOR EACH loX IN loList FOXOBJECT
			IF loX.cKey == tcKey
				RETURN loX.cEngine
			ENDIF
		ENDFOR
		RETURN ""
	ENDPROC

	*-- Run on: el ejecutor elegido; CheckEngine de su motor en la carpeta y el
	*-- panel al día. .F. si no existe.
	PROCEDURE Choose
		LPARAMETERS tcOn
		LOCAL lcKey, lcEngine, loCat
		lcKey = This.NormalKey(tcOn)
		lcEngine = This.EngineOf(lcKey)
		IF EMPTY(lcEngine)
			This.cLastCode = "on_unknown"
			This.cLastError = "there is no executor '" + TRANSFORM(tcOn) + "' in this IDE (dbf, the id of a connection of data, or handle:<n>)"
			This.oHost.NotifyKey("queries.runOn.unknown", TRANSFORM(tcOn))
			RETURN .F.
		ENDIF
		This.cOn = lcKey
		This.oHost.Log("queries: Run on " + lcKey + " (" + lcEngine + ")")
		loCat = This.Catalog()
		IF !ISNULL(loCat)
			loCat.cEngine = lcEngine
			IF loCat.lLoaded
				=loCat.Load(.T.)
			ENDIF
			IF VARTYPE(loCat.oForm) == "O"
				loCat.oForm.Texts()
				loCat.oForm.ShowPanel()
			ENDIF
		ENDIF
		This.oHost.RefreshMenu()
		RETURN .T.
	ENDPROC

	*-- La barra de Run on >: elige, y una conexión sin conectar va a su Connect...
	PROCEDURE RunOnBar
		LPARAMETERS tcKey
		LOCAL loC, lcId
		IF !This.Choose(tcKey)
			RETURN .F.
		ENDIF
		IF LEFT(This.cOn, 5) == "conn:"
			lcId = SUBSTR(This.cOn, 6)
			loC = This.Conns()
			IF !ISNULL(loC) AND !loC.IsConnected(lcId)
				This.oHost.NotifyKey("queries.runOn.connectFirst", lcId)
				=loC.ConnectBar(lcId)
			ENDIF
		ENDIF
		RETURN .T.
	ENDPROC

	*-- El ejecutor de una clave, listo para FoxQuery: un Empty con oDb, cEngine,
	*-- cKind y cKey; o .NULL. con cLastCode y cLastError. tlAgent: las banderas de
	*-- data (agentCanRead; para escribir, allowWrite).
	PROCEDURE Resolve
		LPARAMETERS tcOn, tlAgent, tlWrite
		LOCAL lcKey, loX, loC, loConn, lcId, lcWhy, lnN, lnI, llIn
		LOCAL ARRAY laH[1]
		lcKey = This.NormalKey(tcOn)
		loX = CREATEOBJECT("Empty")
		ADDPROPERTY(loX, "cKey", lcKey)
		ADDPROPERTY(loX, "oDb", .NULL.)
		ADDPROPERTY(loX, "cEngine", "")
		ADDPROPERTY(loX, "cKind", "")
		DO CASE
			CASE lcKey == "dbf"
				loX.oDb = NEWOBJECT("QueryLocal", This.CopyFile())
				loX.cEngine = "vfp"
				loX.cKind = "dbf"
			CASE LEFT(lcKey, 7) == "handle:"
				lnN = INT(VAL(SUBSTR(lcKey, 8)))
				llIn = .F.
				FOR lnI = 1 TO ASQLHANDLES(laH)
					llIn = llIn OR laH[lnI] = lnN
				ENDFOR
				IF lnN < 1 OR !llIn
					RETURN This.Refuse("on_unknown", "there is no open ODBC handle " + SUBSTR(lcKey, 8) + " in this IDE (ASQLHANDLES)")
				ENDIF
				loX.oDb = NEWOBJECT("QueryOdbc", This.CopyFile(), "", lnN)
				loX.cEngine = loX.oDb.cEngine
				loX.cKind = "handle"
				IF EMPTY(loX.cEngine)
					RETURN This.Refuse(loX.oDb.cLastErrorCode, loX.oDb.cLastError)
				ENDIF
			OTHERWISE
				lcId = SUBSTR(lcKey, 6)
				loC = This.Conns()
				IF ISNULL(loC)
					RETURN This.Refuse("connections_off", "the connections of data are not loaded in this IDE (the data package, or its module connections, is off): only dbf and handle:<n>")
				ENDIF
				loConn = loC.Find(lcId)
				IF ISNULL(loConn)
					RETURN This.Refuse("on_unknown", "there is no executor '" + lcId + "' in this IDE: dbf, the id of a connection of data (" + ;
						This.ConnIds(loC) + "), or handle:<n>")
				ENDIF
				IF tlAgent
					lcWhy = loC.AgentRefusal(lcId)
					IF !EMPTY(lcWhy)
						RETURN This.Refuse("agent_cannot_read", lcWhy)
					ENDIF
					IF tlWrite AND !loConn.lAllowWrite
						RETURN This.Refuse("write_not_allowed", "Connection '" + loConn.cId + "' does not let the agent write: allowWrite is false in " + ;
							loConn.cFile + ". To allow it, set " + ["allowWrite": true] + " in that connection (FoxDock > Data > Connections > Edit connections...).")
					ENDIF
				ENDIF
				IF !loC.Ready(lcId)
					RETURN This.Refuse(EVL(loC.cLastCode, "not_connected"), loC.cLastError)
				ENDIF
				loX.oDb = loC.Live(lcId)
				loX.cEngine = loConn.cEngine
				loX.cKind = "conn"
		ENDCASE
		RETURN loX
	ENDPROC

	PROTECTED PROCEDURE ConnIds
		LPARAMETERS toC
		LOCAL lcOut, loConn
		lcOut = ""
		FOR EACH loConn IN toC.oList FOXOBJECT
			lcOut = lcOut + IIF(EMPTY(lcOut), "", ", ") + loConn.cId
		ENDFOR
		RETURN EVL(lcOut, "none")
	ENDPROC

	PROCEDURE Refuse
		LPARAMETERS tcCode, tcError
		This.cLastCode = TRANSFORM(tcCode)
		This.cLastError = TRANSFORM(tcError)
		RETURN .NULL.
	ENDPROC

	*--------------------------------------------------------------
	* La sesión 1 como estaba.
	*--------------------------------------------------------------
	PROCEDURE SaveIde
		LOCAL loS, lnN, lnI, lcA
		LOCAL ARRAY laU[1]
		loS = CREATEOBJECT("Empty")
		ADDPROPERTY(loS, "nDs", SET("DATASESSION"))
		SET DATASESSION TO 1
		ADDPROPERTY(loS, "nSelect", SELECT(0))
		ADDPROPERTY(loS, "cDeleted", SET("DELETED"))
		ADDPROPERTY(loS, "cAnsi", SET("ANSI"))
		ADDPROPERTY(loS, "cExact", SET("EXACT"))
		ADDPROPERTY(loS, "cTablePrompt", SET("TABLEPROMPT"))
		ADDPROPERTY(loS, "oPointers", CREATEOBJECT("Collection"))
		lnN = AUSED(laU, 1)
		FOR lnI = 1 TO lnN
			lcA = UPPER(laU[lnI, 1])
			loS.oPointers.Add(IIF(EOF(lcA), -1, RECNO(lcA)), lcA)
		ENDFOR
		RETURN loS
	ENDPROC

	PROCEDURE RestoreIde
		LPARAMETERS toS
		LOCAL lnI, lcA, lnRec, lcSet, loErr
		SET DATASESSION TO 1
		FOR lnI = 1 TO toS.oPointers.Count
			lcA = toS.oPointers.GetKey(lnI)
			lnRec = toS.oPointers.Item(lnI)
			TRY
				DO CASE
					CASE !USED(lcA)
					CASE lnRec = -1
						GO BOTTOM IN (lcA)
						IF !EOF(lcA)
							SKIP 1 IN (lcA)
						ENDIF
					CASE lnRec <= RECCOUNT(lcA) AND RECNO(lcA) # lnRec
						GO (lnRec) IN (lcA)
				ENDCASE
			CATCH TO loErr
			ENDTRY
		ENDFOR
		lcSet = toS.cDeleted
		SET DELETED &lcSet
		lcSet = toS.cAnsi
		SET ANSI &lcSet
		lcSet = toS.cExact
		SET EXACT &lcSet
		lcSet = toS.cTablePrompt
		SET TABLEPROMPT &lcSet
		TRY
			SELECT (toS.nSelect)
		CATCH TO loErr
		ENDTRY
		SET DATASESSION TO (toS.nDs)
	ENDPROC

	*--------------------------------------------------------------
	* La llamada: Run (tcVerb "run") o Execute ("execute") de una consulta por su
	* nombre. tnMax: las filas como mucho (0, sin tope). tlAgent: la guarda de la
	* copia y las banderas de data. Devuelve .T. o .F. con cLastCode y
	* cLastError; deja cLastCursor (la sesión 1), nLastRows, nLastTotal,
	* lLastTruncated y nLastAffected.
	*--------------------------------------------------------------
	PROCEDURE Exec
		LPARAMETERS tcName, tcOn, toParams, tnMax, tcVerb, tlWhole, tlAgent
		LOCAL loCat, loS, loX, loDef, lvSql, loG, lcWhy, loState, lcAlias, lnOld, llOk, lnN, loErr, lcErr, loIdent, lvIdent, lcTmp, llWrite, lvMap
		This.cLastCode = ""
		This.cLastError = ""
		This.cLastCursor = ""
		This.nLastRows = 0
		This.nLastTotal = 0
		This.lLastTruncated = .F.
		This.nLastAffected = -1
		llWrite = (tcVerb == "execute")
		loCat = This.Catalog()
		IF ISNULL(loCat)
			RETURN This.Fail("catalog_off", "the catalog module of the queries package is off (options.queries.catalog.enabled)")
		ENDIF
		IF !loCat.EnsureLoaded()
			RETURN This.Fail("folder_not_found", "the folder of the queries does not exist: " + loCat.Folder())
		ENDIF
		loS = loCat.Store()
		loDef = loS.Get(tcName)
		IF ISNULL(loDef)
			RETURN This.Fail(EVL(loS.cLastErrorCode, "query_not_found"), EVL(loS.cLastError, "there is no query called " + TRANSFORM(tcName)))
		ENDIF
		loX = This.Resolve(tcOn, tlAgent, llWrite)
		IF ISNULL(loX)
			RETURN .F.
		ENDIF
		This.cLastEngine = loX.cEngine
		*-- Los idents recordados (config.json, queries.idents), antes de la llamada.
		FOR EACH loIdent IN loDef.oIdents FOXOBJECT
			lvIdent = This.oHost.Options.Get("queries", "idents." + LOWER(loIdent.cName), "")
			IF !EMPTY(lvIdent)
				=loS.SetIdent(loIdent.cName, TRANSFORM(lvIdent))
			ENDIF
		ENDFOR
		IF VARTYPE(toParams) # "O"
			toParams = CREATEOBJECT("Empty")
		ENDIF
		*-- La guarda sobre el texto resuelto, para el agente.
		IF tlAgent
			lvSql = loS.Sql(tcName, loX.cEngine, "", toParams)
			IF VARTYPE(lvSql) # "C"
				RETURN This.Fail(loS.cLastErrorCode, loS.cLastError)
			ENDIF
			loG = NEWOBJECT("QueriesSqlGuard", This.GuardFile())
			loG.cEngine = loX.cEngine
			lcWhy = IIF(llWrite, loG.CheckWrite(lvSql, tlWhole), loG.Check(lvSql))
			IF !EMPTY(lcWhy) AND !(loDef.cKind == IIF(llWrite, "read", "write"))
				RETURN This.Fail("guard_refused", "the SQL of " + tcName + " for " + loX.cEngine + " " + lcWhy + ;
					". Nothing was sent to the engine. (" + IIF(llWrite, "A write by the agent goes one statement at a time, and a whole table only with wholeTable.", ;
					"The agent only reads: a read query that writes or locks is refused.") + ")")
			ENDIF
		ENDIF
		loState = This.SaveIde()
		lcErr = ""
		lnOld = .NULL.
		lvMap = .NULL.
		TRY
			IF llWrite
				lnN = loS.Execute(loX.oDb, tcName, toParams)
				llOk = (lnN >= 0)
				This.nLastAffected = lnN
			ELSE
				lcAlias = "q_" + LEFT(CHRTRAN(LOWER(tcName), ".- ", "___"), 100)
				IF USED(lcAlias)
					USE IN (lcAlias)
				ENDIF
				IF loX.cKind # "dbf" AND tnMax > 0
					lnOld = CURSORGETPROP("MaxRecords", 0)
					=CURSORSETPROP("MaxRecords", tnMax + 1, 0)
				ENDIF
				*-- De una conexión, los binarios como binarios (Varbinary y Blob), como
				*-- lee data; lo que tuviera la sesión vuelve en el FINALLY.
				IF loX.cKind # "dbf"
					lvMap = CURSORGETPROP("MapBinary", 0)
					=CURSORSETPROP("MapBinary", .T., 0)
				ENDIF
				llOk = loS.Run(loX.oDb, tcName, toParams, lcAlias)
				IF VARTYPE(lvMap) == "L"
					=CURSORSETPROP("MapBinary", lvMap, 0)
					lvMap = .NULL.
				ENDIF
				IF VARTYPE(lnOld) == "N"
					=CURSORSETPROP("MaxRecords", lnOld, 0)
					lnOld = .NULL.
				ENDIF
				IF llOk AND USED(lcAlias)
					This.nLastTotal = RECCOUNT(lcAlias)
					IF tnMax > 0 AND RECCOUNT(lcAlias) > tnMax
						This.lLastTruncated = .T.
						lcTmp = "FDQ" + SYS(2015)
						SELECT * FROM &lcAlias WHERE RECNO() <= tnMax INTO CURSOR (lcTmp) READWRITE
						USE IN (lcAlias)
						SELECT * FROM &lcTmp INTO CURSOR (lcAlias) READWRITE
						USE IN (lcTmp)
					ENDIF
					This.nLastRows = RECCOUNT(lcAlias)
					This.cLastCursor = lcAlias
				ENDIF
			ENDIF
		CATCH TO loErr
			llOk = .F.
			lcErr = "error " + TRANSFORM(loErr.ErrorNo) + ": " + loErr.Message
		FINALLY
			IF VARTYPE(lnOld) == "N"
				=CURSORSETPROP("MaxRecords", lnOld, 0)
			ENDIF
			IF VARTYPE(lvMap) == "L"
				=CURSORSETPROP("MapBinary", lvMap, 0)
			ENDIF
			This.RestoreIde(loState)
		ENDTRY
		DO CASE
			CASE !EMPTY(lcErr)
				RETURN This.Fail("executor_failed", lcErr)
			CASE !llOk
				RETURN This.Fail(loS.cLastErrorCode, loS.cLastError)
		ENDCASE
		This.oHost.Log("queries: " + tcVerb + " " + tcName + " on " + loX.cKey + " (" + loX.cEngine + "): " + ;
			IIF(llWrite, TRANSFORM(This.nLastAffected) + " row(s) changed", TRANSFORM(This.nLastRows) + " row(s)" + ;
			IIF(This.lLastTruncated, " (there were more)", "") + " in " + This.cLastCursor) + IIF(tlAgent, ", for the agent", ""))
		RETURN .T.
	ENDPROC

	PROCEDURE Fail
		LPARAMETERS tcCode, tcError
		This.cLastCode = TRANSFORM(tcCode)
		This.cLastError = TRANSFORM(tcError)
		RETURN .F.
	ENDPROC

	*-- Las filas de un cursor de la sesión 1 en JSON, con el tratamiento de cada
	*-- tipo de ide_data_db_query (DataJson.Walk de data, si está cargado); si no,
	*-- uno propio: texto sin relleno, fechas en ISO 8601, null.
	PROCEDURE RowsJson
		LPARAMETERS tcAlias, tnMax
		LOCAL loD, loT, loJ, loR, lcRows, lnDs, lnI, lcRow, luV, lnSel, loH
		loD = This.oHost.PluginById("data")
		lcRows = ""
		IF !ISNULL(loD)
			loT = CREATEOBJECT("DataTable")
			loJ = NEWOBJECT("DataJson", loD.CodeFile("DataJson.prg"), "", This.oHost)
			TRY
				IF loT.Open(tcAlias, .F.)
					loR = loJ.Walk(loT, tnMax, "", 0)
					lcRows = STRTRAN(loR.cClip, "," + CRLF, ",")
				ENDIF
			FINALLY
				loT.Close()
			ENDTRY
			RETURN "[" + lcRows + "]"
		ENDIF
		loH = This.oHost.oJson
		lnDs = SET("DATASESSION")
		SET DATASESSION TO 1
		lnSel = SELECT()
		SELECT (tcAlias)
		SCAN
			lcRow = ""
			FOR lnI = 1 TO FCOUNT()
				luV = EVALUATE(FIELD(lnI))
				DO CASE
					CASE VARTYPE(luV) == "C"
						luV = RTRIM(luV)
					CASE VARTYPE(luV) == "D" AND !EMPTY(luV)
						luV = TRANSFORM(DTOS(luV), "@R 9999-99-99")
				ENDCASE
				lcRow = lcRow + IIF(lnI = 1, "", ",") + loH.Quote(LOWER(FIELD(lnI))) + ":" + loH.Stringify(luV)
			ENDFOR
			lcRows = lcRows + IIF(EMPTY(lcRows), "", ",") + "{" + lcRow + "}"
		ENDSCAN
		SELECT (lnSel)
		SET DATASESSION TO (lnDs)
		RETURN "[" + lcRows + "]"
	ENDPROC

	*-- Cierra el cursor de la última llamada (las tools).
	PROCEDURE CloseLast
		LOCAL lnDs
		lnDs = SET("DATASESSION")
		SET DATASESSION TO 1
		IF !EMPTY(This.cLastCursor) AND USED(This.cLastCursor)
			USE IN (This.cLastCursor)
		ENDIF
		SET DATASESSION TO (lnDs)
	ENDPROC

	*--------------------------------------------------------------
	* Run...: la ventanita de parámetros.
	*--------------------------------------------------------------
	*-- La barra: la consulta elegida en la ventana; sin ventana o sin elegida, la
	*-- ventana, y el aviso dice que se elija una.
	PROCEDURE RunBar
		LOCAL loCat, lcName
		loCat = This.Catalog()
		IF ISNULL(loCat)
			RETURN .F.
		ENDIF
		lcName = IIF(VARTYPE(loCat.oForm) == "O", loCat.oForm.Chosen(), "")
		IF EMPTY(lcName)
			=loCat.OpenWindow()
			This.oHost.NotifyKey("queries.run.chooseFirst")
			RETURN .F.
		ENDIF
		RETURN !ISNULL(This.OpenRun(lcName))
	ENDPROC

	PROCEDURE OpenRun
		LPARAMETERS tcName
		LOCAL loCat, loS, loDef, loP
		loCat = This.Catalog()
		IF ISNULL(loCat) OR !loCat.EnsureLoaded()
			This.oHost.NotifyKey("queries.noFolder", IIF(ISNULL(loCat), "", loCat.Folder()))
			RETURN .NULL.
		ENDIF
		loS = loCat.Store()
		loDef = loS.Get(tcName)
		IF ISNULL(loDef)
			This.oHost.NotifyKey("queries.run.notLoaded", TRANSFORM(tcName))
			RETURN .NULL.
		ENDIF
		IF VARTYPE(This.oForm) == "O"
			This.oForm.Release()
		ENDIF
		loP = This.Plugin()
		This.oForm = NEWOBJECT("QueriesRunForm", loP.CodeFile("QueriesRun.prg"), "", This, loDef)
		IF This.lShow
			This.oForm.Show()
		ENDIF
		RETURN This.oForm
	ENDPROC

	*-- El botón Run de la ventanita. Una write pide confirmación en la propia
	*-- ventanita (Run it); una read con una columna y una fila da el valor.
	PROCEDURE RunFromForm
		LPARAMETERS toF
		LOCAL loPar, lcName, lnLimit, llOk, lnDs, lcTitle, lcAlias, loDef
		loDef = toF.oDef
		lcName = loDef.cName
		loPar = toF.Values()
		IF ISNULL(loPar)
			RETURN .F.
		ENDIF
		IF !toF.RememberIdents()
			RETURN .F.
		ENDIF
		lnLimit = MAX(INT(toF.spnLimit.Value), 0)
		IF loDef.cKind == "write" AND !toF.lConfirmed
			toF.lConfirmed = .T.
			toF.cmdRun.Caption = This.T("queries.run.runIt")
			This.Say(toF, "queries.run.confirm", lcName, This.cOn)
			RETURN .F.
		ENDIF
		llOk = This.Exec(lcName, This.cOn, loPar, lnLimit, IIF(loDef.cKind == "write", "execute", "run"), .T., .F.)
		toF.lConfirmed = .F.
		toF.cmdRun.Caption = This.T("queries.run.run")
		IF !llOk
			This.Say(toF, "queries.run.failed", This.CaptionOf(This.cOn), This.cLastCode, STRTRAN(This.cLastError, This.cLastCode + ": ", "", 1, 1))
			*-- En las DBF locales VFP ejecuta la SQL tal cual, y la de otro motor
			*-- (corchetes, .dbo., CASE WHEN) da un error de VFP que parece la falta de
			*-- una conexión («error 1300: Function name is missing )»): se dice qué
			*-- hacer. La frase va primero: el cuadro enseña pocas líneas, y el error
			*-- técnico en inglés las llenaría.
			IF This.cOn == "dbf" AND This.cLastCode == "executor_failed"
				This.cLastSaid = This.T("queries.run.dbfHint") + CRLF + This.cLastSaid
				toF.edtSay.Value = This.cLastSaid
			ENDIF
			RETURN .F.
		ENDIF
		IF loDef.cKind == "write"
			This.Say(toF, "queries.run.changed", lcName, This.nLastAffected)
			This.oHost.NotifyKey("queries.run.changed", lcName, This.nLastAffected)
			RETURN .T.
		ENDIF
		lcAlias = This.cLastCursor
		lnDs = SET("DATASESSION")
		SET DATASESSION TO 1
		This.lLastScalar = USED(lcAlias) AND FCOUNT(lcAlias) = 1 AND RECCOUNT(lcAlias) = 1
		IF This.lLastScalar
			GO TOP IN (lcAlias)
			This.vLastValue = EVALUATE(lcAlias + "." + FIELD(1, lcAlias))
			SET DATASESSION TO (lnDs)
			This.Say(toF, "queries.run.value", lcName, TRANSFORM(This.vLastValue))
			This.oHost.NotifyKey("queries.run.value", lcName, TRANSFORM(This.vLastValue))
			RETURN .T.
		ENDIF
		lcTitle = This.T("queries.run.title", lcName, This.cLastEngine, This.nLastRows, ;
			IIF(This.lLastTruncated, This.T("queries.run.firstN", lnLimit), ""))
		This.cLastTitle = lcTitle
		IF This.lShow AND _screen.Visible
			SELECT (lcAlias)
			GO TOP
			BROWSE NOWAIT NOMODIFY NOAPPEND NODELETE NORMAL IN SCREEN TITLE lcTitle
		ENDIF
		SET DATASESSION TO (lnDs)
		This.Say(toF, "queries.run.rows", lcName, This.nLastRows, lcAlias)
		RETURN .T.
	ENDPROC

	*-- To object: las filas del último Run a una Collection PUBLIC (una variable
	*-- para la ventana de comandos), como To object de Explore....
	PROCEDURE ToObject
		LPARAMETERS toF, tcVar
		LOCAL lnDs, lnSel, loC, loR, lcVar
		lcVar = ALLTRIM(TRANSFORM(tcVar))
		DO CASE
			CASE EMPTY(lcVar) OR !ISALPHA(lcVar) OR LEN(CHRTRAN(LOWER(lcVar), "abcdefghijklmnopqrstuvwxyz0123456789_", "")) > 0
				This.Say(toF, "queries.run.badVar", lcVar)
				RETURN .F.
			CASE TYPE(lcVar) # "U"
				This.Say(toF, "queries.run.varExists", lcVar)
				RETURN .F.
			CASE EMPTY(This.cLastCursor)
				This.Say(toF, "queries.run.noRows")
				RETURN .F.
		ENDCASE
		lnDs = SET("DATASESSION")
		SET DATASESSION TO 1
		IF !USED(This.cLastCursor)
			SET DATASESSION TO (lnDs)
			This.Say(toF, "queries.run.noRows")
			RETURN .F.
		ENDIF
		lnSel = SELECT()
		SELECT (This.cLastCursor)
		loC = CREATEOBJECT("Collection")
		SCAN
			SCATTER NAME loR MEMO
			loC.Add(loR)
		ENDSCAN
		SELECT (lnSel)
		SET DATASESSION TO (lnDs)
		PUBLIC &lcVar
		&lcVar = loC
		This.oHost.Log("queries: " + lcVar + " (PUBLIC): " + TRANSFORM(loC.Count) + " rows of " + This.cLastCursor)
		This.Say(toF, "queries.run.object", lcVar, loC.Count)
		RETURN .T.
	ENDPROC

	PROCEDURE Say
		LPARAMETERS toF, tcKey, tv1, tv2, tv3
		This.cLastSaid = This.T(tcKey, tv1, tv2, tv3)
		This.oHost.Log("queries: " + This.E(tcKey, tv1, tv2, tv3))
		IF VARTYPE(toF) == "O"
			toF.edtSay.Value = This.cLastSaid
		ENDIF
	ENDPROC
ENDDEFINE


*------------------------------------------------------------------
* La ventanita de Run..., hecha desde el QueryDef: una fila
* por parámetro (nombre, tipo, obligatorio, y su cuadro: D con el SET DATE del
* IDE, T con fecha y hora, L una casilla, list un texto con comas, lo demás un
* texto; el default puesto), Sort, Idents (el último valor, de config.json),
* Limit, Run, To object y lo que dice, sin diálogos.
*------------------------------------------------------------------
DEFINE CLASS QueriesRunForm AS Form
	AutoCenter = .T.
	MinButton = .F.
	MaxButton = .F.
	ShowWindow = 0
	WindowType = 0
	BorderStyle = 2
	Width = 480
	Height = 200
	Name = "FoxDockQueriesRun"
	oModule = .NULL.
	oDef = .NULL.
	lConfirmed = .F.
	nParams = 0
	nIdents = 0
	DIMENSION aParams[1]
	DIMENSION aIdents[1]

	ADD OBJECT lblQuery AS Label WITH Caption = "", Left = 10, Top = 10, Width = 460, Height = 18, FontBold = .T.

	PROCEDURE Init
		LPARAMETERS toModule, toDef
		LOCAL lnTop, loP, lnI, lcName, loI, lnSort, lcCol, loM
		This.oModule = toModule
		This.oDef = toDef
		loM = toModule
		This.Caption = loM.T("queries.run.window", toDef.cName)
		This.lblQuery.Caption = toDef.cName + "  (" + toDef.cKind + ")  " + toDef.cDescription
		lnTop = 36
		lnI = 0
		FOR EACH loP IN toDef.oParams FOXOBJECT
			lnI = lnI + 1
			DIMENSION This.aParams[lnI]
			This.aParams[lnI] = loP.cName
			This.AddObject("lblP" + TRANSFORM(lnI), "Label")
			WITH This.Controls(This.ControlCount)
				.Caption = loP.cName + " (" + loP.cType + IIF(loP.lList, ", list", "") + ")" + IIF(loP.lRequired, " *", "")
				.Left = 10
				.Top = lnTop + 4
				.AutoSize = .T.
				.Visible = .T.
			ENDWITH
			This.AddParamBox(lnI, loP, lnTop)
			lnTop = lnTop + 30
		ENDFOR
		This.nParams = lnI
		*-- Sort: las columnas de «-- sort:», cada una ASC y DESC.
		This.AddObject("lblSort", "Label")
		WITH This.lblSort
			.Caption = loM.T("queries.run.sort")
			.Left = 10
			.Top = lnTop + 4
			.AutoSize = .T.
			.Visible = .T.
		ENDWITH
		This.AddObject("cboSort", "ComboBox")
		WITH This.cboSort
			.Left = 150
			.Top = lnTop
			.Width = 200
			.Style = 2
			.AddItem(loM.T("queries.run.sortDefault"))
			FOR lnSort = 1 TO toDef.nSort
				lcCol = toDef.aSortList[lnSort]
				.AddItem(lcCol + " ASC")
				.AddItem(lcCol + " DESC")
			ENDFOR
			.ListIndex = 1
			.Enabled = toDef.nSort > 0
			.Visible = .T.
		ENDWITH
		lnTop = lnTop + 30
		lnI = 0
		FOR EACH loI IN toDef.oIdents FOXOBJECT
			lnI = lnI + 1
			DIMENSION This.aIdents[lnI]
			This.aIdents[lnI] = loI.cName
			This.AddObject("lblI" + TRANSFORM(lnI), "Label")
			WITH This.Controls(This.ControlCount)
				.Caption = "{ident " + loI.cName + "}"
				.Left = 10
				.Top = lnTop + 4
				.AutoSize = .T.
				.Visible = .T.
			ENDWITH
			This.AddObject("txtI" + TRANSFORM(lnI), "TextBox")
			WITH This.Controls(This.ControlCount)
				.Left = 150
				.Top = lnTop
				.Width = 120
				.MaxLength = 64
				.Value = PADR(TRANSFORM(loM.oHost.Options.Get("queries", "idents." + LOWER(loI.cName), "")), 64)
				.Visible = .T.
			ENDWITH
			lnTop = lnTop + 30
		ENDFOR
		This.nIdents = lnI
		This.AddObject("lblLimit", "Label")
		WITH This.lblLimit
			.Caption = loM.T("queries.run.limit")
			.Left = 10
			.Top = lnTop + 4
			.AutoSize = .T.
			.Visible = .T.
		ENDWITH
		This.AddObject("spnLimit", "Spinner")
		WITH This.spnLimit
			.Left = 150
			.Top = lnTop
			.Width = 90
			.SpinnerLowValue = 0
			.SpinnerHighValue = 1000000
			.KeyboardLowValue = 0
			.KeyboardHighValue = 1000000
			.Increment = 100
			.Value = This.DefaultLimit()
			.Visible = .T.
		ENDWITH
		lnTop = lnTop + 34
		This.AddObject("edtSay", "EditBox")
		WITH This.edtSay
			.Left = 10
			.Top = lnTop
			.Width = 460
			*-- 79: cinco líneas, el aviso entero de las DBF locales (cuatro en alemán)
			*-- y el principio del error.
			.Height = 79
			.ReadOnly = .T.
			.ScrollBars = 2
			.Value = loM.T("queries.run.on", loM.CaptionOf(loM.cOn))
			.Visible = .T.
		ENDWITH
		lnTop = lnTop + 87
		This.AddObject("cmdRun", "QueriesRunButton")
		WITH This.cmdRun
			.Caption = loM.T("queries.run.run")
			.Left = 10
			.Top = lnTop
			.Width = 90
			.Height = 28
			.Default = .T.
			.Visible = .T.
		ENDWITH
		This.AddObject("txtObject", "TextBox")
		WITH This.txtObject
			.Left = 200
			.Top = lnTop + 2
			.Width = 160
			*-- 24, la de los cuadros de data: con la de serie de AddObject (21) no se
			*-- ve el guion bajo de un nombre como «loListado_socios_activos».
			.Height = 24
			.MaxLength = 128
			.Value = PADR("lo" + STRTRAN(PROPER(STRTRAN(toDef.cName, ".", " ")), " ", ""), 128)
			.Visible = .T.
		ENDWITH
		This.AddObject("cmdObject", "QueriesObjectButton")
		WITH This.cmdObject
			.Caption = loM.T("queries.run.toObject")
			.Left = 106
			.Top = lnTop
			.Width = 90
			.Height = 28
			.Visible = .T.
		ENDWITH
		This.AddObject("cmdClose", "QueriesCloseButton")
		WITH This.cmdClose
			.Caption = loM.T("queries.window.close")
			.Left = 380
			.Top = lnTop
			.Width = 90
			.Height = 28
			.Cancel = .T.
			.Visible = .T.
		ENDWITH
		This.Height = lnTop + 38
	ENDPROC

	PROCEDURE Destroy
		IF VARTYPE(This.oModule) == "O"
			This.oModule.FormGone()
		ENDIF
		This.oModule = .NULL.
	ENDPROC

	*-- El límite de data (connections.queryLimit, 100 de entrada).
	PROCEDURE DefaultLimit
		LOCAL lnN
		lnN = This.oModule.oHost.Options.Get("data", "connections.queryLimit", 100)
		lnN = IIF(VARTYPE(lnN) == "N", INT(lnN), INT(VAL(TRANSFORM(lnN))))
		RETURN MAX(lnN, 0)
	ENDPROC

	*-- El cuadro de un parámetro, por su tipo, con su default.
	PROCEDURE AddParamBox
		LPARAMETERS tnI, toP, tnTop
		LOCAL lcName
		lcName = "ctlP" + TRANSFORM(tnI)
		DO CASE
			CASE toP.cType == "L" AND !toP.lList
				This.AddObject(lcName, "CheckBox")
				WITH This.Controls(This.ControlCount)
					.Caption = ""
					.Value = IIF(toP.lHasDefault AND VARTYPE(toP.vDefault) == "L", toP.vDefault, .F.)
				ENDWITH
			CASE toP.cType == "D" AND !toP.lList
				This.AddObject(lcName, "TextBox")
				WITH This.Controls(This.ControlCount)
					.Value = IIF(toP.lHasDefault AND VARTYPE(toP.vDefault) == "D", toP.vDefault, {})
					.Width = 110
				ENDWITH
			CASE toP.cType == "T" AND !toP.lList
				This.AddObject(lcName, "TextBox")
				WITH This.Controls(This.ControlCount)
					.Value = IIF(toP.lHasDefault AND VARTYPE(toP.vDefault) == "T", toP.vDefault, {/:})
					.Width = 170
				ENDWITH
			OTHERWISE
				This.AddObject(lcName, "TextBox")
				WITH This.Controls(This.ControlCount)
					.Value = PADR(IIF(toP.lHasDefault, TRANSFORM(toP.vDefault), ""), 254)
					.Width = 300
					.MaxLength = 254
				ENDWITH
		ENDCASE
		WITH This.Controls(This.ControlCount)
			.Left = 150
			.Top = tnTop
			.Visible = .T.
		ENDWITH
	ENDPROC

	*-- Los parámetros como los pide FoxQuery (un Empty por nombre, con su tipo);
	*-- uno vacío y no obligatorio no va. sort, si se eligió una. .NULL. si un
	*-- número no es un número (y lo dice).
	PROCEDURE Values
		LOCAL loV, lnI, loP, loCtl, luV, lcText
		loV = CREATEOBJECT("Empty")
		FOR lnI = 1 TO This.nParams
			loP = This.oDef.oParams.Item(LOWER(This.aParams[lnI]))
			loCtl = EVALUATE("This.ctlP" + TRANSFORM(lnI))
			luV = loCtl.Value
			DO CASE
				CASE VARTYPE(luV) == "L"
				CASE VARTYPE(luV) $ "DT"
					IF EMPTY(luV)
						LOOP
					ENDIF
				OTHERWISE
					lcText = ALLTRIM(TRANSFORM(luV))
					IF EMPTY(lcText)
						LOOP
					ENDIF
					DO CASE
						CASE loP.lList
							luV = lcText
						CASE INLIST(loP.cType, "N", "I", "Y")
							IF LEN(CHRTRAN(lcText, "0123456789.-", "")) > 0
								This.oModule.Say(This, "queries.run.notANumber", loP.cName, lcText)
								RETURN .NULL.
							ENDIF
							luV = IIF(loP.cType == "I", INT(VAL(lcText)), IIF(loP.cType == "Y", NTOM(VAL(lcText)), VAL(lcText)))
						OTHERWISE
							luV = lcText
					ENDCASE
			ENDCASE
			ADDPROPERTY(loV, loP.cName, luV)
		ENDFOR
		IF This.cboSort.ListIndex > 1
			ADDPROPERTY(loV, "sort", This.cboSort.Value)
		ENDIF
		RETURN loV
	ENDPROC

	*-- Los idents: al almacén y a config.json (queries.idents). Primero se fijan
	*-- todos en el almacén, que valida su forma (FQ_SET); uno que no encaja («0X»
	*-- en un digits 2) lo dice, no se guarda y no se ejecuta nada: guardado,
	*-- FoxQuery diría ident_missing y mandaría a FQ_SET. .T. si todos valen.
	PROCEDURE RememberIdents
		LOCAL lnI, lcValue, loCat, loS, llOk
		loCat = This.oModule.Catalog()
		loS = loCat.Store()
		llOk = .T.
		FOR lnI = 1 TO This.nIdents
			lcValue = ALLTRIM(EVALUATE("This.txtI" + TRANSFORM(lnI) + ".Value"))
			IF !EMPTY(lcValue) AND !loS.SetIdent(This.aIdents[lnI], lcValue)
				This.oModule.Say(This, "queries.run.identBad", This.aIdents[lnI], lcValue, loS.cLastError)
				llOk = .F.
				EXIT
			ENDIF
		ENDFOR
		IF llOk
			FOR lnI = 1 TO This.nIdents
				This.oModule.oHost.Options.Set("queries", "idents." + LOWER(This.aIdents[lnI]), ;
					ALLTRIM(EVALUATE("This.txtI" + TRANSFORM(lnI) + ".Value")))
			ENDFOR
		ENDIF
		RETURN llOk
	ENDPROC

	*-- Un parámetro por su nombre (así lo rellenan las pruebas).
	PROCEDURE SetParam
		LPARAMETERS tcName, tvValue
		LOCAL lnI, loCtl
		FOR lnI = 1 TO This.nParams
			IF LOWER(This.aParams[lnI]) == LOWER(tcName)
				loCtl = EVALUATE("This.ctlP" + TRANSFORM(lnI))
				loCtl.Value = tvValue
				RETURN .T.
			ENDIF
		ENDFOR
		RETURN .F.
	ENDPROC
ENDDEFINE

DEFINE CLASS QueriesRunButton AS CommandButton
	PROCEDURE Click
		=Thisform.oModule.RunFromForm(Thisform)
	ENDPROC
ENDDEFINE

DEFINE CLASS QueriesObjectButton AS CommandButton
	PROCEDURE Click
		=Thisform.oModule.ToObject(Thisform, Thisform.txtObject.Value)
	ENDPROC
ENDDEFINE

DEFINE CLASS QueriesCloseButton AS CommandButton
	PROCEDURE Click
		Thisform.Release()
	ENDPROC
ENDDEFINE


* ======================================================================== *
* QueriesSqlGuard: la guarda del texto que el agente hace correr con las tools
* de queries, la misma que la DataSqlGuard del plugin data. Se mira el texto
* sin los literales, los identificadores entre comillas ni los comentarios:
* Check deja pasar una sola sentencia que empieza por SELECT o WITH y no
* escribe nada; CheckWrite, una sola de INSERT, UPDATE, DELETE, CREATE, ALTER,
* DROP o TRUNCATE, y un UPDATE o un DELETE sin WHERE, un DROP o un TRUNCATE
* solo con tlWholeTable. Devuelven "" o el motivo.
* ======================================================================== *
DEFINE CLASS QueriesSqlGuard AS Custom
	cSql = ""
	cEngine = ""      && el motor, para decir con qué comillas se reescribe
	cStatement = ""   && la palabra con la que empieza la sentencia que pasa CheckWrite
	cWords = "INSERT UPDATE DELETE DROP ALTER CREATE TRUNCATE MERGE UPSERT EXEC EXECUTE CALL GRANT REVOKE " + ;
		"INTO ATTACH DETACH PRAGMA VACUUM COPY LOCK REINDEX RENAME SET DECLARE BEGIN COMMIT ROLLBACK"
	*-- Lo que no va en una escritura, en ningún sitio de ella (SET, INTO,
	*-- RENAME o DROP sí: los llevan UPDATE, INSERT y ALTER).
	cWriteWords = "EXEC EXECUTE CALL GRANT REVOKE ATTACH DETACH PRAGMA VACUUM COPY LOCK DECLARE BEGIN COMMIT ROLLBACK"

	*-- La guarda de ide_data_db_execute. Una sola sentencia de
	*-- INSERT, UPDATE, DELETE, CREATE, ALTER, DROP o TRUNCATE, mirada como Check
	*-- (sin literales ni comentarios: un where dentro de una cadena no cuenta).
	*-- Un SELECT o un WITH van a ide_data_db_query. Un UPDATE o un DELETE sin
	*-- WHERE, un DROP y un TRUNCATE, solo con tlWholeTable. Devuelve "" (y la
	*-- sentencia en cSql, y su palabra en cStatement) o el motivo.
	PROCEDURE CheckWrite
		LPARAMETERS tcSql, tlWholeTable
		LOCAL lcSql, lcCode, lcFirst, lcUp, lnW, lcW, lnLast
		LOCAL ARRAY laW[1]
		lcSql = ALLTRIM(TRANSFORM(tcSql), 1, " ", CHR(9), CHR(13), CHR(10))
		This.cSql = ""
		This.cStatement = ""
		IF EMPTY(lcSql)
			RETURN "the statement is empty"
		ENDIF
		lcCode = This.Code(lcSql)
		IF RIGHT(RTRIM(lcCode), 1) == ";"
			lnLast = RAT(";", lcCode)
			lcCode = LEFT(lcCode, lnLast - 1)
			lcSql = LEFT(lcSql, lnLast - 1)
		ENDIF
		IF ";" $ lcCode
			RETURN "it has more than one statement (a ';' with something after it): ide_data_db_execute runs one at a time"
		ENDIF
		lcUp = " " + UPPER(CHRTRAN(lcCode, "(),.;=<>+-*/%!|&^~:@#$?{}", SPACE(30))) + " "
		lcFirst = GETWORDNUM(lcUp, 1)
		DO CASE
			CASE INLIST(lcFirst, "SELECT", "WITH")
				RETURN "it is a " + lcFirst + ": reading goes through ide_data_db_query"
			CASE !INLIST(lcFirst, "INSERT", "UPDATE", "DELETE", "CREATE", "ALTER", "DROP", "TRUNCATE")
				RETURN "it starts with " + IIF(EMPTY(lcFirst), "nothing", "'" + lcFirst + "'") + ;
					": ide_data_db_execute runs one INSERT, UPDATE, DELETE, CREATE, ALTER, DROP or TRUNCATE"
		ENDCASE
		FOR lnW = 1 TO ALINES(laW, STRTRAN(This.cWriteWords, " ", CHR(13)), 1 + 4)
			lcW = laW[lnW]
			IF " " + lcW + " " $ lcUp
				RETURN "it has " + lcW + " in it" + This.Rewrite(lcW, lcUp)
			ENDIF
		ENDFOR
		IF !tlWholeTable
			DO CASE
				CASE lcFirst == "UPDATE" AND !(" WHERE " $ lcUp)
					RETURN "the UPDATE has no WHERE: it would change every row of the table; pass wholeTable: true if that is what you mean"
				CASE lcFirst == "DELETE" AND !(" WHERE " $ lcUp)
					RETURN "the DELETE has no WHERE: it would delete every row of the table; pass wholeTable: true if that is what you mean"
				CASE lcFirst == "TRUNCATE"
					RETURN "a TRUNCATE empties the whole table; pass wholeTable: true if that is what you mean"
				CASE lcFirst == "DROP"
					RETURN "a DROP removes the whole table; pass wholeTable: true if that is what you mean"
			ENDCASE
		ENDIF
		This.cStatement = lcFirst
		This.cSql = ALLTRIM(lcSql, 1, " ", CHR(9), CHR(13), CHR(10))
		RETURN ""
	ENDPROC

	PROCEDURE Check
		LPARAMETERS tcSql
		LOCAL lcSql, lcCode, lcFirst, lcUp, lnW, lcW, lnLast
		LOCAL ARRAY laW[1]
		lcSql = ALLTRIM(TRANSFORM(tcSql), 1, " ", CHR(9), CHR(13), CHR(10))
		This.cSql = ""
		IF EMPTY(lcSql)
			RETURN "is empty"
		ENDIF
		lcCode = This.Code(lcSql)
		IF RIGHT(RTRIM(lcCode), 1) == ";"
			lnLast = RAT(";", lcCode)
			lcCode = LEFT(lcCode, lnLast - 1)
			lcSql = LEFT(lcSql, lnLast - 1)
		ENDIF
		IF ";" $ lcCode
			RETURN "has more than one statement (a ';' with something after it)"
		ENDIF
		lcUp = " " + UPPER(CHRTRAN(lcCode, "(),.;=<>+-*/%!|&^~:@#$?{}", SPACE(30))) + " "
		lcFirst = GETWORDNUM(lcUp, 1)
		IF !INLIST(lcFirst, "SELECT", "WITH")
			RETURN "starts with " + IIF(EMPTY(lcFirst), "nothing", "'" + lcFirst + "'")
		ENDIF
		FOR lnW = 1 TO ALINES(laW, STRTRAN(This.cWords, " ", CHR(13)), 1 + 4)
			lcW = laW[lnW]
			IF " " + lcW + " " $ lcUp
				RETURN "has " + lcW + " in it" + This.Rewrite(lcW, lcUp)
			ENDIF
		ENDFOR
		This.cSql = ALLTRIM(lcSql, 1, " ", CHR(9), CHR(13), CHR(10))
		RETURN ""
	ENDPROC

	*-- Cómo se reescribe un falso positivo: FOR UPDATE es un bloqueo
	*-- y sobra; una columna o una tabla con ese nombre va entre las comillas
	*-- del motor (cEngine, si lo puso quien llama).
	PROCEDURE Rewrite
		LPARAMETERS tcWord, tcUp
		LOCAL lcQ
		IF tcWord == "UPDATE" AND " FOR UPDATE " $ tcUp
			RETURN " (FOR UPDATE locks rows: leave it out, the agent only reads)"
		ENDIF
		DO CASE
			CASE This.cEngine == "sqlserver"
				lcQ = "[" + LOWER(tcWord) + "]"
			CASE INLIST(This.cEngine, "mysql", "mariadb")
				lcQ = "`" + LOWER(tcWord) + "`"
			OTHERWISE
				lcQ = ["] + LOWER(tcWord) + ["]
		ENDCASE
		RETURN " (if it is not a statement: a column or a table called " + LOWER(tcWord) + ;
			" goes in the quotes of the engine (" + lcQ + " here))"
	ENDPROC

	*-- El código sin literales ni comentarios: cada carácter de dentro (y los
	*-- tabuladores y saltos), un espacio; mismo largo que tcSql, para que los ;
	*-- caigan en su sitio. Un «--» acaba en el salto de línea.
	PROTECTED PROCEDURE Code
		LPARAMETERS tcSql
		LOCAL lcSql, lcCode, lnLen, lnI, lcC, lcState
		lcSql = tcSql
		lcCode = ""
		lcState = ""
		lnLen = LEN(lcSql)
		lnI = 1
		DO WHILE lnI <= lnLen
			lcC = SUBSTR(lcSql, lnI, 1)
			DO CASE
				CASE lcState == "'" OR lcState == ["] OR lcState == "`"
					IF lcC == lcState
						IF SUBSTR(lcSql, lnI + 1, 1) == lcState
							lcCode = lcCode + "  "
							lnI = lnI + 2
							LOOP
						ENDIF
						lcState = ""
					ENDIF
					lcCode = lcCode + " "
				CASE lcState == "["
					IF lcC == "]"
						lcState = ""
					ENDIF
					lcCode = lcCode + " "
				CASE lcState == "--"
					IF INLIST(lcC, CHR(13), CHR(10))
						lcState = ""
					ENDIF
					lcCode = lcCode + " "
				CASE lcState == "/*"
					IF lcC == "*" AND SUBSTR(lcSql, lnI + 1, 1) == "/"
						lcCode = lcCode + "  "
						lnI = lnI + 2
						lcState = ""
						LOOP
					ENDIF
					lcCode = lcCode + " "
				CASE lcC == "-" AND SUBSTR(lcSql, lnI + 1, 1) == "-"
					lcState = "--"
					lcCode = lcCode + " "
				CASE lcC == "/" AND SUBSTR(lcSql, lnI + 1, 1) == "*"
					lcState = "/*"
					lcCode = lcCode + "  "
					lnI = lnI + 2
					LOOP
				CASE INLIST(lcC, "'", ["], "`", "[")
					lcState = lcC
					lcCode = lcCode + " "
				CASE INLIST(lcC, CHR(9), CHR(13), CHR(10))
					lcCode = lcCode + " "
				OTHERWISE
					lcCode = lcCode + lcC
			ENDCASE
			lnI = lnI + 1
		ENDDO
		RETURN lcCode
	ENDPROC
ENDDEFINE
