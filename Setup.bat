@echo off

if not defined NO_SET_LOCAL (
    setlocal
)

pushd "%~dp0"

call :MarkStartOfBlock "%~0"

call :MarkStartOfBlock "Setup the git hooks"
    if not exist .git\hooks (
      echo ".git\hooks not found: skipping git hook setup"
      goto SkipGitHooks
    )

    rem Remove the old post-checkout hook.
    if exist .git\hooks\post-checkout del .git\hooks\post-checkout

    rem Remove the old post-merge hook.
    if exist .git\hooks\post-merge del .git\hooks\post-merge

    rem Remove the old pre-commit hook.
    if exist .git\hooks\pre-commit del .git\hooks\pre-commit

    rem Copy git hooks to .git directory.
    xcopy /s /i /q "%~dp0\SpatialGDK\Extras\git" "%~dp0\.git\hooks"

    rem We pass Setup.bat args, such as --mobile, to the post-merge hook to run Setup.bat with the same args in future.
    set POST_MERGE_HOOK="%~dp0\.git\hooks\post-merge"
    powershell -Command "(Get-Content -Path %POST_MERGE_HOOK%) -replace \"SETUP_ARGS\", \"%*\" | Set-Content -Path %POST_MERGE_HOOK%"

    :SkipGitHooks
call :MarkEndOfBlock "Setup the git hooks"

call :MarkStartOfBlock "Check dependencies"

    call "%~dp0SpatialGDK\Build\Scripts\FindMSBuild.bat"

    if not defined MSBUILD_EXE (
        echo Error: Could not find the MSBuild executable. Please make sure you have Microsoft Visual Studio or Microsoft Build Tools installed.
        pause
        exit /b 1
    )

    where spatial >nul
    if ERRORLEVEL 1 (
        echo Error: Could not find spatial. Please make sure you have it installed and the containing directory added to PATH environment variable.
        pause
        exit /b 1
    )
call :MarkEndOfBlock "Check dependencies"

call :MarkStartOfBlock "Setup variables"
    set /p PINNED_CORE_SDK_VERSION=<.\SpatialGDK\Extras\core-sdk.version
    set BUILD_DIR=%~dp0SpatialGDK\Build
    set CORE_SDK_DIR=%BUILD_DIR%\core_sdk
    set WORKER_SDK_DIR=%~dp0SpatialGDK\Source\SpatialGDK\Public\WorkerSDK
    set WORKER_SDK_DIR_OLD=%~dp0SpatialGDK\Source\Public\WorkerSdk
    set BINARIES_DIR=%~dp0SpatialGDK\Binaries\ThirdParty\Improbable

    rem Copy schema to the projects spatial directory.
    set SPATIAL_DIR=%~dp0..\..\..\spatial
    set SPATIAL_TOOLS_COPY_DIR=%SPATIAL_DIR%\tools
    set SCHEMA_COPY_DIR=%SPATIAL_DIR%\schema\unreal\gdk
    set SCHEMA_STD_COPY_DIR=%SPATIAL_DIR%\build\dependencies\schema\standard_library
    set DOMAIN_ENVIRONMENT_VAR=
    set DOWNLOAD_MOBILE=
    set RETRIEVE_INTERNAL_PACKAGES=
    for %%A in (%*) do (
        if "%%A"=="--china" set DOMAIN_ENVIRONMENT_VAR=--environment cn-production
        if "%%A"=="--mobile" set DOWNLOAD_MOBILE=True
        if "%%A"=="--internal" set RETRIEVE_INTERNAL_PACKAGES=True
    )
call :MarkEndOfBlock "Setup variables"

call :MarkStartOfBlock "Setup services region"
    set USE_CHINA_SERVICES_REGION=
    for %%A in (%*) do (
        if "%%A"=="--china" set USE_CHINA_SERVICES_REGION=True
    )

    rem Create or remove an empty file in the plugin directory indicating whether to use China services region.
    if defined USE_CHINA_SERVICES_REGION (
        echo. 2> UseChinaServicesRegion
    ) else (
        if exist UseChinaServicesRegion del UseChinaServicesRegion
    )
call :MarkEndOfBlock "Setup services region"

call :MarkStartOfBlock "Clean folders"
    rd /s /q "%CORE_SDK_DIR%"           2>nul
    rd /s /q "%WORKER_SDK_DIR%"         2>nul
    rd /s /q "%WORKER_SDK_DIR_OLD%"     2>nul
    rd /s /q "%BINARIES_DIR%"           2>nul

    if exist "%SPATIAL_DIR%" (
        rd /s /q "%SCHEMA_STD_COPY_DIR%"    2>nul
        rd /s /q "%SCHEMA_COPY_DIR%"        2>nul
        rd /s /q "%SPATIAL_TOOLS_COPY_DIR%" 2>nul
    )
call :MarkEndOfBlock "Clean folders"

call :MarkStartOfBlock "Create folders"
    md "%WORKER_SDK_DIR%"            >nul 2>nul
    md "%CORE_SDK_DIR%\schema"       >nul 2>nul
    md "%CORE_SDK_DIR%\tools"        >nul 2>nul
    md "%CORE_SDK_DIR%\worker_sdk"   >nul 2>nul
    md "%BINARIES_DIR%"              >nul 2>nul
    md "%BINARIES_DIR%\Android"      >nul 2>nul
    md "%BINARIES_DIR%\Programs"     >nul 2>nul

    if exist "%SPATIAL_DIR%" (
        md "%SCHEMA_STD_COPY_DIR%"    >nul 2>nul
        md "%SCHEMA_COPY_DIR%"        >nul 2>nul
        md "%SPATIAL_TOOLS_COPY_DIR%" >nul 2>nul
    )
call :MarkEndOfBlock "Create folders"

call :MarkStartOfBlock "Retrieve dependencies"
    call :ExecuteAndCheck spatial package retrieve tools         schema_compiler-x86_64-win32               %PINNED_CORE_SDK_VERSION%    %DOMAIN_ENVIRONMENT_VAR%    "%CORE_SDK_DIR%\tools\schema_compiler-x86_64-win32.zip"
    call :ExecuteAndCheck spatial package retrieve tools         snapshot_converter-x86_64-win32            %PINNED_CORE_SDK_VERSION%    %DOMAIN_ENVIRONMENT_VAR%    "%CORE_SDK_DIR%\tools\snapshot_converter-x86_64-win32.zip"
    call :ExecuteAndCheck spatial package retrieve schema        standard_library                           %PINNED_CORE_SDK_VERSION%    %DOMAIN_ENVIRONMENT_VAR%    "%CORE_SDK_DIR%\schema\standard_library.zip"
    call :ExecuteAndCheck spatial package retrieve worker_sdk    c_headers                                  %PINNED_CORE_SDK_VERSION%    %DOMAIN_ENVIRONMENT_VAR%    "%CORE_SDK_DIR%\worker_sdk\c_headers.zip"
    call :ExecuteAndCheck spatial package retrieve worker_sdk    c-dynamic-x86_64-vc141_md-win32            %PINNED_CORE_SDK_VERSION%    %DOMAIN_ENVIRONMENT_VAR%    "%CORE_SDK_DIR%\worker_sdk\c-dynamic-x86_64-vc141_md-win32.zip"
    call :ExecuteAndCheck spatial package retrieve worker_sdk    c-dynamic-x86_64-clang1000-linux           %PINNED_CORE_SDK_VERSION%    %DOMAIN_ENVIRONMENT_VAR%    "%CORE_SDK_DIR%\worker_sdk\c-dynamic-x86_64-clang1000-linux.zip"
if defined RETRIEVE_INTERNAL_PACKAGES (
    call :ExecuteAndCheck spatial package retrieve internal      etlog-x86_64-win32                         %PINNED_CORE_SDK_VERSION%    %DOMAIN_ENVIRONMENT_VAR%    "%CORE_SDK_DIR%\tools\etlog-win32.zip"
)
if defined DOWNLOAD_MOBILE (
    call :ExecuteAndCheck spatial package retrieve worker_sdk    c-static-fullylinked-arm-clang-ios         %PINNED_CORE_SDK_VERSION%    %DOMAIN_ENVIRONMENT_VAR%    "%CORE_SDK_DIR%\worker_sdk\c-static-fullylinked-arm-clang-ios.zip"
    call :ExecuteAndCheck spatial package retrieve worker_sdk    c-dynamic-arm64v8a-clang_ndk21d-android    %PINNED_CORE_SDK_VERSION%    %DOMAIN_ENVIRONMENT_VAR%    "%CORE_SDK_DIR%\worker_sdk\c-dynamic-arm64v8a-clang_clang_ndk21-android.zip"
    call :ExecuteAndCheck spatial package retrieve worker_sdk    c-dynamic-armv7a-clang_ndk21d-android      %PINNED_CORE_SDK_VERSION%    %DOMAIN_ENVIRONMENT_VAR%    "%CORE_SDK_DIR%\worker_sdk\c-dynamic-armv7a-clang_clang_ndk21-android.zip"
    call :ExecuteAndCheck spatial package retrieve worker_sdk    c-dynamic-x86_64-clang_ndk21d-android      %PINNED_CORE_SDK_VERSION%    %DOMAIN_ENVIRONMENT_VAR%    "%CORE_SDK_DIR%\worker_sdk\c-dynamic-x86_64-clang_clang_ndk21-android.zip"
)
    call :ExecuteAndCheck spatial package retrieve worker_sdk    csharp_cinterop                            %PINNED_CORE_SDK_VERSION%   %DOMAIN_ENVIRONMENT_VAR%   "%CORE_SDK_DIR%\worker_sdk\csharp_cinterop.zip"
call :MarkEndOfBlock "Retrieve dependencies"

REM There is a race condition between retrieve and unzip, add version call to stall briefly
call spatial version
if ERRORLEVEL 1 pause && exit /b %ERRORLEVEL%

call :MarkStartOfBlock "Unpack dependencies"
    powershell -Command "Expand-Archive -Path \"%CORE_SDK_DIR%\worker_sdk\c_headers.zip\"                           -DestinationPath \"%BINARIES_DIR%\Headers\" -Force; "^
                        "Expand-Archive -Path \"%CORE_SDK_DIR%\worker_sdk\c-dynamic-x86_64-vc141_md-win32.zip\"     -DestinationPath \"%BINARIES_DIR%\Win64\" -Force; "^
                        "Expand-Archive -Path \"%CORE_SDK_DIR%\worker_sdk\c-dynamic-x86_64-clang1000-linux.zip\"    -DestinationPath \"%BINARIES_DIR%\Linux\" -Force; "^
                        "Expand-Archive -Path \"%CORE_SDK_DIR%\worker_sdk\csharp_cinterop.zip\"                     -DestinationPath \"%BINARIES_DIR%\Programs\worker_sdk\csharp_cinterop\" -Force; "^
                        "Expand-Archive -Path \"%CORE_SDK_DIR%\tools\schema_compiler-x86_64-win32.zip\"             -DestinationPath \"%BINARIES_DIR%\Programs\" -Force; "^
                        "Expand-Archive -Path \"%CORE_SDK_DIR%\tools\snapshot_converter-x86_64-win32.zip\"          -DestinationPath \"%BINARIES_DIR%\Programs\" -Force; "^
                        "Expand-Archive -Path \"%CORE_SDK_DIR%\schema\standard_library.zip\"                        -DestinationPath \"%BINARIES_DIR%\Programs\schema\" -Force;"
    if defined RETRIEVE_INTERNAL_PACKAGES (
        powershell -Command "Expand-Archive -Path \"%CORE_SDK_DIR%\tools\etlog-win32.zip\"                                          -DestinationPath \"%BINARIES_DIR%\Programs\" -Force;"
    )
    if defined DOWNLOAD_MOBILE (
        powershell -Command "Expand-Archive -Path \"%CORE_SDK_DIR%\worker_sdk\c-static-fullylinked-arm-clang-ios.zip\"              -DestinationPath \"%BINARIES_DIR%\IOS\" -Force;"^
                            "Expand-Archive -Path \"%CORE_SDK_DIR%\worker_sdk\c-dynamic-arm64v8a-clang_clang_ndk21-android.zip\"    -DestinationPath \"%BINARIES_DIR%\Android\arm64-v8a\" -Force; "^
                            "Expand-Archive -Path \"%CORE_SDK_DIR%\worker_sdk\c-dynamic-armv7a-clang_clang_ndk21-android.zip\"      -DestinationPath \"%BINARIES_DIR%\Android\armeabi-v7a\" -Force; "^
                            "Expand-Archive -Path \"%CORE_SDK_DIR%\worker_sdk\c-dynamic-x86_64-clang_clang_ndk21-android.zip\"      -DestinationPath \"%BINARIES_DIR%\Android\x86_64\" -Force; "^
    )
    xcopy /s /i /q "%BINARIES_DIR%\Headers\include" "%WORKER_SDK_DIR%"
call :MarkEndOfBlock "Unpack dependencies"

REM When the worker libs are updated outside of the build system, timestamps are not updated on unzip so 
REM no change is registered, resulting in broken builds (lib / dll mismatch). 
call :MarkStartOfBlock "Touching worker libs"
call :TouchFilesInFolder %BINARIES_DIR%\Win64\
call :TouchFilesInFolder %BINARIES_DIR%\Linux\
call :MarkEndOfBlock "Touching worker libs"

if exist "%SPATIAL_DIR%" (
    call :MarkStartOfBlock "Copy standard library schema"
        echo Copying standard library schemas to "%SCHEMA_STD_COPY_DIR%"
        xcopy /s /i /q "%BINARIES_DIR%\Programs\schema" "%SCHEMA_STD_COPY_DIR%"
    call :MarkEndOfBlock "Copy standard library schema"

    call :MarkStartOfBlock "Copy GDK schema"
        echo Copying schemas to "%SCHEMA_COPY_DIR%".
        xcopy /s /i /q "%~dp0\SpatialGDK\Extras\schema" "%SCHEMA_COPY_DIR%"
    call :MarkEndOfBlock "Copy GDK schema"

    call :MarkStartOfBlock "Copy schema compiler"
        echo Copying schema compiler to "%SPATIAL_TOOLS_COPY_DIR%".
        xcopy /s /i /q "%BINARIES_DIR%\Programs\schema_compiler.exe" "%SPATIAL_TOOLS_COPY_DIR%"
    call :MarkEndOfBlock "Copy schema compiler

    call :MarkStartOfBlock "Copy snapshot converter"
        echo Copying snapshot converter to "%SPATIAL_TOOLS_COPY_DIR%"
        xcopy /s /i /q "%BINARIES_DIR%\Programs\snapshot_converter.exe" "%SPATIAL_TOOLS_COPY_DIR%"
        xcopy /s /i /q "%BINARIES_DIR%\Programs\snapshot.descriptor" "%SPATIAL_TOOLS_COPY_DIR%"
    call :MarkEndOfBlock "Copy snapshot converter"
)

call :MarkStartOfBlock "Build C# utilities"
    call :ExecuteAndCheck %MSBUILD_EXE% /nologo /verbosity:minimal .\SpatialGDK\Build\Programs\Improbable.Unreal.Scripts\Improbable.Unreal.Scripts.sln /property:Configuration=Release /restore
call :MarkEndOfBlock "Build C# utilities"

call :MarkEndOfBlock "%~0"

popd

echo UnrealGDK build completed successfully^!

if not defined NO_PAUSE (
    pause
)

exit /b %ERRORLEVEL%

:TouchFilesInFolder
echo Touching lib/dll files in: %~1
pushd "%~1"
for /R %%f in (*.lib,*.dll,*.so) do copy /b %%f +,,
popd 
exit /b 0

:MarkStartOfBlock
echo Starting: %~1
exit /b 0

:MarkEndOfBlock
echo Finished: %~1
exit /b 0

:ExecuteAndCheck
%*
if ERRORLEVEL 1 (
    echo ERROR: Command '%*' did not complete successfully. Aborting...
    pause
    exit 1
)
exit /b 0
