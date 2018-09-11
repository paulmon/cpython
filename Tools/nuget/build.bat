@echo off
setlocal
set D=%~dp0
set PCBUILD=%D%..\..\PCbuild\
if "%Py_OutDir%"=="" set Py_OutDir=%PCBUILD%

set BUILDX86=
set BUILDX64=
set BUILDARM=
set REBUILD=
set OUTPUT=
set PACKAGES=
set DEBUG=
set DEBUG_SUFFIX=
set WINIOT=

:CheckOpts
if "%~1" EQU "-h" goto Help
if "%~1" EQU "-x86" (set BUILDX86=1) && shift && goto CheckOpts
if "%~1" EQU "-x64" (set BUILDX64=1) && shift && goto CheckOpts
if "%~1" EQU "-arm" (set BUILDARM=1) && shift && goto CheckOpts
if "%~1" EQU "-r" (set REBUILD=-r) && shift && goto CheckOpts
if "%~1" EQU "-d" (set DEBUG=-d && set _SUFFIX=_d) && shift && goto CheckOpts
if "%~1" EQU "--winiot" (set WINIOT=/p:"WinIoT='true'") && shift && goto CheckOpts
if "%~1" EQU "-o" (set OUTPUT="/p:OutputPath=%~2") && shift && shift && goto CheckOpts
if "%~1" EQU "--out" (set OUTPUT="/p:OutputPath=%~2") && shift && shift && goto CheckOpts
if "%~1" EQU "-p" (set PACKAGES=%PACKAGES% %~2) && shift && shift && goto CheckOpts
if "%~1" NEQ "" echo Unknown parameter "%~1" && exit

if not defined BUILDX86 if not defined BUILDX64 if not defined BUILDARM (set BUILDX86=1) && (set BUILDX64=1) && (set BUILDARM=1)

call "%D%..\msi\get_externals.bat"
call "%PCBUILD%find_msbuild.bat" %MSBUILD%
if ERRORLEVEL 1 (echo Cannot locate MSBuild.exe on PATH or as MSBUILD variable & exit /b 2)

if defined PACKAGES set PACKAGES="/p:Packages=%PACKAGES%"

if defined DEBUG (set CONFIGURATION=Debug
) else set CONFIGURATION=Release

if defined BUILDX86 (
    if defined REBUILD ( call "%PCBUILD%build.bat" -e -r
    ) else if not exist "%Py_OutDir%win32\python.exe" call "%PCBUILD%build.bat" -e
    if errorlevel 1 goto :eof

    %MSBUILD% "%D%make_pkg.proj" /p:Configuration=%CONFIGURATION% /p:Platform=x86 %OUTPUT% %PACKAGES% %WINIOT%
    if errorlevel 1 goto :eof
)

if defined BUILDX64 (
    if defined REBUILD ( call "%PCBUILD%build.bat" -p x64 -e -r
    ) else if not exist "%Py_OutDir%amd64\python.exe" call "%PCBUILD%build.bat" -p x64 -e
    if errorlevel 1 goto :eof

    %MSBUILD% "%D%make_pkg.proj" /p:Configuration=%CONFIGURATION% /p:Platform=x64 %OUTPUT% %PACKAGES% %WINIOT%
    if errorlevel 1 goto :eof
)

if defined BUILDARM (
    if defined REBUILD ( call "%PCBUILD%build.bat" -p ARM -e %DEBUG% -r --no-tkinter --no-ssl --no-vs
    ) else if not exist "%Py_OutDir%arm32\python%_SUFFIX%.exe" call "%PCBUILD%build.bat" -p ARM -e %DEBUG% --no-tkinter --no-ssl --no-vs
    if errorlevel 1 goto :eof

    %MSBUILD% "%D%make_pkg.proj" /p:Configuration=%CONFIGURATION% /p:Platform=ARM  /p:"PythonExe=%PCBUILD%amd64\python.exe" %OUTPUT% %PACKAGES% %WINIOT%  
    if errorlevel 1 goto :eof
)

exit /B 0

:Help
echo build.bat [-x86] [-x64] [--out DIR] [-r] [-h]
echo.
echo    -x86                Build x86 installers
echo    -x64                Build x64 installers
echo    -r                  Rebuild rather than incremental build
echo    --out [DIR]         Override output directory
echo    -h                  Show usage
