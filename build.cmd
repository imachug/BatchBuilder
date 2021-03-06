@echo off
setlocal ENABLEDELAYEDEXPANSION

pushd %~dp0

if not exist "src" (
	echo No src directory found. Make sure build.cmd is in the same directory as src.
	echo If you want to create a new project, use create-project.cmd instead.
	exit /b
)

:: Create dist ::
	rmdir /S /Q dist 2>nul
	mkdir dist

	echo 1 >dist\1
	echo 2 >dist\2
	echo @echo off >dist\settings.cmd
	echo rem Built by batchbuilder >>dist\settings.cmd

:: Parse INI
	set settings_entry=entry.cmd
	set settings_delete_compiled=yes
	set settings_compile_if=batch ~-4 .cmd,batch ~-4 .bat
	set settings_packed=yes

	for /F "tokens=1,* delims==" %%a IN (src\build.ini) do (
		set settings_%%a=%%b
	)

	for /F "tokens=1,* delims==" %%a IN ('set settings_') do (
		echo set %%a=%%b>>dist\settings.cmd
	)

	:: Parse compile_if
		set compile_if_count=0

		for %%i in ("%settings_compile_if:,=" "%") do (
			set i=%%~i
			for /F "tokens=1* delims= " %%u in ("!i:* =!") do (
				set key=%%u
				set value=%%v
			)

			for /F "delims=" %%k in ("!i:* =!") do (
				set compiler=!i: %%k=!
			)

			if not exist "compiler\!compiler!_compiler" (
				echo Compiler !compiler! does not exist
				exit /b
			)

			set /a compile_if_count=!compile_if_count! + 1
			set compile_if_compiler_!compile_if_count!=!compiler!
			set compile_if_key_!compile_if_count!=!key!
			set compile_if_value_!compile_if_count!=!value!
		)

:: Compile ::
	rmdir /S /Q compiler\compiled 2>nul
	mkdir compiler\compiled
	mkdir compiler\info
	mkdir compiler\info\exports
	mkdir compiler\info\exports_has_return
	mkdir compiler\info\classes

	set root=%~dp0src\

	for /R src %%a IN (*) DO (
		set ext=%%a

		set compiler=none
		for /L %%i in (1,1,%compile_if_count%) do (
			for /F "delims=" %%k in ("!compile_if_key_%%i!") do (
				if "!ext:%%k!" == "!compile_if_value_%%i!" (
					set compiler=!compile_if_compiler_%%i!
				)
			)
		)

		set relative=%%a
		set relative=!relative:%root%=!

		if not "!compiler!" == "none" (
			call "compiler\!compiler!_compiler\compile1.cmd" "%%a" "!relative!" >"compiler\compiled\!relative!" 2>compiler\info\log
			if "!ERRORLEVEL!" == "1" (
				echo Compile error in !relative!:
				type compiler\info\log

				rmdir /S /Q compiler\compiled
				rmdir /S /Q compiler\info

				popd
				exit /b
			) else (
				set first_line=
				<compiler\info\log set /p first_line=
				if not "!first_line!" == "" (
					echo Warnings in !relative!:
					type compiler\info\log
				)
			)
		) else (
			copy "%%a" "compiler\compiled\!relative!"
		)
	)

	set root=%~dp0compiler\compiled\

	for /R compiler\compiled %%a IN (*) DO (
		set ext=%%a
		set ext=!ext:~-4!

		set compiler=none
		for /L %%i in (1,1,%compile_if_count%) do (
			for /F "delims=" %%k in ("!compile_if_key_%%i!") do (
				if "!ext:%%k!" == "!compile_if_value_%%i!" (
					set compiler=!compile_if_compiler_%%i!
				)
			)
		)

		set relative=%%a
		set relative=!relative:%root%=!

		if not "!compiler!" == "none" (
			move "%%a" "%%a.before_compilation"

			call "compiler\!compiler!_compiler\compile2.cmd" "%%a.before_compilation" "!relative!" >"compiler\compiled\!relative!" 2>compiler\info\log
			if "!ERRORLEVEL!" == "1" (
				echo Compile error in !relative!:
				type compiler\info\log

				rmdir /S /Q compiler\compiled
				rmdir /S /Q compiler\info

				popd
				exit /b
			) else (
				set first_line=
				<compiler\info\log set /p first_line=
				if not "!first_line!" == "" (
					echo Warnings in !relative!:
					type compiler\info\log
				)
			)

			del "%%a.before_compilation"
		)
	)

	:: Run finish hooks ::
		for /L %%i in (1,1,%compile_if_count%) do (
			set compiler=!compile_if_compiler_%%i!
			if not defined __compiler_handled_!compiler!__ (
				set __compiler_handled_!compiler!__=yes
				call "compiler\!compiler!_compiler\finish.cmd"
			)
		)
		for /L %%i in (1,1,%compile_if_count%) do (
			set __compiler_handled_!compiler!__=
		)

	:: Add __class__
		copy "%~dp0compiler\__class__.cmd" "compiler\compiled\__class__.cmd"

if "%settings_packed%" == "local" (
	set settings_packed=no
)

if "%settings_packed%" == "no" (
	:: Create bootstrap ::
		copy dist\settings.cmd+compiler\bootstrap_unpacked.cmd /B dist\bootstrap.cmd

	:: Save scripts :
		robocopy compiler\compiled dist\contents /E >nul
) else (
	:: Create CAB ::
		echo .OPTION EXPLICIT >tmp.ddf
		echo .Set CabinetNameTemplate=data.cab >>tmp.ddf
		echo .Set Cabinet=on >>tmp.ddf
		echo .Set Compress=on >>tmp.ddf
		echo .Set DiskDirectoryTemplate=dist >>tmp.ddf

		set root=%~dp0compiler\compiled\
		for /R compiler\compiled %%a IN (*) DO (
			set relative=%%a
			set relative=!relative:%root%=!

			echo "%%a" >>tmp.ddf
		)


		:: Always add 2 more files because EXPAND works with >1 files only ::
		echo "%~dp0dist\1" >>tmp.ddf
		echo "%~dp0dist\2" >>tmp.ddf

		makecab /F tmp.ddf >nul

		del tmp.ddf
		del setup.rpt
		del setup.inf

	:: Append CAB to bootstrapper ::
		copy dist\settings.cmd+compiler\bootstrap.cmd+dist\data.cab /B dist\bootstrap.cmd

		if not "%settings_delete_compiled%" == "no" (
			del dist\data.cab
		)
)

if not "%settings_delete_compiled%" == "no" (
	rmdir /S /Q compiler\compiled
)

rmdir /S /Q compiler\info
del dist\1
del dist\2
del dist\settings.cmd

popd