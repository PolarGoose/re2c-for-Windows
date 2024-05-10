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
& "$installationPath\Common7\Tools\Launch-VsDevShell.ps1" -Arch amd64

Info "Remove '$buildDir' folder if it exists"
Remove-Item $buildDir -Force -Recurse -ErrorAction SilentlyContinue
New-Item $buildDir -Force -ItemType "directory" > $null

Info "Download re2c source code"
Invoke-WebRequest -Uri https://codeload.github.com/skvadrik/re2c/zip/refs/tags/3.1 -OutFile $buildDir/re2c.zip

Info "Extract the source code"
[System.IO.Compression.ZipFile]::ExtractToDirectory("$buildDir/re2c.zip", "$buildDir")

Info "Change the minimal Cmake version to allow specifying CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded"
(Get-Content $buildDir/re2c-3.1/CMakeLists.txt) -replace "^cmake_minimum_required\(VERSION .+\)$", "cmake_minimum_required(VERSION 3.28)" | Set-Content $buildDir/re2c-3.1/CMakeLists.txt

Info "Cmake generate cache"
cmake `
  -S $buildDir/re2c-3.1 `
  -B $buildDir/out `
  -G Ninja `
  -DCMAKE_BUILD_TYPE=Release `
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded
CheckReturnCodeOfPreviousCommand "cmake cache failed"

Info "Cmake build"
cmake --build $buildDir/out
CheckReturnCodeOfPreviousCommand "cmake build failed"

Info "Copy the executables to the publish directory and archive them"
New-Item $buildDir/publish -Force -ItemType "directory" > $null
Copy-Item -Path $buildDir/out/re2c.exe, $buildDir/out/re2go.exe, $buildDir/out/re2rust.exe -Destination $buildDir/publish
Compress-Archive -Path "$buildDir/publish/*.exe" -DestinationPath $buildDir/publish/re2c.zip
