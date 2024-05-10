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

Function GetVersion() {
  $gitCommand = Get-Command -Name git

  try { $tag = & $gitCommand describe --exact-match --tags HEAD } catch { }
  if(-Not $?) {
      Info "The commit is not tagged. Use 'v0.0-dev' as a version instead"
      $tag = "v0.0-dev"
  }

  $commitHash = & $gitCommand rev-parse --short HEAD
  CheckReturnCodeOfPreviousCommand "Failed to get git commit hash"

  return "$($tag.Substring(1))-$commitHash"
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$root = Resolve-Path "$PSScriptRoot"
$buildDir = "$root/build"

$gitCommand = Get-Command -Name git

Info "Find Visual Studio installation path"
$vswhereCommand = Get-Command -Name "${Env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$installationPath = & $vswhereCommand -prerelease -latest -property installationPath

Info "Open Visual Studio 2022 Developer PowerShell"
& "$installationPath\Common7\Tools\Launch-VsDevShell.ps1" -Arch amd64

Info "Remove '$buildDir' folder if it exists"
Remove-Item $buildDir -Force -Recurse -ErrorAction SilentlyContinue
New-Item $buildDir -Force -ItemType "directory" > $null

Info "Clone re2c repo"
& $gitCommand clone --branch 4.0 --single-branch https://github.com/skvadrik/re2c.git $buildDir/re2c-repo

Info "Change the minimal Cmake version to allow specifying CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded"
(Get-Content $buildDir/re2c-repo/CMakeLists.txt) -replace "^cmake_minimum_required\(VERSION .+\)$", "cmake_minimum_required(VERSION 3.28)" | Set-Content $buildDir/re2c-repo/CMakeLists.txt

Info "Cmake generate cache"
cmake `
  -S $buildDir/re2c-repo `
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

Info "Generate version number"
$re2cShortGitCommitHash = & $gitCommand -C "$buildDir/re2c-repo" rev-parse --short HEAD
$re2cNearestTagName = & $gitCommand -C "$buildDir/re2c-repo" describe --tags --abbrev=0

Info "Copy the executables to the publish directory and archive them"
New-Item $buildDir/publish -Force -ItemType "directory" > $null
Copy-Item -Path $buildDir/out/re2c.exe -Destination $buildDir/publish
Compress-Archive -Path "$buildDir/publish/*.exe" -DestinationPath $buildDir/publish/re2c-v$re2cNearestTagName-$re2cShortGitCommitHash.zip
