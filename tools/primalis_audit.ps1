#requires -Version 5.1

[CmdletBinding()]
param(
    [string]$GodotPath = "",
    [ValidateRange(30, 1800)]
    [int]$ProcessTimeoutSeconds = 420
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$script:ReportLines = New-Object 'System.Collections.Generic.List[string]'
$script:FailCount = 0
$script:WarnCount = 0
$script:TempProject = $null

function Write-AuditLine {
    param([AllowEmptyString()][string]$Text = "")
    Write-Host $Text
    [void]$script:ReportLines.Add($Text)
}

function Write-Section {
    param([string]$Name)
    Write-AuditLine ""
    Write-AuditLine $Name
    Write-AuditLine ("-" * $Name.Length)
}

function Add-Check {
    param(
        [ValidateSet("PASS", "WARN", "FAIL", "INFO")]
        [string]$Status,
        [string]$Message
    )
    if ($Status -eq "FAIL") {
        $script:FailCount++
    } elseif ($Status -eq "WARN") {
        $script:WarnCount++
    }
    Write-AuditLine ("[{0}] {1}" -f $Status, $Message)
}

function Format-Bytes {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return ("{0:N2} GiB" -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ("{0:N2} MiB" -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ("{0:N2} KiB" -f ($Bytes / 1KB)) }
    return ("{0} B" -f $Bytes)
}

function Get-RelativePath {
    param(
        [string]$BasePath,
        [string]$Path
    )
    $baseFull = [IO.Path]::GetFullPath($BasePath).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $pathFull = [IO.Path]::GetFullPath($Path)
    $baseUri = New-Object System.Uri($baseFull)
    $pathUri = New-Object System.Uri($pathFull)
    return [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($pathUri).ToString()).Replace('/', '\')
}

function Get-FilesExcludingDirectories {
    param(
        [string]$RootPath,
        [string[]]$ExcludedDirectoryNames
    )
    $files = New-Object 'System.Collections.Generic.List[System.IO.FileInfo]'
    $pending = New-Object 'System.Collections.Generic.Stack[string]'
    $pending.Push([IO.Path]::GetFullPath($RootPath))
    while ($pending.Count -gt 0) {
        $current = $pending.Pop()
        foreach ($item in @(Get-ChildItem -LiteralPath $current -Force -ErrorAction SilentlyContinue)) {
            if ($item.PSIsContainer) {
                if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
                if ($ExcludedDirectoryNames -contains $item.Name) { continue }
                $pending.Push($item.FullName)
            } else {
                [void]$files.Add($item)
            }
        }
    }
    return $files.ToArray()
}

function Invoke-CapturedProcess {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [string]$WorkingDirectory,
        [int]$TimeoutSeconds = 300
    )
    $job = $null
    $timedOut = $false
    $exitCode = -1
    $output = @()
    try {
        $jobArguments = @($FilePath, (,$Arguments), $WorkingDirectory)
        $job = Start-Job -ScriptBlock {
            param($Executable, $ProcessArguments, $ProcessWorkingDirectory)
            Set-Location -LiteralPath $ProcessWorkingDirectory
            if ($ProcessArguments -contains '--headless') {
                $auditUserHome = Join-Path $ProcessWorkingDirectory '.audit_user'
                New-Item -ItemType Directory -Path $auditUserHome -Force | Out-Null
                $env:GODOT_USER_HOME = $auditUserHome
            }
            $captured = @(& $Executable @ProcessArguments 2>&1 | ForEach-Object { $_.ToString() })
            [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $captured }
        } -ArgumentList $jobArguments
        $finished = @(Wait-Job -Job $job -Timeout $TimeoutSeconds)
        if ($finished.Count -eq 0) {
            $timedOut = $true
            Stop-Job -Job $job -ErrorAction SilentlyContinue
        } else {
            $payload = @(Receive-Job -Job $job -ErrorAction SilentlyContinue)
            $result = @($payload | Where-Object { $null -ne $_.PSObject.Properties['ExitCode'] } | Select-Object -Last 1)
            if ($result.Count -gt 0) {
                $exitCode = [int]$result[0].ExitCode
                $output = @($result[0].Output)
            } else {
                $output = @($payload | ForEach-Object { $_.ToString() })
                $output += 'PROCESS RESULT ERROR: child process returned no exit-code payload.'
            }
        }
    } catch {
        $output += "PROCESS START ERROR: $($_.Exception.Message)"
    } finally {
        if ($null -ne $job) {
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        }
    }
    return [pscustomobject]@{
        ExitCode = $exitCode
        TimedOut = $timedOut
        Output = @($output)
    }
}

function Get-ProcessDiagnostics {
    param([string[]]$Lines)
    $allErrors = @($Lines | Where-Object {
        $_ -match '^\s*(ERROR|SCRIPT ERROR):' -or
        $_ -match 'Parse Error:' -or
        $_ -match 'No loader found for resource' -or
        $_ -match 'referenced non-existent resource'
    })
    $environmentErrors = @($allErrors | Where-Object {
        $_ -match 'Failed to read the root certificate store' -or
        $_ -match "Failed to open 'user://logs/" -or
        $_ -match 'Failed to open log file for writing: user://logs/' -or
        $_ -match 'Cannot save file .*AppData.Roaming.Godot.editor_settings' -or
        $_ -match 'Error saving editor settings to .*AppData.Roaming.Godot.editor_settings'
    })
    $errors = @($allErrors | Where-Object { $environmentErrors -notcontains $_ })
    $warnings = @($Lines | Where-Object { $_ -match '^\s*WARNING:' })
    $environmentWarnings = @($warnings | Where-Object {
        $_ -match '(Vulkan|OpenGL|Direct3D|audio|ALSA|PulseAudio|display server|D-Bus|device)'
    })
    $implementationWarnings = @($warnings | Where-Object { $environmentWarnings -notcontains $_ })
    return [pscustomobject]@{
        Errors = $errors
        EnvironmentErrors = $environmentErrors
        Warnings = $warnings
        EnvironmentWarnings = $environmentWarnings
        ImplementationWarnings = $implementationWarnings
    }
}

function Write-DiagnosticSample {
    param(
        [string]$Label,
        [string[]]$Lines,
        [int]$Limit = 8
    )
    if ($Lines.Count -eq 0) { return }
    Write-AuditLine ("  {0}:" -f $Label)
    foreach ($line in @($Lines | Select-Object -First $Limit)) {
        Write-AuditLine ("    {0}" -f $line.Trim())
    }
    if ($Lines.Count -gt $Limit) {
        Write-AuditLine ("    ... {0} more" -f ($Lines.Count - $Limit))
    }
}

function Find-GodotExecutable {
    param(
        [string]$RequestedPath,
        [string]$ProjectRoot
    )
    $explicit = New-Object 'System.Collections.Generic.List[object]'
    $candidates = New-Object 'System.Collections.Generic.List[object]'
    $seen = @{}

    function Add-GodotCandidate {
        param([string]$Path, [string]$Source, [bool]$IsExplicit)
        if ([string]::IsNullOrWhiteSpace($Path)) { return }
        $expanded = [Environment]::ExpandEnvironmentVariables($Path.Trim().Trim('"'))
        if (-not (Test-Path -LiteralPath $expanded -PathType Leaf)) { return }
        $full = [IO.Path]::GetFullPath($expanded)
        $key = $full.ToLowerInvariant()
        if ($seen.ContainsKey($key)) { return }
        $seen[$key] = $true
        $item = [pscustomobject]@{ Path = $full; Source = $Source }
        if ($IsExplicit) { [void]$explicit.Add($item) } else { [void]$candidates.Add($item) }
    }

    Add-GodotCandidate $RequestedPath "-GodotPath" $true
    Add-GodotCandidate $env:GODOT_PATH "GODOT_PATH" $true

    foreach ($hintName in @('.godot_path', 'godot_path.txt', 'tools\godot_path.txt')) {
        $hintPath = Join-Path $ProjectRoot $hintName
        if (Test-Path -LiteralPath $hintPath -PathType Leaf) {
            $hintValue = @(Get-Content -LiteralPath $hintPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1)
            if ($hintValue.Count -gt 0) {
                Add-GodotCandidate $hintValue[0] ("repository hint {0}" -f $hintName) $true
            }
        }
    }

    if ($explicit.Count -gt 0) { return $explicit[0] }

    foreach ($commandName in @(
        'Godot_v4.7.2-stable_win64_console.exe',
        'Godot_v4.7.2-stable_win64.exe',
        'godot4',
        'godot'
    )) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $command) {
            Add-GodotCandidate $command.Source ("PATH ({0})" -f $commandName) $false
        }
    }

    $userProfile = [Environment]::GetFolderPath('UserProfile')
    $searchRoots = @(
        (Join-Path $userProfile 'Downloads'),
        (Join-Path $userProfile 'Desktop'),
        (Join-Path $env:LOCALAPPDATA 'Programs'),
        $env:ProgramFiles,
        ${env:ProgramFiles(x86)},
        'C:\Godot',
        'C:\Tools'
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and (Test-Path -LiteralPath $_ -PathType Container) } | Select-Object -Unique

    foreach ($searchRoot in $searchRoots) {
        foreach ($file in @(Get-ChildItem -LiteralPath $searchRoot -Filter 'Godot*.exe' -File -ErrorAction SilentlyContinue)) {
            Add-GodotCandidate $file.FullName ("local search ({0})" -f $searchRoot) $false
        }
        foreach ($directory in @(Get-ChildItem -LiteralPath $searchRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Godot' })) {
            foreach ($file in @(Get-ChildItem -LiteralPath $directory.FullName -Filter 'Godot*.exe' -File -ErrorAction SilentlyContinue)) {
                Add-GodotCandidate $file.FullName ("local search ({0})" -f $searchRoot) $false
            }
        }
    }

    if ($candidates.Count -eq 0) { return $null }
    $ranked = @($candidates | Sort-Object `
        @{ Expression = { if ($_.Path -match '4\.7\.2') { 0 } else { 1 } } }, `
        @{ Expression = { if ($_.Path -match '_console\.exe$') { 0 } else { 1 } } }, `
        @{ Expression = { $_.Path } })
    return $ranked[0]
}

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\', '/')
$reportPath = Join-Path $projectRoot 'captures\audit\latest_primalis_audit.txt'
$exitCode = 1

try {
    Write-AuditLine "PRIMALIS PROJECT AUDIT"
    Write-AuditLine ("Generated: {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss K'))
    Write-AuditLine ("Project:   {0}" -f $projectRoot)

    Write-Section "Project Root"
    $requiredPaths = @(
        'project.godot',
        'docs\PRIMALIS_MASTER.md',
        'scenes',
        'scripts',
        'tests',
        'assets'
    )
    $missingPaths = @()
    foreach ($requiredPath in $requiredPaths) {
        if (-not (Test-Path -LiteralPath (Join-Path $projectRoot $requiredPath))) {
            $missingPaths += $requiredPath
        }
    }
    if ($missingPaths.Count -eq 0) {
        Add-Check PASS "Core project structure is present."
    } else {
        Add-Check FAIL ("Missing core path(s): {0}" -f ($missingPaths -join ', '))
    }

    Write-Section "Git"
    $gitCommand = Get-Command git -ErrorAction SilentlyContinue
    $statusLines = @()
    if ($null -eq $gitCommand) {
        Add-Check FAIL "Git is not available on PATH."
    } else {
        $branch = ((& git -C $projectRoot branch --show-current 2>&1) | Out-String).Trim()
        $head = ((& git -C $projectRoot rev-parse HEAD 2>&1) | Out-String).Trim()
        $statusLines = @(& git -C $projectRoot status --porcelain=v1 --untracked-files=all 2>&1)
        Add-Check INFO ("Branch: {0}" -f $(if ($branch) { $branch } else { '(detached)' }))
        Add-Check INFO ("HEAD:   {0}" -f $head)
        if ($statusLines.Count -eq 0) {
            Add-Check PASS "Working tree is clean."
        } else {
            $untracked = @($statusLines | Where-Object { $_.StartsWith('??') })
            $modified = @($statusLines | Where-Object { -not $_.StartsWith('??') })
            Add-Check WARN ("Working tree is dirty: {0} modified/staged, {1} untracked." -f $modified.Count, $untracked.Count)
            if ($modified.Count -gt 0) {
                Write-AuditLine "  Modified/staged:"
                foreach ($line in $modified) { Write-AuditLine ("    {0}" -f $line) }
            }
            if ($untracked.Count -gt 0) {
                Write-AuditLine "  Untracked:"
                foreach ($line in $untracked) { Write-AuditLine ("    {0}" -f $line) }
            }
        }
    }

    Write-Section "Godot"
    $godot = Find-GodotExecutable -RequestedPath $GodotPath -ProjectRoot $projectRoot
    $godotExecutable = $null
    $godotVersion = ""
    if ($null -eq $godot) {
        Add-Check FAIL "Godot executable was not found. Set GODOT_PATH or pass -GodotPath."
    } else {
        $godotExecutable = $godot.Path
        Add-Check INFO ("Executable: {0}" -f $godotExecutable)
        Add-Check INFO ("Detected via: {0}" -f $godot.Source)
        $versionRun = Invoke-CapturedProcess -FilePath $godotExecutable -Arguments @('--version') -WorkingDirectory $projectRoot -TimeoutSeconds 30
        $versionLines = @($versionRun.Output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($versionRun.ExitCode -ne 0 -or $versionLines.Count -eq 0) {
            Add-Check FAIL ("Could not query Godot version (exit {0})." -f $versionRun.ExitCode)
        } else {
            $godotVersion = $versionLines[0].Trim()
            if ($godotVersion -match '^4\.7\.2\.stable') {
                Add-Check PASS ("Godot version: {0} (expected 4.7.2 stable)." -f $godotVersion)
            } elseif ($godotVersion -match '^4\.') {
                Add-Check WARN ("Godot version: {0}; expected 4.7.2 stable." -f $godotVersion)
            } else {
                Add-Check FAIL ("Godot version: {0}; this project requires Godot 4.7.2 stable." -f $godotVersion)
            }
        }
    }

    $testFiles = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'tests') -Filter '*_headless.gd' -File -ErrorAction SilentlyContinue | Sort-Object `
        @{ Expression = { if ($_.BaseName -match '^step(\d+)_headless$') { [int]$Matches[1] } else { [int]::MaxValue } } }, `
        @{ Expression = { $_.Name } })

    $runtimeReady = $false
    if ($null -ne $godotExecutable -and $missingPaths.Count -eq 0) {
        Write-Section "Cold Import / Parse"
        $tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
        $script:TempProject = Join-Path $tempBase ("PrimalisAudit_{0}_{1}" -f $PID, [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:TempProject -Force | Out-Null
        $copyArguments = @(
            '.', $script:TempProject, '/E', '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/R:1', '/W:1',
            '/XD', '.git', '.godot', 'godot-mcp', 'captures', '.sf'
        )
        $copyRun = Invoke-CapturedProcess -FilePath 'robocopy.exe' -Arguments $copyArguments -WorkingDirectory $projectRoot -TimeoutSeconds 180
        if ($copyRun.TimedOut -or $copyRun.ExitCode -gt 7 -or $copyRun.ExitCode -lt 0) {
            Add-Check FAIL ("Could not create isolated cold-import copy (robocopy exit {0})." -f $copyRun.ExitCode)
            Write-DiagnosticSample "Copy output" $copyRun.Output
        } else {
            Add-Check PASS "Created isolated project copy without touching the existing .godot cache."
            $importRun = Invoke-CapturedProcess -FilePath $godotExecutable `
                -Arguments @('--headless', '--path', '.', '--import') `
                -WorkingDirectory $script:TempProject -TimeoutSeconds $ProcessTimeoutSeconds
            $importDiagnostics = Get-ProcessDiagnostics $importRun.Output
            if ($importRun.TimedOut) {
                Add-Check FAIL ("Cold import timed out after {0} seconds." -f $ProcessTimeoutSeconds)
            } elseif ($importRun.ExitCode -ne 0 -or $importDiagnostics.Errors.Count -gt 0) {
                Add-Check FAIL ("Cold import/parse failed (exit {0}, {1} error line(s))." -f $importRun.ExitCode, $importDiagnostics.Errors.Count)
            } else {
                Add-Check PASS ("Cold import/parse completed (exit {0}, no implementation errors)." -f $importRun.ExitCode)
                $runtimeReady = $true
            }
            if ($importDiagnostics.ImplementationWarnings.Count -gt 0) {
                Add-Check WARN ("Cold import emitted {0} implementation warning(s)." -f $importDiagnostics.ImplementationWarnings.Count)
            } elseif ($importDiagnostics.EnvironmentWarnings.Count -gt 0) {
                Add-Check INFO ("Cold import emitted {0} environment/device warning(s)." -f $importDiagnostics.EnvironmentWarnings.Count)
            } else {
                Add-Check PASS "Cold import emitted no warnings."
            }
            Write-DiagnosticSample "Errors" $importDiagnostics.Errors
            Write-DiagnosticSample "Implementation warnings" $importDiagnostics.ImplementationWarnings
            Write-DiagnosticSample "Environment warnings" $importDiagnostics.EnvironmentWarnings
            if ($importDiagnostics.EnvironmentErrors.Count -gt 0) {
                Add-Check INFO ("Cold import emitted {0} sandbox/OS-only error diagnostic(s), classified separately." -f $importDiagnostics.EnvironmentErrors.Count)
                Write-DiagnosticSample "Environment errors" $importDiagnostics.EnvironmentErrors
            }
        }

        Write-Section "Headless Boot"
        if (-not (Test-Path -LiteralPath (Join-Path $script:TempProject 'project.godot'))) {
            Add-Check FAIL "Headless boot skipped because the isolated project copy is unavailable."
        } else {
            $bootRun = Invoke-CapturedProcess -FilePath $godotExecutable `
                -Arguments @('--headless', '--path', '.', '--quit-after', '120') `
                -WorkingDirectory $script:TempProject -TimeoutSeconds $ProcessTimeoutSeconds
            $bootDiagnostics = Get-ProcessDiagnostics $bootRun.Output
            if ($bootRun.TimedOut) {
                Add-Check FAIL ("Headless boot timed out after {0} seconds." -f $ProcessTimeoutSeconds)
            } elseif ($bootRun.ExitCode -ne 0 -or $bootDiagnostics.Errors.Count -gt 0) {
                Add-Check FAIL ("Headless boot failed (exit {0}, {1} error line(s))." -f $bootRun.ExitCode, $bootDiagnostics.Errors.Count)
            } else {
                Add-Check PASS "Headless boot completed without parser, resource, or scene-reference errors."
            }
            if ($bootDiagnostics.ImplementationWarnings.Count -gt 0) {
                Add-Check WARN ("Headless boot emitted {0} implementation warning(s)." -f $bootDiagnostics.ImplementationWarnings.Count)
            } elseif ($bootDiagnostics.EnvironmentWarnings.Count -gt 0) {
                Add-Check INFO ("Headless boot emitted {0} environment/device warning(s)." -f $bootDiagnostics.EnvironmentWarnings.Count)
            } else {
                Add-Check PASS "Headless boot emitted no warnings."
            }
            Write-DiagnosticSample "Errors" $bootDiagnostics.Errors
            Write-DiagnosticSample "Implementation warnings" $bootDiagnostics.ImplementationWarnings
            Write-DiagnosticSample "Environment warnings" $bootDiagnostics.EnvironmentWarnings
            if ($bootDiagnostics.EnvironmentErrors.Count -gt 0) {
                Add-Check INFO ("Headless boot emitted {0} sandbox/OS-only error diagnostic(s), classified separately." -f $bootDiagnostics.EnvironmentErrors.Count)
                Write-DiagnosticSample "Environment errors" $bootDiagnostics.EnvironmentErrors
            }
        }

        Write-Section "Tests"
        if ($testFiles.Count -eq 0) {
            Add-Check FAIL "No *_headless.gd automated test suites were discovered."
        } else {
            Add-Check PASS ("Discovered {0} suite(s) dynamically under tests/." -f $testFiles.Count)
            $testPass = 0
            $testFail = 0
            foreach ($testFile in $testFiles) {
                $relativeTest = Get-RelativePath $projectRoot $testFile.FullName
                $resourcePath = 'res://' + $relativeTest.Replace('\', '/')
                $testRun = Invoke-CapturedProcess -FilePath $godotExecutable `
                    -Arguments @('--headless', '--path', '.', '--script', $resourcePath) `
                    -WorkingDirectory $script:TempProject -TimeoutSeconds $ProcessTimeoutSeconds
                $testDiagnostics = Get-ProcessDiagnostics $testRun.Output
                $failLines = @($testRun.Output | Where-Object { $_ -match '^FAIL\s' })
                $summaryLines = @($testRun.Output | Where-Object { $_ -match 'HEADLESS:\s' })
                $summary = if ($summaryLines.Count -gt 0) { $summaryLines[-1].Trim() } else { 'No summary line emitted' }
                $label = $testFile.BaseName.ToUpperInvariant().Replace('_HEADLESS', '')
                if ($testFile.BaseName -match '^step(\d+)_headless$') { $label = 'STEP ' + $Matches[1] }
                if ($testRun.TimedOut -or $testRun.ExitCode -ne 0 -or $failLines.Count -gt 0 -or $testDiagnostics.Errors.Count -gt 0) {
                    $testFail++
                    Add-Check FAIL ("{0,-8} {1} (exit {2}) - {3}" -f $label, 'FAIL', $testRun.ExitCode, $summary)
                    Write-DiagnosticSample ("{0} failures/errors" -f $testFile.Name) @($failLines + $testDiagnostics.Errors) 12
                } else {
                    $testPass++
                    Add-Check PASS ("{0,-8} {1} (exit {2}) - {3}" -f $label, 'PASS', $testRun.ExitCode, $summary)
                }
                if ($testDiagnostics.ImplementationWarnings.Count -gt 0) {
                    Add-Check WARN ("{0} emitted {1} implementation warning(s)." -f $testFile.Name, $testDiagnostics.ImplementationWarnings.Count)
                    Write-DiagnosticSample ("{0} warnings" -f $testFile.Name) $testDiagnostics.ImplementationWarnings
                }
                if ($testDiagnostics.EnvironmentErrors.Count -gt 0) {
                    Add-Check INFO ("{0}: {1} sandbox/OS-only diagnostic(s) classified separately." -f $testFile.Name, $testDiagnostics.EnvironmentErrors.Count)
                }
            }
            Write-AuditLine ""
            Write-AuditLine "TOTAL TESTS:"
            Write-AuditLine ("  {0} PASS" -f $testPass)
            Write-AuditLine ("  {0} FAIL" -f $testFail)
        }
    } else {
        Write-Section "Cold Import / Parse"
        Add-Check FAIL "Import, boot, and tests cannot run without the core project and a Godot executable."
        Write-Section "Headless Boot"
        Add-Check FAIL "Skipped."
        Write-Section "Tests"
        Add-Check FAIL "Skipped."
    }

    Write-Section "Large Files"
    $auditFiles = @(Get-FilesExcludingDirectories -RootPath $projectRoot -ExcludedDirectoryNames @('.git', '.godot', 'node_modules', '.sf'))
    $largeFiles = @($auditFiles | Where-Object { $_.Length -gt 10MB } | Sort-Object Length -Descending)
    if ($largeFiles.Count -eq 0) {
        Add-Check PASS "No source/project files exceed 10 MiB."
    } else {
        Add-Check WARN ("Found {0} file(s) over 10 MiB (informational; size alone is not a failure)." -f $largeFiles.Count)
        foreach ($file in $largeFiles) {
            $bands = New-Object 'System.Collections.Generic.List[string]'
            foreach ($threshold in @(10, 25, 50, 100)) {
                if ($file.Length -gt ($threshold * 1MB)) { [void]$bands.Add((">{0}MB" -f $threshold)) }
            }
            Write-AuditLine ("  {0} | {1} | {2} | {3}" -f `
                (Get-RelativePath $projectRoot $file.FullName), (Format-Bytes $file.Length), $file.Extension.ToLowerInvariant(), ($bands -join ', '))
        }
    }

    Write-Section "Git LFS"
    if ($null -eq $gitCommand) {
        Add-Check WARN "Git LFS status unavailable because Git is unavailable."
    } else {
        $lfsVersionOutput = @(& git -C $projectRoot lfs version 2>&1)
        $lfsExit = $LASTEXITCODE
        if ($lfsExit -ne 0) {
            Add-Check WARN "Git LFS: NOT INSTALLED."
        } else {
            Add-Check PASS ("Git LFS: INSTALLED ({0})." -f (($lfsVersionOutput | Select-Object -First 1) -join ''))
            $trackedPatterns = @()
            $attributesPath = Join-Path $projectRoot '.gitattributes'
            if (Test-Path -LiteralPath $attributesPath) {
                $trackedPatterns = @(Get-Content -LiteralPath $attributesPath | Where-Object { $_ -match 'filter=lfs' } | ForEach-Object { ($_ -split '\s+')[0] })
            }
            if ($trackedPatterns.Count -gt 0) {
                Add-Check INFO ("LFS tracked patterns: {0}" -f ($trackedPatterns -join ', '))
            } else {
                Add-Check WARN "Git LFS is installed, but no filter=lfs patterns were found in .gitattributes."
            }
        }
    }

    Write-Section "Assets"
    $assetLedgerPath = Join-Path $projectRoot 'docs\ASSET_LEDGER.csv'
    $assetRows = @()
    $assetLedgerReadable = $false
    if (Test-Path -LiteralPath $assetLedgerPath) {
        try {
            $assetRows = @(Import-Csv -LiteralPath $assetLedgerPath)
            $assetLedgerReadable = $true
            $assetColumns = if ($assetRows.Count -gt 0) { @($assetRows[0].PSObject.Properties.Name) } else { @() }
            Add-Check INFO ("Asset ledger: {0} row(s); schema: {1}" -f $assetRows.Count, ($assetColumns -join ', '))
        } catch {
            Add-Check FAIL ("Asset ledger could not be parsed: {0}" -f $_.Exception.Message)
        }
    } else {
        Add-Check FAIL "docs/ASSET_LEDGER.csv is missing."
    }

    $productionAssets = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'assets') -File -Recurse -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -ne '.gitkeep' -and $_.Extension -ne '.import'
    } | Sort-Object FullName)
    $trackedAssets = New-Object 'System.Collections.Generic.List[string]'
    $untrackedAssets = New-Object 'System.Collections.Generic.List[string]'
    $unknownAssets = New-Object 'System.Collections.Generic.List[string]'
    foreach ($asset in $productionAssets) {
        $relative = (Get-RelativePath $projectRoot $asset.FullName).Replace('\', '/')
        if (-not $assetLedgerReadable -or $assetRows.Count -eq 0) {
            [void]$unknownAssets.Add($relative)
            continue
        }
        $relativeLower = $relative.ToLowerInvariant()
        $nameLower = $asset.Name.ToLowerInvariant()
        $matched = $false
        foreach ($row in $assetRows) {
            $values = @($row.PSObject.Properties | ForEach-Object { [string]$_.Value } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            foreach ($value in $values) {
                $normalizedValue = $value.Replace('\', '/').ToLowerInvariant()
                if ($normalizedValue -eq $relativeLower -or $normalizedValue -eq $nameLower -or $normalizedValue.Contains($relativeLower)) {
                    $matched = $true
                    break
                }
            }
            if (-not $matched) {
                $originalProperty = $row.PSObject.Properties | Where-Object { $_.Name -ieq 'original_filename' } | Select-Object -First 1
                if ($null -ne $originalProperty -and -not [string]::IsNullOrWhiteSpace([string]$originalProperty.Value)) {
                    $sourceStem = [IO.Path]::GetFileNameWithoutExtension([string]$originalProperty.Value).ToLowerInvariant()
                    $assetStem = [IO.Path]::GetFileNameWithoutExtension($asset.Name).ToLowerInvariant()
                    if ($assetStem -eq $sourceStem -or $assetStem.StartsWith($sourceStem + '_')) { $matched = $true }
                }
            }
            if ($matched) { break }
        }
        if ($matched) { [void]$trackedAssets.Add($relative) } else { [void]$untrackedAssets.Add($relative) }
    }
    Add-Check INFO ("Asset coverage: {0} TRACKED, {1} UNTRACKED, {2} UNKNOWN." -f $trackedAssets.Count, $untrackedAssets.Count, $unknownAssets.Count)
    if ($untrackedAssets.Count -gt 0) {
        Add-Check WARN ("{0} production asset(s) have no apparent ASSET_LEDGER match." -f $untrackedAssets.Count)
        foreach ($path in $untrackedAssets) { Write-AuditLine ("  UNTRACKED  {0}" -f $path) }
    } elseif ($unknownAssets.Count -gt 0) {
        Add-Check WARN ("Coverage is UNKNOWN for {0} production asset(s)." -f $unknownAssets.Count)
        foreach ($path in $unknownAssets) { Write-AuditLine ("  UNKNOWN    {0}" -f $path) }
    } else {
        Add-Check PASS "Every production asset has an apparent ledger match."
    }
    foreach ($path in $trackedAssets) { Write-AuditLine ("  TRACKED    {0}" -f $path) }

    Write-Section "Licenses"
    $licenseLedgerPath = Join-Path $projectRoot 'docs\LICENSE_LEDGER.csv'
    $licenseRows = @()
    $licenseLedgerReadable = $false
    if (Test-Path -LiteralPath $licenseLedgerPath) {
        try {
            $licenseRows = @(Import-Csv -LiteralPath $licenseLedgerPath)
            $licenseLedgerReadable = $true
            $licenseColumns = if ($licenseRows.Count -gt 0) { @($licenseRows[0].PSObject.Properties.Name) } else { @() }
            Add-Check INFO ("License ledger: {0} row(s); schema: {1}" -f $licenseRows.Count, ($licenseColumns -join ', '))
        } catch {
            Add-Check FAIL ("License ledger could not be parsed: {0}" -f $_.Exception.Message)
        }
    } else {
        Add-Check FAIL "docs/LICENSE_LEDGER.csv is missing."
    }

    $licenseIssues = New-Object 'System.Collections.Generic.List[string]'
    if ($assetLedgerReadable) {
        foreach ($assetRow in $assetRows) {
            $assetIdProperty = $assetRow.PSObject.Properties | Where-Object { $_.Name -ieq 'asset_id' } | Select-Object -First 1
            $assetId = if ($null -ne $assetIdProperty) { [string]$assetIdProperty.Value } else { '(no asset_id)' }
            $matches = @()
            if ($licenseLedgerReadable) {
                $matches = @($licenseRows | Where-Object {
                    $idProperty = $_.PSObject.Properties | Where-Object { $_.Name -ieq 'asset_id' } | Select-Object -First 1
                    $null -ne $idProperty -and [string]$idProperty.Value -eq $assetId
                })
            }
            if ($matches.Count -eq 0) {
                [void]$licenseIssues.Add(("{0}: missing license entry" -f $assetId))
                continue
            }
            foreach ($licenseRow in $matches) {
                foreach ($fieldName in @('license', 'commercial_ok', 'AI_processing_allowed')) {
                    $property = $licenseRow.PSObject.Properties | Where-Object { $_.Name -ieq $fieldName } | Select-Object -First 1
                    if ($null -eq $property -or [string]::IsNullOrWhiteSpace([string]$property.Value) -or [string]$property.Value -match '(?i)UNKNOWN|pending|not yet') {
                        [void]$licenseIssues.Add(("{0}: {1} is {2}" -f $assetId, $fieldName, $(if ($null -eq $property -or [string]::IsNullOrWhiteSpace([string]$property.Value)) { 'missing' } else { [string]$property.Value })))
                    }
                }
                $allValues = ($licenseRow.PSObject.Properties | ForEach-Object { [string]$_.Value }) -join ' '
                if ($allValues -match '(?i)non[- ]commercial|editorial[- ]only|\bCC[- ]?BY[- ]?NC\b|\bNC[- ]only\b') {
                    [void]$licenseIssues.Add(("{0}: non-commercial/editorial marker present in ledger data" -f $assetId))
                }
                $sourceProperty = $licenseRow.PSObject.Properties | Where-Object { $_.Name -ieq 'source' } | Select-Object -First 1
                $snapshotProperty = $licenseRow.PSObject.Properties | Where-Object { $_.Name -ieq 'license_snapshot' } | Select-Object -First 1
                if ($null -eq $sourceProperty -or [string]::IsNullOrWhiteSpace([string]$sourceProperty.Value) -or [string]$sourceProperty.Value -match '(?i)UNKNOWN|unclear') {
                    [void]$licenseIssues.Add(("{0}: source metadata is missing or unclear" -f $assetId))
                }
                if ($null -eq $snapshotProperty -or [string]::IsNullOrWhiteSpace([string]$snapshotProperty.Value) -or [string]$snapshotProperty.Value -match '(?i)UNKNOWN|pending|not yet') {
                    [void]$licenseIssues.Add(("{0}: license snapshot is missing or unresolved" -f $assetId))
                }
            }
        }
    }
    foreach ($path in $untrackedAssets) {
        [void]$licenseIssues.Add(("{0}: no asset-ledger linkage; license coverage unknown" -f $path))
    }
    $licenseIssues = @($licenseIssues | Select-Object -Unique)
    if ($licenseIssues.Count -eq 0 -and $licenseLedgerReadable) {
        Add-Check PASS "No missing, unknown, non-commercial, or unclear license metadata was detected."
    } else {
        Add-Check WARN ("License audit found {0} unresolved fact(s); no legal conclusion is inferred." -f $licenseIssues.Count)
        foreach ($issue in $licenseIssues) { Write-AuditLine ("  {0}" -f $issue) }
    }

    Write-Section "Unexpected Production Files"
    if ($null -eq $gitCommand) {
        Add-Check WARN "Cannot inspect untracked production files without Git."
    } else {
        $unexpected = @(& git -C $projectRoot ls-files --others --exclude-standard -- assets art_source references 2>&1)
        if ($LASTEXITCODE -ne 0) {
            Add-Check WARN "Git could not enumerate untracked production files."
        } elseif ($unexpected.Count -eq 0) {
            Add-Check PASS "No untracked files found under assets/, art_source/, or references/."
        } else {
            Add-Check WARN ("Found {0} untracked production-area file(s)." -f $unexpected.Count)
            foreach ($path in $unexpected) { Write-AuditLine ("  {0}" -f $path) }
        }
    }

    Write-Section "Repository Hygiene"
    if ($null -eq $gitCommand) {
        Add-Check WARN "Cannot inspect tracked junk files without Git."
    } else {
        $trackedFiles = @(& git -C $projectRoot ls-files 2>&1)
        $junk = @($trackedFiles | Where-Object {
            $_ -match '(?i)(\.blend[12]|\.tmp|\.bak|Thumbs\.db|\.DS_Store)$'
        })
        if ($junk.Count -eq 0) {
            Add-Check PASS "No tracked *.blend1, *.blend2, *.tmp, *.bak, Thumbs.db, or .DS_Store files."
        } else {
            Add-Check WARN ("Found {0} tracked junk/backup file(s)." -f $junk.Count)
            foreach ($path in $junk) { Write-AuditLine ("  {0}" -f $path) }
        }
    }

    Write-Section "Godot Import Hygiene"
    foreach ($protectedFolder in @('docs', 'references', 'captures')) {
        $marker = Join-Path $projectRoot (Join-Path $protectedFolder '.gdignore')
        if (Test-Path -LiteralPath $marker -PathType Leaf) {
            Add-Check PASS ("{0}/ is protected by .gdignore." -f $protectedFolder)
        } else {
            Add-Check WARN ("{0}/ has no .gdignore marker." -f $protectedFolder)
        }
    }
    $artSourceMarker = Join-Path $projectRoot 'art_source\.gdignore'
    if (Test-Path -LiteralPath $artSourceMarker -PathType Leaf) {
        Add-Check PASS "art_source/ is protected by .gdignore."
    } else {
        Add-Check WARN "art_source/ is not protected by .gdignore; report only, no structure was changed."
    }

    Write-Section "Project Statistics"
    $scriptCount = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'scripts') -Filter '*.gd' -File -Recurse -ErrorAction SilentlyContinue).Count
    $sceneCount = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'scenes') -Filter '*.tscn' -File -Recurse -ErrorAction SilentlyContinue).Count
    $glbCount = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'assets') -Filter '*.glb' -File -Recurse -ErrorAction SilentlyContinue).Count
    $assetBytes = [long](($productionAssets | Measure-Object -Property Length -Sum).Sum)
    $allProjectFiles = @(Get-FilesExcludingDirectories -RootPath $projectRoot -ExcludedDirectoryNames @('.git'))
    $projectBytes = [long](($allProjectFiles | Measure-Object -Property Length -Sum).Sum)
    Add-Check INFO (".gd gameplay/tool scripts under scripts/: {0}" -f $scriptCount)
    Add-Check INFO (".tscn scenes under scenes/: {0}" -f $sceneCount)
    Add-Check INFO ("Automated *_headless.gd suites: {0}" -f $testFiles.Count)
    Add-Check INFO ("GLB files under assets/: {0}" -f $glbCount)
    Add-Check INFO ("assets/ production-file size: {0}" -f (Format-Bytes $assetBytes))
    Add-Check INFO ("Project disk size excluding .git directories: {0}" -f (Format-Bytes $projectBytes))
} catch {
    Add-Check FAIL ("Audit runner error: {0}" -f $_.Exception.Message)
    Write-AuditLine ("  {0}" -f $_.ScriptStackTrace)
} finally {
    if ($null -ne $script:TempProject -and (Test-Path -LiteralPath $script:TempProject)) {
        try {
            $tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
            $resolvedTemp = [IO.Path]::GetFullPath($script:TempProject)
            $leaf = Split-Path -Leaf $resolvedTemp
            if ($resolvedTemp.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase) -and $leaf.StartsWith('PrimalisAudit_')) {
                Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
            } else {
                Add-Check WARN ("Refused to remove unexpected temporary path: {0}" -f $resolvedTemp)
            }
        } catch {
            Add-Check WARN ("Could not remove isolated audit copy: {0}" -f $_.Exception.Message)
        }
    }

    Write-Section "Final Result"
    $finalResult = if ($script:FailCount -gt 0) { 'FAIL' } elseif ($script:WarnCount -gt 0) { 'PASS WITH WARNINGS' } else { 'PASS' }
    Write-AuditLine ("FINAL RESULT: {0}" -f $finalResult)
    Write-AuditLine ("Checks: {0} fail, {1} warning" -f $script:FailCount, $script:WarnCount)
    Write-AuditLine ("Report: {0}" -f $reportPath)

    try {
        $reportDirectory = Split-Path -Parent $reportPath
        New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [IO.File]::WriteAllLines($reportPath, $script:ReportLines.ToArray(), $utf8NoBom)
    } catch {
        Write-Host ("[FAIL] Could not write report: {0}" -f $_.Exception.Message)
        $script:FailCount++
    }

    if ($script:FailCount -eq 0) { $exitCode = 0 } else { $exitCode = 1 }
}

exit $exitCode
