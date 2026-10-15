# build_native.ps1
#
# Builds the quickjs_engine native bridge from source on Windows and
# stages the resulting DLL inside native/build. The consumer app's
# windows/CMakeLists.txt rebuilds it via add_subdirectory at
# `flutter run` time, so manual rebuild is only needed when you change
# native sources or run `flutter test` from this repo.
#
# Required:
#   - CMake >= 3.10  (winget install Kitware.CMake)
#   - Visual Studio Build Tools 2019+ with the "Desktop development with C++"
#     workload, OR the "Developer Command Prompt" environment for cl.exe
#
# Run:
#   pwsh tool/build_native.ps1
#   # or, from regular powershell.exe:
#   powershell.exe -ExecutionPolicy Bypass -File tool/build_native.ps1

$ErrorActionPreference = 'Stop'

$pkgRoot  = Split-Path -Parent $PSScriptRoot
$buildDir = Join-Path $pkgRoot 'native\build'

Write-Host "[quickjs_engine] Configuring (cmake -S native -B native\build)..."
& cmake -S (Join-Path $pkgRoot 'native') -B $buildDir -DCMAKE_BUILD_TYPE=Release
if ($LASTEXITCODE -ne 0) { throw "cmake configure failed (exit $LASTEXITCODE)" }

Write-Host "[quickjs_engine] Building..."
$jobs = [Environment]::ProcessorCount
& cmake --build $buildDir --config Release -j $jobs
if ($LASTEXITCODE -ne 0) { throw "cmake build failed (exit $LASTEXITCODE)" }

# CMake on Windows + MSVC drops the DLL inside a Release\ subdir of the
# build directory. With a single-config generator (Ninja, Make) the DLL
# lands at the top level. Locate it either way.
$candidates = @(
  (Join-Path $buildDir 'Release\quickjs_c_bridge_plugin.dll'),
  (Join-Path $buildDir 'quickjs_c_bridge_plugin.dll')
)
$dll = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $dll) {
  throw "Built successfully but couldn't find quickjs_c_bridge_plugin.dll under $buildDir"
}

Write-Host "[quickjs_engine] Built: $dll"
Write-Host "[quickjs_engine] (Consumer apps rebuild this via the plugin's"
Write-Host "                  windows\CMakeLists.txt at 'flutter run' time.)"
