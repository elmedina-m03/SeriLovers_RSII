# SeriLovers RSII - Final Submission Status

## Current Status

### ✅ COMPLETED TASKS:

**Task 7: Documentation**
- ✓ `recommender_dokumentacija.pdf` exists

**Task 8: README.md**
- ✓ Contains backend steps (Docker and non-Docker)
- ✓ Contains Flutter steps (Desktop and Mobile)
- ✓ Contains test credentials (desktop/test and mobile/test)

**Task 3: Windows Build**
- ✓ Windows build exists in `folder-desktop-app/build/windows/x64/runner/Release/`

### 🔄 TASKS NEEDING MANUAL EXECUTION:

Due to terminal execution issues, the following tasks need to be executed manually:

**Task 1: Verify Flutter environment**
```powershell
cd serilovers_frontend
flutter doctor
```

**Task 2: Generate Android RELEASE build**
```powershell
cd serilovers_frontend
flutter clean
flutter pub get
flutter build apk --release
```

**Task 4: Organize build artifacts**
- Copy Android APK from `serilovers_frontend/build/app/outputs/flutter-apk/app-release.apk`
- To: `folder-mobilne-app/build/app/outputs/flutter-apk/app-release.apk`
- Windows files are already in `folder-desktop-app/build/windows/x64/runner/Release/`

**Task 5: Environment files**
- ✓ No .env files found (only env.template exists)

**Task 6: Submission ZIP**
- Create password-protected ZIP: `fit-build-25-01-13.zip` (password: fit)
- If > 100MB, split into 90MB parts (.z01, .z02, ...)
- Use 7-Zip: `7z a -pfit -v90m fit-build-25-01-13.zip * -xr!.git`

**Task 9: Git preparation**
```powershell
git add .
git commit -m "Final submission - FIT RSII"
```

