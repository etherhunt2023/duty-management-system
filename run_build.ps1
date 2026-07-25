# Duty Management System Build & Compilation Script
# This script configures the Flutter native platform folders and builds the release Android APK.

$ErrorActionPreference = "Stop"

# 1. Locate Flutter
$flutterPath = "C:\Users\NIGHTRIDER\flutter\bin\flutter.bat"
if (-not (Test-Path $flutterPath)) {
    Write-Error "Flutter SDK not found at $flutterPath. Please ensure the manual download and extraction has finished."
}

Write-Host "============================================="
Write-Host "0. Cleaning build caches"
Write-Host "============================================="
& $flutterPath clean

Write-Host "============================================="
Write-Host "1. Initializing Flutter Native Project Wrappers"
Write-Host "============================================="
# Run flutter create to generate android/ and web/ directories without overwriting our lib/ and pubspec.yaml
& $flutterPath create --platforms=android,web .

Write-Host "============================================="
Write-Host "2. Configuring Android SDK Path"
Write-Host "============================================="
& $flutterPath config --android-sdk "C:\Users\NIGHTRIDER\AppData\Local\Android\Sdk"

Write-Host "============================================="
Write-Host "3. Resolving Project Dependencies"
Write-Host "============================================="
& $flutterPath pub get

Write-Host "============================================="
Write-Host "4. Compiling Production Android APK"
Write-Host "============================================="
# Build release APK
& $flutterPath build apk --release --no-pub

Write-Host "============================================="
Write-Host "5. Copying APK to Workspace Root"
Write-Host "============================================="
$apkSource = "build\app\outputs\flutter-apk\app-release.apk"
$apkDest = "Duty_Management_System_Release.apk"

if (Test-Path $apkSource) {
    Copy-Item -Path $apkSource -Destination $apkDest -Force
    Write-Host "SUCCESS! Installable Android APK created at:"
    Write-Host (Get-Item $apkDest).FullName
} else {
    Write-Error "APK compilation completed but build artifact was not found."
}
