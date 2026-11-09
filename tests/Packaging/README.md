# AJN portable release

Build the Windows x64 frontend from the repository root with the .NET 10 SDK:

```powershell
dotnet publish src/MpvNet.Windows/MpvNet.Windows.csproj -p:PublishProfile=AjnPortable -p:InformationalVersion=7.1.2.0-ajn.2 -o publish
```

The profile includes the .NET and Windows Desktop runtimes. Do not override
`SelfContained` to false: AJN's installer and updater do not install a shared
Desktop Runtime. `IncludeNativeLibrariesForSelfExtract` also bundles the native
runtime libraries into the executable; they are extracted on first launch.

Package the complete publish output together with the portable player resources
(`mpvnet.com`, `libmpv-2.dll`, `MediaInfo.dll`, `Locale`, and license). AJN replaces
libmpv with its separately pinned native engine during assembly. The existing
`src/Tools/release-mpv.net.ps1` is the upstream debug-release script and does not
use this AJN publish profile.

Test the actual portable directory, using a fresh output directory:

```powershell
pwsh -File tests/Packaging/Test-SelfContained.ps1 -PlayerDirectory D:/TestPlayer -OutputDirectory D:/NewPackagingResults
```

This launches the packaged EXE with runtime-root variables pointing to an empty
directory, omits .NET from its PATH, suppresses the missing-runtime dialog, and
records host resolution. It requires a successful version query and normal exit,
and verifies that .NET 10 used its internal host and CoreCLR built into the EXE. It does
not uninstall or alter any system runtime. A framework-dependent package must
fail this test even on a development PC with .NET installed.

This is a runtime-dependency regression test, not a clean-Windows VM test. Run
`tests/DisplayChange` for the separate window/DPI behavior checks.
