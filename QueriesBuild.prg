*==================================================================
* QueriesBuild.prg: el módulo «build» del paquete «queries» de FoxDock.
*
* Build catalog... (la barra, detrás de Check, y el botón de la ventana): la
* ventanita que compila la carpeta de las consultas a un .fq con QueryCompiler
* de la copia (por NEWOBJECT, nunca FQ_* ni SET PROCEDURE), carga lo escrito
* en un almacén aparte antes de decir que está hecho, y lo añade al proyecto.
* La clave nunca va a config.json, a foxdock.log ni a una tool; con Remember,
* cifrada con DPAPI (DataDpapi de plugins\data\DataConnections.prg), en
* <DataDir>\secrets\queries-<proyecto>.cred. La tool ide_queries_build
* (QueriesTools.prg) compila con la clave recordada, o sin clave y lo dice.
*
* Sin diálogos: un .fq que existe no se pisa sin Replace it, y lo dice la
* ventanita; Build de la copia pone SET SAFETY OFF y lo repone.
*==================================================================

#DEFINE CRLF CHR(13) + CHR(10)

DEFINE CLASS QueriesBuild AS Custom
	cId = "build"
	oHost = .NULL.
	oForm = .NULL.          && la ventanita de Build catalog..., una sola
	lShow = .T.             && .F.: sin enseñar la ventanita (los casos)
	cProjectFile = ""       && si no está vacío, el .pjx del «proyecto» (los casos)
	cLastError = ""
	cLastCode = ""
	cLastSaid = ""
	cLastFq = ""
	nLastQueries = 0
	nLastBytes = 0
	nLastMs = 0
	lLastEncrypted = .F.
	lLastKeyed = .F.
	cLastAdded = ""         && "added", "already", o "" (sin proyecto, o no se pidió)
	cLastOpened = ""        && lo último que Open folder le dio al Explorador (los casos)
	oLastWarnings = .NULL.  && los avisos del motor del último Build, uno por línea

	PROCEDURE Init
		LPARAMETERS toHost
		This.oHost = toHost
		This.oLastWarnings = CREATEOBJECT("Collection")
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

	*-- Su barra: «build», Build catalog... (detrás de Check, antes del separador).
	PROCEDURE FillMenuPart
		LPARAMETERS tcPopup, tnBar, tcPart
		LOCAL loP
		loP = This.Plugin()
		IF tcPart == "build"
			tnBar = loP.DefineBar(tcPopup, tnBar + 1, This.T("queries.bar.build"), "BuildBar", "", This.T("queries.bar.build.message"))
		ENDIF
		RETURN tnBar
	ENDPROC

	PROCEDURE GetAgentTools
		LPARAMETERS toTools
		IF ISNULL(This.Catalog())
			RETURN 0
		ENDIF
		toTools.Add(CREATEOBJECT("IdeQueriesBuildTool"))
		RETURN 1
	ENDPROC

	*--------------------------------------------------------------
	* El proyecto, el .fq y la clave.
	*--------------------------------------------------------------
	*-- El .pjx del proyecto activo ("" sin proyecto). El que se está cerrando no cuenta.
	PROCEDURE ProjectFile
		LOCAL loCat
		IF !EMPTY(This.cProjectFile)
			RETURN This.cProjectFile
		ENDIF
		IF _VFP.Projects.Count > 0
			loCat = This.Catalog()
			IF ISNULL(loCat) OR !(UPPER(_VFP.ActiveProject.Name) == UPPER(loCat.cClosing))
				RETURN _VFP.ActiveProject.Name
			ENDIF
		ENDIF
		RETURN ""
	ENDPROC

	*-- El .fq de entrada: <proyecto>.fq junto al .pjx; sin proyecto, queries.fq de la carpeta actual.
	PROCEDURE DefaultFq
		LOCAL lcPjx
		lcPjx = This.ProjectFile()
		IF EMPTY(lcPjx)
			RETURN ADDBS(SET("DEFAULT") + CURDIR()) + "queries.fq"
		ENDIF
		RETURN ADDBS(JUSTPATH(lcPjx)) + LOWER(JUSTSTEM(lcPjx)) + ".fq"
	ENDPROC

	*-- <DataDir>\secrets\queries-<proyecto>.cred; "" sin proyecto (la clave va con el proyecto).
	PROCEDURE SecretFile
		LOCAL lcPjx
		lcPjx = This.ProjectFile()
		IF EMPTY(lcPjx)
			RETURN ""
		ENDIF
		RETURN This.oHost.DataDir + "secrets\queries-" + LOWER(JUSTSTEM(lcPjx)) + ".cred"
	ENDPROC

	*-- DataConnections.prg del paquete data, esté data encendido o no: su carpeta de código.
	PROCEDURE DpapiFile
		LOCAL loD
		loD = This.oHost.PluginById("data")
		IF !ISNULL(loD)
			RETURN loD.CodeFile("DataConnections.prg")
		ENDIF
		RETURN This.oHost.CodeHome("data") + "DataConnections.prg"
	ENDPROC

	*-- Por qué no se puede recordar la clave ("" si se puede).
	PROCEDURE NoRemember
		DO CASE
			CASE EMPTY(This.ProjectFile())
				RETURN This.T("queries.build.noRememberProject")
			CASE !FILE(This.DpapiFile())
				RETURN This.T("queries.build.noRememberDpapi", This.DpapiFile())
		ENDCASE
		RETURN ""
	ENDPROC

	PROTECTED PROCEDURE Dpapi
		LOCAL loD, loErr
		loD = .NULL.
		IF !EMPTY(This.NoRemember())
			RETURN .NULL.
		ENDIF
		TRY
			loD = NEWOBJECT("DataDpapi", This.DpapiFile())
		CATCH TO loErr
			This.oHost.LogWarn("queries: DataDpapi could not be made from " + This.DpapiFile() + ": " + loErr.Message)
		ENDTRY
		RETURN loD
	ENDPROC

	PROCEDURE HasKey
		LOCAL lcFile
		lcFile = This.SecretFile()
		RETURN !EMPTY(lcFile) AND FILE(lcFile)
	ENDPROC

	*-- La clave recordada del proyecto, o "".
	PROCEDURE ReadKey
		LOCAL loD
		IF !This.HasKey()
			RETURN ""
		ENDIF
		loD = This.Dpapi()
		IF ISNULL(loD)
			RETURN ""
		ENDIF
		RETURN loD.Unprotect(FILETOSTR(This.SecretFile()))
	ENDPROC

	*-- Con Remember: la clave, cifrada con la cuenta de Windows. .F. con el motivo.
	PROCEDURE RememberKey
		LPARAMETERS tcKey
		LOCAL loD, lcBlob, lcFile, lcSafety
		This.cLastError = This.NoRemember()
		IF !EMPTY(This.cLastError)
			RETURN .F.
		ENDIF
		loD = This.Dpapi()
		lcBlob = IIF(ISNULL(loD), "", loD.Protect(tcKey))
		IF EMPTY(lcBlob)
			This.cLastError = This.T("queries.build.notRemembered")
			RETURN .F.
		ENDIF
		lcFile = This.SecretFile()
		IF !DIRECTORY(JUSTPATH(lcFile), 1)
			MKDIR (JUSTPATH(lcFile))
		ENDIF
		lcSafety = SET("SAFETY")
		SET SAFETY OFF
		STRTOFILE(lcBlob, lcFile, 0)
		SET SAFETY &lcSafety
		This.oHost.Log("queries: key remembered for " + LOWER(JUSTSTEM(This.ProjectFile())) + ", encrypted with the Windows account, in " + lcFile)
		RETURN .T.
	ENDPROC

	PROCEDURE ForgetKey
		IF !This.HasKey()
			RETURN .F.
		ENDIF
		ERASE (This.SecretFile())
		This.oHost.Log("queries: the remembered key for " + LOWER(JUSTSTEM(This.ProjectFile())) + " was removed")
		RETURN .T.
	ENDPROC

	*--------------------------------------------------------------
	* Build: compila, carga lo escrito aparte, y al proyecto.
	*--------------------------------------------------------------
	PROCEDURE Build
		LPARAMETERS tcFq, tcKey, tlEncrypt, tlReplace, tlAdd
		LOCAL loCat, lcFolder, loC, lnT0, llOk, loS, lnI, lcKey, laF[1]
		This.cLastError = ""
		This.cLastCode = ""
		This.cLastFq = ALLTRIM(TRANSFORM(tcFq))
		This.nLastQueries = 0
		This.nLastBytes = 0
		This.nLastMs = 0
		This.lLastEncrypted = .F.
		This.lLastKeyed = .F.
		This.cLastAdded = ""
		This.oLastWarnings = CREATEOBJECT("Collection")
		lcKey = IIF(VARTYPE(tcKey) == "C", tcKey, "")
		loCat = This.Catalog()
		IF ISNULL(loCat)
			RETURN This.Fail("catalog_off", "the catalog module of the queries package is off (options.queries.catalog.enabled)")
		ENDIF
		lcFolder = loCat.Folder()
		IF !DIRECTORY(lcFolder, 1)
			RETURN This.Fail("folder_not_found", "the folder of the queries does not exist: " + lcFolder)
		ENDIF
		IF EMPTY(This.cLastFq)
			RETURN This.Fail("catalog_invalid", "Build needs the name of the .fq to write")
		ENDIF
		IF EMPTY(JUSTEXT(This.cLastFq))
			This.cLastFq = This.cLastFq + ".fq"
		ENDIF
		IF FILE(This.cLastFq) AND !tlReplace
			RETURN This.Fail("fq_exists", This.cLastFq + " is already there: check Replace it to overwrite it")
		ENDIF
		loC = NEWOBJECT("QueryCompiler", This.CopyFile())
		lnT0 = SECONDS()
		llOk = loC.Build(lcFolder, This.cLastFq, lcKey, tlEncrypt)
		This.nLastMs = INT((SECONDS() - lnT0) * 1000)
		IF !llOk
			RETURN This.Fail(loC.cLastErrorCode, loC.cLastError)
		ENDIF
		*-- El mensaje de FoxQuery ya lleva su código delante: el fichero sin ruta, la línea y el mensaje.
		FOR lnI = 1 TO loC.nWarnings
			This.oLastWarnings.Add(LOWER(JUSTFNAME(TRANSFORM(loC.aWarnings[lnI, 2]))) + " line " + TRANSFORM(loC.aWarnings[lnI, 3]) + ": " + ;
				This.WithCode(loC.aWarnings[lnI, 1], loC.aWarnings[lnI, 4]))
		ENDFOR
		*-- Lo que no carga no está hecho: el .fq recién escrito, en un almacén aparte, con la misma clave.
		loS = loCat.NewStore()
		IF !loS.Load(This.cLastFq, lcKey)
			RETURN This.Fail("catalog_not_loaded", This.cLastFq + " was written, but it does not load: " + loS.cLastErrorCode + ": " + loS.cLastError)
		ENDIF
		This.nLastQueries = loS.nQueries
		IF ADIR(laF, This.cLastFq) > 0
			This.nLastBytes = laF[1, 2]
		ENDIF
		This.lLastEncrypted = tlEncrypt
		This.lLastKeyed = !EMPTY(lcKey)
		IF tlAdd
			This.cLastAdded = This.AddToProject(This.cLastFq)
		ENDIF
		This.oHost.Log("queries: built " + This.cLastFq + " from " + lcFolder + ": " + TRANSFORM(This.nLastQueries) + " queries, " + ;
			TRANSFORM(This.nLastBytes) + " bytes, " + TRANSFORM(This.nLastMs) + " ms, " + IIF(tlEncrypt, "encrypted", "not encrypted") + ", " + ;
			IIF(This.lLastKeyed, "with its key", "with the fixed key of FoxQuery") + ", " + TRANSFORM(This.oLastWarnings.Count) + " warning(s)" + ;
			IIF(EMPTY(This.cLastAdded), "", ", " + This.cLastAdded + " to the project"))
		RETURN .T.
	ENDPROC

	*-- Files.Add del proyecto abierto si no está ya. "added", "already" o "" (sin proyecto).
	PROCEDURE AddToProject
		LPARAMETERS tcFq
		LOCAL loPj, loF, lcPjx, loErr, lcSaid
		lcPjx = This.ProjectFile()
		loPj = .NULL.
		FOR EACH loF IN _VFP.Projects
			IF UPPER(loF.Name) == UPPER(FULLPATH(lcPjx))
				loPj = loF
			ENDIF
		ENDFOR
		IF EMPTY(lcPjx) OR ISNULL(loPj)
			RETURN ""
		ENDIF
		FOR EACH loF IN loPj.Files
			IF UPPER(loF.Name) == UPPER(FULLPATH(tcFq))
				RETURN "already"
			ENDIF
		ENDFOR
		lcSaid = ""
		TRY
			loF = loPj.Files.Add(FULLPATH(tcFq))
			loF.Exclude = .F.
			lcSaid = "added"
		CATCH TO loErr
			This.oHost.LogWarn("queries: " + tcFq + " could not be added to " + lcPjx + ": " + loErr.Message)
		ENDTRY
		RETURN lcSaid
	ENDPROC

	PROCEDURE Fail
		LPARAMETERS tcCode, tcError
		This.cLastCode = TRANSFORM(tcCode)
		This.cLastError = TRANSFORM(tcError)
		This.oHost.LogWarn("queries: not built: " + This.WithCode(This.cLastCode, This.cLastError))
		RETURN .F.
	ENDPROC

	*-- «código: motivo», sin repetir el código si el motivo ya lo trae delante (los de FoxQuery).
	PROCEDURE WithCode
		LPARAMETERS tcCode, tcWhy
		LOCAL lcCode, lcWhy
		lcCode = TRANSFORM(tcCode)
		lcWhy = TRANSFORM(tcWhy)
		*-- El código, una vez: si el motivo ya lo trae, delante o en medio («fichero(línea): código: motivo»), va tal cual.
		IF EMPTY(lcCode) OR ATC(lcCode + ": ", lcWhy) > 0
			RETURN lcWhy
		ENDIF
		RETURN lcCode + ": " + lcWhy
	ENDPROC

	*-- Lo que dice el panel de la ventanita tras un Build que salió bien.
	PROCEDURE DoneText
		LOCAL lcText, lcW
		lcText = This.T("queries.build.done", This.cLastFq, This.nLastQueries, This.nLastBytes, This.nLastMs) + CRLF + ;
			IIF(This.lLastEncrypted, This.T("queries.build.encrypted"), This.T("queries.build.notEncrypted")) + ", " + ;
			IIF(This.lLastKeyed, This.T("queries.build.keyed"), This.T("queries.build.fixedKey"))
		DO CASE
			CASE This.cLastAdded == "added"
				lcText = lcText + CRLF + This.T("queries.build.added", JUSTFNAME(This.ProjectFile()))
			CASE This.cLastAdded == "already"
				lcText = lcText + CRLF + This.T("queries.build.already", JUSTFNAME(This.ProjectFile()))
		ENDCASE
		IF This.oLastWarnings.Count > 0
			lcText = lcText + CRLF + This.T("queries.build.warnings", This.oLastWarnings.Count)
			FOR EACH lcW IN This.oLastWarnings
				lcText = lcText + CRLF + "  " + lcW
			ENDFOR
		ENDIF
		RETURN lcText
	ENDPROC

	*--------------------------------------------------------------
	* Build catalog...: la ventanita.
	*--------------------------------------------------------------
	PROCEDURE BuildBar
		RETURN !ISNULL(This.OpenBuild())
	ENDPROC

	PROCEDURE OpenBuild
		LOCAL loP
		IF VARTYPE(This.oForm) == "O"
			IF This.lShow
				This.oForm.Show()
			ENDIF
			RETURN This.oForm
		ENDIF
		loP = This.Plugin()
		This.oForm = NEWOBJECT("QueriesBuildForm", loP.CodeFile("QueriesBuild.prg"), "", This)
		IF This.lShow
			This.oForm.Show()
		ENDIF
		RETURN This.oForm
	ENDPROC

	*-- El botón Build de la ventanita.
	PROCEDURE BuildFromForm
		LPARAMETERS toF
		LOCAL lcKey, llOk, lcFq
		lcKey = ALLTRIM(toF.txtKey.Value)
		lcFq = ALLTRIM(toF.txtFq.Value)
		llOk = This.Build(lcFq, lcKey, toF.chkEncrypt.Value, toF.chkReplace.Value, toF.chkAdd.Value AND toF.chkAdd.Enabled)
		IF !llOk
			This.Say(toF, IIF(This.cLastCode == "fq_exists", "queries.build.exists", "queries.build.failed"), This.cLastFq, This.cLastCode, ;
				STRTRAN(This.cLastError, This.cLastCode + ": ", "", 1, 1))
			*-- catalog_not_written: la carpeta del .fq no existe (FoxQuery lo dice y no la crea), o el .fq está
			*-- abierto en un editor o es de solo lectura. A cada caso, su remedio.
			IF This.cLastCode == "catalog_not_written"
				This.cLastSaid = This.cLastSaid + CRLF + IIF(!EMPTY(lcFq) AND !DIRECTORY(JUSTPATH(lcFq)), ;
					This.T("queries.build.noFolder", JUSTPATH(lcFq)), This.T("queries.build.notWritten"))
				toF.edtSay.Value = This.cLastSaid
			ENDIF
			RETURN .F.
		ENDIF
		toF.chkReplace.Value = .F.
		IF toF.chkRemember.Value AND toF.chkRemember.Enabled AND !EMPTY(lcKey)
			IF !This.RememberKey(lcKey)
				This.Say(toF, "queries.build.notRememberedWhy", This.cLastError)
				RETURN .T.
			ENDIF
			toF.cmdForget.Enabled = .T.
		ENDIF
		This.cLastSaid = This.DoneText()
		toF.edtSay.Value = This.cLastSaid
		This.oHost.NotifyKey("queries.build.notify", JUSTFNAME(This.cLastFq), This.nLastQueries)
		RETURN .T.
	ENDPROC

	*-- Open folder de la ventanita: la carpeta del .fq en el Explorador de
	*-- Windows, con el .fq elegido si ya está. Sin la carpeta, .F. y lo dice en
	*-- cLastSaid. Con FOXDOCK_SHELL_OPEN=off (las pruebas) no abre nada; cLastOpened,
	*-- los argumentos del Explorador, para los casos.
	PROCEDURE OpenFqFolder
		LPARAMETERS tcFq
		LOCAL lcFq, lcDir, lcArgs
		This.cLastOpened = ""
		lcFq = ALLTRIM(TRANSFORM(tcFq))
		IF EMPTY(lcFq)
			lcDir = ""
		ELSE
			IF EMPTY(JUSTEXT(lcFq))
				lcFq = lcFq + ".fq"
			ENDIF
			*-- Una ruta entera, como está escrita (FULLPATH la pasa a mayúsculas).
			IF !(SUBSTR(lcFq, 2, 1) == ":" OR LEFT(lcFq, 2) == "\\")
				lcFq = FULLPATH(lcFq)
			ENDIF
			lcDir = ADDBS(JUSTPATH(lcFq))
		ENDIF
		IF EMPTY(lcDir) OR !DIRECTORY(lcDir, 1)
			This.cLastSaid = This.T("queries.build.noFolder", lcDir)
			This.oHost.Log("queries: " + This.E("queries.build.noFolder", lcDir))
			RETURN .F.
		ENDIF
		lcArgs = IIF(FILE(lcFq), '/select,"' + lcFq + '"', '"' + lcDir + '"')
		This.cLastOpened = lcArgs
		DECLARE INTEGER ShellExecute IN shell32 AS FdQueriesShellExecute INTEGER hWnd, STRING cOperation, STRING cFile, ;
			STRING cParameters, STRING cDirectory, INTEGER nShowCmd
		IF !(LOWER(GETENV("FOXDOCK_SHELL_OPEN")) == "off")
			=FdQueriesShellExecute(_screen.HWnd, "open", "explorer.exe", lcArgs, lcDir, 1)
		ENDIF
		This.oHost.Log("queries: " + IIF(FILE(lcFq), lcFq + " shown", lcDir + " opened") + " in the Windows Explorer")
		This.cLastSaid = ""
		RETURN .T.
	ENDPROC

	PROCEDURE ForgetFromForm
		LPARAMETERS toF
		=This.ForgetKey()
		toF.txtKey.Value = ""
		toF.chkRemember.Value = .F.
		toF.cmdForget.Enabled = .F.
		This.Say(toF, "queries.build.forgotten", LOWER(JUSTSTEM(This.ProjectFile())))
	ENDPROC

	PROCEDURE Say
		LPARAMETERS toF, tcKey, tv1, tv2, tv3
		This.cLastSaid = This.T(tcKey, tv1, tv2, tv3)
		IF VARTYPE(toF) == "O"
			toF.edtSay.Value = This.cLastSaid
		ENDIF
	ENDPROC
ENDDEFINE


*------------------------------------------------------------------
* La ventanita de Build catalog...: la carpeta, el .fq, la
* clave con Remember y Forget, Encrypt, Add to the project, Replace it, el panel
* y Build y Close. Sin diálogos.
*------------------------------------------------------------------
DEFINE CLASS QueriesBuildForm AS Form
	AutoCenter = .T.
	MinButton = .F.
	MaxButton = .F.
	ShowWindow = 0
	WindowType = 0
	BorderStyle = 2
	Width = 520
	Height = 352
	Name = "FoxDockQueriesBuild"
	oModule = .NULL.

	ADD OBJECT lblFolder AS Label WITH Left = 10, Top = 14, AutoSize = .T.
	ADD OBJECT txtFolder AS TextBox WITH Left = 130, Top = 10, Width = 380, ReadOnly = .T., TabStop = .F.
	ADD OBJECT lblFq AS Label WITH Left = 10, Top = 46, AutoSize = .T.
	*-- Open folder, al lado del .fq.
	ADD OBJECT txtFq AS TextBox WITH Left = 130, Top = 42, Width = 280, MaxLength = 254
	ADD OBJECT cmdOpenFq AS QueriesOpenFqButton WITH Left = 420, Top = 41, Width = 90, Height = 26
	ADD OBJECT lblKey AS Label WITH Left = 10, Top = 78, AutoSize = .T.
	ADD OBJECT txtKey AS TextBox WITH Left = 130, Top = 74, Width = 200, MaxLength = 128, PasswordChar = "*"
	ADD OBJECT chkRemember AS CheckBox WITH Left = 340, Top = 76, AutoSize = .T., Value = .F.
	ADD OBJECT cmdForget AS QueriesForgetButton WITH Left = 430, Top = 72, Width = 80, Height = 26
	ADD OBJECT chkEncrypt AS CheckBox WITH Left = 130, Top = 108, AutoSize = .T., Value = .F.
	ADD OBJECT chkAdd AS CheckBox WITH Left = 130, Top = 132, AutoSize = .T., Value = .F.
	ADD OBJECT chkReplace AS CheckBox WITH Left = 130, Top = 156, AutoSize = .T., Value = .F.
	ADD OBJECT edtSay AS EditBox WITH Left = 10, Top = 186, Width = 500, Height = 120, ReadOnly = .T., ScrollBars = 2
	ADD OBJECT cmdBuild AS QueriesBuildButton WITH Left = 10, Top = 314, Width = 100, Height = 28, Default = .T.
	ADD OBJECT cmdClose AS QueriesBuildCloseButton WITH Left = 410, Top = 314, Width = 100, Height = 28, Cancel = .T.

	PROCEDURE Init
		LPARAMETERS toModule
		LOCAL loM, loCat, lcWhy, lcSay, lcPjx
		This.oModule = toModule
		loM = toModule
		loCat = loM.Catalog()
		lcPjx = loM.ProjectFile()
		This.Caption = loM.T("queries.build.window")
		This.lblFolder.Caption = loM.T("queries.build.folder")
		This.lblFq.Caption = loM.T("queries.build.fq")
		This.lblKey.Caption = loM.T("queries.build.key")
		This.chkRemember.Caption = loM.T("queries.build.remember")
		This.cmdForget.Caption = loM.T("queries.build.forget")
		This.cmdOpenFq.Caption = loM.T("queries.window.openFolder")
		This.chkEncrypt.Caption = loM.T("queries.build.encrypt")
		This.chkAdd.Caption = loM.T("queries.build.add")
		This.chkReplace.Caption = loM.T("queries.build.replace")
		This.cmdBuild.Caption = loM.T("queries.build.build")
		This.cmdClose.Caption = loM.T("queries.window.close")
		This.txtFolder.Value = IIF(ISNULL(loCat), "", loCat.Folder())
		This.txtFq.Value = PADR(loM.DefaultFq(), 254)
		lcSay = ""
		*-- Remember: con proyecto y con DataDpapi; una clave recordada viene puesta.
		lcWhy = loM.NoRemember()
		This.chkRemember.Enabled = EMPTY(lcWhy)
		IF !EMPTY(lcWhy)
			lcSay = lcSay + lcWhy + CRLF
		ENDIF
		IF loM.HasKey()
			This.txtKey.Value = PADR(loM.ReadKey(), 128)
			This.chkRemember.Value = !EMPTY(This.txtKey.Value)
		ENDIF
		This.cmdForget.Enabled = loM.HasKey()
		*-- Add to the project: marcada con un proyecto abierto; sin él, apagada y dice por qué.
		This.chkAdd.Enabled = !EMPTY(lcPjx)
		This.chkAdd.Value = !EMPTY(lcPjx)
		IF EMPTY(lcPjx)
			lcSay = lcSay + loM.T("queries.build.noProject") + CRLF
		ENDIF
		IF FILE(ALLTRIM(This.txtFq.Value))
			lcSay = lcSay + loM.T("queries.build.existsAlready", ALLTRIM(This.txtFq.Value)) + CRLF
		ENDIF
		This.edtSay.Value = lcSay
	ENDPROC

	PROCEDURE Destroy
		IF VARTYPE(This.oModule) == "O"
			This.oModule.FormGone()
		ENDIF
		This.oModule = .NULL.
	ENDPROC
ENDDEFINE

DEFINE CLASS QueriesBuildButton AS CommandButton
	PROCEDURE Click
		=Thisform.oModule.BuildFromForm(Thisform)
	ENDPROC
ENDDEFINE

DEFINE CLASS QueriesOpenFqButton AS CommandButton
	PROCEDURE Click
		IF !Thisform.oModule.OpenFqFolder(Thisform.txtFq.Value)
			Thisform.edtSay.Value = Thisform.oModule.cLastSaid
		ENDIF
	ENDPROC
ENDDEFINE

DEFINE CLASS QueriesForgetButton AS CommandButton
	PROCEDURE Click
		=Thisform.oModule.ForgetFromForm(Thisform)
	ENDPROC
ENDDEFINE

DEFINE CLASS QueriesBuildCloseButton AS CommandButton
	PROCEDURE Click
		Thisform.Release()
	ENDPROC
ENDDEFINE
