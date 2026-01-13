# Finalize Submission Script
# This script organizes build files, creates zip archives, and prepares for git commit

$ErrorActionPreference = "Stop"
$date = Get-Date -Format "yy-MM-dd"
$buildDate = Get-Date -Format "yyyy-MM-dd"

Write-Host "=== SeriLovers Finalize Submission Script ===" -ForegroundColor Green
Write-Host "Date: $buildDate" -ForegroundColor Cyan

# Step 1: Verify build files exist
Write-Host "`n[1/5] Verifying build files..." -ForegroundColor Yellow

$androidApk = "serilovers_frontend\build\app\outputs\flutter-apk\app-release.apk"
$windowsBuild = "serilovers_frontend\build\windows\x64\runner\Release"

if (-not (Test-Path $androidApk)) {
    Write-Host "  ✗ Android APK not found at: $androidApk" -ForegroundColor Red
    Write-Host "  Please run: cd serilovers_frontend && flutter build apk --release" -ForegroundColor Yellow
    exit 1
}
Write-Host "  ✓ Android APK found" -ForegroundColor Green

if (-not (Test-Path $windowsBuild)) {
    Write-Host "  ✗ Windows build not found at: $windowsBuild" -ForegroundColor Red
    Write-Host "  Please run: cd serilovers_frontend && flutter build windows --release" -ForegroundColor Yellow
    exit 1
}
Write-Host "  ✓ Windows build found" -ForegroundColor Green

# Step 2: Organize build files
Write-Host "`n[2/5] Organizing build files..." -ForegroundColor Yellow

# Create directory structure
New-Item -ItemType Directory -Path "folder-mobilne-app\build\app\outputs\flutter-apk" -Force | Out-Null
New-Item -ItemType Directory -Path "folder-desktop-app\build\windows\x64\runner\Release" -Force | Out-Null

# Copy Android APK
Copy-Item $androidApk -Destination "folder-mobilne-app\build\app\outputs\flutter-apk\app-release.apk" -Force
Write-Host "  ✓ Android APK copied to folder-mobilne-app" -ForegroundColor Green

# Copy Windows files
Copy-Item "$windowsBuild\*" -Destination "folder-desktop-app\build\windows\x64\runner\Release\" -Recurse -Force
Write-Host "  ✓ Windows build files copied to folder-desktop-app" -ForegroundColor Green

# Step 3: Create zip archive
Write-Host "`n[3/5] Creating zip archive..." -ForegroundColor Yellow

$zipName = "fit-build-$date.zip"
$zipPath = Join-Path $PWD $zipName

# Try to use 7-Zip if available
$use7zip = $false
$zipTool = $null

# Check common 7-Zip installation paths
$possiblePaths = @(
    "C:\Program Files\7-Zip\7z.exe",
    "C:\Program Files (x86)\7-Zip\7z.exe",
    "$env:ProgramFiles\7-Zip\7z.exe",
    "$env:ProgramFiles(x86)\7-Zip\7z.exe"
)

foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        $zipTool = $path
        $use7zip = $true
        Write-Host "  Found 7-Zip at: $path" -ForegroundColor Cyan
        break
    }
}

# Also check if 7z is in PATH
if (-not $use7zip) {
    if (Get-Command "7z" -ErrorAction SilentlyContinue) {
        $zipTool = "7z"
        $use7zip = $true
    } elseif (Get-Command "7za" -ErrorAction SilentlyContinue) {
        $zipTool = "7za"
        $use7zip = $true
    }
}

if ($use7zip) {
    # Remove existing zip if it exists
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }
    
    # Remove any existing split files
    Get-ChildItem -Path $PWD -Filter "fit-build-$date.z*" | Remove-Item -Force -ErrorAction SilentlyContinue
    
    Write-Host "  Creating zip archive with password 'fit' and 90MB split..." -ForegroundColor Cyan
    
    # Create zip with password and split at 90MB
    # -tzip = zip format, -pfit = password, -v90m = split at 90MB
    & $zipTool a -tzip -pfit -v90m "$zipPath" "folder-mobilne-app\build\app\outputs\flutter-apk\*" "folder-desktop-app\build\windows\x64\runner\Release\*"
    
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
        Write-Host "  ✗ Failed to create zip archive with 7-Zip!" -ForegroundColor Red
        exit 1
    }
} else {
    # Use PowerShell Compress-Archive (no password support)
    Write-Host "  ⚠ 7-Zip not found. Creating zip without password..." -ForegroundColor Yellow
    
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }
    
    Compress-Archive -Path "folder-mobilne-app\build\app\outputs\flutter-apk", "folder-desktop-app\build\windows\x64\runner\Release" -DestinationPath $zipPath -Force
    
    if (Test-Path $zipPath) {
        $size = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
        Write-Host "  ✓ Created $zipName ($size MB) WITHOUT PASSWORD" -ForegroundColor Yellow
        Write-Host "  ⚠ IMPORTANT: Add password 'fit' manually using 7-Zip or WinRAR!" -ForegroundColor Red
        Write-Host "    1. Install 7-Zip from https://www.7-zip.org/" -ForegroundColor White
        Write-Host "    2. Right-click $zipName -> 7-Zip -> Add to archive..." -ForegroundColor White
        Write-Host "    3. Set password to 'fit' and split to 90MB volumes" -ForegroundColor White
    } else {
        Write-Host "  ✗ Failed to create zip archive!" -ForegroundColor Red
        exit 1
    }
}

# Step 4: Verify recommender documentation
Write-Host "`n[4/5] Verifying documentation..." -ForegroundColor Yellow

if (Test-Path "recommender_dokumentacija.pdf") {
    Write-Host "  ✓ recommender_dokumentacija.pdf found" -ForegroundColor Green
} else {
    Write-Host "  ✗ recommender_dokumentacija.pdf NOT FOUND!" -ForegroundColor Red
    Write-Host "  Please ensure this file exists in the root directory." -ForegroundColor Yellow
    exit 1
}

# Step 5: Summary
Write-Host "`n[5/5] Final Summary:" -ForegroundColor Yellow
Write-Host "  ✓ Android APK: folder-mobilne-app\build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
Write-Host "  ✓ Windows build: folder-desktop-app\build\windows\x64\runner\Release\" -ForegroundColor Green
Write-Host "  ✓ Zip archive: $zipName" -ForegroundColor Green
Write-Host "  ✓ Documentation: recommender_dokumentacija.pdf" -ForegroundColor Green

Write-Host "`n=== Finalization Complete! ===" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. If zip doesn't have password, add it manually with 7-Zip/WinRAR" -ForegroundColor White
Write-Host "  2. Review all files before committing" -ForegroundColor White
Write-Host "  3. Run: git add ." -ForegroundColor White
Write-Host "  4. Run: git commit -m 'chore: prepare build files for submission'" -ForegroundColor White
Write-Host "  5. Run: git push origin main" -ForegroundColor White

