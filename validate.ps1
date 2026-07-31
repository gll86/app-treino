param([switch]$Update)

$ErrorActionPreference = 'Stop'
# O console do Windows usa um codepage OEM por padrao (ex: "DOS Western European"),
# que corrompe acentos ao capturar saida UTF-8 de processos externos como o git
# (ex: "Tríceps" vira lixo) - isso quebrava a comparacao byte-a-byte do TREINOS_DATA
# contra o commit anterior. Forcar UTF-8 aqui corrige a captura do `git show`.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$html = [System.IO.File]::ReadAllText("$PSScriptRoot\index.html", [System.Text.Encoding]::UTF8)
$html = $html -replace "`r`n", "`n"
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

# 2. IDs obrigatorios / treinos obrigatorios
# panel-A..D nao existem no HTML estatico (buildAll() monta tudo via JS a
# partir de TREINOS_DATA), entao valida as chaves de treino no dado em vez do id.
$ids = @('id="panels"','id="tabs"')
foreach ($id in $ids) {
    if ($html.Contains($id)) { Pass "Elemento presente: $id" }
    else                      { Fail "Elemento ausente:  $id" }
}
foreach ($key in @('"A":{','"B":{','"C":{','"D":{')) {
    if ($html.Contains($key)) { Pass "Treino presente no TREINOS_DATA: $key" }
    else                       { Fail "Treino ausente no TREINOS_DATA:  $key" }
}

# 3. Contagem de exercicios no TREINOS_DATA (snapshot)
# Cada exercicio tem uma chave "reps" (grupos e treinos nao tem), entao contar
# '"reps":' equivale a contar exercicios, sem depender de HTML pre-renderizado
# (o app monta tabs/paineis 100% via JS em buildAll(), a partir de TREINOS_DATA).
$exCount = ([regex]::Matches($html, '"reps":')).Count

if ($Update) {
    $snap = @{ exerciseCount = $exCount }
    $snap | ConvertTo-Json | Set-Content $snapshotFile -Encoding UTF8
    Write-Host "  INFO  Snapshot atualizado: $exCount exercicios" -ForegroundColor Cyan
}
elseif (Test-Path $snapshotFile) {
    $snap = Get-Content $snapshotFile | ConvertFrom-Json
    $expected = $snap.exerciseCount
    if ($exCount -eq $expected) { Pass "exercicio count = $exCount" }
    else { Fail "exercicio count: esperado $expected, encontrado $exCount (rode -Update se a mudanca foi intencional)" }
}
else {
    Write-Host "  INFO  exercicio count: $exCount (sem snapshot - rode -Update para salvar)" -ForegroundColor Yellow
}

# 4. TREINOS_DATA e um JSON valido
# Isso roda ANTES de qualquer teste no navegador: um JSON quebrado aqui vira
# uma tela em branco silenciosa pro usuario (buildAll() falha ja no loadTreinos()).
$treinosDataMatch = [regex]::Match($html, '(?m)^const TREINOS_DATA = (.+);$')
if ($treinosDataMatch.Success) {
    try {
        $null = $treinosDataMatch.Groups[1].Value | ConvertFrom-Json -ErrorAction Stop
        Pass "TREINOS_DATA e um JSON valido"
    } catch {
        Fail "TREINOS_DATA tem JSON invalido: $($_.Exception.Message)"
    }
} else {
    Fail "TREINOS_DATA nao encontrado no arquivo (regex nao bateu)"
}

# 5. TREINOS_VERSION incrementado quando TREINOS_DATA muda
# Esquecer o bump ja causou um bug real (usuarios com cache antigo continuavam
# vendo o plano velho, ver commit c84a1b9 / CLAUDE.md). Compara contra o
# ultimo commit; se nao houver repo git ou commit anterior, pula com aviso.
$newVersionMatch = [regex]::Match($html, '(?m)^const TREINOS_VERSION=(\d+);$')
$gitAvailable = $false
try { git -C $PSScriptRoot rev-parse --is-inside-work-tree *>$null; $gitAvailable = ($LASTEXITCODE -eq 0) } catch {}
if (-not $gitAvailable) {
    Write-Host "  INFO  Sem repo git - pulando checagem de TREINOS_VERSION" -ForegroundColor Yellow
} else {
    $headHtmlLines = git -C $PSScriptRoot show HEAD:index.html 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $headHtmlLines) {
        Write-Host "  INFO  Sem commit anterior de index.html - pulando checagem de TREINOS_VERSION" -ForegroundColor Yellow
    } else {
        $headHtml = ($headHtmlLines -join "`n") -replace "`r`n", "`n"
        $oldDataMatch = [regex]::Match($headHtml, '(?m)^const TREINOS_DATA = (.+);$')
        $oldVersionMatch = [regex]::Match($headHtml, '(?m)^const TREINOS_VERSION=(\d+);$')
        if (-not ($treinosDataMatch.Success -and $oldDataMatch.Success -and $newVersionMatch.Success -and $oldVersionMatch.Success)) {
            Fail "Nao foi possivel comparar TREINOS_DATA/TREINOS_VERSION com o commit anterior (regex nao bateu em algum dos dois arquivos)"
        } else {
            $dataChanged = $oldDataMatch.Groups[1].Value -ne $treinosDataMatch.Groups[1].Value
            $oldV = [int]$oldVersionMatch.Groups[1].Value
            $newV = [int]$newVersionMatch.Groups[1].Value
            if ($dataChanged -and $newV -le $oldV) {
                Fail "TREINOS_DATA mudou desde o ultimo commit mas TREINOS_VERSION nao foi incrementado ($oldV -> $newV) - usuarios com cache antigo nao verao a mudanca"
            } elseif ($dataChanged) {
                Pass "TREINOS_DATA mudou e TREINOS_VERSION foi incrementado ($oldV -> $newV)"
            } else {
                Pass "TREINOS_DATA sem mudancas desde o ultimo commit"
            }
        }
    }
}

# 6. Toda funcao chamada em onclick/oninput/onchange/onkeydown existe no script
# Pega erros de digitacao/renomeacao que so aparecem em runtime (clique sem
# efeito, sem nenhum erro visivel na tela).
$handlerCalls = [regex]::Matches($html, 'on(?:click|input|change|keydown)="(?:if\([^)]*\))?([a-zA-Z_][a-zA-Z0-9_]*)\(')
$calledFuncs = $handlerCalls | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
$missingFuncs = @()
foreach ($fn in $calledFuncs) {
    if ($html -notmatch "function $fn\(") { $missingFuncs += $fn }
}
if ($calledFuncs.Count -eq 0) {
    Fail "Nenhuma chamada de funcao encontrada em atributos on* (regex pode ter quebrado)"
} elseif ($missingFuncs.Count -eq 0) {
    Pass "Todas as $($calledFuncs.Count) funcoes referenciadas em atributos on* existem"
} else {
    Fail "Funcoes referenciadas em atributos on* mas nao definidas: $($missingFuncs -join ', ')"
}

# 7. Padroes proibidos (funcionalidades removidas)
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