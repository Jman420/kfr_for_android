. ./variables.ps1

$AndroidSdkDir = "Android/Sdk"
$CmakeVersion = "3.10.2.4988404"
$AndroidCmakeExe = "$AndroidSdkDir/cmake/$CmakeVersion/bin/cmake.exe"
$AndroidNinjaExe = "$AndroidSdkDir/cmake/$CmakeVersion/bin/ninja.exe"
$NdkVersion = "21.0.6113669"
$NdkBundle = "$AndroidSdkDir/ndk/$NdkVersion"
$ToolchainFile = "$NdkBundle/build/cmake/android.toolchain.cmake"
$ArchTargets = @("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
$KfrArchitectures = @("neon", "neon64", "avx1", "avx1")
$LibraryFilePattern = "*.a"
$AndroidBuildDir = "$BuildDir/android"
$AndroidOutputDir = "$OutputDir/android"

for ($archCounter = 0; $archCounter -lt $ArchTargets.Length; $archCounter++) {
    $archTarget = $ArchTargets[$archCounter]
    $kfrArchitecture = $KfrArchitectures[$archCounter]
    $archBuildDir = "$AndroidBuildDir/$archTarget"
    $archOutputDir = "$AndroidOutputDir/$archTarget"

    # Remove build & output directories
    Write-Output "Removing Existing Build & Output Directories for $archTarget ..."
    if (Test-Path $archBuildDir) {
        Write-Output "Removing existing Build Directory for $archTarget ..."
        Remove-Item $archBuildDir -Force -Recurse
    }
    if (Test-Path $archOutputDir) {
        Write-Output "Removing existing Output Directory for $archTarget ..."
        Remove-Item $archOutputDir -Force -Recurse
    }

    # Make Target Output Directory
    Write-Output "Creating Build & Output Directory for $archTarget ..."
    New-Item -ItemType directory -Force -Path $archBuildDir
    New-Item -ItemType directory -Force -Path $archOutputDir
    $fullOutputPath = Resolve-Path $archOutputDir
    
    Write-Output "Building KFR Lib for Android - $archTarget ..."
    Push-Location $archBuildDir
    . $env:LOCALAPPDATA\$AndroidCmakeExe `
        -DENABLE_TESTS=OFF `
        -DCMAKE_CXX_FLAGS=-m64 `
        -DCMAKE_BUILD_TYPE=Release `
        -DCPU_ARCH="$kfrArchitecture" `
        -DANDROID_NDK="$env:LOCALAPPDATA/$NdkBundle" `
        -DCMAKE_TOOLCHAIN_FILE="$env:LOCALAPPDATA/$ToolchainFile" `
        -DCMAKE_MAKE_PROGRAM="$env:LOCALAPPDATA/$AndroidNinjaExe" `
        -DCMAKE_CXX_FLAGS=-std=c++14 `
        -DANDROID_STL=c++_shared `
        -DANDROID_ABI="$archTarget" `
        -G "Ninja" `
        "../../../$RootSourcePath"
    
    . $env:LOCALAPPDATA\$AndroidCmakeExe --build .
    Write-Output "Successfully built KFR Lib for Android - $archTarget !"
    
    Write-Output "Copying $archTarget binaries to Output Directory..."
    $libraryFiles = (Get-ChildItem -Path $LibraryFilePattern -Recurse).FullName | Resolve-Path -Relative
    foreach ($libFile in $libraryFiles) {
        $libFileDest = "$fullOutputPath/" + $libFile.Replace(".\", "").Replace("\", "/")
        Write-Output "Copying $libFile to $libFileDest ..."
        New-Item -Force $libFileDest
        Copy-Item -Force $libFile -Destination $libFileDest
    }
    Pop-Location
}
Write-Output "Successfully built KFR Lib for Android!"

& "$PSScriptRoot\copy_include_headers.ps1"