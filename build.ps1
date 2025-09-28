Function Info($msg) {
  Write-Host -ForegroundColor DarkGreen "`nINFO: $msg`n"
}

Function Error($msg) {
  Write-Host `n`n
  Write-Error $msg
  exit 1
}

Function CheckReturnCodeOfPreviousCommand($msg) {
  if(-Not $?) {
    Error "${msg}. Error code: $LastExitCode"
  }
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = Resolve-Path "$PSScriptRoot"
$buildDir = "$root/build"

Info "Find Visual Studio installation path"
$vswhereCommand = Get-Command -Name "${Env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$installationPath = & $vswhereCommand -prerelease -latest -property installationPath

Info "Open Visual Studio 2022 Developer PowerShell"
& "$installationPath\Common7\Tools\Launch-VsDevShell.ps1" -SkipAutomaticLocation -Arch amd64

Info "Remove '$buildDir' folder if it exists"
Remove-Item $buildDir -Force -Recurse -ErrorAction SilentlyContinue
New-Item $buildDir -Force -ItemType "directory" > $null

Info "Download re2c source code"
Invoke-WebRequest -Uri https://github.com/skvadrik/re2c/archive/refs/tags/4.3.zip -OutFile "$buildDir/re2c-source-code.zip"
[System.IO.Compression.ZipFile]::ExtractToDirectory("$buildDir/re2c-source-code.zip", "$buildDir")

Info "Cmake generate cache"
cmake `
  -S $buildDir/re2c-4.3 `
  -B $buildDir/out `
  -G Ninja `
  -D CMAKE_BUILD_TYPE=Release `
  -D CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded `
  -D RE2C_BUILD_RE2D=0 `
  -D RE2C_BUILD_RE2GO=0 `
  -D RE2C_BUILD_RE2HS=0 `
  -D RE2C_BUILD_RE2JAVA=0 `
  -D RE2C_BUILD_RE2JS=0 `
  -D RE2C_BUILD_RE2OCAML=0 `
  -D RE2C_BUILD_RE2PY=0 `
  -D RE2C_BUILD_RE2RUST=0 `
  -D RE2C_BUILD_RE2V=0 `
  -D RE2C_BUILD_RE2ZIG=0 `
  -D RE2C_BUILD_TESTS=0
CheckReturnCodeOfPreviousCommand "cmake cache failed"

Info "Cmake build"
cmake --build $buildDir/out
CheckReturnCodeOfPreviousCommand "cmake build failed"

Info "Copy the executables to the publish directory and archive them"
New-Item $buildDir/publish -Force -ItemType "directory" > $null
Copy-Item -Path $buildDir/out/re2c.exe -Destination $buildDir/publish
Compress-Archive -Path "$buildDir/publish/*.exe" -DestinationPath $buildDir/publish/re2c.zip
