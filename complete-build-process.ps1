# Complete Build and Submission Process
# This script builds both Android and Windows apps, then finalizes submission

$ErrorActionPreference = "Stop"
Write-Host "=== SeriLovers Complete Build Process ===" -ForegroundColor Green

# Step 1: Clean and prepare
Write-Host "`n[1/6] Cleaning Flutter project..." -ForegroundColor Yellow
Set-Location "serilovers_frontend"
flutter clean
flutter pub get

# Step 2: Build Windows app (usually faster)
Write-Host "`n[2/6] Building Windows app (this may take 5-10 minutes)..." -ForegroundColor Yellow
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Windows build failed!" -ForegroundColor Red
    Write-Host "Please check the error messages above." -ForegroundColor Yellow
    exit 1
}
Write-Host "✓ Windows build successful!" -ForegroundColor Green

# Step 3: Build Android APK
Write-Host "`n[3/6] Building Android APK (this may take 5-10 minutes)..." -ForegroundColor Yellow
Write-Host "Note: If you see Android license errors, you may need to:" -ForegroundColor Cyan
Write-Host "  1. Open Android Studio" -ForegroundColor White
Write-Host "  2. Go to Tools > SDK Manager" -ForegroundColor White
Write-Host "  3. Install Android SDK Command-line Tools" -ForegroundColor White
Write-Host "  4. Run: flutter doctor --android-licenses" -ForegroundColor White
Write-Host ""

flutter build apk --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "WARNING: Android build failed!" -ForegroundColor Yellow
    Write-Host "This might be due to missing Android licenses." -ForegroundColor Yellow
    Write-Host "You can try to fix it later, but continuing with Windows build..." -ForegroundColor Yellow
    
    # Check if APK exists anyway
    if (-not (Test-Path "build\app\outputs\flutter-apk\app-release.apk")) {
        Write-Host "Android APK not found. Please fix Android build issues." -ForegroundColor Red
        Write-Host "Continuing with Windows build only..." -ForegroundColor Yellow
    }
} else {
    Write-Host "✓ Android build successful!" -ForegroundColor Green
}

# Step 4: Verify build files
Write-Host "`n[4/6] Verifying build files..." -ForegroundColor Yellow
Set-Location ".."

$windowsExists = Test-Path "serilovers_frontend\build\windows\x64\runner\Release\serilovers_frontend.exe"
$androidExists = Test-Path "serilovers_frontend\build\app\outputs\flutter-apk\app-release.apk"

if ($windowsExists) {
    Write-Host "  ✓ Windows build found" -ForegroundColor Green
} else {
    Write-Host "  ✗ Windows build NOT found!" -ForegroundColor Red
    exit 1
}

if ($androidExists) {
    Write-Host "  ✓ Android APK found" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Android APK NOT found (build may have failed)" -ForegroundColor Yellow
}

# Step 5: Organize files
Write-Host "`n[5/6] Organizing build files..." -ForegroundColor Yellow

# Create directory structure
New-Item -ItemType Directory -Path "folder-mobilne-app\build\app\outputs\flutter-apk" -Force | Out-Null
New-Item -ItemType Directory -Path "folder-desktop-app\build\windows\x64\runner\Release" -Force | Out-Null

# Copy Windows files
Copy-Item "serilovers_frontend\build\windows\x64\runner\Release\*" -Destination "folder-desktop-app\build\windows\x64\runner\Release\" -Recurse -Force
Write-Host "  ✓ Windows build files copied" -ForegroundColor Green

# Copy Android APK if it exists
if ($androidExists) {
    Copy-Item "serilovers_frontend\build\app\outputs\flutter-apk\app-release.apk" -Destination "folder-mobilne-app\build\app\outputs\flutter-apk\app-release.apk" -Force
    Write-Host "  ✓ Android APK copied" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Android APK not copied (build failed)" -ForegroundColor Yellow
}

# Step 6: Create zip archive with 7-Zip
Write-Host "`n[6/6] Creating zip archive with 7-Zip..." -ForegroundColor Yellow

$date = Get-Date -Format "yy-MM-dd"
$zipName = "fit-build-$date.zip"
$zipPath = Join-Path $PWD $zipName

# Find 7-Zip
$zipTool = $null
if (Get-Command "7z" -ErrorAction SilentlyContinue) {
    $zipTool = "7z"
} else {
    $possiblePaths = @(
        "C:\Program Files\7-Zip\7z.exe",
        "C:\Program Files (x86)\7-Zip\7z.exe"
    )
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $zipTool = $path
            break
        }
    }
}

if ($zipTool) {
    # Remove existing zip and split files
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Get-ChildItem -Path $PWD -Filter "fit-build-$date.z*" | Remove-Item -Force -ErrorAction SilentlyContinue
    
    Write-Host "  Using 7-Zip: $zipTool" -ForegroundColor Cyan
    Write-Host "  Creating zip with password 'fit' and 90MB split..." -ForegroundColor Cyan
    
    # Build command based on what exists
    $sourcePaths = @()
    if ($androidExists) {
        $sourcePaths += "folder-mobilne-app\build\app\outputs\flutter-apk\*"
    }
    $sourcePaths += "folder-desktop-app\build\windows\x64\runner\Release\*"
    
    # Create zip with password and split at 90MB
    & $zipTool a -tzip -pfit -v90m "$zipPath" $sourcePaths
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Created $zipName with password 'fit'" -ForegroundColor Green
        
        # Check for split files
        $splitFiles = Get-ChildItem -Path $PWD -Filter "fit-build-$date.z*" | Sort-Object Name
        if ($splitFiles.Count -gt 1) {
            Write-Host "  ✓ Created split archive files:" -ForegroundColor Green
            foreach ($file in $splitFiles) {
                $size = [math]::Round($file.Length / 1MB, 2)
                Write-Host "    - $($file.Name) ($size MB)" -ForegroundColor Cyan
            }
        } else {
            $size = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
            Write-Host "  ✓ Archive size: $size MB" -ForegroundColor Cyan
        }
    } else {
        Write-Host "  ✗ Failed to create zip archive!" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  ✗ 7-Zip not found! Please install from https://www.7-zip.org/" -ForegroundColor Red
    exit 1
}

# Final summary
Write-Host "`n=== Build Process Complete! ===" -ForegroundColor Green
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  ✓ Windows build: folder-desktop-app\build\windows\x64\runner\Release\" -ForegroundColor Green
if ($androidExists) {
    Write-Host "  ✓ Android APK: folder-mobilne-app\build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Android APK: Build failed - needs fixing" -ForegroundColor Yellow
}
Write-Host "  ✓ Zip archive: $zipName" -ForegroundColor Green

Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "  1. Review build files" -ForegroundColor White
Write-Host "  2. If Android build failed, fix Android SDK issues and rebuild" -ForegroundColor White
Write-Host "  3. Run: git add ." -ForegroundColor White
Write-Host "  4. Run: git commit -m 'chore: prepare build files for submission'" -ForegroundColor White
Write-Host "  5. Run: git push origin main" -ForegroundColor White

