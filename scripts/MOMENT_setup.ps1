$ErrorActionPreference = 'Continue'

$repoRoot = Split-Path -Parent $PSScriptRoot
$destinationPath = Join-Path $repoRoot 'MOMENT'
$pythonScriptPath = Join-Path $PSScriptRoot 'MOMENT_setup.py'
$projectPath = Join-Path $destinationPath 'MOMENT-main'
$repositoryUrl = 'https://github.com/MOMENT-in-MOTION/MOMENT.git'
$versionCheck = "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}' if sys.version_info >= (3, 10) else '')"
$pythonCommand = $null
$pythonPrefix = @()
$pythonVersion = ''

$launcher = Get-Command -Name 'py.exe' -CommandType Application -ErrorAction SilentlyContinue
if ($null -ne $launcher) {
    $pythonVersion = [string](& $launcher.Source -3 -c $versionCheck 2>$null)
    $pythonVersion = $pythonVersion.Trim()
    if ($LASTEXITCODE -eq 0 -and $pythonVersion) {
        $pythonCommand = $launcher.Source
        $pythonPrefix = @("-$pythonVersion")
    }
} else {
    foreach ($commandName in @('python.exe', 'python')) {
        $candidate = Get-Command -Name $commandName -CommandType Application -ErrorAction SilentlyContinue
        if ($null -ne $candidate) {
            $pythonVersion = [string](& $candidate.Source -c $versionCheck 2>$null)
            $pythonVersion = $pythonVersion.Trim()
            if ($LASTEXITCODE -eq 0 -and $pythonVersion) {
                $pythonCommand = $candidate.Source
                break
            }
        }
    }
}

if ($null -eq $pythonCommand) {
    [Console]::Error.WriteLine('Error: Python 3.10 or newer is required. Install it and make sure py.exe, python.exe, or python is available on PATH.')
    exit 1
}

if (-not (Test-Path -LiteralPath $pythonScriptPath -PathType Leaf)) {
    [Console]::Error.WriteLine("Error: Python script not found: $pythonScriptPath")
    exit 1
}

$pythonArguments = @($pythonPrefix) + @($pythonScriptPath, 'scaffold', $repoRoot)
& $pythonCommand @pythonArguments
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$gitDirectory = Join-Path $projectPath '.git'
if (-not (Test-Path -LiteralPath $gitDirectory -PathType Container)) {
    if (Test-Path -LiteralPath $projectPath) {
        [Console]::Error.WriteLine("Error: $projectPath exists but is not a Git checkout. Move it aside and run setup again.")
        exit 1
    }

    $gitCommand = Get-Command -Name 'git.exe' -CommandType Application -ErrorAction SilentlyContinue
    if ($null -eq $gitCommand) {
        $gitCommand = Get-Command -Name 'git' -CommandType Application -ErrorAction SilentlyContinue
    }
    if ($null -eq $gitCommand) {
        [Console]::Error.WriteLine('Error: Git is required to download MOMENT. Install Git and make sure it is available on PATH.')
        exit 1
    }

    $cloneArguments = @($pythonPrefix) + @($pythonScriptPath, 'clone', $repositoryUrl, $projectPath)
    & $pythonCommand @cloneArguments
    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine('Error: Could not clone the MOMENT repository.')
        exit $LASTEXITCODE
    }
}

$requirementsPath = Join-Path $projectPath 'requirements.txt'
$testsPath = Join-Path $projectPath 'tests'
$mainPath = Join-Path $projectPath 'src\main.py'
if (-not (Test-Path -LiteralPath $requirementsPath -PathType Leaf) -or
    -not (Test-Path -LiteralPath $testsPath -PathType Container) -or
    -not (Test-Path -LiteralPath $mainPath -PathType Leaf)) {
    [Console]::Error.WriteLine("Error: MOMENT project files were not found in $projectPath")
    exit 1
}

Write-Host 'Setting up the Python virtual environment...'
$venvPath = Join-Path $projectPath '.venv'
$venvPython = Join-Path $venvPath 'Scripts\python.exe'
if (-not (Test-Path -LiteralPath $venvPython -PathType Leaf)) {
    $venvArguments = @($pythonPrefix) + @('-m', 'venv', $venvPath)
    & $pythonCommand @venvArguments
    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine('Error: Could not create the MOMENT virtual environment.')
        exit $LASTEXITCODE
    }
}

& $venvPython $pythonScriptPath 'run' $projectPath
$runExitCode = $LASTEXITCODE

# Paths below are relative to the repository root ($repoRoot), where this shell ends up.
# MOMENT_setup.bat opens a cmd.exe window afterwards, so these commands use cmd syntax (pushd/popd), not PowerShell.
$projectRelative = 'MOMENT\MOMENT-main'
$metamodelRelative = 'workshop\create_your_metamodel\metamodel.json'
$outputRelative = 'workshop\API_output'
$modelScriptRelative = 'workshop\create_your_model\your_car_model.py'
$venvPythonFromRoot = "$projectRelative\.venv\Scripts\python.exe"
$generateApiCommand = "pushd $projectRelative && .\.venv\Scripts\python.exe -m src.main `"..\..\$metamodelRelative`" -o `"..\..\$outputRelative`" && popd"

Write-Host ''
Write-Host 'Workshop steps (run all commands from this window/directory):'
Write-Host ''
Write-Host "1. Open your metamodel: $metamodelRelative"
Write-Host '   It is the unfinished car metamodel from the presentation.'
Write-Host ''
Write-Host '2. Complete the metamodel as described in the presentation instructions.'
Write-Host ''
Write-Host '3. Generate the API from your metamodel:'
Write-Host "     $generateApiCommand"
Write-Host ''
Write-Host "4. Open your model script: $modelScriptRelative"
Write-Host '   Build a model of a vehicle of your choice using the generated API.'
Write-Host ''
Write-Host '5. Run the script to serialize your model:'
Write-Host "     .\$venvPythonFromRoot -m workshop.create_your_model.your_car_model"
Write-Host ''
Write-Host 'For CLI help and available options:'
Write-Host "  pushd $projectRelative && .\.venv\Scripts\python.exe -m src.main --help && popd"

exit $runExitCode