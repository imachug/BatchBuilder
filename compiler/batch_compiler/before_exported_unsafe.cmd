setlocal

rem Clean
for /F "tokens=1,* delims==" %%a IN ('set') do (
	if not "%%a" == "__local_storage__" (
		if not "%%a" == "__global_storage__" (
			if not "%%a" == "__passed_global_storage__" (
				setlocal ENABLEDELAYEDEXPANSION
				set a=%%a
				if not "!a:~0,9!" == "__return_" (
					endlocal & set %%a=
				) else (
					endlocal
				)
			)
		)
	)
)

rem Set global
for /F "tokens=1* delims==" %%a IN ('type %__global_storage__%') do (
	set "%%a=%%b"
)

rem Save local storage
set __local_storage__=%TEMP%\%RANDOM%%RANDOM%%RANDOM%.tmp
