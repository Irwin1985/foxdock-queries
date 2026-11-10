*==================================================================
* QueriesPlugin.prg: el paquete «queries» de FoxDock.
*
* FoxQuery dentro del IDE: la carpeta de .sql del proyecto, validar, ejecutar
* por nombre y compilar el .fq. Tres módulos: catalog (QueriesCatalog.prg),
* la ventana FoxDock - Queries, las barras Queries..., New query..., Check y
* Reload, y las tools ide_queries_list, _get, _check, _sql y _save; run
* (QueriesRun.prg), Run..., Run on > y las tools ide_queries_run e
* ide_queries_execute; y build (QueriesBuild.prg), Build catalog... y la tool
* ide_queries_build. Las tools están en QueriesTools.prg.
*
* EL MENÚ LO RELLENA EL PAQUETE (FillWith, como data): Run on > es un submenú
* y AddBar no los tiene. El orden: Queries..., New query..., Run..., Check,
* Build catalog..., ----, Run on >, Reload. Cada barra llama a FoxDock.APP por
* su ruta: DO "<app>" WITH "bar", "queries", "<acción>" [, "<parámetro>"].
*
* El molde es el de «data» (DataPlugin.prg): un módulo por .prg con el prefijo
* del paquete, que se apaga en config.json y apagado no existe:
*   "options": { "queries": { "catalog": { "enabled": false } } }
* y el paquete entero, como cualquier plugin:
*   "plugins": { "queries": { "enabled": false } }
*
* FOXQUERY: la librería que el plugin pide con requires, en lib\foxquery\; no se edita
* aquí: se arregla en FoxQuery y se reemplaza entera. El paquete usa
* sus clases por NEWOBJECT con la ruta de la copia, nunca las funciones FQ_*
* (guardan su estado en _SCREEN, que es del programa del usuario) y nunca un
* SET PROCEDURE a ella (taparía el foxquery.prg que el usuario tenga en su
* proyecto). El almacén (Store) se crea la primera vez que se pide, nunca al
* arrancar el IDE, y se suelta en OnShutdown.
*==================================================================

#DEFINE CRLF CHR(13) + CHR(10)

DEFINE CLASS QueriesPlugin AS PluginBase
	cId = "queries"
	cTitle = "Queries"
	nOrder = 945
	cVersion = "0.7.0"
	lWantsIdle = .T.
	oModules = .NULL.
	oStore = .NULL.

	*-- Los módulos del paquete, uno por línea: id, clase y .prg.
	PROCEDURE ModuleList
		RETURN "catalog,QueriesCatalog,QueriesCatalog.prg" + CRLF + "run,QueriesRun,QueriesRun.prg" + CRLF + ;
			"build,QueriesBuild,QueriesBuild.prg"
	ENDPROC

	*-- Los módulos encendidos (una Collection por id), como en DataPlugin.
	PROCEDURE Modules
		LOCAL lnI
		LOCAL ARRAY laM[1], laP[1]
		IF ISNULL(This.oModules)
			This.oModules = CREATEOBJECT("Collection")
			FOR lnI = 1 TO ALINES(laM, This.ModuleList(), 1 + 4)
				IF ALINES(laP, laM[lnI], 1, ",") = 3
					This.LoadModule(LOWER(laP[1]), laP[2], laP[3])
				ENDIF
			ENDFOR
		ENDIF
		RETURN This.oModules
	ENDPROC

	*-- Un módulo por su id, o .NULL. si está apagado o no cargó.
	PROCEDURE Module
		LPARAMETERS tcId
		LOCAL loMods
		loMods = This.Modules()
		IF loMods.GetKey(LOWER(tcId)) > 0
			RETURN loMods.Item(LOWER(tcId))
		ENDIF
		RETURN .NULL.
	ENDPROC

	PROTECTED PROCEDURE LoadModule
		LPARAMETERS tcId, tcClass, tcPrg
		LOCAL loM, loErr
		IF !This.oHost.Options.Get(This.cId, tcId + ".enabled", .T.)
			This.oHost.Log(This.cId + ": module " + tcId + " is off in config.json (options." + This.cId + "." + ;
				tcId + ".enabled): its bars and tools are not there")
			RETURN
		ENDIF
		TRY
			SET PROCEDURE TO (This.CodeFile(tcPrg)) ADDITIVE
			loM = CREATEOBJECT(tcClass, This.oHost)
			This.oModules.Add(loM, tcId)
			This.oHost.Log(This.cId + ": module " + tcId + " loaded")
		CATCH TO loErr
			This.oHost.LogFault(This.cId + ": module " + tcId + " failed to load: " + TRANSFORM(loErr.ErrorNo) + ;
				" " + loErr.Message)
		ENDTRY
	ENDPROC

	*-- El título en el idioma de FoxDock, y el submenú lo rellena el paquete
	*-- (FillWith) si está el módulo catalog: sin él no hay línea Queries.
	PROCEDURE BuildMenu
		LPARAMETERS toMenu
		LOCAL loCat, loRun, loF
		This.cTitle = This.oHost.Translate("queries.title")
		This.Modules()
		loCat = This.Module("catalog")
		IF !ISNULL(loCat)
			toMenu.FillWith("FillMenu")
			*-- Las ventanas abiertas vuelven a poner sus textos (el idioma cambió).
			IF VARTYPE(loCat.oForm) == "O"
				loCat.oForm.Texts()
			ENDIF
		ENDIF
	ENDPROC

	*-- El submenú, en el orden de la cabecera.
	PROCEDURE FillMenu
		LPARAMETERS tcPopup
		LOCAL loCat, loRun, lnBar, loBuild
		loCat = This.Module("catalog")
		loRun = This.Module("run")
		IF ISNULL(loCat)
			RETURN
		ENDIF
		lnBar = 0
		lnBar = loCat.FillMenuPart(tcPopup, lnBar, "top")
		IF !ISNULL(loRun)
			lnBar = loRun.FillMenuPart(tcPopup, lnBar, "run")
		ENDIF
		lnBar = loCat.FillMenuPart(tcPopup, lnBar, "check")
		loBuild = This.Module("build")
		IF !ISNULL(loBuild)
			lnBar = loBuild.FillMenuPart(tcPopup, lnBar, "build")
		ENDIF
		IF !ISNULL(loRun)
			lnBar = loRun.FillMenuPart(tcPopup, lnBar, "runon")
		ENDIF
		lnBar = loCat.FillMenuPart(tcPopup, lnBar, "reload")
	ENDPROC

	*-- Una barra del submenú que llama al .APP (el molde de DataPlugin); acción
	*-- vacía, un separador. tcParam: el parámetro de la acción.
	PROCEDURE DefineBar
		LPARAMETERS tcPopup, tnBar, tcCaption, tcAction, tcParam, tcMessage
		LOCAL lcCmd
		IF EMPTY(tcAction)
			lcCmd = "DEFINE BAR " + TRANSFORM(tnBar) + " OF " + tcPopup + " PROMPT [\-]"
			&lcCmd
			RETURN tnBar
		ENDIF
		lcCmd = "DEFINE BAR " + TRANSFORM(tnBar) + " OF " + tcPopup + " PROMPT [" + tcCaption + "]" + ;
			IIF(EMPTY(tcMessage), "", " MESSAGE [" + CHRTRAN(tcMessage, "[]", "()") + "]")
		&lcCmd
		lcCmd = [ON SELECTION BAR ] + TRANSFORM(tnBar) + [ OF ] + tcPopup + [ DO "] + This.oHost.cAppPath + ;
			[" WITH "bar", "] + This.cId + [", "] + tcAction + ["] + IIF(EMPTY(tcParam), "", [, "] + tcParam + ["])
		&lcCmd
		This.oHost.oMenu.Remember(lcCmd)
		RETURN tnBar
	ENDPROC

	*-- Una barra que abre un submenú nuevo, tcSub, dentro de tcPopup.
	PROCEDURE DefineSubmenu
		LPARAMETERS tcPopup, tnBar, tcCaption, tcSub
		LOCAL lcCmd
		lcCmd = "DEFINE BAR " + TRANSFORM(tnBar) + " OF " + tcPopup + " PROMPT [" + tcCaption + "]"
		&lcCmd
		lcCmd = "ON BAR " + TRANSFORM(tnBar) + " OF " + tcPopup + " ACTIVATE POPUP " + tcSub
		&lcCmd
		This.oHost.oMenu.Remember(lcCmd)
		lcCmd = "DEFINE POPUP " + tcSub + " MARGIN RELATIVE"
		&lcCmd
		RETURN tnBar
	ENDPROC

	PROCEDURE GetAgentTools
		LPARAMETERS toTools
		LOCAL loMods, loM, lnN
		IF !("\IDETOOLS." $ UPPER(SET("PROCEDURE")))
			RETURN 0
		ENDIF
		This.EnsureProcedures()
		lnN = 0
		loMods = This.Modules()
		FOR EACH loM IN loMods
			lnN = lnN + loM.GetAgentTools(toTools)
		ENDFOR
		RETURN lnN
	ENDPROC

	*-- Las clases de las tools tienen que seguir visibles: el Bridge crea una
	*-- por llamada, por su nombre (y CLOSE ALL vacía SET PROCEDURE), como data.
	PROCEDURE OnIdle
		This.EnsureProcedures()
	ENDPROC

	PROCEDURE EnsureProcedures
		LOCAL lcTools, loErr
		lcTools = This.CodeFile("QueriesTools.prg")
		IF !EMPTY(This.cHome) AND !("\QUERIESTOOLS." $ UPPER(SET("PROCEDURE"))) AND ;
				"\IDETOOLS." $ UPPER(SET("PROCEDURE")) AND FILE(lcTools) AND !ISNULL(This.Module("catalog"))
			TRY
				SET PROCEDURE TO (lcTools) ADDITIVE
			CATCH TO loErr
				This.oHost.LogWarn("queries: " + lcTools + " not loaded: " + loErr.Message)
			ENDTRY
		ENDIF
	ENDPROC

	*-- Las acciones de las barras. Con el módulo apagado no hay barra que las
	*-- llame; si llega una (una barra vieja), se dice y no pasa nada.
	PROCEDURE OpenWindow
		LOCAL loM
		loM = This.Module("catalog")
		RETURN IIF(ISNULL(loM), This.Off("catalog"), !ISNULL(loM.OpenWindow()))
	ENDPROC

	PROCEDURE NewQuery
		LOCAL loM
		loM = This.Module("catalog")
		RETURN IIF(ISNULL(loM), This.Off("catalog"), !ISNULL(loM.OpenNew()))
	ENDPROC

	PROCEDURE CheckBar
		LOCAL loM
		loM = This.Module("catalog")
		RETURN IIF(ISNULL(loM), This.Off("catalog"), loM.CheckFolder() >= 0)
	ENDPROC

	PROCEDURE ReloadBar
		LOCAL loM
		loM = This.Module("catalog")
		RETURN IIF(ISNULL(loM), This.Off("catalog"), loM.Reload())
	ENDPROC

	*-- Run... y Run on >.
	PROCEDURE RunBar
		LOCAL loM
		loM = This.Module("run")
		RETURN IIF(ISNULL(loM), This.Off("run"), loM.RunBar())
	ENDPROC

	PROCEDURE RunOnBar
		LPARAMETERS tcKey
		LOCAL loM
		loM = This.Module("run")
		RETURN IIF(ISNULL(loM), This.Off("run"), loM.RunOnBar(tcKey))
	ENDPROC

	*-- Build catalog...
	PROCEDURE BuildBar
		LOCAL loM
		loM = This.Module("build")
		RETURN IIF(ISNULL(loM), This.Off("build"), loM.BuildBar())
	ENDPROC

	*-- El editor de un .sql que abrió el paquete se cerró.
	PROCEDURE OnEditorClose
		LPARAMETERS toInfo
		LOCAL loM
		loM = This.Module("catalog")
		IF !ISNULL(loM) AND VARTYPE(toInfo) == "O" AND PEMSTATUS(toInfo, "wh", 5)
			=loM.EditorClosed(toInfo.wh)
		ENDIF
	ENDPROC

	*-- La carpeta va con el proyecto activo; la ventana se cierra con él.
	PROCEDURE OnProjectOpen
		LPARAMETERS toProject
		LOCAL loM
		loM = This.Module("catalog")
		IF !ISNULL(loM)
			loM.ProjectChanged("")
		ENDIF
	ENDPROC

	PROCEDURE OnProjectClose
		LPARAMETERS tcProjectName
		LOCAL loM
		loM = This.Module("catalog")
		IF !ISNULL(loM)
			loM.ProjectChanged(TRANSFORM(tcProjectName))
		ENDIF
	ENDPROC

	PROTECTED PROCEDURE Off
		LPARAMETERS tcId
		This.oHost.LogWarn(This.cId + ": module " + tcId + " is off or did not load")
		RETURN .F.
	ENDPROC

	*-- El QueryStore de FoxQuery, por NEWOBJECT con la ruta de la copia del
	*-- paquete (sin SET PROCEDURE); se crea la primera vez que se pide y no carga
	*-- ninguna carpeta (eso es del módulo catalog). .NULL. si no se pudo crear,
	*-- y el log dice por qué.
	PROCEDURE Store
		LOCAL lcPrg, loErr
		IF ISNULL(This.oStore)
			lcPrg = This.CodeFile("lib\foxquery\foxquery.prg")
			TRY
				This.oStore = NEWOBJECT("QueryStore", lcPrg)
				This.oHost.Log(This.cId + ": FoxQuery " + This.oStore.cVersion + " query store made from " + lcPrg)
			CATCH TO loErr
				This.oStore = .NULL.
				This.oHost.LogFault(This.cId + ": the FoxQuery query store could not be made from " + lcPrg + ": " + ;
					TRANSFORM(loErr.ErrorNo) + " " + loErr.Message)
			ENDTRY
		ENDIF
		RETURN This.oStore
	ENDPROC

	*-- Al desmontar o cerrar el IDE: las ventanas se cierran y el almacén se suelta.
	PROCEDURE OnShutdown
		LOCAL loM
		loM = IIF(ISNULL(This.oModules), .NULL., This.Module("build"))
		IF !ISNULL(loM)
			loM.CloseAll()
		ENDIF
		loM = IIF(ISNULL(This.oModules), .NULL., This.Module("run"))
		IF !ISNULL(loM)
			loM.CloseAll()
		ENDIF
		loM = IIF(ISNULL(This.oModules), .NULL., This.Module("catalog"))
		IF !ISNULL(loM)
			loM.CloseAll()
		ENDIF
		IF !ISNULL(This.oStore)
			This.oStore = .NULL.
			This.oHost.Log(This.cId + ": query store released")
		ENDIF
	ENDPROC
ENDDEFINE
