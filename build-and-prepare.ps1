# Build and Prepare Script for SeriLovers Project
# This script builds Android and Windows apps, organizes files, and creates zip archives

$ErrorActionPreference = "Stop"
$date = Get-Date -Format "yy-MM-dd"
$buildDate = Get-Date -Format "yyyy-MM-dd"

Write-Host "=== SeriLovers Build and Prepare Script ===" -ForegroundColor Green
Write-Host "Build Date: $buildDate" -ForegroundColor Cyan

# Step 1: Clean Flutter project
Write-Host "`n[1/7] Cleaning Flutter project..." -ForegroundColor Yellow
Set-Location "serilovers_frontend"
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Flutter clean failed!" -ForegroundColor Red
    exit 1
}

# Step 2: Get dependencies
Write-Host "`n[2/7] Getting Flutter dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Flutter pub get failed!" -ForegroundColor Red
    exit 1
}

# Step 3: Build Android APK
Write-Host "`n[3/7] Building Android APK (this may take several minutes)..." -ForegroundColor Yellow
flutter build apk --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Android build failed!" -ForegroundColor Red
    exit 1
}

# Step 4: Build Windows app
Write-Host "`n[4/7] Building Windows app (this may take several minutes)..." -ForegroundColor Yellow
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Windows build failed!" -ForegroundColor Red
    exit 1
}

# Step 5: Organize build files
Write-Host "`n[5/7] Organizing build files..." -ForegroundColor Yellow
Set-Location ".."

# Create directory structure
New-Item -ItemType Directory -Path "folder-mobilne-app\build\app\outputs\flutter-apk" -Force | Out-Null
New-Item -ItemType Directory -Path "folder-desktop-app\build\windows\x64\runner\Release" -Force | Out-Null

# Copy Android APK
if (Test-Path "serilovers_frontend\build\app\outputs\flutter-apk\app-release.apk") {
    Copy-Item "serilovers_frontend\build\app\outputs\flutter-apk\app-release.apk" -Destination "folder-mobilne-app\build\app\outputs\flutter-apk\app-release.apk" -Force
    Write-Host "  ✓ Android APK copied" -ForegroundColor Green
} else {
    Write-Host "  ✗ Android APK not found!" -ForegroundColor Red
    exit 1
}

# Copy Windows files
if (Test-Path "serilovers_frontend\build\windows\x64\runner\Release") {
    Copy-Item "serilovers_frontend\build\windows\x64\runner\Release\*" -Destination "folder-desktop-app\build\windows\x64\runner\Release\" -Recurse -Force
    Write-Host "  ✓ Windows build files copied" -ForegroundColor Green
} else {
    Write-Host "  ✗ Windows build files not found!" -ForegroundColor Red
    exit 1
}

# Step 6: Create zip archives
Write-Host "`n[6/7] Creating zip archives..." -ForegroundColor Yellow

# Check if 7-Zip is available
$zipTool = $null
if (Get-Command "7z" -ErrorAction SilentlyContinue) {
    $zipTool = "7z"
} elseif (Get-Command "7za" -ErrorAction SilentlyContinue) {
    $zipTool = "7za"
} else {
    # Use PowerShell Compress-Archive (no password support, will need manual step)
    Write-Host "  ⚠ 7-Zip not found. Using PowerShell Compress-Archive (no password)." -ForegroundColor Yellow
    Write-Host "  ⚠ You will need to manually add password 'fit' using 7-Zip or WinRAR." -ForegroundColor Yellow
    
    $zipName = "fit-build-$date.zip"
    Compress-Archive -Path "folder-mobilne-app\build\app\outputs\flutter-apk", "folder-desktop-app\build\windows\x64\runner\Release" -DestinationPath $zipName -Force
    
    Write-Host "  ✓ Created $zipName (without password - add manually)" -ForegroundColor Green
    Write-Host "  ⚠ IMPORTANT: Add password 'fit' to the zip file using 7-Zip or WinRAR!" -ForegroundColor Yellow
} else {
    # Use 7-Zip with password
    $zipName = "fit-build-$date.zip"
    & $zipTool a -tzip -pfit -v90m "$zipName" "folder-mobilne-app\build\app\outputs\flutter-apk\*" "folder-desktop-app\build\windows\x64\runner\Release\*"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Created $zipName with password 'fit'" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Failed to create zip archive!" -ForegroundColor Red
        exit 1
    }
}

# Step 7: Summary
Write-Host "`n[7/7] Build Summary:" -ForegroundColor Yellow
Write-Host "  ✓ Android APK: folder-mobilne-app\build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
Write-Host "  ✓ Windows build: folder-desktop-app\build\windows\x64\runner\Release\" -ForegroundColor Green
if (Test-Path "fit-build-$date.zip") {
    $zipSize = (Get-Item "fit-build-$date.zip").Length / 1MB
    Write-Host "  ✓ Zip archive: fit-build-$date.zip ($([math]::Round($zipSize, 2)) MB)" -ForegroundColor Green
}

Write-Host "`n=== Build Complete! ===" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Verify build files are correct" -ForegroundColor White
Write-Host "  2. If zip doesn't have password, add it manually with 7-Zip/WinRAR" -ForegroundColor White
Write-Host "  3. Commit and push to git repository" -ForegroundColor White

