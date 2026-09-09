$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework

function Add-LoadLine {
    param(
        [Parameter(Mandatory)] [string] $StartupFile,
        [Parameter(Mandatory)] [string] $Marker,
        [Parameter(Mandatory)] [string] $LoadLine
    )

    if (Test-Path -LiteralPath $StartupFile) {
        $content = Get-Content -LiteralPath $StartupFile -Raw
        if ($content -match [regex]::Escape($Marker)) { return }
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        Copy-Item -LiteralPath $StartupFile -Destination "$StartupFile.bak-$stamp" -Force
    } else {
        $content = ";;; AutoCAD startup file`r`n"
    }

    $addition = "`r`n;;; WIW Dynamic Bolt Plugin`r`n$LoadLine`r`n"
    Set-Content -LiteralPath $StartupFile -Value ($content.TrimEnd() + $addition) -Encoding ASCII
}

try {
    $payload = Split-Path -Parent $PSCommandPath
    $autodeskRoot = Join-Path $env:APPDATA 'Autodesk'
    $supportFolders = @(
        Get-ChildItem -LiteralPath $autodeskRoot -Directory -Filter 'AutoCAD 20*' -ErrorAction SilentlyContinue |
        ForEach-Object {
            Get-ChildItem -LiteralPath $_.FullName -Directory -Filter 'R*' -ErrorAction SilentlyContinue |
            ForEach-Object {
                Get-ChildItem -LiteralPath $_.FullName -Directory -ErrorAction SilentlyContinue |
                ForEach-Object {
                    $candidate = Join-Path $_.FullName 'Support'
                    if (Test-Path -LiteralPath $candidate) { $candidate }
                }
            }
        } | Sort-Object -Unique
    )

    if (-not $supportFolders) {
        throw 'No AutoCAD user Support folder was found. Start AutoCAD once, close it, and run this installer again.'
    }

    $files = @(
        'ImperialBoltBlock.lsp',
        'ibolt.dcl',
        'IBOLT_SOURCE_V2.dwg',
        'ibolt16.bmp',
        'ibolt32.bmp',
        'bolt_toolbar_integration.lsp'
    )

    foreach ($support in $supportFolders) {
        foreach ($file in $files) {
            $source = Join-Path $payload $file
            if (-not (Test-Path -LiteralPath $source)) { throw "Installer payload is missing $file." }
            Copy-Item -LiteralPath $source -Destination (Join-Path $support $file) -Force
        }

        $boltPath = (Join-Path $support 'ImperialBoltBlock.lsp').Replace('\','/')
        $toolbarPath = (Join-Path $support 'bolt_toolbar_integration.lsp').Replace('\','/')
        $startup = Join-Path $support 'acaddoc.lsp'
        Add-LoadLine -StartupFile $startup -Marker 'ImperialBoltBlock.lsp' -LoadLine "(load `"$boltPath`")"
        Add-LoadLine -StartupFile $startup -Marker 'bolt_toolbar_integration.lsp' -LoadLine "(load `"$toolbarPath`")"
    }

    $versions = ($supportFolders | ForEach-Object {
        if ($_ -match 'AutoCAD (20\d\d)') { $Matches[1] }
    } | Sort-Object -Unique) -join ', '

    [System.Windows.MessageBox]::Show(
        "Dynamic Bolt Plugin installed for AutoCAD $versions.`n`nRestart AutoCAD, then use IBOLT or the Bolt toolbar button.",
        'Dynamic Bolt Plugin', 'OK', 'Information') | Out-Null
    exit 0
}
catch {
    [System.Windows.MessageBox]::Show(
        "Installation failed:`n`n$($_.Exception.Message)",
        'Dynamic Bolt Plugin', 'OK', 'Error') | Out-Null
    exit 1
}
