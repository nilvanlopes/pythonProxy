param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$ProxyDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# --------------------------------------------------
# Recarrega variáveis de ambiente no terminal atual
# --------------------------------------------------
function Refresh-CurrentEnv {
    $env:PATH = (
        [Environment]::GetEnvironmentVariable("PATH", "User"),
        [Environment]::GetEnvironmentVariable("PATH", "Machine")
    ) -join ";"
}

# --------------------------------------------------
# Python local (prioridade máxima)
# --------------------------------------------------
function Get-LocalPython {
    $venv = Join-Path (Get-Location) ".venv\Scripts\python.exe"
    if (Test-Path $venv) { return $venv }

    $local = Join-Path (Get-Location) "python.exe"
    if (Test-Path $local) { return $local }

    return $null
}

# --------------------------------------------------
# Python global existente no PATH (exceto o proxy)
# --------------------------------------------------
function Get-GlobalPython {
    try {
        $cmd = Get-Command python.exe -ErrorAction Stop
        if ($cmd.Source -ne $MyInvocation.MyCommand.Path) {
            return $cmd.Source
        }
    } catch {}
    return $null
}

# --------------------------------------------------
# Pythons instalados via uv (somente instalados)
# --------------------------------------------------
function Get-UvPythons {
    $output = uv python list 2>$null
    if (-not $output) { return @() }

    $output |
        Where-Object {
            $_ -notmatch "<download available>" -and
            $_ -match "uv\\python"
        } |
        ForEach-Object {
            $parts = $_ -split "\s{2,}"
            if ($parts.Count -ge 2 -and (Test-Path $parts[1])) {
                [PSCustomObject]@{
                    Name = $parts[0]
                    Path = $parts[1]
                }
            }
        } |
        Sort-Object Name -Unique
}

# --------------------------------------------------
# Seleção interativa
# --------------------------------------------------
function Select-UvPython {
    $versions = Get-UvPythons
    if (-not $versions -or $versions.Count -eq 0) {
        Write-Error "Nenhuma versão do Python instalada via uv."
        exit 1
    }

    Write-Host "Selecione uma versão do Python (uv):"
    for ($i = 0; $i -lt $versions.Count; $i++) {
        Write-Host "[$i] $($versions[$i].Name)"
    }

    $choice = Read-Host "Número"
    $selected = $versions[$choice]

    if (-not $selected) {
        Write-Error "Seleção inválida."
        exit 1
    }

    return $selected.Path
}

# --------------------------------------------------
# Atualiza PATH do usuário + terminal atual
# --------------------------------------------------
function Set-GlobalPythonPath {
    param([string]$PythonExe)

    $PythonDir = Split-Path -Parent $PythonExe
    $userPath = [Environment]::GetEnvironmentVariable("PATH", "User") -split ";"

    # remove pythons antigos do uv
    $userPath = $userPath | Where-Object { $_ -notmatch "\\uv\\python\\" }

    # garante proxy no topo
    $userPath = $userPath | Where-Object { $_ -ne $ProxyDir }
    $userPath = @($ProxyDir, $PythonDir) + $userPath

    $newPath = ($userPath | Select-Object -Unique) -join ";"
    [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")

    # atualiza o shell atual
    Refresh-CurrentEnv
}

# --------------------------------------------------
# Ativa venv do projeto atual
# --------------------------------------------------
function Activate-ProjectVenv {
    $venvScript = Join-Path (Get-Location) ".venv\Scripts\Activate.ps1"
    
    if (Test-Path $venvScript) {
        & $venvScript
        Write-Host "Venv ativado: $(Get-Location)\.venv"
        return $true
    }
    
    return $false
}

# --------------------------------------------------
# Comando especial: python change version
# --------------------------------------------------
if ($Args.Count -ge 2 -and $Args[0] -eq "change" -and $Args[1] -eq "version") {
    $pythonExe = Select-UvPython
    Set-GlobalPythonPath $pythonExe
    Write-Host "Python global atualizado."
    exit 0
}

# --------------------------------------------------
# Comando especial: python activate venv
# --------------------------------------------------
if ($Args.Count -ge 2 -and $Args[0] -eq "activate" -and $Args[1] -eq "venv") {
    if (Activate-ProjectVenv) {
        exit 0
    } else {
        Write-Error "Nenhum venv encontrado no diretório atual (.venv\Scripts\Activate.ps1)."
        exit 1
    }
}

# --------------------------------------------------
# Fluxo principal
# --------------------------------------------------

# 1️⃣ Python local
$python = Get-LocalPython
if ($python) {
    & $python @Args
    exit $LASTEXITCODE
}

# 2️⃣ Python global existente
$python = Get-GlobalPython
if ($python) {
    & $python @Args
    exit $LASTEXITCODE
}

# 3️⃣ Nenhum encontrado → selecionar uv + setar global
$pythonExe = Select-UvPython
Set-GlobalPythonPath $pythonExe
& $pythonExe @Args
exit $LASTEXITCODE
