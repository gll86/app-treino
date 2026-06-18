param([switch]$Update)

$ErrorActionPreference = 'Stop'
$html = [System.IO.File]::ReadAllText("$PSScriptRoot\index.html", [System.Text.Encoding]::UTF8)
$snapshotFile = "$PSScriptRoot\validate.snapshot.json"

$passed = 0
$failed = 0

function Pass($msg) { Write-Host "  OK   $msg" -ForegroundColor Green; $script:passed++ }
function Fail($msg) { Write-Host "  FAIL $msg" -ForegroundColor Red;   $script:failed++ }

Write-Host ""
Write-Host "Validando index.html..." 
Write-Host ""

# 1. Divs balanceados
$open  = ([regex]::Matches($html, '<div[\s>]')).Count
$close = ([regex]::Matches($html, '</div>')).Count
if ($open -eq $close) { Pass "Divs balanceados ($open abertos, $close fechados)" }
else                   { Fail "Divs desbalanceados: $open abertos vs $close fechados" }

# 2. IDs obrigatorios
$ids = @('id="panels"','id="tabs"','id="panel-A"','id="panel-B"','id="panel-C"','id="panel-D"','id="panel-E"','id="panel-F"')
foreach ($id in $ids) {
    if ($html.Contains($id)) { Pass "Elemento presente: $id" }
    else                      { Fail "Elemento ausente:  $id" }
}

# 3. Contagem de exercise-items (snapshot)
$exCount = ([regex]::Matches($html, 'class="exercise-item"')).Count

if ($Update) {
    $snap = @{ exerciseItemCount = $exCount }
    $snap | ConvertTo-Json | Set-Content $snapshotFile -Encoding UTF8
    Write-Host "  INFO  Snapshot atualizado: $exCount exercise-items" -ForegroundColor Cyan
}
elseif (Test-Path $snapshotFile) {
    $snap = Get-Content $snapshotFile | ConvertFrom-Json
    $expected = $snap.exerciseItemCount
    if ($exCount -eq $expected) { Pass "exercise-item count = $exCount" }
    else { Fail "exercise-item count: esperado $expected, encontrado $exCount (rode -Update se a mudanca foi intencional)" }
}
else {
    Write-Host "  INFO  exercise-item count: $exCount (sem snapshot - rode -Update para salvar)" -ForegroundColor Yellow
}

# 4. Padroes proibidos (funcionalidades removidas)
$forbidden = @(
    'class="sets-area"',
    'class="set-row"',
    'toggleSetDone',
    'buildSetsArea',
    'openSets',
    'hist_'
)
foreach ($pat in $forbidden) {
    if (-not $html.Contains($pat)) { Pass "Sem padrao proibido: $pat" }
    else                            { Fail "Padrao proibido encontrado: $pat" }
}

# Resultado
Write-Host ""
if ($failed -eq 0) {
    Write-Host "PASSOU - $passed checks ok" -ForegroundColor Green
    Write-Host ""
    exit 0
}
else {
    Write-Host "FALHOU - $failed de $($passed + $failed) checks falharam" -ForegroundColor Red
    Write-Host ""
    exit 1
}