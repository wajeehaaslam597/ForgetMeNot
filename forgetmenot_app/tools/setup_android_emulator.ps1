# One-time: installs Android cmdline-tools into %LOCALAPPDATA%\Android\Sdk so Flutter can create emulators.
# Then run: flutter doctor --android-licenses   (press y until done)
# Then:     flutter emulators --create
# Then:     flutter emulators --launch <id>
#
# Usage:  Set-ExecutionPolicy -Scope Process Bypass; .\tools\setup_android_emulator.ps1

$ErrorActionPreference = "Stop"
$sdkRoot = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$zip = Join-Path $env:TEMP "commandlinetools-win.zip"
$toolsUrl = "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
$destLatest = Join-Path $sdkRoot "cmdline-tools\latest"

if (Test-Path (Join-Path $destLatest "bin\sdkmanager.bat")) {
    Write-Host "cmdline-tools already present at $destLatest"
} else {
    if (-not (Test-Path $sdkRoot)) { New-Item -ItemType Directory -Path $sdkRoot -Force | Out-Null }
    Write-Host "Downloading command-line tools (~150 MB). Please wait..."
    if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
        curl.exe -fSL --retry 3 -o $zip $toolsUrl
    } else {
        Invoke-WebRequest -Uri $toolsUrl -OutFile $zip -UseBasicParsing
    }
    $extract = Join-Path $env:TEMP "cmdline-tools-extract"
    if (Test-Path $extract) { Remove-Item $extract -Recurse -Force }
    Expand-Archive -Path $zip -DestinationPath $extract -Force
    $top = Get-ChildItem $extract | Select-Object -First 1
    if (Test-Path $destLatest) { Remove-Item $destLatest -Recurse -Force }
    New-Item -ItemType Directory -Path (Split-Path $destLatest) -Force | Out-Null
    Move-Item $top.FullName $destLatest
    Write-Host "Installed: $destLatest"
}

$env:ANDROID_HOME = $sdkRoot
$env:ANDROID_SDK_ROOT = $sdkRoot

Write-Host ""
Write-Host "Next steps (run in this order):"
Write-Host "  1. flutter doctor --android-licenses    # type y for each prompt"
Write-Host "  2. flutter emulators --create           # creates an Android emulator"
Write-Host "  3. flutter emulators                    # note the emulator id"
Write-Host "  4. flutter emulators --launch <id>      # or start from Android Studio Device Manager"
Write-Host "  5. cd to forgetmenot_app and:"
Write-Host "     flutter run -d emulator-5554 --dart-define=API_BASE=http://192.168.100.29:8000"
Write-Host ""
Write-Host "Backend must be:  uvicorn main:app --host 0.0.0.0 --port 8000"
Write-Host "(Use your PC IPv4 from ipconfig instead of 192.168.100.29 if it changed.)"
