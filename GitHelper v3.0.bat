@echo off
rem ======================================================================
rem  GitHub Team Helper - arquivo unico (.bat) com GUI Windows Forms
rem  Duplo clique para abrir. Requer: Windows + Git instalado.
rem
rem  Como funciona: este .bat le a si proprio, localiza o marcador de
rem  codigo embutido (mais abaixo) e o executa no Windows PowerShell,
rem  que ja vem com o Windows. Nenhum outro arquivo e necessario.
rem  (Esta parte inicial do arquivo e propositalmente ASCII puro.)
rem ======================================================================
setlocal DisableDelayedExpansion
set "GTH_SELF=%~f0"
where powershell.exe >nul 2>&1 || (echo Este programa requer o Windows PowerShell, incluido no Windows. & pause & exit /b 1)
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -Command "try{$t=[IO.File]::ReadAllText($env:GTH_SELF,[Text.Encoding]::UTF8);$i=$t.IndexOf('#PS'+'START');Invoke-Expression $t.Substring($i)}catch{Add-Type -AssemblyName System.Windows.Forms;[void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'GitHub Team Helper')}"
exit /b 0

#PSSTART
# ======================================================================
#  GITHUB TEAM HELPER - codigo da GUI (embutido no .bat)
#  Tudo abaixo desta linha e executado pelo PowerShell/.NET do Windows.
#
#  Organizacao interna (modulos):
#    NUCLEO      estado, preferencias, cores, desenho, botoes, dialogos,
#                log (com sanitizacao), execucao segura do git
#    VALIDACAO   nome de branch, mensagem de commit, URL, pasta
#    SERVICO GIT Svc-* : operacoes individuais, usadas pelos tres modos
#    PINTURA     cards, banner, navegacao, mapa de branches
#    PAGINAS     painel (Single User / Team Easy / Team Dev), branches,
#                comandos, configuracoes
#    FLUXOS      NOVO_PROJETO | CLONAR_REPOSITORIO | ABRIR_PROJETO
#                CONFIGURAR_USUARIO | ATUALIZAR | CRIAR_BRANCH
#                REGISTRAR_ALTERACOES | PUBLICAR_BRANCH | CONCLUIR_TRABALHO
#                SALVAR (Single User) | STATUS | MAIS_COMANDOS | TEAM_DEV
#
#  ATENCAO (PowerShell nao diferencia maiusculas de minusculas nas variaveis):
#  por isso o estado global se chama $App, as fontes $Fnt e os pinceis $Bx.
# ======================================================================
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
try { [Windows.Forms.Application]::EnableVisualStyles() } catch {}
try { [Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false) } catch {}
# Barra de titulo escura (opcional; se falhar, apenas fica a barra padrao)
try { Add-Type -Namespace GTH -Name Dwm -MemberDefinition '[System.Runtime.InteropServices.DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(System.IntPtr hwnd, int attr, ref int val, int size);' } catch {}

# ----------------------------------------------------------------------
# NUCLEO: estado global, cores, fontes, pinceis
# ----------------------------------------------------------------------
$App = @{
    Path = $null; Name = ''; Branch = ''; StatusText = ''; Running = $false; Busy = $false
    Form = $null; LogBox = $null; Lockables = $null; Page = 'start'; LogVisible = $false
    Recent = @(); Settings = @{ Workspace = 'easy'; Logs = 'none'; Remember = 'off' }
    RecentItems = @(); RecentHover = -1; Tip = ''; Activity = ''
    Br = @{ Base = ''; All = @(); Page = 0; Visible = @(); Detail = @{}; Index = @{}; History = @(); Loading = $false; Msg = ''; Hits = @(); Hover = ''; Total = 0 }
    ChoiceCards = @(); HomeMinH = 520; Full = $false
}

function Get-Col([string]$h) { return [Drawing.ColorTranslator]::FromHtml($h) }
function Pt([int]$x, [int]$y) { return (New-Object Drawing.Point($x, $y)) }
function Sz([int]$w, [int]$h) { return (New-Object Drawing.Size($w, $h)) }

$Colors = @{
    bg = (Get-Col '#0a0524'); side = (Get-Col '#0d062e'); panel = (Get-Col '#120a38'); panel2 = (Get-Col '#1c1252')
    card = (Get-Col '#130b3a'); cardH = (Get-Col '#1d1255'); border = (Get-Col '#2e2182'); borderH = (Get-Col '#6a4be8')
    logbg = (Get-Col '#07031a')
    text = (Get-Col '#f1eeff'); muted = (Get-Col '#9a92d0'); white = (Get-Col '#ffffff'); dark = (Get-Col '#0a0524')
    accent = (Get-Col '#b894ff'); info = (Get-Col '#7aa2ff'); success = (Get-Col '#3ddc97')
    warn = (Get-Col '#ffb454'); error = (Get-Col '#ff5c70'); danger = (Get-Col '#ff5c70')
    purple1 = (Get-Col '#7c3aed'); purple2 = (Get-Col '#c04dff'); orange1 = (Get-Col '#ff9a5a'); orange2 = (Get-Col '#ff5f8f')
    yellow = (Get-Col '#ffd400'); red1 = (Get-Col '#e5384f'); red2 = (Get-Col '#ff7a59'); blue1 = (Get-Col '#3a6df0'); blue2 = (Get-Col '#6aa6ff')
    gray1 = (Get-Col '#2a1d6b'); gray2 = (Get-Col '#46359a')
    b_primary = (Get-Col '#7c3aed'); b_primary_h = (Get-Col '#9559ff')
    b_success = (Get-Col '#1fb97a'); b_success_h = (Get-Col '#3ddc97')
    b_danger = (Get-Col '#e5384f'); b_danger_h = (Get-Col '#ff5c70')
    b_warn = (Get-Col '#d9822b'); b_warn_h = (Get-Col '#ff9f45')
    b_secondary = (Get-Col '#2a1d6b'); b_secondary_h = (Get-Col '#3d2c8f')
}
$Fnt = @{
    ui     = (New-Object Drawing.Font('Segoe UI', 9.5))
    bold   = (New-Object Drawing.Font('Segoe UI', 9.5, [Drawing.FontStyle]::Bold))
    h1     = (New-Object Drawing.Font('Segoe UI', 20, [Drawing.FontStyle]::Bold))
    h2     = (New-Object Drawing.Font('Segoe UI', 12, [Drawing.FontStyle]::Bold))
    h3     = (New-Object Drawing.Font('Segoe UI', 13, [Drawing.FontStyle]::Bold))
    small  = (New-Object Drawing.Font('Segoe UI', 8.5))
    smallB = (New-Object Drawing.Font('Segoe UI', 8, [Drawing.FontStyle]::Bold))
    nav    = (New-Object Drawing.Font('Segoe UI', 7.5, [Drawing.FontStyle]::Bold))
    glyph  = (New-Object Drawing.Font('Segoe UI', 16, [Drawing.FontStyle]::Bold))
    mono   = (New-Object Drawing.Font('Consolas', 9.5))
    monoB  = (New-Object Drawing.Font('Consolas', 9.5, [Drawing.FontStyle]::Bold))
    monoS  = (New-Object Drawing.Font('Consolas', 9, [Drawing.FontStyle]::Bold))
}
# Pinceis solidos reutilizaveis
$Bx = @{}
foreach ($k in @('text', 'muted', 'card', 'cardH', 'white', 'dark', 'orange1', 'panel', 'panel2', 'success', 'warn', 'error', 'accent', 'border')) {
    $Bx[$k] = (New-Object Drawing.SolidBrush($Colors[$k]))
}
# Formatos de texto
$SFL = New-Object Drawing.StringFormat; $SFL.Trimming = 'EllipsisCharacter'; $SFL.FormatFlags = 'NoWrap'
$SFW = New-Object Drawing.StringFormat; $SFW.Trimming = 'EllipsisWord'
$SFC = New-Object Drawing.StringFormat; $SFC.Alignment = 'Center'; $SFC.LineAlignment = 'Center'; $SFC.Trimming = 'EllipsisCharacter'; $SFC.FormatFlags = 'NoWrap'
$SFV = New-Object Drawing.StringFormat; $SFV.Alignment = 'Near'; $SFV.LineAlignment = 'Center'; $SFV.Trimming = 'EllipsisCharacter'; $SFV.FormatFlags = 'NoWrap'
$SFR = New-Object Drawing.StringFormat; $SFR.Alignment = 'Far'; $SFR.LineAlignment = 'Center'; $SFR.Trimming = 'EllipsisCharacter'; $SFR.FormatFlags = 'NoWrap'
# Cores das linhas das branches no mapa (uma por ramificacao)
$LaneCols = @((Get-Col '#9b6bff'), (Get-Col '#ff9a5a'), (Get-Col '#3ddc97'), (Get-Col '#ff5fa2'), (Get-Col '#5aa9ff'), (Get-Col '#ffd400'), (Get-Col '#35d6e0'), (Get-Col '#ff6b6b'))
$LanePens = @(); $LaneBrushes = @()
foreach ($lc in $LaneCols) {
    $lp = New-Object Drawing.Pen($lc, 2.6); $lp.StartCap = 'Round'; $lp.EndCap = 'Round'
    $LanePens += $lp
    $LaneBrushes += (New-Object Drawing.SolidBrush($lc))
}
$App.tt = New-Object Windows.Forms.ToolTip

# ----------------------------------------------------------------------
# NUCLEO: ajudantes de desenho (GDI+)
# ----------------------------------------------------------------------
function New-RoundPath([double]$x, [double]$y, [double]$w, [double]$h, [double]$r) {
    $p = New-Object Drawing.Drawing2D.GraphicsPath
    $d = [Math]::Max(1, [Math]::Min($r * 2, [Math]::Min($w, $h)))
    $p.AddArc([single]$x, [single]$y, [single]$d, [single]$d, 180, 90)
    $p.AddArc([single]($x + $w - $d), [single]$y, [single]$d, [single]$d, 270, 90)
    $p.AddArc([single]($x + $w - $d), [single]($y + $h - $d), [single]$d, [single]$d, 0, 90)
    $p.AddArc([single]$x, [single]($y + $h - $d), [single]$d, [single]$d, 90, 90)
    $p.CloseFigure()
    return $p
}
function New-Grad([double]$x, [double]$y, [double]$w, [double]$h, $c1, $c2, [single]$angle = 0) {
    $rc = New-Object Drawing.RectangleF([single]$x, [single]$y, [single][Math]::Max(1, $w), [single][Math]::Max(1, $h))
    return (New-Object Drawing.Drawing2D.LinearGradientBrush($rc, $c1, $c2, $angle))
}
function Draw-Text($g, [string]$t, $font, $brush, [double]$x, [double]$y, [double]$w, [double]$h, $sf) {
    if ($w -lt 2 -or $h -lt 2) { return }
    $rect = New-Object Drawing.RectangleF([single]$x, [single]$y, [single]$w, [single]$h)
    $g.DrawString($t, $font, $brush, $rect, $sf)
}
function DL($g, $pen, $x1, $y1, $x2, $y2) { $g.DrawLine($pen, [single]$x1, [single]$y1, [single]$x2, [single]$y2) }
function DE($g, $pen, $x, $y, $w, $h) { $g.DrawEllipse($pen, [single]$x, [single]$y, [single]$w, [single]$h) }
function DA($g, $pen, $x, $y, $w, $h, $a, $b) { $g.DrawArc($pen, [single]$x, [single]$y, [single]$w, [single]$h, [single]$a, [single]$b) }
function DB($g, $pen, $x1, $y1, $x2, $y2, $x3, $y3, $x4, $y4) {
    $g.DrawBezier($pen, [single]$x1, [single]$y1, [single]$x2, [single]$y2, [single]$x3, [single]$y3, [single]$x4, [single]$y4)
}
function DLs($g, $pen, [double[]]$pts) {
    $n = [int]($pts.Count / 2)
    $arr = New-Object 'System.Drawing.PointF[]' $n
    for ($i = 0; $i -lt $n; $i++) { $arr[$i] = (New-Object Drawing.PointF([single]$pts[2 * $i], [single]$pts[2 * $i + 1])) }
    $g.DrawLines($pen, $arr)
}
function Set-DB($c) {
    try {
        $pi2 = [Windows.Forms.Control].GetProperty('DoubleBuffered', [Reflection.BindingFlags]'Instance,NonPublic')
        $pi2.SetValue($c, $true, $null)
    } catch {}
    $c.Add_Resize({ param($sd, $ev) $sd.Invalidate() })
}
function Set-DarkTitle($form) {
    try {
        $v = 1
        [void][GTH.Dwm]::DwmSetWindowAttribute($form.Handle, 20, [ref]$v, 4)
        [void][GTH.Dwm]::DwmSetWindowAttribute($form.Handle, 19, [ref]$v, 4)
        $cap = 0x24050A   # cor da barra de titulo (Windows 11) = fundo do app, formato BGR
        [void][GTH.Dwm]::DwmSetWindowAttribute($form.Handle, 35, [ref]$cap, 4)
    } catch {}
}

# Icones desenhados por codigo (sem arquivos de imagem)
function Draw-Icon($g, [string]$name, [double]$x, [double]$y, $pen) {
    switch ($name) {
        'home' {
            DLs $g $pen @(($x - 13), ($y + 1), $x, ($y - 11), ($x + 13), ($y + 1))
            DLs $g $pen @(($x - 9), ($y - 2), ($x - 9), ($y + 11), ($x + 9), ($y + 11), ($x + 9), ($y - 2))
            DLs $g $pen @(($x - 3), ($y + 11), ($x - 3), ($y + 5), ($x + 3), ($y + 5), ($x + 3), ($y + 11))
        }
        'graph' {
            DE $g $pen ($x - 12) ($y - 12) 8 8
            DE $g $pen ($x - 12) ($y + 4) 8 8
            DE $g $pen ($x + 4) ($y - 10) 8 8
            DL $g $pen ($x - 8) ($y - 4) ($x - 8) ($y + 4)
            DB $g $pen ($x - 8) ($y + 2) ($x - 8) ($y - 3) ($x + 8) ($y + 1) ($x + 8) ($y - 2)
        }
        'term' {
            $rp = New-RoundPath ($x - 13) ($y - 10) 26 20 4
            $g.DrawPath($pen, $rp); $rp.Dispose()
            DLs $g $pen @(($x - 7), ($y - 4), ($x - 2), $y, ($x - 7), ($y + 4))
            DL $g $pen ($x + 1) ($y + 5) ($x + 8) ($y + 5)
        }
        'cog' {
            DE $g $pen ($x - 5) ($y - 5) 10 10
            for ($a = 0; $a -lt 8; $a++) {
                $rad = $a * [Math]::PI / 4
                DL $g $pen ($x + [Math]::Cos($rad) * 8) ($y + [Math]::Sin($rad) * 8) ($x + [Math]::Cos($rad) * 12) ($y + [Math]::Sin($rad) * 12)
            }
        }
        'user' {
            DE $g $pen ($x - 5) ($y - 12) 10 10
            DA $g $pen ($x - 10) ($y + 1) 20 18 180 180
        }
        'swap' {
            DL $g $pen ($x - 11) ($y - 5) ($x + 11) ($y - 5)
            DLs $g $pen @(($x + 7), ($y - 9), ($x + 11), ($y - 5), ($x + 7), ($y - 1))
            DL $g $pen ($x - 11) ($y + 6) ($x + 11) ($y + 6)
            DLs $g $pen @(($x - 7), ($y + 2), ($x - 11), ($y + 6), ($x - 7), ($y + 10))
        }
        'key' {
            DE $g $pen ($x - 13) ($y - 6) 12 12
            DL $g $pen ($x - 1) $y ($x + 12) $y
            DL $g $pen ($x + 7) $y ($x + 7) ($y + 6)
            DL $g $pen ($x + 12) $y ($x + 12) ($y + 4)
        }
        'exit' {
            DLs $g $pen @(($x + 1), ($y - 11), ($x - 11), ($y - 11), ($x - 11), ($y + 11), ($x + 1), ($y + 11))
            DL $g $pen ($x - 5) $y ($x + 12) $y
            DLs $g $pen @(($x + 8), ($y - 4), ($x + 12), $y, ($x + 8), ($y + 4))
        }
    }
}

# Decoracao do banner: linhas de branches com "commits"
function Draw-Deco($g, [double]$x, [double]$y, [double]$w, [double]$h) {
    $x1 = $x + $w * 0.30; $x2 = $x + $w * 0.55; $x3 = $x + $w * 0.80
    $pP = New-Object Drawing.Pen($Colors.purple2, 3); $pP.StartCap = 'Round'; $pP.EndCap = 'Round'
    $pO = New-Object Drawing.Pen($Colors.orange1, 3); $pO.StartCap = 'Round'; $pO.EndCap = 'Round'
    $pY = New-Object Drawing.Pen($Colors.yellow, 3); $pY.StartCap = 'Round'; $pY.EndCap = 'Round'
    $ya = $y + $h * 0.12; $yb = $y + $h * 0.34; $yc = $y + $h * 0.52; $yd = $y + $h * 0.74; $ye = $y + $h * 0.92
    DL $g $pP $x1 $ya $x1 $ye
    DB $g $pO $x1 $yb $x1 (($yb + $yc) / 2) $x2 (($yb + $yc) / 2) $x2 $yc
    DL $g $pO $x2 $yc $x2 $yd
    DB $g $pO $x2 $yd $x2 (($yd + $ye) / 2) $x1 (($yd + $ye) / 2) $x1 $ye
    DB $g $pY $x1 $ya $x1 (($ya + $yb) / 2) $x3 (($ya + $yb) / 2) $x3 $yb
    DL $g $pY $x3 $yb $x3 $yc
    $bgb = New-Object Drawing.SolidBrush((Get-Col '#1a1050'))
    $pts = @(@($x1, $ya, $Colors.purple2), @($x1, $yb, $Colors.purple2), @($x2, $yc, $Colors.orange1), @($x2, $yd, $Colors.orange1), @($x1, $ye, $Colors.purple2), @($x3, $yb, $Colors.yellow), @($x3, $yc, $Colors.yellow))
    foreach ($q in $pts) {
        $nb = New-Object Drawing.SolidBrush($q[2])
        $g.FillEllipse($bgb, [single]($q[0] - 9), [single]($q[1] - 9), [single]18, [single]18)
        $g.FillEllipse($nb, [single]($q[0] - 6), [single]($q[1] - 6), [single]12, [single]12)
        $nb.Dispose()
    }
    $bgb.Dispose(); $pP.Dispose(); $pO.Dispose(); $pY.Dispose()
}

# Chip (pilula com bolinha colorida). Retorna a largura ocupada (+ espaco)
function Draw-Chip($g, [double]$x, [double]$y, [string]$text, $color) {
    $h = 26
    $tw = $g.MeasureString($text, $Fnt.small).Width
    $w = $tw + 32
    $p = New-RoundPath $x $y $w $h ($h / 2)
    $g.FillPath($Bx.panel2, $p); $p.Dispose()
    $b = New-Object Drawing.SolidBrush($color)
    $g.FillEllipse($b, [single]($x + 11), [single]($y + $h / 2 - 4), [single]8, [single]8); $b.Dispose()
    Draw-Text $g $text $Fnt.small $Bx.text ($x + 25) $y ($w - 28) $h $SFV
    return ($w + 8)
}

# ----------------------------------------------------------------------
# NUCLEO: sanitizacao (nunca mostrar/gravar segredos ou dados pessoais em logs)
# ----------------------------------------------------------------------
function Protect-Text([string]$s) {
    if (-not $s) { return $s }
    $s = [regex]::Replace($s, '(?i)(https?|ssh)://[^/\s:@]+:[^@\s/]+@', '$1://***@')
    $s = [regex]::Replace($s, '(?i)(https?)://[^/\s@]+@', '$1://***@')
    $s = [regex]::Replace($s, '\b(gh[pousr]_[A-Za-z0-9]{16,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_\-]{12,}|xox[abprs]-[A-Za-z0-9\-]{10,}|AKIA[0-9A-Z]{12,}|AIza[0-9A-Za-z_\-]{20,})\b', '***')
    $s = [regex]::Replace($s, '(?i)(authorization|x-access-token|password|passwd|secret|token|api[_-]?key)(\s*[:=]\s*)(\S+)', '$1$2***')
    $s = [regex]::Replace($s, '(?i)([A-Z]:\\Users\\)[^\\\s"'']+', '$1***')
    $ev2 = [Text.RegularExpressions.MatchEvaluator] { param($m) if ($m.Groups[1].Value -ceq 'git') { $m.Value } else { '***@***' } }
    $s = [regex]::Replace($s, '([A-Za-z0-9._%+\-]+)@([A-Za-z0-9\-]+\.[A-Za-z0-9.\-]+)', $ev2)
    return $s
}

# Texto do comando para exibicao: oculta valores de user.name / user.email
function Format-GitDisplay([string[]]$a) {
    $parts = @(); $mask = $false
    foreach ($x in $a) {
        if ($mask) { $parts += '"***"'; $mask = $false; continue }
        if ($x -eq 'user.name' -or $x -eq 'user.email') { $mask = $true }
        if ($x -match '[\s"]') { $parts += ('"' + $x + '"') } else { $parts += $x }
    }
    return (Protect-Text ('git ' + ($parts -join ' ')))
}

# ----------------------------------------------------------------------
# NUCLEO: preferencias (somente valores de lista fixa, sem dados pessoais)
# ----------------------------------------------------------------------
function Get-SettingsPath {
    $d = $env:APPDATA
    if (-not $d) { $d = [Environment]::GetFolderPath('ApplicationData') }
    return (Join-Path (Join-Path $d 'GitHubTeamHelper') 'settings.json')
}
function Load-Settings {
    $App.Settings = @{ Workspace = 'easy'; Logs = 'none'; Remember = 'off' }
    try {
        $p = Get-SettingsPath
        if (Test-Path -LiteralPath $p) {
            $j = (Get-Content -LiteralPath $p -Raw -Encoding UTF8) | ConvertFrom-Json
            if (@('single', 'easy', 'dev') -contains [string]$j.workspace) { $App.Settings.Workspace = [string]$j.workspace }
            if (@('none', 'nostart', 'show') -contains [string]$j.logs) { $App.Settings.Logs = [string]$j.logs }
            if (@('on', 'off') -contains [string]$j.remember) { $App.Settings.Remember = [string]$j.remember }
        }
    } catch {}
}
function Save-Settings {
    try {
        $p = Get-SettingsPath
        $d = Split-Path -Parent $p
        if (-not (Test-Path -LiteralPath $d)) { [void](New-Item -ItemType Directory -Path $d) }
        $json = '{"workspace":"' + $App.Settings.Workspace + '","logs":"' + $App.Settings.Logs + '","remember":"' + $App.Settings.Remember + '"}'
        [IO.File]::WriteAllText($p, $json, (New-Object Text.UTF8Encoding($false)))
    } catch { Write-Info 'Não foi possível salvar as preferências neste computador.' }
}

# ----------------------------------------------------------------------
# NUCLEO: botoes, rotulos e layouts
# ----------------------------------------------------------------------
function New-Btn([string]$Text, [string]$Style = 'secondary', [int]$W = 120, [int]$H = 36) {
    $b = New-Object Windows.Forms.Button
    $b.Text = $Text
    $b.Size = (Sz $W $H)
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderSize = 0
    $b.UseVisualStyleBackColor = $false
    $b.BackColor = $Colors['b_' + $Style]
    $b.ForeColor = $Colors.white
    $b.FlatAppearance.MouseOverBackColor = $Colors['b_' + $Style + '_h']
    $b.FlatAppearance.MouseDownBackColor = $Colors['b_' + $Style + '_h']
    $b.Font = $Fnt.bold
    $b.Cursor = [Windows.Forms.Cursors]::Hand
    $b.UseMnemonic = $false
    return $b
}
function New-Label([string]$Text, $Font, $Color, [int]$X, [int]$Y, [int]$W, [int]$H) {
    $l = New-Object Windows.Forms.Label
    $l.Text = $Text; $l.Font = $Font; $l.ForeColor = $Color; $l.BackColor = [Drawing.Color]::Transparent
    $l.Location = (Pt $X $Y); $l.Size = (Sz $W $H)
    $l.AutoSize = $false; $l.UseMnemonic = $false; $l.AutoEllipsis = $true
    return $l
}
function New-TL([int]$cols, [int]$rows) {
    $t = New-Object Windows.Forms.TableLayoutPanel
    $t.Dock = 'Fill'; $t.ColumnCount = $cols; $t.RowCount = $rows
    $t.Margin = (New-Object Windows.Forms.Padding(0)); $t.BackColor = $Colors.bg
    return $t
}
function Get-SizeType([string]$kind) {
    if ($kind -eq 'A') { return [Windows.Forms.SizeType]::Absolute }
    if ($kind -eq 'S') { return [Windows.Forms.SizeType]::AutoSize }
    return [Windows.Forms.SizeType]::Percent
}
function Add-Col($tl, [string]$kind, [double]$v) { [void]$tl.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle((Get-SizeType $kind), [single]$v))) }
function Add-Row($tl, [string]$kind, [double]$v) { [void]$tl.RowStyles.Add((New-Object Windows.Forms.RowStyle((Get-SizeType $kind), [single]$v))) }
function Set-Locked([bool]$lock) {
    if (-not $App.Lockables) { return }
    foreach ($c in $App.Lockables) { $c.Enabled = (-not $lock) }
}

# Texto de atividade no cabecalho (feedback de "carregando")
function Get-PageSub([string]$name) {
    switch ($name) {
        'start'    { return 'Escolha como deseja começar' }
        'home'     { return [string]$App.Path }
        'graph'    { return 'Main como linha principal e até 10 ramificações; o destaque marca a branch atual' }
        'cmds'     { return 'Cada card executa um único comando Git, com confirmação quando há risco' }
        'settings' { return 'Preferências salvas apenas neste computador, sem dados pessoais' }
    }
    return ''
}
function Set-Activity([string]$text) {
    $App.Activity = $text
    if ($App.footer) { $App.footer.Invalidate() }
    if (-not $App.hSub) { return }
    if ($text) { $App.hSub.Text = $text; $App.hSub.ForeColor = $Colors.orange1 }
    else { $App.hSub.ForeColor = $Colors.muted; $App.hSub.Text = (Get-PageSub $App.Page) }
}

# ----------------------------------------------------------------------
# VALIDACAO DE ENTRADAS (nada digitado vira comando: sempre argumento separado)
# ----------------------------------------------------------------------
function Test-FolderName([string]$n) {
    if (-not $n) { return 'Informe um nome.' }
    if ($n -ne $n.Trim() -or $n.EndsWith('.')) { return 'O nome não pode terminar com ponto nem começar/terminar com espaço.' }
    if ($n.Length -gt 100) { return 'O nome é muito longo (máximo de 100 caracteres).' }
    if ($n.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0) { return 'O nome contém caracteres não permitidos: \ / : * ? " < > |' }
    if ($n -match '^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\..*)?$') { return 'Esse nome é reservado pelo Windows.' }
    return $null
}
function Get-RepoUrlError([string]$u) {
    if (-not $u) { return 'Informe a URL do repositório.' }
    if ($u.Length -gt 500) { return 'A URL é muito longa.' }
    if ($u -notmatch '^(https?://|ssh://|git@)\S+$') { return "Use uma URL como:`nhttps://github.com/usuario/projeto.git" }
    if ($u -match '(?i)^(https?|ssh)://[^/\s]*@') { return "Não coloque usuário, senha ou token dentro da URL.`n`nO login é feito com segurança pelo Git (Git Credential Manager) quando necessário." }
    return $null
}
function Get-CommitMessageError([string]$m) {
    if (-not $m -or -not $m.Trim()) { return 'Escreva uma mensagem para o commit.' }
    if ($m.Length -gt 500) { return 'A mensagem é muito longa (máximo de 500 caracteres).' }
    if ($m -match '[\x00-\x08\x0b\x0c\x0e-\x1f]') { return 'A mensagem contém caracteres de controle não permitidos.' }
    return $null
}
# Defesa em profundidade: nomes de branch/ref nunca podem comecar com '-' (virar opcao) nem ter espacos
function Assert-SafeRef([string]$b) {
    if ($b -notmatch '^[^\-\s\x00-\x1f][^\s\x00-\x1f]*$') { throw "Nome de branch inválido: $b" }
}

# ----------------------------------------------------------------------
# LOG DE COMANDOS (area de log da GUI) - sanitizado, limitado e opcional
# ----------------------------------------------------------------------
function Write-Log([string]$t, [string]$c = 'text', [bool]$b = $false) {
    $rt = $App.LogBox
    if (-not $rt -or -not $App.LogVisible) { return }   # log oculto: nada e escrito
    $t = Protect-Text $t
    if ($rt.TextLength -gt 60000) {                       # evita crescer indefinidamente
        $cut = $rt.Text.IndexOf("`n", 20000)
        if ($cut -lt 0) { $cut = 20000 }
        $rt.Select(0, $cut + 1); $rt.SelectedText = ''
    }
    $rt.SelectionStart = $rt.TextLength; $rt.SelectionLength = 0
    $rt.SelectionColor = $Colors[$c]
    if ($b) { $rt.SelectionFont = $Fnt.monoB } else { $rt.SelectionFont = $Fnt.mono }
    $rt.AppendText((($t -replace "`r?`n", "`r`n") + "`r`n"))
    $rt.SelectionStart = $rt.TextLength
    $rt.ScrollToCaret()
}
function Write-Info([string]$t) { Write-Log ('i  ' + $t) 'info' }

function Write-GitResult($res) {
    if ($res.Text) { Write-Log 'RESULTADO' 'muted' $true; Write-Log $res.Text 'text' }
    Write-Log 'STATUS' 'muted' $true
    if ($res.Ok) { Write-Log ([string][char]0x2713 + ' Operação concluída') 'success' }
    else { Write-Log ([string][char]0x00D7 + ' Falhou (código ' + $res.ExitCode + ')') 'error' }
    Write-Log ''
}

# ----------------------------------------------------------------------
# EXECUCAO DO GIT (sem passar pelo CMD: argumentos separados e escapados)
# ----------------------------------------------------------------------
function ConvertTo-WinArg([string]$a) {
    if ($a.Length -eq 0) { return '""' }
    if ($a -notmatch '[\s"]') { return $a }
    $s = [regex]::Replace($a, '(\\*)"', '$1$1\"')
    $s = [regex]::Replace($s, '(\\+)$', '$1$1')
    return ('"' + $s + '"')
}

# Executa "git <args>" e devolve objeto {Ok, ExitCode, Out, Err, Text, Display}
# Out/Err = saida original (para o programa interpretar); Text/Display = versoes sanitizadas (para mostrar)
# -Quiet: nao escreve no log nem mostra atividade (consultas internas)
function Invoke-Git {
    param([string[]]$GitArgs, [string]$WorkDir = '', [switch]$Quiet)
    if (-not $WorkDir) { if ($App.Path) { $WorkDir = $App.Path } else { $WorkDir = (Get-Location).Path } }
    $disp = Format-GitDisplay $GitArgs
    if (-not $Quiet) { Write-Log 'COMANDO' 'muted' $true; Write-Log ('> ' + $disp) 'accent' }

    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = 'git'
    $psi.Arguments = (($GitArgs | ForEach-Object { ConvertTo-WinArg $_ }) -join ' ')
    $psi.WorkingDirectory = $WorkDir
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [Text.Encoding]::UTF8
    $psi.EnvironmentVariables['GIT_TERMINAL_PROMPT'] = '0'   # nunca travar esperando prompt no terminal
    $psi.EnvironmentVariables['GIT_MERGE_AUTOEDIT'] = 'no'   # merge nao abre editor de texto

    try {
        $p = [Diagnostics.Process]::Start($psi)
    } catch {
        $m = Protect-Text $_.Exception.Message
        $res = [pscustomobject]@{ Ok = $false; ExitCode = -1; Out = ''; Err = $m; Text = $m; Display = $disp }
        if (-not $Quiet) { Write-GitResult $res }
        return $res
    }

    $App.Running = $true
    $lock = $false
    if (-not $Quiet -and $App.Lockables) {
        $lock = $true; Set-Locked $true; $App.Form.UseWaitCursor = $true
        Set-Activity ('Executando: ' + $disp + ' ...')
    }
    try {
        $oT = $p.StandardOutput.ReadToEndAsync()
        $eT = $p.StandardError.ReadToEndAsync()
        if ($Quiet) {
            $p.WaitForExit()
        } else {
            # mantem a janela viva (sem congelar) enquanto o Git trabalha
            while (-not $p.HasExited) { [Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 25 }
            $p.WaitForExit()
        }
        $out = ([string]$oT.Result).TrimEnd()
        $err = ([string]$eT.Result).TrimEnd()
        $code = $p.ExitCode
    } finally {
        $App.Running = $false
        if ($lock) { Set-Locked $false; $App.Form.UseWaitCursor = $false; Set-Activity '' }
        $p.Dispose()
    }
    $txt = Protect-Text ((@($out, $err) | Where-Object { $_ }) -join "`n")
    $res = [pscustomobject]@{ Ok = ($code -eq 0); ExitCode = $code; Out = $out; Err = $err; Text = $txt; Display = $disp }
    if (-not $Quiet) { Write-GitResult $res }
    return $res
}

# ----------------------------------------------------------------------
# CONFIRMACOES: dialogos graficos (mensagem, confirmacao, entrada de texto, lista)
# ----------------------------------------------------------------------
function New-BtnDef([string]$Text, [string]$Result, [string]$Style = 'secondary') {
    return @{ Text = $Text; Result = $Result; Style = $Style }
}
function Test-InputOk($tb) {
    $cfg = $tb.Tag
    switch ($cfg.Mode) {
        'text'  { return ($tb.Text.Trim().Length -gt 0) }
        'exact' { return ($tb.Text -ceq $cfg.Exact) }   # comparacao exata, sensivel a maiusculas
        default { return $true }
    }
}
# Posiciona/limita dialogos para caberem em telas pequenas
function Fit-Dialog($dlg) {
    $wa = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    if ($dlg.Height -gt ($wa.Height - 30)) { $dlg.AutoScroll = $true; $dlg.Height = $wa.Height - 40 }
}

# Dialogo generico. Retorna objeto com .Result (resultado do botao) e .Text (campo de entrada)
function Show-Dialog {
    param(
        [string]$Title, [string]$Message, [string]$Kind = 'info', [object[]]$Buttons,
        [string]$InputLabel = '', [string]$InputDefault = '', [string]$Require = 'none', [string]$Exact = ''
    )
    if (-not $Buttons -or $Buttons.Count -eq 0) { $Buttons = @((New-BtnDef 'Fechar' 'ok' 'primary')) }
    $Message = ($Message -replace "`r?`n", "`r`n")
    if ($Message.Length -gt 2200) { $Message = $Message.Substring(0, 2200) + "`r`n[...]" }
    $accent = $Colors[$Kind]
    $glyphs = @{ info = 'i'; success = ([string][char]0x2713); warn = '!'; error = ([string][char]0x00D7); danger = '!' }

    $dlg = New-Object Windows.Forms.Form
    $dlg.Text = 'GitHub Team Helper'
    $dlg.FormBorderStyle = 'FixedDialog'; $dlg.StartPosition = 'CenterParent'
    $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false; $dlg.ShowInTaskbar = $false
    $dlg.BackColor = $Colors.bg; $dlg.ForeColor = $Colors.text; $dlg.Font = $Fnt.ui
    $dlg.Tag = 'cancel'
    $dlg.Add_HandleCreated({ param($sd, $ev) Set-DarkTitle $sd })

    $W = 560; $tx = 84; $tw = $W - $tx - 28
    $strip = New-Object Windows.Forms.Panel
    $strip.BackColor = $accent; $strip.Location = (Pt 0 0); $strip.Size = (Sz $W 4)
    $dlg.Controls.Add($strip)

    $ic = New-Object Windows.Forms.Label
    $ic.Text = $glyphs[$Kind]; $ic.Font = $Fnt.glyph; $ic.TextAlign = 'MiddleCenter'
    $ic.BackColor = $accent; $ic.ForeColor = $Colors.dark
    $ic.Location = (Pt 26 26); $ic.Size = (Sz 40 40)
    $gp = New-Object Drawing.Drawing2D.GraphicsPath
    $gp.AddEllipse(0, 0, 40, 40)
    $ic.Region = (New-Object Drawing.Region($gp))
    $dlg.Controls.Add($ic)

    $y = 24
    $dlg.Controls.Add((New-Label $Title $Fnt.h2 $Colors.text $tx $y $tw 28))
    $y += 36
    $meas = [Windows.Forms.TextRenderer]::MeasureText($Message, $Fnt.ui, (Sz $tw 0), [Windows.Forms.TextFormatFlags]::WordBreak)
    $mh = [Math]::Min($meas.Height + 12, 380)
    $lm = New-Label $Message $Fnt.ui $Colors.text $tx $y $tw $mh
    $lm.AutoEllipsis = $false
    $dlg.Controls.Add($lm)
    $y += $mh + 10

    $tb = $null
    if ($InputLabel) {
        $dlg.Controls.Add((New-Label $InputLabel $Fnt.small $Colors.muted $tx $y $tw 18))
        $y += 22
        $tb = New-Object Windows.Forms.TextBox
        $tb.Name = 'inp'; $tb.Location = (Pt $tx $y); $tb.Width = $tw
        $tb.BackColor = $Colors.panel2; $tb.ForeColor = $Colors.text; $tb.BorderStyle = 'FixedSingle'
        $tb.Font = $Fnt.ui; $tb.Text = $InputDefault; $tb.MaxLength = 500
        $tb.Tag = @{ Mode = $Require; Exact = $Exact }
        $dlg.Controls.Add($tb)
        $y += 40
    }
    $y += 8

    # Botoes alinhados a direita; se faltar espaco, quebram para a linha de baixo (nunca sobrepoem)
    $btnRight = $W - 24
    $bxnX = $btnRight
    $okBtn = $null; $cancelBtn = $null
    $rowY = $y
    for ($i = $Buttons.Count - 1; $i -ge 0; $i--) {
        $bd = $Buttons[$i]
        $bw = [Math]::Max(110, [int]([Windows.Forms.TextRenderer]::MeasureText($bd.Text, $Fnt.bold).Width + 40))
        if (($bxnX - $bw) -lt ($tx - 20)) { $bxnX = $btnRight; $rowY += 46 }
        $b = New-Btn $bd.Text $bd.Style $bw 38
        $bxnX -= $bw
        $b.Location = (Pt $bxnX $rowY)
        $bxnX -= 10
        $b.Tag = $bd.Result
        $b.Add_Click({ param($sd, $ev) $fm = $sd.FindForm(); $fm.Tag = $sd.Tag; $fm.Close() })
        if ($bd.Result -eq 'ok') { $b.Name = 'okbtn'; $okBtn = $b }
        if ($bd.Result -eq 'cancel') { $cancelBtn = $b }
        $dlg.Controls.Add($b)
    }
    $y = $rowY
    if ($tb -and $okBtn) {
        $okBtn.Enabled = (Test-InputOk $tb)
        $tb.Add_TextChanged({ param($sd, $ev) $o = $sd.FindForm().Controls['okbtn']; if ($o) { $o.Enabled = (Test-InputOk $sd) } })
    }
    if ($okBtn) { $dlg.AcceptButton = $okBtn }
    if ($cancelBtn) { $dlg.CancelButton = $cancelBtn } elseif ($okBtn) { $dlg.CancelButton = $okBtn }
    $dlg.Add_Shown({ param($sd, $ev) $t = $sd.Controls['inp']; if ($t) { [void]$t.Focus(); $t.SelectAll() } })
    $dlg.ClientSize = (Sz $W ($y + 38 + 24))
    Fit-Dialog $dlg

    if ($App.Form -and $App.Form.Visible) { [void]$dlg.ShowDialog($App.Form) } else { [void]$dlg.ShowDialog() }
    $txt = ''
    if ($tb) { $txt = $tb.Text }
    $res = [pscustomobject]@{ Result = [string]$dlg.Tag; Text = $txt }
    $dlg.Dispose()
    return $res
}

function Show-Msg([string]$Title, [string]$Text, [string]$Kind = 'info') {
    [void](Show-Dialog -Title $Title -Message $Text -Kind $Kind -Buttons @((New-BtnDef 'Fechar' 'ok' 'primary')))
}

# Confirmacao Cancelar/Continuar. Retorna $true somente se o usuario confirmar.
function Confirm-Action([string]$Title, [string]$Text, [string]$OkText = 'Continuar', [string]$Kind = 'warn', [string]$CancelText = 'Cancelar') {
    $style = 'primary'
    if ($Kind -eq 'danger' -or $Kind -eq 'error') { $style = 'danger' } elseif ($Kind -eq 'warn') { $style = 'warn' }
    $r = Show-Dialog -Title $Title -Message $Text -Kind $Kind -Buttons @((New-BtnDef $CancelText 'cancel' 'secondary'), (New-BtnDef $OkText 'ok' $style))
    return ($r.Result -eq 'ok')
}

# Pede um texto (obrigatorio). Retorna o texto ou $null se cancelado.
function Ask-Text([string]$Title, [string]$Text, [string]$Label, [string]$Default = '', [string]$OkText = 'Continuar') {
    $r = Show-Dialog -Title $Title -Message $Text -Kind 'info' -InputLabel $Label -InputDefault $Default -Require 'text' -Buttons @((New-BtnDef 'Cancelar' 'cancel' 'secondary'), (New-BtnDef $OkText 'ok' 'primary'))
    if ($r.Result -ne 'ok') { return $null }
    return $r.Text.Trim()
}

# Mensagem de commit validada (repete ate ser valida ou cancelar)
function Ask-CommitMessage([string]$Text, [string]$OkText = 'Continuar') {
    $default = ''
    while ($true) {
        $m = Ask-Text 'Mensagem do commit' $Text 'Mensagem do commit:' $default $OkText
        if ($null -eq $m) { return $null }
        $e = Get-CommitMessageError $m
        if (-not $e) { return $m }
        Show-Msg 'Mensagem inválida' $e 'error'
        $default = $m
    }
}

# Lista de opcoes (ex.: branches). Retorna o item escolhido ou $null.
function Select-FromList([string]$Title, [string]$Text, [string[]]$Items, [string]$Selected = '', [string]$OkText = 'Selecionar', [string]$OkStyle = 'primary') {
    $dlg = New-Object Windows.Forms.Form
    $dlg.Text = 'GitHub Team Helper'
    $dlg.FormBorderStyle = 'FixedDialog'; $dlg.StartPosition = 'CenterParent'
    $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false; $dlg.ShowInTaskbar = $false
    $dlg.BackColor = $Colors.bg; $dlg.ForeColor = $Colors.text; $dlg.Font = $Fnt.ui
    $dlg.ClientSize = (Sz 540 456); $dlg.Tag = $null
    $dlg.Add_HandleCreated({ param($sd, $ev) Set-DarkTitle $sd })

    $strip = New-Object Windows.Forms.Panel
    $strip.BackColor = $Colors.purple2; $strip.Location = (Pt 0 0); $strip.Size = (Sz 540 4)
    $dlg.Controls.Add($strip)
    $dlg.Controls.Add((New-Label $Title $Fnt.h2 $Colors.text 28 22 484 28))
    $lt = New-Label $Text $Fnt.ui $Colors.muted 28 58 484 72
    $lt.AutoEllipsis = $false
    $dlg.Controls.Add($lt)

    $lb = New-Object Windows.Forms.ListBox
    $lb.Name = 'lst'; $lb.Location = (Pt 28 136); $lb.Size = (Sz 484 240)
    $lb.BackColor = $Colors.panel2; $lb.ForeColor = $Colors.text; $lb.BorderStyle = 'None'
    $lb.Font = (New-Object Drawing.Font('Segoe UI', 11)); $lb.IntegralHeight = $false
    $lb.HorizontalScrollbar = $true
    foreach ($it in $Items) { [void]$lb.Items.Add($it) }
    $dlg.Controls.Add($lb)

    $bo = New-Btn $OkText $OkStyle 170 38
    $bo.Name = 'okbtn'; $bo.Location = (Pt 342 396)
    $bc = New-Btn 'Cancelar' 'secondary' 120 38
    $bc.Location = (Pt 212 396)
    $bo.Add_Click({ param($sd, $ev) $fm = $sd.FindForm(); $l = $fm.Controls['lst']; if ($l.SelectedItem) { $fm.Tag = [string]$l.SelectedItem; $fm.Close() } })
    $bc.Add_Click({ param($sd, $ev) $sd.FindForm().Close() })
    $lb.Add_DoubleClick({ param($sd, $ev) if ($sd.SelectedItem) { $fm = $sd.FindForm(); $fm.Tag = [string]$sd.SelectedItem; $fm.Close() } })
    $dlg.Controls.Add($bo); $dlg.Controls.Add($bc)

    $ix = $lb.Items.IndexOf($Selected)
    if ($ix -ge 0) { $lb.SelectedIndex = $ix } elseif ($lb.Items.Count -gt 0) { $lb.SelectedIndex = 0 }
    $bo.Enabled = ($lb.SelectedIndex -ge 0)
    $lb.Add_SelectedIndexChanged({ param($sd, $ev) $o = $sd.FindForm().Controls['okbtn']; if ($o) { $o.Enabled = ($sd.SelectedIndex -ge 0) } })
    $dlg.AcceptButton = $bo; $dlg.CancelButton = $bc
    Fit-Dialog $dlg

    if ($App.Form -and $App.Form.Visible) { [void]$dlg.ShowDialog($App.Form) } else { [void]$dlg.ShowDialog() }
    $res = $null
    if ($null -ne $dlg.Tag) { $res = [string]$dlg.Tag }
    $dlg.Dispose()
    return $res
}

function Select-Folder([string]$Desc, [string]$Start = '', [bool]$AllowNew = $true) {
    $d = New-Object Windows.Forms.FolderBrowserDialog
    $d.Description = $Desc; $d.ShowNewFolderButton = $AllowNew
    if ($Start -and (Test-Path -LiteralPath $Start)) { $d.SelectedPath = $Start }
    $r = $d.ShowDialog($App.Form)
    $p = $d.SelectedPath
    $d.Dispose()
    if ($r -eq 'OK' -and $p) { return $p }
    return $null
}

# ----------------------------------------------------------------------
# TRATAMENTO_DE_ERROS
# ----------------------------------------------------------------------
# Explica (o que aconteceu / por que / o que fazer) os erros mais comuns do Git
function Get-ErrorHint([string]$t, [int]$code = 0) {
    if ($code -eq -1 -and $t -match '(?i)cannot find|não pode encontrar|nao pode encontrar|not recognized|win32') {
        return "O que aconteceu: o Git não foi encontrado neste computador.`nO que fazer: instale o Git (git-scm.com) e abra o programa de novo."
    }
    if ($t -match '(?i)not a git repository|não é um repositório') {
        return "O que aconteceu: a pasta não é (ou deixou de ser) um repositório Git.`nO que fazer: verifique se a pasta ainda existe ou abra/crie outro projeto."
    }
    if ($t -match '(?i)could not resolve host|unable to access|failed to connect|timed out|network is unreachable|could not connect|connection (refused|reset)') {
        return "O que aconteceu: não foi possível falar com o GitHub (sem internet ou servidor indisponível).`nO que fazer: verifique sua conexão e tente novamente. Nada foi alterado no GitHub."
    }
    if ($t -match '(?i)authentication failed|could not read username|terminal prompts disabled|permission denied|error: 403|http 403|invalid username or password') {
        return "O que aconteceu: o GitHub não aceitou o seu login ou você não tem permissão no repositório.`nO que fazer: entre novamente na sua conta (a janela do Git Credential Manager aparece quando necessário) ou peça acesso ao repositório."
    }
    if ($t -match '(?i)repository not found|does not appear to be a git repository|remote origin already exists') {
        return "O que aconteceu: o endereço do repositório remoto não existe ou já está configurado.`nO que fazer: confira a URL (Mais comandos > Ver remotos)."
    }
    if ($t -match '(?i)rejected|non-fast-forward|fetch first|failed to push some refs') {
        return "O que aconteceu: o GitHub recusou o envio porque ele tem commits que você ainda não tem.`nO que fazer: atualize o projeto (pull) primeiro, resolva eventuais conflitos e envie de novo. Nada foi forçado."
    }
    if ($t -match '(?i)conflict|automatic merge failed') {
        return "O que aconteceu: o Git encontrou conflitos, isto é, as mesmas linhas foram alteradas dos dois lados.`nO que fazer: abra os arquivos em conflito, escolha o texto correto, depois use Registrar Alterações. Para desistir do merge, rode 'git merge --abort' em um terminal."
    }
    if ($t -match '(?i)would be overwritten|please commit your changes or stash') {
        return "O que aconteceu: existem alterações locais que seriam sobrescritas.`nO que fazer: registre as alterações (commit) ou guarde-as (git stash) antes de continuar. Nada foi apagado."
    }
    if ($t -match '(?i)already exists') {
        return "O que aconteceu: já existe algo com esse nome (branch ou remoto).`nO que fazer: escolha outro nome ou use a opção de trocar de branch."
    }
    if ($t -match '(?i)did not match any|invalid reference|not a valid object name|unknown revision|couldn.t find remote ref') {
        return "O que aconteceu: a branch informada não existe.`nO que fazer: confira o nome em Mais comandos > Listar branches. Se for do GitHub, rode Buscar novidades (fetch) antes."
    }
    if ($t -match '(?i)unrelated histories') {
        return "O que aconteceu: os dois históricos não têm origem em comum.`nO que fazer: normalmente indica dois repositórios diferentes. Nada foi alterado."
    }
    if ($t -match "(?i)no upstream|has no upstream branch|no tracking information") {
        return "O que aconteceu: a branch ainda não está ligada a uma branch do GitHub.`nO que fazer: envie a branch pelo menos uma vez (Publicar/Push)."
    }
    if ($t -match '(?i)index\.lock|another git process') {
        return "O que aconteceu: outro processo do Git parece estar rodando neste projeto.`nO que fazer: aguarde terminar e tente de novo. Se não houver outro Git aberto, remova o arquivo .git/index.lock manualmente."
    }
    return ''
}

function Show-GitError($r, [string]$Extra = '') {
    $reason = $r.Text
    if (-not $reason) { $reason = '(o Git não retornou mensagem; código ' + $r.ExitCode + ')' }
    if ($reason.Length -gt 600) { $reason = $reason.Substring(0, 600) + ' [...]' }
    $hint = Get-ErrorHint $r.Text $r.ExitCode
    $m = "O comando não pôde ser executado.`n`nComando:`n" + $r.Display + "`n`nMotivo:`n" + $reason
    if ($hint) { $m += "`n`n" + $hint }
    if ($Extra) { $m += "`n`n" + $Extra }
    Show-Msg 'Erro' $m 'error'
}

# Executa uma acao protegendo a GUI: impede cliques repetidos/simultaneos e captura excecoes
function Guard([string]$fn, [string]$arg = '') {
    if ($App.Running -or $App.Busy) { return }
    $App.Busy = $true
    try { if ($arg) { & $fn $arg } else { & $fn } }
    catch {
        $m = Protect-Text $_.Exception.Message
        Write-Log ([string][char]0x00D7 + ' Erro interno: ' + $m) 'error'
        Show-Msg 'Erro inesperado' ("Ocorreu um erro inesperado na ferramenta:`n`n" + $m) 'error'
    }
    finally { $App.Busy = $false }
}

# ----------------------------------------------------------------------
# FUNCOES AUXILIARES DE REPOSITORIO (consultas, sem alterar nada)
# ----------------------------------------------------------------------
function Get-Changes([switch]$TrackedOnly) {
    $a = @('status', '--porcelain')
    if ($TrackedOnly) { $a += '--untracked-files=no' }
    $r = Invoke-Git $a -Quiet
    if (-not $r.Ok -or -not $r.Out.Trim()) { return @() }
    return @($r.Out -split '\r?\n' | Where-Object { $_.Trim() })
}
function Format-Changes($lines, [int]$Max = 8) {
    $n = @($lines).Count
    $show = @($lines | Select-Object -First $Max)
    $t = ($show -join "`n")
    if ($n -gt $Max) { $t += "`n... e mais $($n - $Max) item(ns)" }
    return $t
}
function Get-ConflictFiles {
    $r = Invoke-Git @('diff', '--name-only', '--diff-filter=U') -Quiet
    if ($r.Ok -and $r.Out) { return @($r.Out -split '\r?\n' | Where-Object { $_ }) }
    return @()
}
function Test-Origin {
    $r = Invoke-Git @('remote') -Quiet
    return ($r.Ok -and ((@($r.Out -split '\r?\n')) -contains 'origin'))
}
function Test-LocalMain { return (Invoke-Git @('rev-parse', '--verify', '-q', 'refs/heads/main') -Quiet).Ok }
function Test-Merging { return (Invoke-Git @('rev-parse', '-q', '--verify', 'MERGE_HEAD') -Quiet).Ok }
function Test-LocalBranchExists([string]$n) { return (Invoke-Git @('show-ref', '--verify', '--quiet', ('refs/heads/' + $n)) -Quiet).Ok }
function Test-HasUpstream([string]$branch = '') {
    $ref = '@{u}'
    if ($branch) { $ref = $branch + '@{u}' }
    return (Invoke-Git @('rev-parse', '--abbrev-ref', '--symbolic-full-name', $ref) -Quiet).Ok
}
function Get-GitDirPath {
    $r = Invoke-Git @('rev-parse', '--git-dir') -Quiet
    if (-not $r.Ok) { return $null }
    $d = $r.Out.Trim()
    if (-not [IO.Path]::IsPathRooted($d)) { $d = Join-Path $App.Path $d }
    return $d
}
# Detecta estados "no meio de" (merge, rebase, cherry-pick, revert). Retorna descricao ou $null
function Get-RepoBusyState {
    if (Test-Merging) { return 'um merge em andamento' }
    $gd = Get-GitDirPath
    if ($gd) {
        if ((Test-Path -LiteralPath (Join-Path $gd 'rebase-merge')) -or (Test-Path -LiteralPath (Join-Path $gd 'rebase-apply'))) { return 'um rebase em andamento' }
        if (Test-Path -LiteralPath (Join-Path $gd 'CHERRY_PICK_HEAD')) { return 'um cherry-pick em andamento' }
        if (Test-Path -LiteralPath (Join-Path $gd 'REVERT_HEAD')) { return 'um revert em andamento' }
    }
    return $null
}
function Get-CurrentBranchName {
    $b = Invoke-Git @('branch', '--show-current') -Quiet
    $name = ''
    if ($b.Ok) { $name = $b.Out.Trim() }
    if (-not $name) {
        $b2 = Invoke-Git @('symbolic-ref', '--short', '-q', 'HEAD') -Quiet
        if ($b2.Ok) { $name = $b2.Out.Trim() }
    }
    if (-not $name) { $name = '(HEAD destacado)' }
    $App.Branch = $name
    return $name
}
# Verificacoes comuns antes de operacoes importantes (mostra o erro e retorna $false se algo impede)
function Test-RepoReady {
    param([switch]$NeedOrigin, [switch]$NeedBranch, [switch]$NoBusy, [string]$Title = 'Operação')
    if (-not $App.Path) { return $false }
    $chk = Invoke-Git @('rev-parse', '--is-inside-work-tree') -Quiet
    if (-not $chk.Ok) {
        Show-Msg $Title "Esta pasta não parece mais ser um repositório Git.`n`nVerifique se a pasta ainda existe e não foi movida ou apagada.`n`nPasta:`n$($App.Path)" 'error'
        return $false
    }
    $cur = Get-CurrentBranchName
    if ($NeedBranch -and $cur -eq '(HEAD destacado)') {
        Show-Msg $Title "Você está sem branch (HEAD destacado).`n`nVolte para uma branch (Mais comandos > Trocar de branch) antes de continuar." 'error'
        return $false
    }
    if ($NoBusy) {
        $busy = Get-RepoBusyState
        if ($busy) {
            Show-Msg $Title "O repositório está com $busy.`n`nFinalize ou desfaça essa operação antes de continuar (resolva os conflitos e use Registrar Alterações, ou rode 'git merge --abort' em um terminal)." 'warn'
            return $false
        }
    }
    if ($NeedOrigin -and -not (Test-Origin)) {
        Show-Msg $Title "Este projeto não tem um remoto chamado 'origin'.`n`nConecte-o ao GitHub (git remote add origin <URL>) antes de continuar." 'warn'
        return $false
    }
    return $true
}
# Nome de branch valido? Retorna mensagem de erro ou $null
function Get-BranchNameError([string]$n) {
    if (-not $n) { return 'Informe o nome da branch.' }
    if ($n.Length -gt 200) { return 'O nome é muito longo (máximo de 200 caracteres).' }
    if ($n -match '[\x00-\x1f\x7f\s]') { return 'O nome não pode ter espaços nem caracteres de controle.' }
    if ($n.StartsWith('-') -or $n.StartsWith('/')) { return "O nome não pode começar com '-' ou '/'." }
    if ($n -match '@\{' -or $n -ceq 'HEAD') { return "Esse nome não pode ser usado como branch." }
    $v = Invoke-Git @('check-ref-format', '--branch', $n) -Quiet
    if (-not $v.Ok) { return "O Git não aceita esse nome de branch.`n`nEvite espaços e os caracteres ~ ^ : ? * [ \ além de '..'." }
    return $null
}
function Resolve-RepoRoot([string]$dir) {
    $r = Invoke-Git @('rev-parse', '--show-toplevel') -WorkDir $dir -Quiet
    if (-not $r.Ok -or -not $r.Out.Trim()) { return $null }
    return (($r.Out.Trim()) -replace '/', '\')
}
# Executa "git branch" (visivel no log) e devolve @{Items; Current}
function Get-BranchList {
    $r = Invoke-Git @('branch')
    if (-not $r.Ok) { Show-GitError $r; return $null }
    $items = @(); $cur = ''
    foreach ($ln in ($r.Out -split '\r?\n')) {
        if (-not $ln.Trim()) { continue }
        $isCur = $ln.StartsWith('*')
        $name = $ln.Substring(2).Trim()
        if ($name.StartsWith('(')) { continue }   # "(HEAD destacado em ...)"
        $items += $name
        if ($isCur) { $cur = $name }
    }
    return @{ Items = $items; Current = $cur }
}
function Ensure-GitUser {
    $un = (Invoke-Git @('config', '--local', '--get', 'user.name') -Quiet).Out.Trim()
    $ue = (Invoke-Git @('config', '--local', '--get', 'user.email') -Quiet).Out.Trim()
    if ($un -and $ue) { return $true }
    $go = Confirm-Action 'Usuário Git não configurado' "Este projeto ainda não tem nome e e-mail configurados para os commits.`n`nDeseja configurar agora? (git config --local)" 'Configurar' 'info'
    if (-not $go) { return $false }
    return (Configurar-Usuario)
}

# ----------------------------------------------------------------------
# SERVICO GIT: operacoes individuais (base unica dos tres modos de trabalho)
# Cada funcao monta os argumentos como lista (nunca texto de shell) e devolve o resultado.
# ----------------------------------------------------------------------
function Get-PushArgs([string]$b) {
    Assert-SafeRef $b
    if (Test-HasUpstream $b) { return @('push', 'origin', $b) }
    return @('push', '-u', 'origin', $b)
}
function Svc-Fetch { return (Invoke-Git @('fetch', 'origin')) }
function Svc-Pull([string[]]$PullArgs) { return (Invoke-Git $PullArgs) }
function Svc-CreateBranch([string]$name) { Assert-SafeRef $name; return (Invoke-Git @('switch', '-c', $name)) }
function Svc-Switch([string]$name) { Assert-SafeRef $name; return (Invoke-Git @('switch', $name)) }
function Svc-Add([string[]]$paths) {
    if ($paths -and $paths.Count -gt 0) { return (Invoke-Git (@('add', '--') + $paths)) }
    return (Invoke-Git @('add', '.'))
}
function Svc-Commit([string]$msg) { return (Invoke-Git @('commit', '-m', $msg)) }
function Svc-Merge([string]$branch) { Assert-SafeRef $branch; return (Invoke-Git @('merge', $branch)) }
function Svc-Push([string]$branch) { return (Invoke-Git (Get-PushArgs $branch)) }
function Svc-DeleteBranch([string]$branch) { Assert-SafeRef $branch; return (Invoke-Git @('branch', '-d', $branch)) }

# Mostra o resultado de um merge que falhou (conflito ou outro erro). Nada e resolvido automaticamente.
function Show-MergeFailure($m, [string]$Extra = '') {
    $cf = @(Get-ConflictFiles)
    if ($cf.Count -gt 0) {
        $t = "O merge encontrou conflitos e foi interrompido.`n`nArquivos em conflito:`n" + (Format-Changes $cf) + "`n`nResolva os conflitos nos arquivos e use 'Registrar Alterações' para concluir o merge.`n`nPara desfazer o merge, rode 'git merge --abort' em um terminal."
        if ($Extra) { $t += "`n`n" + $Extra }
        Show-Msg 'Conflito no merge' $t 'error'
    } else { Show-GitError $m $Extra }
}

# ----------------------------------------------------------------------
# PINTURA: cards, banner, chips, navegacao lateral
# ----------------------------------------------------------------------
function Paint-Card($c, $ev) {
    $g = $ev.Graphics; $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'ClearTypeGridFit'
    $t = $c.Tag; $w = $c.ClientSize.Width; $h = $c.ClientSize.Height
    if ($w -lt 30 -or $h -lt 24) { return }
    $path = New-RoundPath 1 1 ($w - 3) ($h - 3) 16
    if ($t.Mode -eq 'solid') {
        if ($t.Hover) { $gb = New-Grad 0 0 $w $h $t.G2 $t.G1 0 } else { $gb = New-Grad 0 0 $w $h $t.G1 $t.G2 0 }
        $g.FillPath($gb, $path); $gb.Dispose()
        Draw-Text $g $t.Title $Fnt.bold $Bx.white 6 0 ($w - 12) $h $SFC
    } else {
        if ($t.Hover -or $t.Selected) { $g.FillPath($Bx.cardH, $path) } else { $g.FillPath($Bx.card, $path) }
        $bc = $Colors.border; $bw = 1.5
        if ($t.Hover) { $bc = $Colors.borderH }
        if ($t.Border -and -not $t.Hover) { $bc = $t.Border }
        if ($t.Selected) { $bc = $Colors.purple2; $bw = 2.4 }
        $pen = New-Object Drawing.Pen($bc, $bw); $g.DrawPath($pen, $path); $pen.Dispose()
        if ($t.Mode -eq 'wide') {
            Draw-Text $g $t.Title $Fnt.bold $Bx.white 20 0 ($w - 70) $h $SFV
            Draw-Text $g ([string][char]0x203A) $Fnt.h1 $Bx.orange1 ($w - 52) 0 34 ($h - 4) $SFC
        } elseif ($t.Mode -eq 'choice') {
            Draw-Text $g $t.Title $Fnt.h3 $Bx.text 18 14 ($w - 70) 26 $SFL
            Draw-Text $g $t.Desc $Fnt.small $Bx.muted 18 46 ($w - 36) ([Math]::Max(10, $h - 56)) $SFW
            $rp = New-Object Drawing.Pen($Colors.muted, 1.6)
            DE $g $rp ($w - 38) 16 20 20
            $rp.Dispose()
            if ($t.Selected) {
                $dg = New-Grad ($w - 33) 21 10 10 $Colors.purple1 $Colors.purple2 45
                $g.FillEllipse($dg, [single]($w - 33), [single]21, [single]10, [single]10); $dg.Dispose()
            }
        } else {
            $tx = 18
            if ($t.Num) {
                $nb = New-Grad 18 13 28 28 $t.G1 $t.G2 45
                $g.FillEllipse($nb, [single]18, [single]13, [single]28, [single]28); $nb.Dispose()
                Draw-Text $g ([string]$t.Num) $Fnt.bold $Bx.white 18 13 28 28 $SFC
                $tx = 56
            }
            $tw = $w - $tx - 18
            if ($t.Info) {
                $tw -= 30
                $ip = New-Object Drawing.Pen($Colors.muted, 1.4)
                DE $g $ip ($w - 40) 14 22 22
                $ip.Dispose()
                Draw-Text $g 'i' $Fnt.smallB $Bx.muted ($w - 40) 14 22 22 $SFC
            }
            Draw-Text $g $t.Title $Fnt.h3 $Bx.text $tx 13 $tw 28 $SFL
            Draw-Text $g $t.Desc $Fnt.small $Bx.muted 18 48 ($w - 36) ([Math]::Max(10, $h - 48 - 44)) $SFW
            if ($t.Cmd) {
                $pw0 = [int]$g.MeasureString($t.Cmd, $Fnt.monoS).Width + 24
                $pw = [Math]::Min($pw0, $w - 36); $py = $h - 40
                $pp = New-RoundPath 18 $py $pw 24 12
                $gb = New-Grad 18 $py $pw 24 $t.G1 $t.G2 0
                $g.FillPath($gb, $pp); $gb.Dispose(); $pp.Dispose()
                Draw-Text $g $t.Cmd $Fnt.monoS $Bx.white 18 $py $pw 24 $SFC
            }
        }
    }
    if (-not $c.Enabled) {
        $ov = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(120, 10, 5, 36))
        $g.FillPath($ov, $path); $ov.Dispose()
    }
    $path.Dispose()
}

function New-Card([hashtable]$tag) {
    $p = New-Object Windows.Forms.Panel
    $p.Dock = 'Fill'; $p.Margin = (New-Object Windows.Forms.Padding(6)); $p.BackColor = $Colors.bg
    $tag.Hover = $false
    if (-not $tag.Mode) { $tag.Mode = 'card' }
    $p.Tag = $tag
    $p.Cursor = [Windows.Forms.Cursors]::Hand
    Set-DB $p
    $p.Add_Paint({ param($sd, $ev) Paint-Card $sd $ev })
    $p.Add_MouseEnter({ param($sd, $ev) $sd.Tag.Hover = $true; $sd.Invalidate() })
    $p.Add_MouseLeave({ param($sd, $ev) $sd.Tag.Hover = $false; $sd.Invalidate() })
    $p.Add_MouseClick({ param($sd, $ev)
        if ($ev.Button -ne 'Left') { return }
        $t = $sd.Tag
        # clique no pequeno botao "i" (Info) do canto superior direito
        if ($t.Info -and $ev.X -ge ($sd.ClientSize.Width - 48) -and $ev.X -le ($sd.ClientSize.Width - 6) -and $ev.Y -le 46) { Guard 'Show-Info' $t.Info; return }
        if ($t.Action) { Guard $t.Action $t.Arg }
    })
    $p.Add_EnabledChanged({ param($sd, $ev) $sd.Invalidate() })
    return $p
}

function Paint-Banner($c, $ev) {
    $g = $ev.Graphics; $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'ClearTypeGridFit'
    $t = $c.Tag; $w = $c.ClientSize.Width; $h = $c.ClientSize.Height
    if ($w -lt 60 -or $h -lt 60) { return }
    $path = New-RoundPath 1 1 ($w - 3) ($h - 3) 20
    $gb = New-Grad 0 0 $w $h (Get-Col '#2a1a7c') (Get-Col '#130b3a') 0
    $g.FillPath($gb, $path); $gb.Dispose()
    $pen = New-Object Drawing.Pen($Colors.border, 1.5); $g.DrawPath($pen, $path); $pen.Dispose(); $path.Dispose()
    $deco = ($w -gt 620)
    $tw = $w - 56; if ($deco) { $tw = $w - 300 }
    Draw-Text $g $t.Title $Fnt.h1 $Bx.white 26 14 $tw 36 $SFL
    Draw-Text $g $t.Sub $Fnt.ui $Bx.text 28 52 $tw 22 $SFL
    if ($t.Path) { Draw-Text $g $t.Path $Fnt.small $Bx.muted 28 76 $tw 18 $SFL }
    # chips na parte de baixo, quebrando de linha quando faltar largura (sem sobrepor)
    $x = 28; $y = $h - 42
    $maxX = $w - 28; if ($deco) { $maxX = $w - 270 }
    foreach ($ch in @($t.Chips)) {
        if (-not $ch) { continue }
        $cw = $g.MeasureString($ch.Text, $Fnt.small).Width + 40
        if ($x + $cw -gt $maxX -and $x -gt 28) { $x = 28; $y -= 32 }
        if ($y -lt 96) { break }
        $x += (Draw-Chip $g $x $y $ch.Text $ch.Color)
    }
    if ($deco) { Draw-Deco $g ($w - 250) 8 230 ($h - 16) }
}

function New-Banner([hashtable]$tag) {
    $p = New-Object Windows.Forms.Panel
    $p.Dock = 'Fill'; $p.Margin = (New-Object Windows.Forms.Padding(6)); $p.BackColor = $Colors.bg
    $p.Tag = $tag
    Set-DB $p
    $p.Add_Paint({ param($sd, $ev) Paint-Banner $sd $ev })
    return $p
}

# Pilula do cabecalho (branch / status)
function Paint-Pill($c, $ev) {
    $g = $ev.Graphics; $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'ClearTypeGridFit'
    $t = $c.Tag; if (-not $t) { return }
    $w = $c.ClientSize.Width; $h = $c.ClientSize.Height
    if ($w -lt 40) { return }
    $p = New-RoundPath 1 1 ($w - 3) ($h - 3) (($h - 3) / 2)
    $g.FillPath($Bx.panel2, $p)
    $pen = New-Object Drawing.Pen($Colors.border, 1.2); $g.DrawPath($pen, $p); $pen.Dispose(); $p.Dispose()
    $b = New-Object Drawing.SolidBrush($t.Color)
    $g.FillEllipse($b, [single]14, [single]($h / 2 - 4), [single]8, [single]8); $b.Dispose()
    Draw-Text $g $t.Text $Fnt.bold $Bx.text 28 0 ($w - 34) $h $SFV
}
function Set-Pill($p, [string]$text, [string]$colorName) {
    $w = [Windows.Forms.TextRenderer]::MeasureText($text, $Fnt.bold).Width + 46
    $p.Tag = @{ Text = $text; Color = $Colors[$colorName]; W = [int]$w }
    $p.Width = [int][Math]::Min($w, 360)
    $App.tt.SetToolTip($p, $text)
    $p.Invalidate()
}
# Cabecalho responsivo: titulo/subtitulo ocupam so o espaco que sobra; pilulas encolhem antes de sobrepor
function Layout-Header {
    if (-not $App.Header) { return }
    $hw = $App.Header.ClientSize.Width
    $right = $hw - 24
    $used = 0
    if ($App.pillBranch.Visible -and $App.pillBranch.Tag) {
        $wB = $App.pillBranch.Tag.W; $wS = $App.pillStatus.Tag.W
        $maxP = [int](($hw - 48) * 0.55)
        if (($wB + $wS + 10) -gt $maxP) {
            $wS = [Math]::Min($wS, [int]($maxP * 0.45))
            $wB = [Math]::Max(110, $maxP - $wS - 10)
        }
        $App.pillStatus.Width = $wS; $App.pillBranch.Width = $wB
        $App.pillStatus.Left = $right - $wS
        $App.pillBranch.Left = $App.pillStatus.Left - 10 - $wB
        $used = $wB + $wS + 10 + 24
    }
    $tw = [Math]::Max(120, $hw - 28 - $used - 24)
    $App.hTitle.Width = $tw; $App.hSub.Width = $tw
}

# Barra lateral (itens de navegacao) - tamanhos relativos para caber em qualquer altura
function Paint-Nav($c, $ev) {
    $g = $ev.Graphics; $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'ClearTypeGridFit'
    $t = $c.Tag; $w = $c.ClientSize.Width; $h = $c.ClientSize.Height
    $col = $Colors.muted
    if ($t.Selected) { $col = $Colors.white } elseif ($t.Hover) { $col = $Colors.text }
    if (-not $c.Enabled) { $col = $Colors.border }
    if ($t.Selected) {
        $bp = New-RoundPath 0 ($h * 0.18) 5 ($h * 0.64) 2.5
        $g.FillPath($Bx.white, $bp); $bp.Dispose()
    }
    $iy = [Math]::Max(17, $h * 0.40)
    $pen = New-Object Drawing.Pen($col, 2); $pen.StartCap = 'Round'; $pen.EndCap = 'Round'; $pen.LineJoin = 'Round'
    Draw-Icon $g $t.Icon ($w / 2) $iy $pen
    $pen.Dispose()
    $sb = New-Object Drawing.SolidBrush($col)
    Draw-Text $g $t.Label $Fnt.nav $sb 0 ($iy + 18) $w 16 $SFC
    $sb.Dispose()
}
function Layout-Sidebar {
    if (-not $App.Sidebar -or -not $App.NavItems) { return }
    $n = @($App.NavItems).Count
    $avail = $App.Sidebar.ClientSize.Height - 92
    $step = [Math]::Max(52, [Math]::Min(74, [int]($avail / $n)))
    $y = 88
    foreach ($it in $App.NavItems) {
        $it.Location = (Pt 0 $y); $it.Size = (Sz 100 ($step - 4)); $y += $step
    }
}
function Paint-Logo($c, $ev) {
    $g = $ev.Graphics; $g.SmoothingMode = 'AntiAlias'
    $w = $c.ClientSize.Width
    $gb = New-Grad (($w - 46) / 2) 8 46 46 $Colors.purple1 $Colors.orange2 45
    $g.FillEllipse($gb, [single](($w - 46) / 2), [single]8, [single]46, [single]46); $gb.Dispose()
    $pen = New-Object Drawing.Pen($Colors.white, 2); $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
    Draw-Icon $g 'graph' ($w / 2) 31 $pen
    $pen.Dispose()
}

# Card "Atividade recente" (ultimos commits) + proximo passo sugerido
function Paint-Recent($c, $ev) {
    $g = $ev.Graphics; $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'ClearTypeGridFit'
    $w = $c.ClientSize.Width; $h = $c.ClientSize.Height
    if ($w -lt 60 -or $h -lt 60) { return }
    $path = New-RoundPath 1 1 ($w - 3) ($h - 3) 16
    $g.FillPath($Bx.card, $path)
    $pen = New-Object Drawing.Pen($Colors.border, 1.5); $g.DrawPath($pen, $path); $pen.Dispose(); $path.Dispose()
    $tipH = 0
    if ($App.Tip -and $h -ge 190) {
        $tipH = 64
        $ty = $h - $tipH - 8
        $tp = New-RoundPath 14 $ty ($w - 28) $tipH 12
        $g.FillPath($Bx.panel2, $tp); $tp.Dispose()
        $ab = New-Object Drawing.SolidBrush($Colors.orange1)
        $g.FillRectangle($ab, 14, ($ty + 10), 4, ($tipH - 20)); $ab.Dispose()
        Draw-Text $g 'PRÓXIMO PASSO SUGERIDO' $Fnt.smallB $Bx.orange1 28 ($ty + 6) ($w - 56) 16 $SFL
        Draw-Text $g $App.Tip $Fnt.small $Bx.text 28 ($ty + 24) ($w - 56) ($tipH - 28) $SFW
    }
    Draw-Text $g 'Atividade recente' $Fnt.h3 $Bx.text 20 14 ($w - 40) 26 $SFL
    Draw-Text $g 'Últimos commits da branch atual' $Fnt.small $Bx.muted 20 40 ($w - 40) 18 $SFL
    $rows = @($App.Recent)
    if ($rows.Count -eq 0) {
        Draw-Text $g 'Nenhum commit ainda. Faça o primeiro commit para ele aparecer aqui.' $Fnt.ui $Bx.muted 20 76 ($w - 40) 50 $SFW
        return
    }
    $y = 70
    $sep = New-Object Drawing.Pen($Colors.border, 1)
    foreach ($r in $rows) {
        if ($y + 34 -gt $h - $tipH - 8) { break }
        Draw-Text $g $r.Hash $Fnt.mono $Bx.orange1 20 $y 70 32 $SFV
        $wWhen = [Math]::Min(120, [int](($w - 120) * 0.35))
        Draw-Text $g $r.Msg $Fnt.ui $Bx.text 96 $y ([Math]::Max(20, $w - 96 - $wWhen - 24)) 32 $SFV
        Draw-Text $g $r.When $Fnt.small $Bx.muted ($w - $wWhen - 20) $y $wWhen 32 $SFR
        DL $g $sep 20 ($y + 34) ($w - 20) ($y + 34)
        $y += 38
    }
    $sep.Dispose()
}

# ----------------------------------------------------------------------
# MAPA DE BRANCHES: main como linha principal + ate 10 ramificacoes por pagina
# (somente consultas Git de leitura: for-each-ref, rev-list, merge-base)
# ----------------------------------------------------------------------
function Resize-BranchCanvas {
    if (-not $App.gCanvas) { return }
    $n = @($App.Br.Visible).Count
    $above = [int][Math]::Ceiling($n / 2); $below = [int][Math]::Floor($n / 2)
    $App.gCanvas.Width = [Math]::Max(560, $App.gCont.ClientSize.Width)
    $App.gCanvas.Height = [Math]::Max(220, 70 + $above * 62 + $below * 62 + 80)
    $App.gCanvas.Invalidate()
}

function Refresh-BranchMap {
    if (-not $App.Path) { return }
    $br = $App.Br
    $br.Loading = $true; $br.Msg = ''; $br.Hits = @()
    $App.gCanvas.Invalidate()
    [Windows.Forms.Application]::DoEvents()

    $fmt = '--format=%(refname:short)%1f%(objectname)%1f%(committerdate:relative)%1f%(HEAD)%1f%(subject)'
    $r = Invoke-Git @('for-each-ref', '--sort=-committerdate', $fmt, 'refs/heads') -Quiet
    $entries = @(); $index = @{}
    if ($r.Ok -and $r.Out) {
        foreach ($ln in ($r.Out -split '\r?\n')) {
            $f = $ln.Split([char]0x1f)
            if ($f.Count -lt 5) { continue }
            $e = @{ Name = $f[0]; Hash = $f[1]; When = $f[2]; IsCur = ($f[3] -eq '*'); Subject = $f[4] }
            $entries += $e; $index[$e.Name] = $e
        }
    }
    $br.Index = $index
    $br.Total = $entries.Count
    $base = ''
    if ($index.ContainsKey('main')) { $base = 'main' } elseif ($index.ContainsKey('master')) { $base = 'master' }
    $br.Base = $base
    $others = @($entries | Where-Object { $_.Name -ne $base })
    # branch atual sempre na primeira pagina (fixada no topo), depois as mais recentes
    $cur = @($others | Where-Object { $_.IsCur })
    $rest = @($others | Where-Object { -not $_.IsCur })
    $br.All = @($cur) + @($rest)
    $pages = [Math]::Max(1, [int][Math]::Ceiling($br.All.Count / 10))
    if ($br.Page -ge $pages) { $br.Page = $pages - 1 }
    if ($br.Page -lt 0) { $br.Page = 0 }
    $start = $br.Page * 10
    $br.Visible = @($br.All | Select-Object -Skip $start -First 10)

    $br.History = @(); $br.Detail = @{}
    if ($base) {
        $h = Invoke-Git @('rev-list', '--first-parent', '-n', '80', $base) -Quiet
        if ($h.Ok -and $h.Out) { $br.History = @($h.Out -split '\r?\n' | Where-Object { $_ }) }
        foreach ($e in $br.Visible) {
            [Windows.Forms.Application]::DoEvents()
            $d = @{ Ahead = 0; Behind = 0; ForkIdx = -1; HasBase = $false }
            $mb = Invoke-Git @('merge-base', $base, $e.Name) -Quiet
            if ($mb.Ok -and $mb.Out.Trim()) {
                $d.HasBase = $true
                $mh = $mb.Out.Trim()
                for ($i = 0; $i -lt $br.History.Count; $i++) { if ($br.History[$i] -eq $mh) { $d.ForkIdx = $i; break } }
                $cnt = Invoke-Git @('rev-list', '--left-right', '--count', ($base + '...' + $e.Name)) -Quiet
                if ($cnt.Ok) {
                    $pp = @($cnt.Out.Trim() -split '\s+')
                    if ($pp.Count -ge 2) { $d.Behind = [int]$pp[0]; $d.Ahead = [int]$pp[1] }
                }
            }
            $br.Detail[$e.Name] = $d
        }
    }
    if ($entries.Count -eq 0) {
        $br.Msg = "Nenhuma branch com commits ainda.`n`nFaça o primeiro commit e o mapa de branches aparecerá aqui."
    }
    $br.Loading = $false
    if ($App.brInfo) {
        if ($br.All.Count -eq 0) { $App.brInfo.Text = 'Sem ramificações' }
        else { $App.brInfo.Text = ('Mostrando ' + ($start + 1) + '-' + ($start + @($br.Visible).Count) + ' de ' + $br.All.Count + ' ramificação(ões)') }
        $App.brPrev.Enabled = ($br.Page -gt 0)
        $App.brNext.Enabled = (($br.Page + 1) -lt $pages)
    }
    Resize-BranchCanvas
}
function Br-Prev { if ($App.Br.Page -gt 0) { $App.Br.Page--; Refresh-BranchMap } }
function Br-Next { $App.Br.Page++; Refresh-BranchMap }

function Get-BranchRelationText($d) {
    if (-not $d) { return '' }
    if (-not $d.HasBase) { return 'sem ancestral comum' }
    if ($d.Ahead -eq 0) { return 'já está na ' + $App.Br.Base }
    $t = '' + $d.Ahead + ' à frente'
    if ($d.Behind -gt 0) { $t += ' · ' + $d.Behind + ' atrás' }
    return $t
}

function Paint-BranchMap($c, $ev) {
    $g = $ev.Graphics; $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'ClearTypeGridFit'
    $br = $App.Br
    $w = $c.ClientSize.Width
    $hits = New-Object System.Collections.ArrayList
    $br.Hits = $hits
    if ($br.Loading) { Draw-Text $g 'Carregando branches...' $Fnt.ui $Bx.muted 28 24 ($w - 56) 30 $SFL; return }
    if ($br.Msg) { Draw-Text $g $br.Msg $Fnt.ui $Bx.muted 28 24 ($w - 56) 120 $SFW; return }

    $vis = @($br.Visible); $n = $vis.Count
    $above = [int][Math]::Ceiling($n / 2); $below = [int][Math]::Floor($n / 2)
    $lvl = 62
    $ym = 70 + $above * $lvl
    $xL = 60; $xR = [Math]::Max(300, $w - 240)

    # linha principal (main)
    $baseName = $br.Base; $baseLabel = $baseName
    if (-not $baseLabel) { $baseLabel = 'sem main' }
    $mp = New-Object Drawing.Pen((New-Grad $xL ($ym - 3) ($xR - $xL) 6 $Colors.purple1 $Colors.orange1 0), 6)
    $mp.StartCap = 'Round'; $mp.EndCap = 'Round'
    DL $g $mp $xL $ym $xR $ym
    $mp.Dispose()
    $baseCur = ($baseName -and $br.Index.ContainsKey($baseName) -and $br.Index[$baseName].IsCur)
    # chip da main
    $cwB = [Math]::Min(200, [int]$g.MeasureString($baseLabel, $Fnt.bold).Width + 30)
    $rcB = New-RoundPath ($xR + 12) ($ym - 14) $cwB 28 14
    if ($baseCur) { $gbB = New-Grad ($xR + 12) ($ym - 14) $cwB 28 $Colors.orange2 $Colors.orange1 0 } else { $gbB = New-Grad ($xR + 12) ($ym - 14) $cwB 28 $Colors.purple1 $Colors.purple2 0 }
    $g.FillPath($gbB, $rcB); $gbB.Dispose(); $rcB.Dispose()
    Draw-Text $g $baseLabel $Fnt.bold $Bx.white ($xR + 12) ($ym - 14) $cwB 28 $SFC
    if ($baseName) {
        $sub = 'linha principal'
        if ($baseCur) { $sub = 'você está aqui · principal' }
        Draw-Text $g $sub $Fnt.small $Bx.muted ($xR + 12) ($ym + 16) ([Math]::Max(60, $w - $xR - 20)) 16 $SFL
        [void]$hits.Add(@{ X = ($xR + 12); Y = ($ym - 14); W = $cwB; H = 28; Name = $baseName })
    }
    if ($baseCur) {
        $rp = New-Object Drawing.Pen($Colors.white, 2.4)
        DE $g $rp ($xR - 8) ($ym - 8) 16 16
        $rp.Dispose()
    }
    $maxI = [Math]::Max(1, @($br.History).Count - 1)

    for ($i = 0; $i -lt $n; $i++) {
        $e = $vis[$i]; $d = $br.Detail[$e.Name]
        if (-not $d) { continue }
        $up = (($i % 2) -eq 0)
        $level = [int][Math]::Floor($i / 2) + 1
        if ($up) { $y = $ym - $level * $lvl } else { $y = $ym + $level * $lvl }
        $pen = $LanePens[$i % $LanePens.Count]
        $nbr = $LaneBrushes[$i % $LaneBrushes.Count]
        $isCur = [bool]$e.IsCur
        $merged = ($d.HasBase -and $d.Ahead -eq 0 -and -not $isCur)
        if ($d.ForkIdx -ge 0) { $fx = $xR - 50 - ($d.ForkIdx / $maxI) * ($xR - $xL - 110) } else { $fx = $xL + 24 }
        $fx = [Math]::Max($xL + 10, [Math]::Min($fx, $xR - 90))
        $len = [Math]::Max(80, [Math]::Min(300, 70 + $d.Ahead * 14))
        $xEnd = [Math]::Min($fx + 40 + $len, $xR + 10)
        if ($xEnd -lt ($fx + 70)) { $xEnd = $fx + 70 }
        $drawPen = $pen
        $custom = $null
        if ($merged -or -not $d.HasBase) {
            $custom = New-Object Drawing.Pen($Colors.muted, 2)
            $custom.DashStyle = 'Dash'
            $drawPen = $custom
        }
        if ($isCur) { $thick = New-Object Drawing.Pen($Colors.orange1, 4); $thick.StartCap = 'Round'; $thick.EndCap = 'Round'; $drawPen = $thick }
        # no de partida na main + curva ate o nivel da branch + linha horizontal
        $g.FillEllipse($Bx.panel, [single]($fx - 8), [single]($ym - 8), [single]16, [single]16)
        $g.FillEllipse($nbr, [single]($fx - 5), [single]($ym - 5), [single]10, [single]10)
        DB $g $drawPen $fx $ym $fx ($ym + ($y - $ym) * 0.65) ($fx + 8) $y ($fx + 40) $y
        DL $g $drawPen ($fx + 40) $y $xEnd $y
        $rad = 6; if ($isCur) { $rad = 8 }
        $g.FillEllipse($Bx.panel, [single]($xEnd - $rad - 3), [single]($y - $rad - 3), [single]($rad * 2 + 6), [single]($rad * 2 + 6))
        $g.FillEllipse($nbr, [single]($xEnd - $rad), [single]($y - $rad), [single]($rad * 2), [single]($rad * 2))
        if ($isCur) { $wp = New-Object Drawing.Pen($Colors.white, 2.2); DE $g $wp ($xEnd - $rad - 3) ($y - $rad - 3) ($rad * 2 + 6) ($rad * 2 + 6); $wp.Dispose() }
        # chip com o nome (truncado; nome completo no tooltip e no clique)
        $label = $e.Name
        if ($isCur) { $label = $label }
        $cw = [Math]::Min(220, [int]$g.MeasureString($label, $Fnt.bold).Width + 28)
        $cx = $xEnd + 14
        if (($cx + $cw) -gt ($w - 8)) { $cw = [Math]::Max(80, $w - 8 - $cx) }
        $cp = New-RoundPath $cx ($y - 14) $cw 28 14
        if ($isCur) {
            $cg = New-Grad $cx ($y - 14) $cw 28 $Colors.orange2 $Colors.orange1 0
            $g.FillPath($cg, $cp); $cg.Dispose()
            Draw-Text $g $label $Fnt.bold $Bx.white $cx ($y - 14) $cw 28 $SFC
        } else {
            $g.FillPath($Bx.panel2, $cp)
            $op = New-Object Drawing.Pen($LaneCols[$i % $LaneCols.Count], 1.8)
            if ($merged) { $op.Color = $Colors.muted }
            $g.DrawPath($op, $cp); $op.Dispose()
            $tb = $Bx.text; if ($merged) { $tb = $Bx.muted }
            Draw-Text $g $label $Fnt.bold $tb $cx ($y - 14) $cw 28 $SFC
        }
        $cp.Dispose()
        $subText = Get-BranchRelationText $d
        if ($isCur) { $subText = 'você está aqui · ' + $subText }
        Draw-Text $g $subText $Fnt.small $Bx.muted $cx ($y + 16) ([Math]::Max(60, $w - $cx - 8)) 16 $SFL
        [void]$hits.Add(@{ X = $cx; Y = ($y - 14); W = $cw; H = 28; Name = $e.Name })
        if ($custom) { $custom.Dispose() }
        if ($isCur -and $thick) { $thick.Dispose() }
    }
    $note = 'A linha grossa é a main. O destaque laranja é a branch atual. Passe o mouse sobre um nome para ver o nome completo e clique para detalhes.'
    Draw-Text $g $note $Fnt.small $Bx.muted 24 ($c.ClientSize.Height - 36) ($w - 48) 30 $SFW
}

function Show-BranchDetail([string]$name) {
    $br = $App.Br
    $e = $br.Index[$name]; if (-not $e) { return }
    $d = $br.Detail[$name]
    $rel = ''
    if ($name -eq $br.Base) { $rel = 'Esta é a linha principal.' }
    elseif ($d) { $rel = 'Relação com ' + $br.Base + ': ' + (Get-BranchRelationText $d) + '.' }
    $txt = "Nome completo:`n$name`n`nÚltimo commit:`n" + $e.Subject + ' (' + $e.When + ")`n`n" + $rel
    $btns = @((New-BtnDef 'Fechar' 'cancel' 'secondary'))
    if (-not $e.IsCur) { $btns += (New-BtnDef 'Trocar para esta' 'sw' 'primary') } else { $txt += "`n`nVocê está nesta branch." }
    $r = Show-Dialog -Title 'Branch' -Message $txt -Kind 'info' -Buttons $btns
    if ($r.Result -eq 'sw') { Switch-ToBranch $name $App.Branch }
}

# ----------------------------------------------------------------------
# MENU_PRINCIPAL / MENU_PROJETO: paginas, navegacao e visibilidade do log
# ----------------------------------------------------------------------
$PageMin = @{ start = @(860, 650); home = @(880, 520); graph = @(720, 520); cmds = @(880, 1060); settings = @(800, 760) }

function Apply-LogVisibility {
    $mode = $App.Settings.Logs
    $show = ($mode -eq 'show') -or ($mode -eq 'nostart' -and $App.Page -ne 'start')
    $App.LogVisible = $show
    if (-not $App.main) { return }
    $hgt = 0
    if ($show) { $hgt = [Math]::Max(110, [Math]::Min(220, [int]($App.Form.ClientSize.Height * 0.24))) }
    $App.main.RowStyles[2].Height = $hgt
    $App.logWrap.Visible = $show
}

function Show-Page([string]$name) {
    $App.Page = $name
    foreach ($k in @($App.Pages.Keys)) { $App.Pages[$k].Visible = ($k -eq $name) }
    $App.hTitle.Text = (@{ start = 'Bem-vindo'; home = 'Painel do projeto'; graph = 'Mapa de branches'; cmds = 'Mais comandos individuais'; settings = 'Configurações' })[$name]
    Set-Activity ''
    $App.tt.SetToolTip($App.hSub, (Get-PageSub $name))
    foreach ($n in $App.NavItems) { $n.Tag.Selected = ($n.Tag.Key -eq $name); $n.Invalidate() }
    $hasProj = [bool]$App.Path
    $App.pillBranch.Visible = ($hasProj -and [bool]$App.pillBranch.Tag); $App.pillStatus.Visible = ($hasProj -and [bool]$App.pillStatus.Tag)
    $mn = $PageMin[$name]
    $mh = $mn[1]; if ($name -eq 'home') { $mh = $App.HomeMinH }
    $App.pagesHost.AutoScrollMinSize = (Sz $mn[0] $mh)
    Apply-LogVisibility
    Layout-Header
    if ($name -eq 'graph') { Refresh-BranchMap }
}
function Nav-Home { Show-Page 'home' }
function Nav-Graph { Show-Page 'graph' }
function Nav-Cmds { Show-Page 'cmds' }
function Nav-Settings { Show-Page 'settings' }
function Settings-Back { if ($App.Path) { Show-Page 'home' } else { Show-Page 'start' } }

function Show-StartPanel {
    $App.Path = $null
    Refresh-RecentList
    $App.outer.ColumnStyles[0].Width = 0
    $App.Sidebar.Visible = $false
    Show-Page 'start'
}
function Show-ProjectPanel([string]$dir) {
    $App.Path = $dir
    $App.Name = Split-Path -Leaf $dir
    if (-not $App.Name) { $App.Name = $dir }
    $App.outer.ColumnStyles[0].Width = 100
    $App.Sidebar.Visible = $true
    Layout-Sidebar
    Show-Page 'home'
    Write-Info ('Projeto aberto: ' + $dir)
    Add-Recent $dir
    Update-State
}

function Get-WorkspaceName {
    switch ($App.Settings.Workspace) {
        'single' { return 'Single User' }
        'dev'    { return 'Team Dev' }
        default  { return 'Team Easy' }
    }
}

# Atualiza branch atual / status / commits recentes na GUI (apos cada operacao)
function Update-State {
    if (-not $App.Path) { return }
    [void](Get-CurrentBranchName)
    $lines = @(Get-Changes)
    $merging = Test-Merging
    $conf = @($lines | Where-Object { $_ -match '^(DD|AU|UD|UA|DU|AA|UU) ' })
    if ($conf.Count -gt 0) { $txt = 'Conflitos a resolver'; $col = 'error' }
    elseif ($merging) { $txt = 'Merge em andamento'; $col = 'warn' }
    elseif ($lines.Count -gt 0) { $txt = "$($lines.Count) alteração(ões) pendente(s)"; $col = 'warn' }
    else { $txt = 'Pronto'; $col = 'success' }
    $App.StatusText = $txt

    $un = (Invoke-Git @('config', '--local', '--get', 'user.name') -Quiet).Out.Trim()
    $first = ''
    if ($un) { $first = ($un -split '\s+')[0] }
    $hasRemote = Test-Origin
    $rec = @()
    $lg = Invoke-Git @('log', '-n', '4', '--pretty=format:%h%x1f%s%x1f%ar') -Quiet
    if ($lg.Ok -and $lg.Out) {
        foreach ($ln in ($lg.Out -split '\r?\n')) {
            $pp = $ln.Split([char]0x1f)
            if ($pp.Count -ge 3) { $rec += @{ Hash = $pp[0]; Msg = $pp[1]; When = $pp[2] } }
        }
    }
    $App.Recent = $rec
    $hasCommits = Test-HasCommits
    $hasUp = $false; $ahead = 0
    if ($hasRemote -and $hasCommits) {
        $hasUp = Test-HasUpstream
        if ($hasUp) { $cn = Invoke-Git @('rev-list', '--count', '@{u}..HEAD') -Quiet; if ($cn.Ok) { [void][int]::TryParse($cn.Out.Trim(), [ref]$ahead) } }
    }
    $App.Tip = Get-NextStep $conf.Count $merging $lines.Count $hasRemote $hasCommits $hasUp $ahead ([bool]$un -and [bool](Invoke-Git @('config', '--local', '--get', 'user.email') -Quiet).Out.Trim())

    Set-Pill $App.pillBranch ('Branch: ' + $App.Branch) 'accent'
    Set-Pill $App.pillStatus $txt $col
    if ($App.Path) { $App.pillBranch.Visible = $true; $App.pillStatus.Visible = $true }
    $chipCh = @{ Text = ('Alterações: ' + $lines.Count); Color = $Colors.success }
    if ($lines.Count -gt 0) { $chipCh.Color = $Colors.warn }
    $chipRm = @{ Text = 'Remoto: origin'; Color = $Colors.success }
    if (-not $hasRemote) { $chipRm = @{ Text = 'Sem remoto (origin)'; Color = $Colors.orange2 } }
    $chipMd = @{ Text = ('Modo: ' + (Get-WorkspaceName)); Color = $Colors.purple2 }
    $title = 'Olá!'
    if ($first) { $title = 'Olá, ' + $first + '!' }
    $App.bannerHome.Tag.Title = $title
    $App.bannerHome.Tag.Sub = 'Você está trabalhando em ' + $App.Name
    $App.bannerHome.Tag.Path = $App.Path
    $App.bannerHome.Tag.Chips = @($chipCh, $chipRm, $chipMd)
    $App.bannerHome.Invalidate()
    $App.recentCard.Invalidate()
    if ($App.Page -eq 'home') { Set-Activity '' }
    Layout-Header
    if ($App.Page -eq 'graph') { Refresh-BranchMap }
}

# ----------------------------------------------------------------------
# AREAS DE TRABALHO: Single User / Team Easy / Team Dev (mesma base, abstracoes diferentes)
# ----------------------------------------------------------------------
function Get-WorkspaceDefs([string]$mode) {
    $P1 = $Colors.purple1; $P2 = $Colors.purple2; $O1 = $Colors.orange1; $O2 = $Colors.orange2
    $B1 = $Colors.blue1; $B2 = $Colors.blue2; $R1 = $Colors.red1; $R2 = $Colors.red2
    $status = @{ Title = 'Status'; Desc = 'Mostra a situação atual do repositório.'; Cmd = 'git status'; G1 = $B1; G2 = $B2; Action = 'Acao-Status'; Info = 'status' }
    switch ($mode) {
        'single' {
            return @(
                @{ Num = 1; Title = 'Salvar'; Desc = 'Registra tudo o que mudou (com a sua mensagem) e traz as novidades do GitHub.'; Cmd = 'add + commit + pull'; G1 = $P1; G2 = $P2; Action = 'Acao-Salvar'; Info = 'save'; Span = 2 },
                @{ Num = 2; Title = 'Enviar'; Desc = 'Envia os seus commits para o GitHub.'; Cmd = 'git push origin <branch>'; G1 = $O2; G2 = $O1; Action = 'Acao-Push'; Info = 'send' },
                $status
            )
        }
        'dev' {
            return @(
                @{ Num = 1; Title = 'Fetch'; Desc = 'Baixa as novidades do GitHub sem mexer nos seus arquivos.'; Cmd = 'git fetch origin'; G1 = $P1; G2 = $P2; Action = 'Acao-Fetch'; Info = 'fetch' },
                @{ Num = 2; Title = 'Pull'; Desc = 'Traz as novidades do GitHub para a sua branch.'; Cmd = 'git pull origin'; G1 = $P1; G2 = $P2; Action = 'Acao-DevPull'; Info = 'pull' },
                @{ Num = 3; Title = 'Criar branch'; Desc = 'Cria e entra em uma nova branch.'; Cmd = 'git switch -c <nome>'; G1 = $P1; G2 = $P2; Action = 'Acao-CriarBranch'; Info = 'branch' },
                @{ Num = 4; Title = 'Add'; Desc = 'Marca as alterações para o próximo commit.'; Cmd = 'git add .'; G1 = $P1; G2 = $P2; Action = 'Acao-AddTudo'; Info = 'add' },
                @{ Num = 5; Title = 'Commit'; Desc = 'Cria o commit com o que já foi marcado (add).'; Cmd = 'git commit -m'; G1 = $P1; G2 = $P2; Action = 'Acao-DevCommit'; Info = 'commit' },
                @{ Num = 6; Title = 'Merge main'; Desc = 'Traz a main para a sua branch atual.'; Cmd = 'git merge main'; G1 = $O2; G2 = $O1; Action = 'Acao-DevMergeMain'; Info = 'mergemain' },
                @{ Num = 7; Title = 'Push'; Desc = 'Envia uma branch ao GitHub.'; Cmd = 'git push origin <branch>'; G1 = $O2; G2 = $O1; Action = 'Acao-DevPush'; Info = 'push' },
                @{ Num = 8; Title = 'Switch'; Desc = 'Troca para outra branch existente.'; Cmd = 'git switch <branch>'; G1 = $P1; G2 = $P2; Action = 'Acao-Switch'; Info = 'switch' },
                @{ Num = 9; Title = 'Merge outra branch'; Desc = 'Traz outra branch para a branch atual.'; Cmd = 'git merge <branch>'; G1 = $O2; G2 = $O1; Action = 'Acao-Merge'; Info = 'mergeother' },
                @{ Num = 10; Title = 'Excluir branch'; Desc = 'Remove uma branch local já integrada (seguro).'; Cmd = 'git branch -d <branch>'; G1 = $R1; G2 = $R2; Border = (Get-Col '#7a2a4d'); Action = 'Acao-ExcluirBranch'; Info = 'delbranch' },
                $status
            )
        }
        default {
            return @(
                @{ Num = 1; Title = 'Atualizar projeto'; Desc = 'Traz as novidades do GitHub para o seu projeto.'; Cmd = 'fetch + pull'; G1 = $P1; G2 = $P2; Action = 'Acao-Atualizar'; Info = 'upd' },
                @{ Num = 2; Title = 'Criar branch'; Desc = 'Cria e entra em uma nova branch de trabalho.'; Cmd = 'git switch -c'; G1 = $P1; G2 = $P2; Action = 'Acao-CriarBranch'; Info = 'branch' },
                @{ Num = 3; Title = 'Registrar alterações'; Desc = 'Salva o que você mudou em um novo commit.'; Cmd = 'git add + commit'; G1 = $P1; G2 = $P2; Action = 'Acao-Registrar'; Info = 'reg' },
                @{ Num = 4; Title = 'Publicar branch'; Desc = 'Atualiza com a main e envia a branch ao GitHub.'; Cmd = 'merge main + push'; G1 = $O2; G2 = $O1; Action = 'Acao-Publicar'; Info = 'pub' },
                @{ Num = 5; Title = 'Concluir trabalho'; Desc = 'Integra na main e remove a branch local. Alto risco.'; Cmd = 'merge + push + branch -d'; G1 = $R1; G2 = $R2; Border = (Get-Col '#7a2a4d'); Action = 'Acao-Concluir'; Info = 'fin' },
                $status
            )
        }
    }
}

# (Re)constroi os cards do painel conforme a area de trabalho escolhida
function Build-Workspace {
    $rh = $App.rightHost
    foreach ($ctl in @($rh.Controls)) { $rh.Controls.Remove($ctl); $ctl.Dispose() }
    $defs = @(Get-WorkspaceDefs $App.Settings.Workspace)
    $rowsN = [int][Math]::Ceiling(@($defs | ForEach-Object { if ($_.Span) { $_.Span } else { 1 } } | Measure-Object -Sum).Sum / 2)
    $tl = New-TL 2 $rowsN
    Add-Col $tl 'P' 50; Add-Col $tl 'P' 50
    for ($r = 0; $r -lt $rowsN; $r++) { Add-Row $tl 'P' (100 / $rowsN) }
    $pos = 0
    foreach ($d in $defs) {
        $card = New-Card $d
        $row = [int][Math]::Floor($pos / 2); $col = $pos % 2
        if ($d.Span -eq 2) { $col = 0; if (($pos % 2) -eq 1) { $pos++; $row++ } }
        $tl.Controls.Add($card, $col, $row)
        if ($d.Span -eq 2) { $tl.SetColumnSpan($card, 2); $pos += 2 } else { $pos++ }
    }
    $rh.Controls.Add($tl)
    $App.HomeMinH = [Math]::Max(440, $rowsN * 136 + 40)
    if ($App.Page -eq 'home') { $App.pagesHost.AutoScrollMinSize = (Sz 880 $App.HomeMinH) }
}

function Refresh-Choices {
    foreach ($cc in $App.ChoiceCards) {
        $a = [string]$cc.Tag.Arg
        $sel = $false
        if ($a -eq ('ws:' + $App.Settings.Workspace)) { $sel = $true }
        if ($a -eq ('log:' + $App.Settings.Logs)) { $sel = $true }
        if ($a -eq ('rem:' + $App.Settings.Remember)) { $sel = $true }
        $cc.Tag.Selected = $sel
        $cc.Invalidate()
    }
}

# Troca uma preferencia (valores validados por lista fixa) e aplica na hora
function Choose-Setting([string]$arg) {
    $parts = $arg.Split(':')
    if ($parts.Count -ne 2) { return }
    if ($parts[0] -eq 'ws' -and @('single', 'easy', 'dev') -contains $parts[1]) {
        $App.Settings.Workspace = $parts[1]
        Build-Workspace
        if ($App.Path) { Update-State }
    } elseif ($parts[0] -eq 'log' -and @('none', 'nostart', 'show') -contains $parts[1]) {
        $App.Settings.Logs = $parts[1]
        if ($parts[1] -ne 'show' -and $App.LogBox) { $App.LogBox.Clear() }
    } elseif ($parts[0] -eq 'rem' -and @('on', 'off') -contains $parts[1]) {
        $App.Settings.Remember = $parts[1]
        if ($parts[1] -eq 'off') { Clear-Recent } else { Refresh-RecentList }
    } else { return }
    Save-Settings
    Refresh-Choices
    Apply-LogVisibility
}

# ----------------------------------------------------------------------
# INFO: explicacao simples de cada operacao
# ----------------------------------------------------------------------
$InfoCatalog = @{
    save = @{ Title = 'Salvar'
        Util = 'Salva o seu trabalho em um único passo: registra as alterações em um commit e traz as novidades do GitHub.'
        Cmds = @('git add .', 'git commit -m "sua mensagem"', 'git pull  (antes disso o programa confere se pode haver conflito)')
        Efeitos = 'Cria um commit com TODAS as alterações listadas na confirmação. O pull pode atualizar arquivos locais com o que veio do GitHub. Nada é apagado automaticamente.'
        Erros = 'Sem alterações para salvar; conflito no pull (o fluxo para e explica); sem internet ou login; nome/e-mail do Git não configurados.' }
    send = @{ Title = 'Enviar'
        Util = 'Envia os seus commits para o GitHub, para que outras pessoas (ou outro computador) recebam seu trabalho.'
        Cmds = @('git push origin <branch>   (na primeira vez usa -u para ligar a branch ao GitHub)')
        Efeitos = 'Atualiza a branch no GitHub. Os seus arquivos locais não mudam.'
        Erros = 'Push recusado (o GitHub tem commits que você não tem: atualize primeiro); falta de login ou permissão; projeto sem remoto.' }
    status = @{ Title = 'Status'
        Util = 'Mostra a situação do projeto: branch atual, o que mudou e o que já está pronto para commit.'
        Cmds = @('git status')
        Efeitos = 'Nenhum: é somente leitura.'
        Erros = 'A pasta não ser um repositório Git.' }
    upd = @{ Title = 'Atualizar projeto'
        Util = 'Baixa as alterações mais recentes do repositório remoto e atualiza a sua cópia local.'
        Cmds = @('git fetch origin', 'git pull origin  (ou: git pull origin <branch>, se a branch ainda não estiver ligada ao GitHub)')
        Efeitos = 'Arquivos do seu projeto podem mudar para refletir o que a equipe enviou. Se você tem alterações locais, o programa avisa antes.'
        Erros = 'Sem internet ou login; conflito se a mesma parte de um arquivo mudou nos dois lados; branch inexistente no GitHub.' }
    branch = @{ Title = 'Criar branch'
        Util = 'Cria uma nova linha de trabalho separada da main, para você desenvolver sem afetar o resto da equipe.'
        Cmds = @('git switch -c <nome>')
        Efeitos = 'Cria a branch a partir da branch atual e já passa a usá-la. Alterações não registradas vão junto.'
        Erros = 'Nome inválido (espaços, caracteres proibidos) ou branch que já existe.' }
    reg = @{ Title = 'Registrar alterações'
        Util = 'Salva o que você mudou em um commit, que é um ponto do histórico com uma mensagem explicando a mudança.'
        Cmds = @('git add .  (ou git add -- <arquivos escolhidos>)', 'git commit -m "sua mensagem"')
        Efeitos = 'Cria um commit local. Nada vai para o GitHub ainda.'
        Erros = 'Nenhuma alteração; nome/e-mail do Git não configurados; mensagem vazia.' }
    pub = @{ Title = 'Publicar branch'
        Util = 'Atualiza a sua branch com a main e a envia ao GitHub, deixando-a pronta para revisão da equipe.'
        Cmds = @('git merge main', 'git push -u origin <branch>')
        Efeitos = 'A main local é mesclada na sua branch (cria um commit de merge, se necessário) e a branch é enviada/atualizada no GitHub.'
        Erros = 'Conflito no merge (o envio não acontece); push recusado; sem internet ou login; branch main local inexistente.' }
    fin = @{ Title = 'Concluir trabalho'
        Util = 'Integra o seu trabalho na main, envia a main ao GitHub e remove a branch local que já foi integrada.'
        Cmds = @('git switch main', 'git merge <sua-branch>', 'git push origin main  (com -u na primeira vez)', 'git branch -d <sua-branch>')
        Efeitos = 'A main muda (local e no GitHub). A branch local é removida com -d, que só apaga se estiver integrada. Exige digitar CONFIRMAR.'
        Erros = 'Conflito no merge; push recusado; alterações não registradas. Se uma etapa falha, as seguintes NÃO são executadas e a branch é mantida.' }
    fetch = @{ Title = 'Fetch'
        Util = 'Baixa as novidades do GitHub sem alterar os seus arquivos, só para você saber o que há de novo.'
        Cmds = @('git fetch origin')
        Efeitos = 'Atualiza as referências remotas (origin/...). Seus arquivos e branches locais não mudam.'
        Erros = 'Sem internet ou login; remoto inexistente.' }
    pull = @{ Title = 'Pull'
        Util = 'Traz as novidades do GitHub para a sua branch e as mescla com o seu trabalho.'
        Cmds = @('git pull origin  (ou git pull origin <branch>, conforme a sua escolha)')
        Efeitos = 'Pode mudar arquivos locais e criar um commit de merge. Escolhendo outra branch, ela é mesclada na branch atual.'
        Erros = 'Conflito; alterações locais que seriam sobrescritas; sem internet ou login.' }
    add = @{ Title = 'Add'
        Util = 'Marca as alterações atuais para entrarem no próximo commit.'
        Cmds = @('git add .')
        Efeitos = 'Prepara (stage) todas as alterações, inclusive arquivos novos. Nada é apagado.'
        Erros = 'Nenhuma alteração pendente.' }
    commit = @{ Title = 'Commit'
        Util = 'Cria o commit com o que já foi marcado pelo Add.'
        Cmds = @('git commit -m "sua mensagem"')
        Efeitos = 'Cria um ponto no histórico local. Nada vai para o GitHub ainda.'
        Erros = 'Nada marcado (faça o Add antes); mensagem vazia; nome/e-mail do Git não configurados.' }
    mergemain = @{ Title = 'Merge main'
        Util = 'Traz as mudanças da main para a sua branch atual, mantendo-a atualizada.'
        Cmds = @('git merge main')
        Efeitos = 'Pode criar um commit de merge. Usa a main local do seu computador (faça Fetch/Pull na main antes se quiser a mais recente).'
        Erros = 'Conflito (o Git para e deixa os arquivos marcados para você resolver).' }
    push = @{ Title = 'Push'
        Util = 'Envia os commits de uma branch para o GitHub.'
        Cmds = @('git push origin <branch>   (na primeira vez usa -u)')
        Efeitos = 'Atualiza a branch no GitHub. Não altera seus arquivos locais.'
        Erros = 'Push recusado; falta de login ou permissão; branch inexistente.' }
    switch = @{ Title = 'Switch'
        Util = 'Troca para outra branch que já existe.'
        Cmds = @('git switch <branch>')
        Efeitos = 'Os arquivos da pasta passam a refletir a outra branch. Alterações não registradas vão junto, ou a troca é recusada se houver risco de perda.'
        Erros = 'Branch inexistente; alterações que seriam sobrescritas.' }
    mergeother = @{ Title = 'Merge outra branch'
        Util = 'Traz as mudanças de outra branch para a branch atual.'
        Cmds = @('git merge <branch>')
        Efeitos = 'Pode criar um commit de merge na branch atual.'
        Erros = 'Conflito; branch inexistente.' }
    delbranch = @{ Title = 'Excluir branch'
        Util = 'Remove uma branch local que já foi integrada, para manter a lista organizada.'
        Cmds = @('git branch -d <branch>')
        Efeitos = 'Apaga somente a branch local. O -d é seguro: o Git recusa se houver commits não integrados.'
        Erros = 'Branch não integrada (recusado); tentar excluir a branch atual.' }
}

function Add-Rich($rtb, [string]$t, $color, [bool]$bold) {
    $rtb.SelectionStart = $rtb.TextLength; $rtb.SelectionLength = 0
    $rtb.SelectionColor = $color
    if ($bold) { $rtb.SelectionFont = $Fnt.bold } else { $rtb.SelectionFont = $Fnt.ui }
    $rtb.AppendText($t)
}

function Show-Info([string]$key) {
    $i = $InfoCatalog[$key]
    if (-not $i) { return }
    $dlg = New-Object Windows.Forms.Form
    $dlg.Text = 'GitHub Team Helper'
    $dlg.FormBorderStyle = 'FixedDialog'; $dlg.StartPosition = 'CenterParent'
    $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false; $dlg.ShowInTaskbar = $false
    $dlg.BackColor = $Colors.bg; $dlg.ForeColor = $Colors.text; $dlg.Font = $Fnt.ui
    $wa = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $hh = [Math]::Min(520, $wa.Height - 90)
    $dlg.ClientSize = (Sz 620 $hh)
    $dlg.Add_HandleCreated({ param($sd, $ev) Set-DarkTitle $sd })
    $strip = New-Object Windows.Forms.Panel
    $strip.BackColor = $Colors.info; $strip.Location = (Pt 0 0); $strip.Size = (Sz 620 4)
    $dlg.Controls.Add($strip)
    $dlg.Controls.Add((New-Label ('Info: ' + $i.Title) $Fnt.h2 $Colors.text 28 20 560 28))
    $rtb = New-Object Windows.Forms.RichTextBox
    $rtb.Location = (Pt 28 58); $rtb.Size = (Sz 564 ($hh - 58 - 74))
    $rtb.ReadOnly = $true; $rtb.BorderStyle = 'None'; $rtb.BackColor = $Colors.panel; $rtb.ForeColor = $Colors.text
    $rtb.ScrollBars = 'Vertical'; $rtb.DetectUrls = $false; $rtb.WordWrap = $true; $rtb.Font = $Fnt.ui
    Add-Rich $rtb "Para que serve`n" $Colors.accent $true
    Add-Rich $rtb ($i.Util + "`n`n") $Colors.text $false
    Add-Rich $rtb "Comandos Git executados (nesta ordem)`n" $Colors.accent $true
    $n = 1
    foreach ($cm in $i.Cmds) { Add-Rich $rtb ('' + $n + '. ' + $cm + "`n") $Colors.orange1 $false; $n++ }
    Add-Rich $rtb "`nO que a operação pode causar`n" $Colors.accent $true
    Add-Rich $rtb ($i.Efeitos + "`n`n") $Colors.text $false
    Add-Rich $rtb "Possíveis problemas`n" $Colors.accent $true
    Add-Rich $rtb ($i.Erros + "`n") $Colors.text $false
    $rtb.SelectionStart = 0; $rtb.ScrollToCaret()
    $dlg.Controls.Add($rtb)
    $bc = New-Btn 'Fechar' 'primary' 130 38
    $bc.Location = (Pt (620 - 28 - 130) ($hh - 56))
    $bc.Add_Click({ param($sd, $ev) $sd.FindForm().Close() })
    $dlg.Controls.Add($bc)
    $dlg.AcceptButton = $bc; $dlg.CancelButton = $bc
    if ($App.Form -and $App.Form.Visible) { [void]$dlg.ShowDialog($App.Form) } else { [void]$dlg.ShowDialog() }
    $dlg.Dispose()
}

# ----------------------------------------------------------------------
# CONFIGURAR_USUARIO (somente --local, nunca --global)
# ----------------------------------------------------------------------
function Configurar-Usuario {
    if (-not $App.Path) { return $false }
    $curN = (Invoke-Git @('config', '--local', '--get', 'user.name') -Quiet).Out.Trim()
    $curE = (Invoke-Git @('config', '--local', '--get', 'user.email') -Quiet).Out.Trim()
    $n = Ask-Text 'Configurar usuário Git' "Informe o nome que aparecerá nos seus commits.`n`nSerá salvo apenas neste projeto (git config --local)." 'Nome do usuário Git:' $curN 'Continuar'
    if ($null -eq $n) { return $false }
    $em = $null
    while ($true) {
        $em = Ask-Text 'Configurar usuário Git' "Informe o e-mail usado nos seus commits.`n`nDica: use o mesmo e-mail da sua conta do GitHub." 'E-mail do usuário Git:' $curE 'Salvar'
        if ($null -eq $em) { return $false }
        if ($em -match '^[^@\s]+@[^@\s]+\.[^@\s]+$') { break }
        Show-Msg 'E-mail inválido' 'Digite um e-mail válido, como nome@exemplo.com.' 'error'
        $curE = $em
    }
    $r1 = Invoke-Git @('config', '--local', 'user.name', $n)
    if (-not $r1.Ok) { Show-GitError $r1; return $false }
    $r2 = Invoke-Git @('config', '--local', 'user.email', $em)
    if (-not $r2.Ok) { Show-GitError $r2; return $false }
    Show-Msg 'Usuário configurado' "Nome: $n`nE-mail: $em`n`nSalvo somente neste projeto." 'success'
    return $true
}
function Acao-ConfigurarUsuario {
    if (-not $App.Path) { return }
    [void](Configurar-Usuario)
    Update-State
}

# ----------------------------------------------------------------------
# NOVO_PROJETO
# ----------------------------------------------------------------------
function Acao-NovoProjeto {
    $name = Ask-Text 'Novo projeto' 'Digite o nome do projeto. Uma pasta com esse nome será criada.' 'Nome do projeto:' '' 'Continuar'
    if ($null -eq $name) { return }
    $err = Test-FolderName $name
    if ($err) { Show-Msg 'Nome inválido' $err 'error'; return }

    $parent = Select-Folder 'Escolha a pasta onde o projeto será criado' ([Environment]::GetFolderPath('MyDocuments')) $true
    if (-not $parent) { return }
    $target = Join-Path $parent $name
    if (Test-Path -LiteralPath $target) {
        Show-Msg 'A pasta já existe' "Já existe algo em:`n$target`n`nNada foi alterado. Escolha outro nome ou outro local." 'error'
        return
    }
    $txt = "Será criada a pasta:`n$target`n`nComandos que serão executados:`ngit init`ngit symbolic-ref HEAD refs/heads/main`n`n(O segundo comando define 'main' como branch inicial.)"
    if (-not (Confirm-Action 'Criar novo projeto' $txt 'Criar projeto' 'info')) { Write-Info 'Criação de projeto cancelada.'; return }

    try { [void](New-Item -ItemType Directory -Path $target) }
    catch { Show-Msg 'Erro' ("Não foi possível criar a pasta:`n$target`n`n" + (Protect-Text $_.Exception.Message)) 'error'; return }
    Write-Info ('Pasta criada: ' + $target)

    $r = Invoke-Git @('init') -WorkDir $target
    if (-not $r.Ok) { Show-GitError $r 'A pasta foi criada, mas o repositório não foi inicializado.'; return }
    [void](Invoke-Git @('symbolic-ref', 'HEAD', 'refs/heads/main') -WorkDir $target)

    $App.Path = $target
    if (-not (Configurar-Usuario)) {
        Show-Msg 'Usuário não configurado' "O usuário Git ainda não foi configurado.`n`nVocê pode fazer isso depois pelo botão USUÁRIO da barra lateral." 'warn'
    }

    if (Confirm-Action 'Conectar ao GitHub' "Deseja conectar este projeto a um repositório do GitHub agora?`n`nComando: git remote add origin <URL>" 'Conectar' 'info' 'Agora não') {
        while ($true) {
            $url = Ask-Text 'Conectar ao GitHub' "Informe a URL do repositório.`n`nExemplo: https://github.com/usuario/projeto.git" 'URL do repositório:' '' 'Conectar'
            if ($null -eq $url) { break }
            $ue = Get-RepoUrlError $url
            if ($ue) { Show-Msg 'URL inválida' $ue 'error'; continue }
            $rr = Invoke-Git @('remote', 'add', 'origin', $url)
            if (-not $rr.Ok) { Show-GitError $rr }
            break
        }
    }
    Show-ProjectPanel $target
}

# ----------------------------------------------------------------------
# CLONAR_REPOSITORIO
# ----------------------------------------------------------------------
function Acao-Clonar {
    $name = Ask-Text 'Clonar repositório' 'Digite o nome da pasta onde o projeto será salvo.' 'Nome da pasta:' '' 'Continuar'
    if ($null -eq $name) { return }
    $err = Test-FolderName $name
    if ($err) { Show-Msg 'Nome inválido' $err 'error'; return }

    $parent = Select-Folder 'Escolha onde a pasta do projeto será criada' ([Environment]::GetFolderPath('MyDocuments')) $true
    if (-not $parent) { return }
    $target = Join-Path $parent $name
    if (Test-Path -LiteralPath $target) {
        # nunca apaga nada: so aceita uma pasta existente se estiver vazia
        $isDir = Test-Path -LiteralPath $target -PathType Container
        $items = @()
        if ($isDir) { $items = @(Get-ChildItem -LiteralPath $target -Force -ErrorAction SilentlyContinue) }
        if (-not $isDir -or $items.Count -gt 0) {
            Show-Msg 'Pasta já existe' "O destino já existe e não está vazio:`n$target`n`nNada foi alterado. Escolha outro nome ou outro local." 'error'
            return
        }
    }

    $url = $null
    while ($true) {
        $url = Ask-Text 'Clonar repositório' "Informe o link do repositório.`n`nExemplo: https://github.com/usuario/projeto.git" 'Link do repositório:' '' 'Continuar'
        if ($null -eq $url) { return }
        $ue = Get-RepoUrlError $url
        if (-not $ue) { break }
        Show-Msg 'URL inválida' $ue 'error'
    }

    $txt = "Você está prestes a clonar:`n`n$(Protect-Text $url)`n`nDestino:`n`n$target`n`nComando:`ngit clone <URL> <destino>"
    if (-not (Confirm-Action 'Clonar repositório' $txt 'Continuar' 'info')) { Write-Info 'Clonagem cancelada.'; return }

    $r = Invoke-Git @('clone', $url, $target) -WorkDir $parent
    if (-not $r.Ok) { Show-GitError $r 'Nenhuma pasta existente foi apagada.'; return }

    $root = Resolve-RepoRoot $target
    if (-not $root) { $root = $target }
    $App.Path = $root
    if (-not (Configurar-Usuario)) {
        Show-Msg 'Usuário não configurado' "O usuário Git ainda não foi configurado.`n`nVocê pode fazer isso depois pelo botão USUÁRIO da barra lateral." 'warn'
    }
    Show-ProjectPanel $root
    Acao-Atualizar   # pull inicial (com verificacao e confirmacao)
}

# ----------------------------------------------------------------------
# ABRIR_PROJETO (repositorio existente abre direto; pasta sem Git so recebe git init apos confirmacao no assistente)
# ----------------------------------------------------------------------
function Acao-AbrirProjeto {
    $p = Select-Folder 'Selecione a pasta do projeto (com ou sem Git)' '' $false
    if ($p) { Open-FolderFlow $p }
}

# ----------------------------------------------------------------------
# ATUALIZAR (Team Easy: fetch + pull | Team Dev: pull com escolha de branch)
# ----------------------------------------------------------------------
function Invoke-PullFlow([string]$Branch, [bool]$WithFetch) {
    if (-not (Test-RepoReady -NeedOrigin -NeedBranch -NoBusy -Title 'Atualizar')) { return $false }
    $cur = $App.Branch
    if (-not $Branch) { $Branch = $cur }
    Assert-SafeRef $Branch
    $isCur = ($Branch -eq $cur)
    $hasUp = $false
    if ($isCur) { $hasUp = Test-HasUpstream }
    if ($isCur -and $hasUp) { $pullArgs = @('pull', 'origin') } else { $pullArgs = @('pull', 'origin', $Branch) }
    $disp = 'git ' + ($pullArgs -join ' ')
    $cmds = $disp
    if ($WithFetch) { $cmds = "git fetch origin`n" + $disp }
    $note = ''
    if (-not $isCur) { $note = "`n`nIsto traz origin/$Branch para dentro da branch atual ($cur)." }
    $ch = @(Get-Changes)
    if ($ch.Count -gt 0) {
        $txt = "Existem $($ch.Count) alteração(ões) local(is) não registrada(s):`n`n" + (Format-Changes $ch) + "`n`nO pull pode falhar ou gerar conflitos com essas alterações. Nada será apagado.`n`nComandos:`n$cmds$note"
        $ok = Confirm-Action 'Atualizar projeto' $txt 'Continuar mesmo assim' 'warn'
    } else {
        $txt = "Branch atual:`n$cur`n`nSerão executados:`n$cmds$note`n`nTrazer as novidades do GitHub para o seu projeto?"
        $ok = Confirm-Action 'Atualizar projeto' $txt 'Atualizar' 'info'
    }
    if (-not $ok) { Write-Info 'Atualização cancelada.'; return $false }
    if ($WithFetch) {
        $f = Svc-Fetch
        if (-not $f.Ok) { Show-GitError $f 'Nada foi alterado no seu projeto.'; return $false }
    }
    $r = Svc-Pull $pullArgs
    if ($r.Ok -and $isCur -and -not $hasUp) {
        # guarda a ligacao com o GitHub para os proximos pulls/pushes
        [void](Invoke-Git @('branch', ('--set-upstream-to=origin/' + $Branch), $Branch))
    }
    Update-State
    if ($r.Ok) {
        $t = $r.Text; if ($t.Length -gt 500) { $t = $t.Substring(0, 500) + ' [...]' }
        Show-Msg 'Projeto atualizado' ("Operação concluída.`n`n" + $t) 'success'
        return $true
    }
    if (@(Get-ConflictFiles).Count -gt 0) { Show-MergeFailure $r 'Nada foi sobrescrito sem aviso.' }
    else { Show-GitError $r }
    return $false
}
function Acao-Atualizar { [void](Invoke-PullFlow '' $true) }

# ----------------------------------------------------------------------
# CRIAR_BRANCH
# ----------------------------------------------------------------------
function Acao-CriarBranch {
    if (-not (Test-RepoReady -NeedBranch -NoBusy -Title 'Criar branch')) { return }
    $txt = "Será executado:`ngit switch -c <nome>`n`nA nova branch parte da branch atual ($($App.Branch)). Use nomes sem espaços, como feature-login."
    $name = Ask-Text 'Criar branch' $txt 'Nome da branch:' '' 'Criar branch'
    if ($null -eq $name) { return }
    $e = Get-BranchNameError $name
    if ($e) { Show-Msg 'Nome inválido' $e 'error'; return }
    if (Test-LocalBranchExists $name) {
        Show-Msg 'Branch já existe' "Já existe uma branch chamada '$name'.`n`nEscolha outro nome ou troque para ela (Mais comandos > Trocar de branch)." 'warn'
        return
    }
    $r = Svc-CreateBranch $name
    Update-State
    if ($r.Ok) { Show-Msg 'Branch criada' "Branch atual:`n$name" 'success' } else { Show-GitError $r }
}

# ----------------------------------------------------------------------
# REGISTRAR_ALTERACOES (git add + git commit)
# ----------------------------------------------------------------------
function Acao-Registrar {
    if (-not (Test-RepoReady -NeedBranch -NoBusy -Title 'Registrar alterações')) { return }
    $ch = @(Get-Changes)
    if ($ch.Count -eq 0) { Show-Msg 'Nada para registrar' 'Não há alterações pendentes neste projeto.' 'info'; return }
    if (-not (Ensure-GitUser)) { return }

    $txt = "Existem $($ch.Count) alteração(ões) pendente(s):`n`n" + (Format-Changes $ch) + "`n`nEscolha o que será incluído no commit."
    $c = Show-Dialog -Title 'Como deseja adicionar os arquivos?' -Message $txt -Kind 'info' -Buttons @((New-BtnDef 'Cancelar' 'cancel' 'secondary'), (New-BtnDef 'Arquivo específico' 'file' 'secondary'), (New-BtnDef 'Todos os arquivos' 'all' 'primary'))
    if ($c.Result -ne 'all' -and $c.Result -ne 'file') { return }

    $paths = @()
    $addDisp = 'git add .'
    if ($c.Result -eq 'file') {
        $d = New-Object Windows.Forms.OpenFileDialog
        $d.InitialDirectory = $App.Path; $d.Multiselect = $true; $d.CheckFileExists = $true
        $d.Title = 'Escolha o(s) arquivo(s) para adicionar'
        $rr = $d.ShowDialog($App.Form)
        $sel = @($d.FileNames)
        $d.Dispose()
        if ($rr -ne 'OK' -or $sel.Count -eq 0) { return }
        $base = $App.Path.TrimEnd('\') + '\'
        foreach ($file in $sel) {
            if (-not $file.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) {
                Show-Msg 'Arquivo fora do projeto' "Escolha apenas arquivos dentro da pasta do projeto:`n$($App.Path)`n`nArquivo escolhido:`n$file" 'error'
                return
            }
            $paths += $file.Substring($base.Length).Replace('\', '/')
        }
        $addDisp = 'git add -- ' + (($paths | ForEach-Object { '"' + $_ + '"' }) -join ' ')
    }

    $txt2 = "Serão executados:`n$addDisp`ngit commit -m `"mensagem`"`n`nDescreva o que foi feito. Exemplo: Adiciona sistema de login"
    $msg = Ask-CommitMessage $txt2 'Registrar'
    if ($null -eq $msg) { Write-Info 'Registro cancelado. Nada foi adicionado.'; return }

    if ($c.Result -eq 'all') { if (-not (Confirm-RiskFiles)) { Write-Info 'Registro cancelado. Nada foi adicionado.'; return } }
    $r = Svc-Add $paths
    if (-not $r.Ok) { Show-GitError $r; Update-State; return }
    $staged = Invoke-Git @('diff', '--cached', '--quiet') -Quiet
    if ($staged.ExitCode -eq 0) {
        Update-State
        Show-Msg 'Nada para registrar' 'Nenhuma alteração ficou preparada para o commit (os arquivos escolhidos não têm mudanças).' 'info'
        return
    }
    $r = Svc-Commit $msg
    Update-State
    if ($r.Ok) {
        $t = $r.Text; if ($t.Length -gt 600) { $t = $t.Substring(0, 600) + ' [...]' }
        Show-Msg 'Alterações registradas' ("Commit criado com sucesso.`n`n" + $t) 'success'
    } else { Show-GitError $r 'Os arquivos continuam preparados (git add já foi feito).' }
}

# ----------------------------------------------------------------------
# PUBLICAR_BRANCH (Team Easy: merge main -> push)
# ----------------------------------------------------------------------
function Acao-Publicar {
    if (-not (Test-RepoReady -NeedOrigin -NeedBranch -NoBusy -Title 'Publicar branch')) { return }
    $br = $App.Branch
    if ($br -eq 'main') { Show-Msg 'Publicar branch' "Você está na main.`n`nEsta opção serve para branches de trabalho (ex.: feature-login). Crie uma branch com 'Criar branch'.`n`nPara enviar a própria main (primeiro envio), use Mais comandos > Enviar branch atual." 'warn'; return }
    if (-not (Test-LocalMain)) { Show-Msg 'Branch main não encontrada' "A branch local 'main' não existe neste projeto, então não há com o que atualizar a sua branch." 'error'; return }

    $pend = @(Get-Changes -TrackedOnly)
    $warnTxt = ''
    if ($pend.Count -gt 0) { $warnTxt = "`n`n! Há $($pend.Count) alteração(ões) não registrada(s). Elas NÃO farão parte da publicação (use 'Registrar alterações' antes)." }
    $txt = "Branch atual:`n$br`n`nComando:`ngit merge main`n`nO merge usa a main local do seu computador.$warnTxt"
    if (-not (Confirm-Action 'Atualizar branch com a main?' $txt 'Continuar' 'warn')) { Write-Info 'Publicação cancelada.'; return }

    $m = Svc-Merge 'main'
    Update-State
    if (-not $m.Ok) { Show-MergeFailure $m 'O envio (push) NÃO foi feito.'; return }

    $pa = Get-PushArgs $br
    $pdisp = 'git ' + ($pa -join ' ')
    $txt2 = "Você está prestes a publicar a branch:`n$br`n`nSerão enviadas alterações para:`norigin/$br`n`nComando:`n$pdisp"
    if (-not (Confirm-Action 'Publicar branch' $txt2 'Publicar' 'info')) { Write-Info 'Push cancelado. O merge com a main já foi feito localmente.'; return }
    $p = Svc-Push $br
    Update-State
    if ($p.Ok) { Show-Msg 'Branch publicada' "A branch '$br' foi enviada ao GitHub." 'success' }
    else { Show-GitError $p 'O merge local foi feito, mas a branch não foi enviada.' }
}

# ----------------------------------------------------------------------
# CONCLUIR_TRABALHO (alto risco: exige digitar CONFIRMAR)
#   git switch main -> git merge <branch> -> git push -> git branch -d <branch>
# ----------------------------------------------------------------------
function Acao-Concluir {
    if (-not (Test-RepoReady -NeedOrigin -NeedBranch -NoBusy -Title 'Concluir trabalho')) { return }
    $br = $App.Branch
    if ($br -eq 'main') { Show-Msg 'Concluir trabalho' "Você já está na main.`n`nUse esta opção a partir de uma branch de trabalho (ex.: feature-login)." 'warn'; return }
    if (-not (Test-LocalMain)) { Show-Msg 'Branch main não encontrada' "A branch local 'main' não existe neste projeto." 'error'; return }
    $pend = @(Get-Changes -TrackedOnly)
    if ($pend.Count -gt 0) {
        Show-Msg 'Alterações pendentes' ("Há alterações não registradas:`n`n" + (Format-Changes $pend) + "`n`nUse 'Registrar alterações' antes de concluir o trabalho.") 'warn'
        return
    }

    $pushArgs = Get-PushArgs 'main'
    $pushDisp = 'git ' + ($pushArgs -join ' ')
    $txt = "Branch atual:`n$br`n`nDestino:`nmain`n`nSerão realizadas:`n`ngit switch main`ngit merge $br`n$pushDisp`ngit branch -d $br`n`nIsso irá integrar o trabalho à main e remover a branch local."
    $r = Show-Dialog -Title 'CONCLUIR TRABALHO' -Message $txt -Kind 'danger' -InputLabel 'Digite CONFIRMAR para continuar:' -Require 'exact' -Exact 'CONFIRMAR' -Buttons @((New-BtnDef 'Cancelar' 'cancel' 'secondary'), (New-BtnDef 'Concluir trabalho' 'ok' 'danger'))
    if ($r.Result -ne 'ok') { Write-Info 'Conclusão cancelada. Nada foi alterado.'; return }

    # Uma operacao por vez; qualquer falha interrompe tudo e preserva a branch
    $steps = @(
        @{ D = 'git switch main'; F = { Svc-Switch 'main' } },
        @{ D = "git merge $br"; F = { Svc-Merge $br } },
        @{ D = $pushDisp; F = { Svc-Push 'main' } },
        @{ D = "git branch -d $br"; F = { Svc-DeleteBranch $br } }
    )
    $done = @()
    for ($i = 0; $i -lt $steps.Count; $i++) {
        $st = $steps[$i]
        $res = & $st.F
        Update-State
        if (-not $res.Ok) {
            if ($done.Count -gt 0) { $head = "Etapas concluídas:`n" + ($done -join "`n") } else { $head = 'Nenhuma etapa foi concluída.' }
            switch ($i) {
                0 { $why = 'Não foi possível trocar para a main. Nada foi alterado e a branch não foi excluída.' }
                1 { $why = "A integração falhou. Você está na main e a branch '$br' foi mantida (não foi excluída)." }
                2 { $why = "O push falhou. O merge já está na main LOCAL, mas não foi enviado ao GitHub. A branch '$br' foi mantida." }
                default { $why = "A integração e o envio foram concluídos, mas a exclusão da branch local '$br' falhou. O Git recusa excluir branches não integradas (nada foi forçado)." }
            }
            if ($i -eq 1) { Show-MergeFailure $res ($head + "`n`n" + $why) } else { Show-GitError $res ($head + "`n`n" + $why) }
            return
        }
        $done += ([string][char]0x2713 + ' ' + $st.D)
    }
    Show-Msg 'Trabalho concluído' "A branch '$br' foi integrada à main, enviada ao GitHub e removida localmente.`n`nBranch atual: main" 'success'
}

# ----------------------------------------------------------------------
# SALVAR (Single User): git add . -> git commit -m -> git pull (com verificacoes)
# ----------------------------------------------------------------------
# Atualiza com o GitHub somente se for seguro; nunca tenta resolver conflitos sozinho.
function Invoke-SafePull {
    $cur = $App.Branch
    Assert-SafeRef $cur
    $f = Svc-Fetch
    if (-not $f.Ok) { Show-GitError $f 'Seu commit local foi mantido. Tente atualizar mais tarde.'; return $false }
    $hasUp = Test-HasUpstream
    if ($hasUp) { $ref = '@{u}'; $pullArgs = @('pull', 'origin') }
    else {
        $ref = 'origin/' + $cur
        $pullArgs = @('pull', 'origin', $cur)
        if (-not (Invoke-Git @('show-ref', '--verify', '--quiet', ('refs/remotes/' + $ref)) -Quiet).Ok) {
            Show-Msg 'Atualizar' "A branch '$cur' ainda não existe no GitHub, então não há nada para trazer.`n`nQuando quiser enviá-la, use o botão Enviar." 'info'
            return $true
        }
    }
    $cnt = Invoke-Git @('rev-list', '--left-right', '--count', ('HEAD...' + $ref)) -Quiet
    $ahead = 0; $behind = 0
    if ($cnt.Ok) {
        $pp = @($cnt.Out.Trim() -split '\s+')
        if ($pp.Count -ge 2) { $ahead = [int]$pp[0]; $behind = [int]$pp[1] }
    }
    if ($behind -eq 0) { Show-Msg 'Atualizar' 'Seu projeto já está atualizado com o GitHub.' 'success'; return $true }
    if ($ahead -gt 0) {
        # historicos divergiram: tenta prever conflito sem tocar nos arquivos (git >= 2.38)
        $mt = Invoke-Git @('merge-tree', '--write-tree', 'HEAD', $ref) -Quiet
        if (-not $mt.Ok) {
            if ($mt.ExitCode -eq 1) {
                Show-Msg 'Conflito previsto' "O Git prevê CONFLITOS ao juntar o seu trabalho com o do GitHub.`n`nO pull NÃO foi executado e nada foi alterado. Seu commit local está seguro.`n`nPeça ajuda a quem conhece o projeto ou use o modo Team Easy/Team Dev para resolver com mais controle." 'warn'
                return $false
            }
            $go = Confirm-Action 'Atualizar' "Não foi possível prever se haverá conflito (seu Git é mais antigo).`n`nSe houver, o Git vai parar e marcar os arquivos para você resolver; nada é apagado.`n`nComando:`ngit pull" 'Continuar' 'warn'
            if (-not $go) { Write-Info 'Pull cancelado.'; return $false }
        }
    }
    $r = Svc-Pull $pullArgs
    if ($r.Ok -and -not $hasUp) { [void](Invoke-Git @('branch', ('--set-upstream-to=origin/' + $cur), $cur)) }
    Update-State
    if ($r.Ok) { Show-Msg 'Atualizado' ("Novidades do GitHub trazidas com sucesso.`n`n" + $r.Text) 'success'; return $true }
    if (@(Get-ConflictFiles).Count -gt 0) { Show-MergeFailure $r 'O fluxo foi interrompido. Nada foi resolvido automaticamente.' } else { Show-GitError $r }
    return $false
}

function Acao-Salvar {
    if (-not (Test-RepoReady -NeedBranch -NoBusy -Title 'Salvar')) { return }
    $lines = @(Get-Changes)
    $conf = @($lines | Where-Object { $_ -match '^(DD|AU|UD|UA|DU|AA|UU) ' })
    if ($conf.Count -gt 0) {
        Show-Msg 'Conflitos pendentes' ("Há arquivos em conflito:`n`n" + (Format-Changes $conf) + "`n`nResolva os conflitos nos arquivos antes de salvar.") 'warn'
        return
    }
    $hasOrigin = Test-Origin
    if ($lines.Count -eq 0) {
        if (-not $hasOrigin) { Show-Msg 'Nada para salvar' 'Não há alterações para salvar e o projeto não tem remoto (origin).' 'info'; return }
        $go = Confirm-Action 'Nada para salvar' "Não há alterações para registrar.`n`nDeseja apenas trazer as novidades do GitHub?`n`nComandos:`ngit fetch origin`ngit pull" 'Atualizar' 'info'
        if ($go) { [void](Invoke-SafePull) }
        return
    }
    if (-not (Ensure-GitUser)) { return }

    $msg = Ask-CommitMessage ("Serão incluídas no commit ($($lines.Count) alteração(ões)):`n`n" + (Format-Changes $lines 10) + "`n`nDescreva o que foi feito.") 'Continuar'
    if ($null -eq $msg) { Write-Info 'Salvar cancelado. Nada foi alterado.'; return }

    $cmds = "git add .`ngit commit -m `"$msg`""
    if ($hasOrigin) { $cmds += "`ngit pull" }
    $txt = "Branch:`n$($App.Branch)`n`nSerá feito:`n$cmds`n`nTodas as alterações listadas serão incluídas. Nada é apagado."
    if (-not (Confirm-Action 'Salvar' $txt 'Salvar' 'info')) { Write-Info 'Salvar cancelado. Nada foi alterado.'; return }

    if (-not (Confirm-RiskFiles)) { Write-Info 'Salvar cancelado. Nada foi alterado.'; return }
    $a = Svc-Add @()
    if (-not $a.Ok) { Show-GitError $a; Update-State; return }
    if ((Invoke-Git @('diff', '--cached', '--quiet') -Quiet).ExitCode -eq 0) {
        Update-State
        Show-Msg 'Nada para salvar' 'Depois da conferência não sobrou nenhuma alteração para o commit.' 'info'
        return
    }
    $c = Svc-Commit $msg
    Update-State
    if (-not $c.Ok) { Show-GitError $c 'Os arquivos continuam preparados (git add já foi feito).'; return }
    if (-not $hasOrigin) { Show-Msg 'Salvo' "Commit criado com sucesso.`n`nO projeto não tem remoto (origin), então o pull foi ignorado." 'success'; return }
    [void](Invoke-SafePull)
}

# ----------------------------------------------------------------------
# STATUS
# ----------------------------------------------------------------------
# ----------------------------------------------------------------------
# MAIS_COMANDOS e TEAM DEV: comandos Git individuais
# ----------------------------------------------------------------------
function Show-Output([string]$Title, $r, [string]$Empty) {
    if (-not $r.Ok) { Show-GitError $r; return }
    $t = $r.Text
    if (-not $t) { $t = $Empty }
    if ($t.Length -gt 1300) { $t = $t.Substring(0, 1300) + "`n[...] veja o resultado completo no LOG." }
    Show-Msg $Title $t 'info'
}

function Switch-ToBranch([string]$name, [string]$current) {
    if ($name -eq $current) { Show-Msg 'Trocar de branch' "Você já está na branch '$name'." 'info'; return }
    $pend = @(Get-Changes -TrackedOnly)
    $note = ''
    if ($pend.Count -gt 0) { $note = "`n`n! Há $($pend.Count) alteração(ões) não registrada(s). O Git as levará junto ou recusará a troca se houver risco de perdê-las." }
    $txt = "Branch atual:`n$current`n`nIr para:`n$name`n`nComando:`ngit switch $name$note"
    if (-not (Confirm-Action 'Trocar de branch' $txt 'Trocar' 'info')) { Write-Info 'Troca de branch cancelada.'; return }
    $r = Svc-Switch $name
    Update-State
    if ($r.Ok) { Show-Msg 'Branch alterada' "Branch atual:`n$name" 'success' } else { Show-GitError $r }
}

function Invoke-BranchSwitcher([string]$Title) {
    if (-not (Test-RepoReady -Title 'Branches')) { return }
    $bl = Get-BranchList
    if ($null -eq $bl) { return }
    if ($bl.Items.Count -eq 0) {
        Show-Msg 'Branches' "Ainda não há branches com commits neste projeto.`n`nFaça o primeiro commit com 'Registrar alterações'." 'info'
        return
    }
    $pick = Select-FromList $Title "Resultado de git branch.`nBranch atual: $($bl.Current)`n`nSelecione uma branch para trocar (git switch) ou feche." $bl.Items $bl.Current 'Trocar para esta' 'primary'
    if ($null -eq $pick) { return }
    Switch-ToBranch $pick $bl.Current
}
function Acao-Branch { Invoke-BranchSwitcher 'Branches locais (git branch)' }
function Acao-Switch { Invoke-BranchSwitcher 'Trocar de branch (git switch)' }

function Acao-ExcluirBranch {
    if (-not (Test-RepoReady -NeedBranch -Title 'Excluir branch')) { return }
    $cur = $App.Branch
    $bl = Get-BranchList
    if ($null -eq $bl) { return }
    $items = @($bl.Items | Where-Object { $_ -ne $cur -and $_ -ne 'main' })
    if ($items.Count -eq 0) { Show-Msg 'Excluir branch' "Não há outras branches locais para excluir.`n`n(A branch atual e a main não aparecem nesta lista.)" 'info'; return }
    $pick = Select-FromList 'Excluir branch (git branch -d)' "Escolha a branch local que deseja excluir.`n`nO Git só exclui se ela já estiver integrada; caso contrário, recusa e nada é perdido." $items '' 'Excluir...' 'danger'
    if ($null -eq $pick) { return }
    $txt = "Excluir a branch local:`n$pick`n`nComando:`ngit branch -d $pick`n`nO comando -d é seguro: o Git recusa se houver commits não integrados."
    if (-not (Confirm-Action 'Excluir branch' $txt 'Excluir branch' 'danger')) { Write-Info 'Exclusão cancelada.'; return }
    $r = Svc-DeleteBranch $pick
    Update-State
    if ($r.Ok) { Show-Msg 'Branch excluída' "A branch '$pick' foi excluída localmente." 'success' }
    else { Show-GitError $r 'Nada foi forçado. A branch foi mantida.' }
}

# Merge de uma branch na branch atual (confirmacao + tratamento de conflito)
function Invoke-MergeFlow([string]$source) {
    if (-not (Test-RepoReady -NeedBranch -NoBusy -Title 'Merge')) { return }
    $cur = $App.Branch
    if ($source -eq $cur) { Show-Msg 'Merge' 'Não faz sentido mesclar uma branch nela mesma.' 'info'; return }
    if (-not (Test-LocalBranchExists $source)) { Show-Msg 'Branch não existe' "A branch '$source' não existe neste projeto." 'error'; return }
    $pend = @(Get-Changes -TrackedOnly)
    $note = ''
    if ($pend.Count -gt 0) { $note = "`n`n! Há $($pend.Count) alteração(ões) não registrada(s). Registre-as antes para evitar confusão." }
    $txt = "Branch atual (receberá as mudanças):`n$cur`n`nBranch que será mesclada:`n$source`n`nComando:`ngit merge $source$note"
    if (-not (Confirm-Action 'Mesclar branch' $txt 'Mesclar' 'warn')) { Write-Info 'Merge cancelado.'; return }
    $m = Svc-Merge $source
    Update-State
    if ($m.Ok) { Show-Msg 'Merge concluído' ("A branch '$source' foi mesclada em '$cur'.`n`n" + $m.Text) 'success' }
    else { Show-MergeFailure $m }
}
function Acao-Merge {
    if (-not (Test-RepoReady -NeedBranch -NoBusy -Title 'Mesclar branch')) { return }
    $cur = $App.Branch
    $bl = Get-BranchList
    if ($null -eq $bl) { return }
    $items = @($bl.Items | Where-Object { $_ -ne $cur })
    if ($items.Count -eq 0) { Show-Msg 'Mesclar branch' 'Não há outras branches locais para mesclar.' 'info'; return }
    $pick = Select-FromList 'Mesclar branch (git merge)' "Escolha a branch que será trazida para '$cur'." $items '' 'Continuar' 'primary'
    if ($null -eq $pick) { return }
    Invoke-MergeFlow $pick
}
function Acao-DevMergeMain { Invoke-MergeFlow 'main' }

function Acao-Fetch {
    if (-not (Test-RepoReady -NeedOrigin -Title 'Fetch')) { return }
    $r = Svc-Fetch
    Update-State
    if ($r.Ok) { Show-Msg 'Busca concluída' ("Seus arquivos não foram alterados.`n`n" + $(if ($r.Text) { $r.Text } else { 'Nada novo no GitHub.' })) 'success' } else { Show-GitError $r }
}

# Janela de escolha de branch (Team Dev): ( ) Branch atual  ( ) Outra branch [lista/digitar]
function Show-BranchChooser([string]$Title, [string]$Text, [string]$Current, [string[]]$Names, [string]$Default, [bool]$UseOther) {
    $dlg = New-Object Windows.Forms.Form
    $dlg.Text = 'GitHub Team Helper'
    $dlg.FormBorderStyle = 'FixedDialog'; $dlg.StartPosition = 'CenterParent'
    $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false; $dlg.ShowInTaskbar = $false
    $dlg.BackColor = $Colors.bg; $dlg.ForeColor = $Colors.text; $dlg.Font = $Fnt.ui
    $dlg.ClientSize = (Sz 540 330); $dlg.Tag = $null
    $dlg.Add_HandleCreated({ param($sd, $ev) Set-DarkTitle $sd })
    $strip = New-Object Windows.Forms.Panel
    $strip.BackColor = $Colors.purple2; $strip.Location = (Pt 0 0); $strip.Size = (Sz 540 4)
    $dlg.Controls.Add($strip)
    $dlg.Controls.Add((New-Label $Title $Fnt.h2 $Colors.text 28 20 484 28))
    $lt = New-Label $Text $Fnt.ui $Colors.muted 28 54 484 62
    $lt.AutoEllipsis = $false
    $dlg.Controls.Add($lt)
    $dlg.Controls.Add((New-Label 'Branch:' $Fnt.bold $Colors.text 28 122 484 20))

    $rc = New-Object Windows.Forms.RadioButton
    $rc.Name = 'rbCur'; $rc.Text = 'Branch atual (' + $Current + ')'; $rc.AutoSize = $false
    $rc.Location = (Pt 40 148); $rc.Size = (Sz 470 24); $rc.ForeColor = $Colors.text; $rc.BackColor = $Colors.bg
    $rc.Checked = (-not $UseOther)
    $dlg.Controls.Add($rc)
    $ro = New-Object Windows.Forms.RadioButton
    $ro.Name = 'rbOther'; $ro.Text = 'Outra branch:'; $ro.AutoSize = $false
    $ro.Location = (Pt 40 178); $ro.Size = (Sz 470 24); $ro.ForeColor = $Colors.text; $ro.BackColor = $Colors.bg
    $ro.Checked = $UseOther
    $dlg.Controls.Add($ro)

    $cb = New-Object Windows.Forms.ComboBox
    $cb.Name = 'cbo'; $cb.Location = (Pt 62 208); $cb.Width = 448; $cb.DropDownStyle = 'DropDown'
    $cb.BackColor = $Colors.panel2; $cb.ForeColor = $Colors.text; $cb.FlatStyle = 'Flat'; $cb.MaxLength = 200
    foreach ($nm in $Names) { [void]$cb.Items.Add($nm) }
    $cb.AutoCompleteMode = 'SuggestAppend'; $cb.AutoCompleteSource = 'ListItems'
    $cb.Text = $Default
    $cb.Enabled = $UseOther
    $dlg.Controls.Add($cb)
    $ro.Add_CheckedChanged({ param($sd, $ev) $sd.FindForm().Controls['cbo'].Enabled = $sd.Checked })

    $bo = New-Btn 'Continuar' 'primary' 150 38
    $bo.Location = (Pt 362 270)
    $bc = New-Btn 'Cancelar' 'secondary' 120 38
    $bc.Location = (Pt 232 270)
    $bo.Add_Click({ param($sd, $ev)
        $fm = $sd.FindForm()
        if ($fm.Controls['rbOther'].Checked) { $fm.Tag = 'O:' + $fm.Controls['cbo'].Text.Trim() } else { $fm.Tag = 'C:' }
        $fm.Close()
    })
    $bc.Add_Click({ param($sd, $ev) $sd.FindForm().Close() })
    $dlg.Controls.Add($bo); $dlg.Controls.Add($bc)
    $dlg.AcceptButton = $bo; $dlg.CancelButton = $bc
    Fit-Dialog $dlg
    if ($App.Form -and $App.Form.Visible) { [void]$dlg.ShowDialog($App.Form) } else { [void]$dlg.ShowDialog() }
    $res = $null
    if ($null -ne $dlg.Tag) { $res = [string]$dlg.Tag }
    $dlg.Dispose()
    return $res
}

# Pergunta a branch (padrao: atual). Valida o nome e exige que exista. Retorna o nome ou $null
function Ask-Branch([string]$Title, [string]$Text, [bool]$MustExist = $true) {
    $cur = $App.Branch
    $nl = Invoke-Git @('for-each-ref', '--format=%(refname:short)', 'refs/heads') -Quiet
    $names = @()
    if ($nl.Ok -and $nl.Out) { $names = @($nl.Out -split '\r?\n' | Where-Object { $_ }) }
    $useOther = $false; $default = ''
    while ($true) {
        $ans = Show-BranchChooser $Title $Text $cur $names $default $useOther
        if ($null -eq $ans) { return $null }
        if ($ans -eq 'C:') { return $cur }
        $name = $ans.Substring(2)
        $e = Get-BranchNameError $name
        if (-not $e -and $MustExist -and -not (Test-LocalBranchExists $name)) { $e = "A branch '$name' não existe neste projeto." }
        if (-not $e) { return $name }
        Show-Msg 'Branch inválida' $e 'error'
        $useOther = $true; $default = $name
    }
}

function Acao-DevPull {
    if (-not (Test-RepoReady -NeedOrigin -NeedBranch -NoBusy -Title 'Pull')) { return }
    $b = Ask-Branch 'Pull: qual branch?' "Escolha de qual branch do GitHub (origin) trazer as novidades.`n`nA escolhida será mesclada na branch atual." $false
    if ($null -eq $b) { Write-Info 'Pull cancelado.'; return }
    [void](Invoke-PullFlow $b $false)
}

function Acao-DevPush {
    if (-not (Test-RepoReady -NeedOrigin -NeedBranch -Title 'Push')) { return }
    $b = Ask-Branch 'Push: qual branch?' 'Escolha qual branch será enviada ao GitHub (origin).' $true
    if ($null -eq $b) { Write-Info 'Push cancelado.'; return }
    Invoke-PushFlow $b
}
function Invoke-PushFlow([string]$b) {
    $pa = Get-PushArgs $b
    $disp = 'git ' + ($pa -join ' ')
    $pend = @(Get-Changes -TrackedOnly)
    $note = ''
    if ($pend.Count -gt 0) { $note = "`n`n! Há $($pend.Count) alteração(ões) não registrada(s); elas não serão enviadas." }
    if ($b -eq 'main') { $note += "`n`nVocê está enviando a main." }
    $kind = 'info'; if ($b -eq 'main') { $kind = 'warn' }
    $txt = "Você está prestes a publicar a branch:`n$b`n`nSerão enviadas alterações para:`norigin/$b`n`nComando:`n$disp$note"
    if (-not (Confirm-Action 'Enviar branch' $txt 'Enviar' $kind)) { Write-Info 'Envio cancelado.'; return }
    $r = Svc-Push $b
    Update-State
    if ($r.Ok) { Show-Msg 'Envio concluído' "A branch '$b' foi enviada ao GitHub." 'success' } else { Show-GitError $r }
}
function Acao-Push {
    if (-not (Test-RepoReady -NeedOrigin -NeedBranch -Title 'Enviar branch')) { return }
    Invoke-PushFlow $App.Branch
}

function Acao-AddTudo {
    if (-not (Test-RepoReady -NeedBranch -NoBusy -Title 'Add')) { return }
    $ch = @(Get-Changes)
    if ($ch.Count -eq 0) { Show-Msg 'Nada para preparar' 'Não há alterações pendentes.' 'info'; return }
    $txt = "Marcar todas as alterações para o próximo commit?`n`n" + (Format-Changes $ch) + "`n`nComando:`ngit add ."
    if (-not (Confirm-Action 'Preparar tudo' $txt 'Preparar' 'info')) { Write-Info 'Cancelado.'; return }
    if (-not (Confirm-RiskFiles)) { Write-Info 'Cancelado.'; return }
    $r = Svc-Add @()
    Update-State
    if ($r.Ok) { Show-Toast 'Alterações preparadas' "Tudo foi marcado para o commit. Agora use o Commit." 'success' } else { Show-GitError $r }
}

function Acao-DevCommit {
    if (-not (Test-RepoReady -NeedBranch -NoBusy -Title 'Commit')) { return }
    $s = Invoke-Git @('diff', '--cached', '--name-status') -Quiet
    if (-not $s.Ok -or -not $s.Out.Trim()) { Show-Msg 'Nada para commitar' "Não há alterações preparadas (staged).`n`nUse o passo Add antes." 'info'; return }
    if (-not (Ensure-GitUser)) { return }
    $lines = @($s.Out -split '\r?\n' | Where-Object { $_.Trim() })
    $msg = Ask-CommitMessage ("Serão incluídos no commit ($($lines.Count)):`n`n" + (Format-Changes $lines 10) + "`n`nComando:`ngit commit -m `"mensagem`"") 'Commit'
    if ($null -eq $msg) { Write-Info 'Commit cancelado.'; return }
    $r = Svc-Commit $msg
    Update-State
    if ($r.Ok) { Show-Toast 'Commit criado' $r.Text 'success' } else { Show-GitError $r }
}

function Acao-Stash {
    if (-not (Test-RepoReady -NeedBranch -NoBusy -Title 'Guardar alterações')) { return }
    $pend = @(Get-Changes -TrackedOnly)
    if ($pend.Count -eq 0) { Show-Msg 'Nada para guardar' 'Não há alterações em arquivos rastreados para guardar.' 'info'; return }
    $txt = "Guardar temporariamente estas alterações?`n`n" + (Format-Changes $pend) + "`n`nOs arquivos voltam ao último commit; depois você pode recuperá-las.`n`nComando:`ngit stash"
    if (-not (Confirm-Action 'Guardar alterações' $txt 'Guardar' 'warn')) { Write-Info 'Cancelado.'; return }
    $r = Invoke-Git @('stash')
    Update-State
    if ($r.Ok) { Show-Msg 'Alterações guardadas' ("Para trazê-las de volta, use 'Recuperar guardadas'.`n`n" + $r.Text) 'success' } else { Show-GitError $r }
}

function Acao-StashPop {
    if (-not (Test-RepoReady -NeedBranch -NoBusy -Title 'Recuperar guardadas')) { return }
    $l = Invoke-Git @('stash', 'list') -Quiet
    if (-not $l.Ok -or -not $l.Out.Trim()) { Show-Msg 'Nada guardado' 'Não há alterações guardadas (git stash) neste projeto.' 'info'; return }
    $txt = "Reaplicar a alteração guardada mais recente?`n`n$($l.Out.Split([char]10)[0])`n`nComando:`ngit stash pop"
    if (-not (Confirm-Action 'Recuperar guardadas' $txt 'Recuperar' 'warn')) { Write-Info 'Cancelado.'; return }
    $r = Invoke-Git @('stash', 'pop')
    Update-State
    if ($r.Ok) { Show-Msg 'Alterações recuperadas' 'As alterações guardadas voltaram para os seus arquivos.' 'success' }
    else { Show-GitError $r 'Se houve conflito, resolva os arquivos manualmente. A alteração guardada é mantida pelo Git nesse caso.' }
}

function Acao-Diff {
    if (-not (Test-RepoReady -Title 'Diferenças')) { return }
    $r = Invoke-Git @('diff', '--stat')
    Show-Output 'Diferenças (git diff --stat)' $r 'Nenhuma diferença em arquivos rastreados (arquivos novos não aparecem aqui).'
}
function Acao-Remotos {
    if (-not (Test-RepoReady -Title 'Remotos')) { return }
    $r = Invoke-Git @('remote', '-v')
    Show-Output 'Remotos (git remote -v)' $r 'Nenhum remoto configurado.'
}

# ----------------------------------------------------------------------
# CREDENCIAIS: remover logins do GitHub salvos no Gerenciador de Credenciais
# ----------------------------------------------------------------------
function Invoke-Native([string]$File, [string]$ArgLine) {
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = $File; $psi.Arguments = $ArgLine
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    try {
        $pr = [Diagnostics.Process]::Start($psi)
        $so = $pr.StandardOutput.ReadToEnd(); $se = $pr.StandardError.ReadToEnd()
        $pr.WaitForExit(); $cd = $pr.ExitCode; $pr.Dispose()
    } catch {
        return [pscustomobject]@{ Ok = $false; ExitCode = -1; Out = ''; Text = (Protect-Text $_.Exception.Message) }
    }
    $tx = Protect-Text ((@($so.TrimEnd(), $se.TrimEnd()) | Where-Object { $_ }) -join "`n")
    return [pscustomobject]@{ Ok = ($cd -eq 0); ExitCode = $cd; Out = $so; Text = $tx }
}

function Get-GithubCredTargets {
    $r = Invoke-Native 'cmdkey.exe' '/list'
    $found = @()
    foreach ($ln in ($r.Out -split '\r?\n')) {
        if ($ln -match '(?i)target=(.*github.*?)\s*$') {
            $tg = $Matches[1].Trim()
            if ($tg -and ($found -notcontains $tg)) { $found += $tg }
        }
    }
    return $found
}

function Acao-RemoverCredenciais {
    $targets = @(Get-GithubCredTargets)
    if ($targets.Count -eq 0) {
        Show-Msg 'Credenciais do GitHub' "Nenhuma credencial do GitHub foi encontrada no Gerenciador de Credenciais do Windows." 'info'
        return
    }
    $lista = ($targets | ForEach-Object { '- ' + $_ }) -join "`n"
    $txt = "Serão removidas do Gerenciador de Credenciais do Windows:`n`n$lista`n`nSeus arquivos e repositórios NÃO são afetados. Na próxima vez que usar o GitHub (pull/push/clone), o login será pedido novamente.`n`nComando para cada item:`ncmdkey /delete:<alvo>"
    if (-not (Confirm-Action 'Remover credenciais do GitHub' $txt 'Remover' 'danger')) { Write-Info 'Remoção de credenciais cancelada.'; return }

    $ok = 0; $fail = @()
    foreach ($tg in $targets) {
        Write-Log 'COMANDO' 'muted' $true
        Write-Log ('> cmdkey /delete:"' + $tg + '"') 'accent'
        $r = Invoke-Native 'cmdkey.exe' ('/delete:"' + $tg + '"')
        if ($r.Text) { Write-Log $r.Text 'text' }
        if ($r.Ok) { $ok++; Write-Log ([string][char]0x2713 + ' Removida') 'success' }
        else { $fail += $tg; Write-Log ([string][char]0x00D7 + ' Falhou') 'error' }
        Write-Log ''
    }
    if ($fail.Count -eq 0) {
        Show-Msg 'Credenciais removidas' "$ok credencial(is) do GitHub removida(s) com sucesso." 'success'
    } else {
        Show-Msg 'Remoção parcial' ("Removidas: $ok`n`nNão foi possível remover:`n" + (($fail | ForEach-Object { '- ' + $_ }) -join "`n") + "`n`nTente remover manualmente em: Painel de Controle > Gerenciador de Credenciais.") 'warn'
    }
}

# ----------------------------------------------------------------------
# SAIR / TROCAR PROJETO / TELA CHEIA
# ----------------------------------------------------------------------
function Acao-Sair { $App.Form.Close() }
function Acao-TrocarProjeto { Show-StartPanel; Write-Info 'Projeto fechado. Escolha como deseja continuar.' }
function Toggle-Fullscreen {
    $f = $App.Form
    if (-not $App.Full) {
        $App.PrevState = $f.WindowState
        $f.WindowState = 'Normal'; $f.FormBorderStyle = 'None'; $f.WindowState = 'Maximized'
        $App.Full = $true
    } else {
        $f.FormBorderStyle = 'Sizable'; $f.WindowState = $App.PrevState
        $App.Full = $false
    }
}

# ----------------------------------------------------------------------
# JANELAS MODAIS: dono correto (evita janelas atras de outras) e visualizador de texto
# ----------------------------------------------------------------------
function Show-Modal($dlg) {
    $owner = [Windows.Forms.Form]::ActiveForm
    if (-not $owner -or $owner.IsDisposed) { $owner = $App.Form }
    if ($owner -and $owner.Visible) { return $dlg.ShowDialog($owner) }
    return $dlg.ShowDialog()
}

# Visualizador de texto com rolagem (resultados longos: status, diferencas, historico, diagnostico)
function Show-TextDialog([string]$Title, [string]$Text, [string]$Kind = 'info') {
    if ($Text.Length -gt 60000) { $Text = $Text.Substring(0, 60000) + "`n[...] texto cortado" }
    $dlg = New-Object Windows.Forms.Form
    $dlg.Text = 'GitHub Team Helper'
    $dlg.FormBorderStyle = 'Sizable'; $dlg.StartPosition = 'CenterParent'
    $dlg.MaximizeBox = $true; $dlg.MinimizeBox = $false; $dlg.ShowInTaskbar = $false
    $dlg.BackColor = $Colors.bg; $dlg.ForeColor = $Colors.text; $dlg.Font = $Fnt.ui
    $wa = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $dlg.ClientSize = (Sz ([Math]::Min(780, $wa.Width - 60)) ([Math]::Min(560, $wa.Height - 90)))
    $dlg.MinimumSize = (Sz 440 320)
    $dlg.Add_HandleCreated({ param($sd, $ev) Set-DarkTitle $sd })

    $tl = New-TL 1 3
    Add-Col $tl 'P' 100
    Add-Row $tl 'A' 58; Add-Row $tl 'P' 100; Add-Row $tl 'A' 60
    $tl.Padding = (New-Object Windows.Forms.Padding(24, 14, 24, 8))
    $head = New-Label $Title $Fnt.h2 $Colors.text 0 0 100 30
    $head.Dock = 'Fill'; $head.TextAlign = 'MiddleLeft'
    $tl.Controls.Add($head, 0, 0)

    $rtb = New-Object Windows.Forms.RichTextBox
    $rtb.Dock = 'Fill'; $rtb.ReadOnly = $true; $rtb.BorderStyle = 'None'
    $rtb.BackColor = $Colors.panel; $rtb.ForeColor = $Colors.text; $rtb.Font = $Fnt.mono
    $rtb.DetectUrls = $false; $rtb.WordWrap = $true; $rtb.ScrollBars = 'Vertical'
    $rtb.Margin = (New-Object Windows.Forms.Padding(0))
    $okMark = [string][char]0x2713; $errMark = [string][char]0x00D7
    foreach ($ln in ($Text -split "`r?`n")) {
        $col = $Colors.text
        if ($ln.StartsWith($okMark)) { $col = $Colors.success }
        elseif ($ln.StartsWith('!')) { $col = $Colors.warn }
        elseif ($ln.StartsWith($errMark)) { $col = $Colors.error }
        $rtb.SelectionStart = $rtb.TextLength; $rtb.SelectionLength = 0
        $rtb.SelectionColor = $col; $rtb.SelectionFont = $Fnt.mono
        $rtb.AppendText($ln + "`n")
    }
    $rtb.SelectionStart = 0; $rtb.ScrollToCaret()
    $tl.Controls.Add($rtb, 0, 1)

    $flow = New-Object Windows.Forms.FlowLayoutPanel
    $flow.Dock = 'Fill'; $flow.FlowDirection = 'RightToLeft'; $flow.BackColor = $Colors.bg
    $flow.Padding = (New-Object Windows.Forms.Padding(0, 12, 0, 0))
    $bClose = New-Btn 'Fechar' 'primary' 120 36
    $bClose.Add_Click({ param($sd, $ev) $sd.FindForm().Close() })
    $bCopy = New-Btn 'Copiar texto' 'secondary' 130 36
    $bCopy.Tag = $Text
    $bCopy.Add_Click({ param($sd, $ev) try { [Windows.Forms.Clipboard]::SetText([string]$sd.Tag) } catch {} })
    $flow.Controls.Add($bClose); $flow.Controls.Add($bCopy)
    $tl.Controls.Add($flow, 0, 2)

    $dlg.Controls.Add($tl)
    $strip = New-Object Windows.Forms.Panel
    $strip.BackColor = $Colors[$Kind]; $strip.Dock = 'Top'; $strip.Height = 4
    $dlg.Controls.Add($strip)
    $dlg.AcceptButton = $bClose; $dlg.CancelButton = $bClose
    [void](Show-Modal $dlg)
    $dlg.Dispose()
}

# ----------------------------------------------------------------------
# NOTIFICACOES (toast), PROGRESSO, RODAPE E ICONE
# ----------------------------------------------------------------------
function Paint-Toast($c, $ev) {
    $g = $ev.Graphics; $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'ClearTypeGridFit'
    $t = $c.Tag; if (-not $t) { return }
    $w = $c.ClientSize.Width; $h = $c.ClientSize.Height
    $g.Clear($Colors.panel2)
    $pen = New-Object Drawing.Pen($Colors.border, 1.5); $g.DrawRectangle($pen, 0, 0, ($w - 1), ($h - 1)); $pen.Dispose()
    $b = New-Object Drawing.SolidBrush($t.Color); $g.FillRectangle($b, 0, 0, 6, $h); $b.Dispose()
    Draw-Text $g $t.Title $Fnt.bold $Bx.white 20 10 ($w - 34) 20 $SFL
    Draw-Text $g $t.Text $Fnt.ui $Bx.text 20 34 ($w - 34) ($h - 40) $SFW
}
# Aviso discreto no canto da janela (nao bloqueia). Clique para fechar; se o texto foi cortado, abre o completo.
function Show-Toast([string]$Title, [string]$Text, [string]$Kind = 'success') {
    $f = $App.Form
    if (-not $f -or -not $f.IsHandleCreated) { return }
    if (-not $App.toast) {
        $p = New-Object Windows.Forms.Panel
        $p.Size = (Sz 400 84); $p.Visible = $false; $p.BackColor = $Colors.panel2; $p.Cursor = [Windows.Forms.Cursors]::Hand
        Set-DB $p
        $p.Add_Paint({ param($sd, $ev) Paint-Toast $sd $ev })
        $p.Add_Click({ param($sd, $ev)
            $t = $sd.Tag
            $sd.Visible = $false; $App.toastTimer.Stop()
            if ($t -and $t.Truncated) { Show-Msg $t.Title $t.Full $t.KindName }
        })
        $f.Controls.Add($p)
        $tm = New-Object Windows.Forms.Timer
        $tm.Interval = 5000
        $tm.Add_Tick({ param($sd, $ev) $sd.Stop(); if ($App.toast) { $App.toast.Visible = $false } })
        $App.toast = $p; $App.toastTimer = $tm
    }
    $full = ($Text -replace "`r?`n", "`n").Trim()
    $t = ($full -replace "`n", ' ')
    $trunc = $false
    if ($t.Length -gt 200) { $t = $t.Substring(0, 200) + '...'; $trunc = $true }
    $mh = [Windows.Forms.TextRenderer]::MeasureText($t, $Fnt.ui, (Sz 360 0), [Windows.Forms.TextFormatFlags]::WordBreak).Height
    $h = [Math]::Min(160, [Math]::Max(66, 48 + $mh))
    $App.toast.Tag = @{ Title = $Title; Text = $t; Color = $Colors[$Kind]; Full = $full; Truncated = $trunc; KindName = $Kind }
    $App.toast.Size = (Sz 400 $h)
    $App.toast.Location = (Pt ([Math]::Max(8, $f.ClientSize.Width - 400 - 24)) ([Math]::Max(8, $f.ClientSize.Height - $h - 44)))
    $App.toast.Visible = $true
    $App.toast.BringToFront()
    $App.toast.Invalidate()
    $App.toastTimer.Stop(); $App.toastTimer.Start()
}

function Paint-Footer($c, $ev) {
    $g = $ev.Graphics; $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'ClearTypeGridFit'
    $w = $c.ClientSize.Width; $h = $c.ClientSize.Height
    $pen = New-Object Drawing.Pen($Colors.border, 1); DL $g $pen 0 0 $w 0; $pen.Dispose()
    $dot = $Colors.success; $tb = $Bx.muted
    $left = [string]$gv.Out
    if ($App.Path -and $App.Name) { $left += '   |   Projeto: ' + $App.Name }
    if ($App.Activity) { $dot = $Colors.orange1; $left = $App.Activity; $tb = $Bx.text }
    $b = New-Object Drawing.SolidBrush($dot)
    $g.FillEllipse($b, [single]14, [single]($h / 2 - 3), [single]6, [single]6); $b.Dispose()
    $right = 'Modo: ' + (Get-WorkspaceName) + '   |   F1 Ajuda   F5 Atualizar   F11 Tela cheia'
    Draw-Text $g $left $Fnt.small $tb 28 0 ([Math]::Max(40, $w * 0.45 - 28)) $h $SFV
    Draw-Text $g $right $Fnt.small $Bx.muted ($w * 0.45) 0 ($w * 0.55 - 16) $h $SFR
}
function New-AppIcon {
    $bmp = New-Object Drawing.Bitmap(64, 64)
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $gb = New-Grad 0 0 64 64 $Colors.purple1 $Colors.orange2 45
    $g.FillEllipse($gb, [single]2, [single]2, [single]60, [single]60); $gb.Dispose()
    $pen = New-Object Drawing.Pen($Colors.white, 2); $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
    $g.TranslateTransform(32, 32); $g.ScaleTransform(1.6, 1.6)
    Draw-Icon $g 'graph' 0 0 $pen
    $pen.Dispose(); $g.Dispose()
    return [Drawing.Icon]::FromHandle($bmp.GetHicon())
}

# ----------------------------------------------------------------------
# PROJETOS RECENTES (opcional: so guarda caminhos de pastas quando o usuario ativa)
# Os caminhos ficam em recent.json, separado das preferencias.
# ----------------------------------------------------------------------
function Get-RecentPath { return (Join-Path (Split-Path -Parent (Get-SettingsPath)) 'recent.json') }
function Load-Recent {
    $list = @()
    try {
        $p = Get-RecentPath
        if (Test-Path -LiteralPath $p) {
            $j = (Get-Content -LiteralPath $p -Raw -Encoding UTF8) | ConvertFrom-Json
            foreach ($x in @($j)) {
                $s = [string]$x
                if ($s -and [IO.Path]::IsPathRooted($s) -and (Test-Path -LiteralPath $s -PathType Container) -and ($list -notcontains $s)) { $list += $s }
            }
        }
    } catch {}
    return @($list | Select-Object -First 8)
}
function Save-Recent($list) {
    try {
        $p = Get-RecentPath; $d = Split-Path -Parent $p
        if (-not (Test-Path -LiteralPath $d)) { [void](New-Item -ItemType Directory -Path $d) }
        $json = ConvertTo-Json -InputObject @($list) -Compress
        [IO.File]::WriteAllText($p, $json, (New-Object Text.UTF8Encoding($false)))
    } catch {}
}
function Refresh-RecentList {
    $App.RecentItems = @()
    if ($App.Settings.Remember -eq 'on') { $App.RecentItems = @(Load-Recent) }
    if ($App.recentPanel) { $App.recentPanel.Invalidate() }
}
function Add-Recent([string]$path) {
    if ($App.Settings.Remember -ne 'on' -or -not $path) { return }
    $list = @(Load-Recent)
    $new = @($path) + @($list | Where-Object { $_ -ne $path })
    Save-Recent @($new | Select-Object -First 8)
    Refresh-RecentList
}
function Clear-Recent { Save-Recent @(); Refresh-RecentList }
function Acao-LimparRecentes { Clear-Recent; Show-Toast 'Lista limpa' 'Os projetos recentes foram esquecidos.' 'info' }
function Open-RecentIndex([string]$idx) {
    $i = [int]$idx
    $items = @($App.RecentItems)
    if ($i -lt 0 -or $i -ge $items.Count) { return }
    Open-FolderFlow ([string]$items[$i])
}
function Get-RecentFit([double]$h) { return [Math]::Max(1, [int][Math]::Floor(($h - 56) / 42)) }
function Get-RecentHit([double]$x, [double]$y, [double]$w, [double]$h) {
    $items = @($App.RecentItems)
    if ($App.Settings.Remember -ne 'on' -or $items.Count -eq 0) { return -1 }
    if ($x -lt 10 -or $x -gt ($w - 10) -or $y -lt 48) { return -1 }
    $i = [int][Math]::Floor(($y - 48) / 42)
    if ($i -ge [Math]::Min($items.Count, (Get-RecentFit $h))) { return -1 }
    return $i
}
function Paint-RecentProjects($c, $ev) {
    $g = $ev.Graphics; $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'ClearTypeGridFit'
    $w = $c.ClientSize.Width; $h = $c.ClientSize.Height
    if ($w -lt 120 -or $h -lt 70) { return }
    $path = New-RoundPath 1 1 ($w - 3) ($h - 3) 16
    $g.FillPath($Bx.card, $path)
    $pen = New-Object Drawing.Pen($Colors.border, 1.5); $g.DrawPath($pen, $path); $pen.Dispose(); $path.Dispose()
    Draw-Text $g 'Projetos recentes' $Fnt.h3 $Bx.text 20 12 ($w - 170) 28 $SFL
    $items = @($App.RecentItems)
    if ($App.Settings.Remember -ne 'on') {
        Draw-Text $g 'Para ver aqui os últimos projetos abertos, ative "Lembrar projetos recentes" em Configurações. Só os caminhos das pastas são guardados, apenas neste computador.' $Fnt.small $Bx.muted 20 48 ($w - 40) ($h - 58) $SFW
        return
    }
    if ($items.Count -eq 0) {
        Draw-Text $g 'Nenhum projeto recente ainda. Os projetos que você abrir aparecerão aqui.' $Fnt.small $Bx.muted 20 48 ($w - 40) ($h - 58) $SFW
        return
    }
    Draw-Text $g 'Limpar lista' $Fnt.small $Bx.orange1 ($w - 130) 12 110 28 $SFR
    $n = [Math]::Min($items.Count, (Get-RecentFit $h))
    for ($i = 0; $i -lt $n; $i++) {
        $y = 48 + $i * 42
        if ($i -eq $App.RecentHover) {
            $rp = New-RoundPath 10 $y ($w - 20) 40 10
            $g.FillPath($Bx.cardH, $rp); $rp.Dispose()
        }
        $full = [string]$items[$i]
        $leaf = Split-Path -Leaf $full
        if (-not $leaf) { $leaf = $full }
        Draw-Text $g $leaf $Fnt.bold $Bx.text 22 ($y + 2) ($w - 44) 20 $SFL
        Draw-Text $g $full $Fnt.small $Bx.muted 22 ($y + 21) ($w - 44) 16 $SFL
    }
}

# ----------------------------------------------------------------------
# SEGURANCA DE ARQUIVOS: segredos, arquivos grandes, pastas perigosas
# ----------------------------------------------------------------------
function Test-SensitiveName([string]$n) {
    $l = $n.ToLowerInvariant()
    $leaf = $l.Substring($l.LastIndexOf('/') + 1)
    if ($leaf -match '^\.env(\..+)?$' -and $leaf -notmatch '\.(example|sample|template|dist)$') { return $true }
    if ($leaf -match '\.(pem|key|pfx|p12|jks|keystore|ppk|kdbx)$') { return $true }
    if ($leaf -match '^id_(rsa|dsa|ecdsa|ed25519)$') { return $true }
    if ($leaf -match '^(credentials|secrets?)(\.(json|ya?ml|xml|txt|ini|conf|toml))?$') { return $true }
    if ($leaf -match '^\.(npmrc|pypirc|netrc|git-credentials|htpasswd)$') { return $true }
    if ($leaf -match '^(service[-_]?account.*|.*[-_]credentials)\.json$') { return $true }
    return $false
}
# Entradas do "git status" (caminhos exatos, sem aspas) como objetos {X, Y, Path}
function Get-StatusEntries {
    $r = Invoke-Git @('-c', 'core.quotepath=false', 'status', '--porcelain=v1', '-z', '--untracked-files=all') -Quiet
    $res = @()
    if (-not $r.Ok -or -not $r.Out) { return $res }
    $parts = $r.Out.Split([char]0)
    $i = 0
    while ($i -lt $parts.Count) {
        $e = [string]$parts[$i]; $i++
        if ($e.Length -lt 4) { continue }
        $x = $e.Substring(0, 1); $y = $e.Substring(1, 1)
        if ($x -eq 'R' -or $x -eq 'C' -or $y -eq 'R' -or $y -eq 'C') { $i++ }
        $res += [pscustomobject]@{ X = $x; Y = $y; Path = $e.Substring(3) }
    }
    return $res
}
function Get-RiskReport([string[]]$rel, [string]$base) {
    $sens = @(); $large = @()
    foreach ($r in @($rel | Select-Object -First 5000)) {
        if (-not $r) { continue }
        if (Test-SensitiveName ($r -replace '\\', '/')) { $sens += $r }
        try {
            $fi = New-Object IO.FileInfo((Join-Path $base $r))
            if ($fi.Exists -and $fi.Length -ge 52428800) { $large += @{ Path = $r; MB = [int][Math]::Round($fi.Length / 1048576) } }
        } catch {}
    }
    return @{ Sensitive = $sens; Large = $large }
}
function ConvertTo-IgnorePattern([string]$rel) {
    $s = ($rel -replace '\\', '/')
    $s = $s -replace '([\\\*\?\[\]])', '\$1'
    if ($s.StartsWith('#') -or $s.StartsWith('!')) { $s = '\' + $s }
    if ($s.EndsWith(' ')) { $s = $s.Substring(0, $s.Length - 1) + '\ ' }
    return '/' + $s
}
# Acrescenta linhas ao .gitignore (cria se nao existir; nunca remove nada). Retorna $true/$false
function Add-ToGitignore([string[]]$rels) {
    try {
        $file = Join-Path $App.Path '.gitignore'
        $cur = ''
        if (Test-Path -LiteralPath $file) { $cur = [IO.File]::ReadAllText($file) }
        $have = @($cur -split '\r?\n')
        $add = @()
        foreach ($r in $rels) {
            if ($r -match '[\r\n]') { continue }
            $pat = ConvertTo-IgnorePattern $r
            if ($have -notcontains $pat -and $add -notcontains $pat) { $add += $pat }
        }
        if ($add.Count -eq 0) { return $true }
        $nl = "`r`n"
        $txt = ''
        if ($cur.Length -gt 0 -and -not $cur.EndsWith("`n")) { $txt += $nl }
        $mark = '# Arquivos sensíveis ou grandes (adicionado pelo GitHub Team Helper)'
        if ($have -notcontains $mark) { $txt += $mark + $nl }
        $txt += (($add -join $nl) + $nl)
        [IO.File]::AppendAllText($file, $txt, (New-Object Text.UTF8Encoding($false)))
        return $true
    } catch { return $false }
}
function Test-HasCommits { return (Invoke-Git @('rev-parse', '--verify', '-q', 'HEAD') -Quiet).Ok }
function Svc-Unstage([string[]]$paths) {
    $target = @('.'); if ($paths -and $paths.Count -gt 0) { $target = $paths }
    $r = Invoke-Git (@('restore', '--staged', '--') + $target)
    if (-not $r.Ok -and -not (Test-HasCommits)) {
        $r = Invoke-Git (@('rm', '--cached', '-r', '-q', '--') + $target)
    }
    return $r
}
# Antes de "git add": avisa sobre segredos e arquivos grandes. Retorna $true para continuar.
function Confirm-RiskFiles([switch]$ScanOnly) {
    $ent = @(Get-StatusEntries)
    $byPath = @{}
    foreach ($e in $ent) { $byPath[$e.Path] = $e }
    $rel = @($ent | Where-Object { $_.X -ne 'D' -and $_.Y -ne 'D' } | ForEach-Object { $_.Path })
    $rep = Get-RiskReport $rel $App.Path
    if ($rep.Sensitive.Count -eq 0 -and $rep.Large.Count -eq 0) { return $true }
    $t = ''
    if ($rep.Sensitive.Count -gt 0) {
        $t += "Estes arquivos podem conter SENHAS ou CHAVES:`n" + (Format-Changes $rep.Sensitive 8) + "`n`nNão envie esses arquivos ao GitHub: quem tiver acesso ao repositório poderá lê-los.`n`n"
    }
    if ($rep.Large.Count -gt 0) {
        $t += "Arquivos muito grandes (o GitHub recusa acima de 100 MB):`n" + ((@($rep.Large | Select-Object -First 6) | ForEach-Object { $_.Path + ' (' + $_.MB + ' MB)' }) -join "`n") + "`n`n"
    }
    $flag = @($rep.Sensitive) + @($rep.Large | ForEach-Object { $_.Path })
    $canIgnore = @($flag | Where-Object { $byPath[$_] -and ($byPath[$_].X -eq '?' -or $byPath[$_].X -eq 'A') })
    $keepText = 'Incluir mesmo assim'; if ($ScanOnly) { $keepText = 'Manter como está' }
    $btns = @((New-BtnDef 'Cancelar' 'cancel' 'secondary'))
    if ($canIgnore.Count -gt 0) { $btns += (New-BtnDef 'Ignorar esses arquivos' 'ignore' 'primary') }
    $btns += (New-BtnDef $keepText 'keep' 'warn')
    $t += 'O que deseja fazer? "Ignorar" coloca os arquivos no .gitignore (eles continuam na sua pasta, só deixam de ir para o Git).'
    $d = Show-Dialog -Title 'Arquivos que merecem atenção' -Message $t -Kind 'warn' -Buttons $btns
    if ($d.Result -eq 'ignore') {
        $staged = @($canIgnore | Where-Object { $byPath[$_].X -eq 'A' })
        if ($staged.Count -gt 0) { [void](Svc-Unstage $staged) }
        if (Add-ToGitignore $canIgnore) {
            $rest = @($flag | Where-Object { $canIgnore -notcontains $_ })
            if ($rest.Count -gt 0) {
                Show-Msg 'Alguns arquivos continuam no Git' ("Estes arquivos já fazem parte do projeto, então o .gitignore não os afeta:`n`n" + (Format-Changes $rest 8) + "`n`nSe não devem ser enviados, remova-os do projeto manualmente.") 'warn'
            }
            Show-Toast 'Arquivos ignorados' ('Adicionados ao .gitignore: ' + $canIgnore.Count) 'success'
            return $true
        }
        Show-Msg 'Não foi possível atualizar o .gitignore' 'Verifique se o arquivo não está aberto ou protegido. Nada foi enviado.' 'error'
        return $false
    }
    if ($d.Result -eq 'keep') { return $true }
    return $false
}
function Acao-VerificarSensiveis {
    if (-not (Test-RepoReady -Title 'Arquivos sensíveis')) { return }
    $ent = @(Get-StatusEntries)
    if ($ent.Count -eq 0) { Show-Msg 'Arquivos sensíveis' 'Não há arquivos novos ou alterados para verificar.' 'info'; return }
    if (Confirm-RiskFiles -ScanOnly) { Show-Toast 'Verificação concluída' 'Nenhum arquivo suspeito pendente (ou mantido por sua escolha).' 'success' }
}

# Pastas onde iniciar o Git seria um erro (retorna @{Level; Text} ou $null)
function Get-UnsafeFolder([string]$p) {
    try { $full = [IO.Path]::GetFullPath($p).TrimEnd('\') } catch { return @{ Level = 'block'; Text = 'Caminho de pasta inválido.' } }
    $root = [IO.Path]::GetPathRoot($full).TrimEnd('\')
    if ($full -ieq $root) { return @{ Level = 'block'; Text = "Esta é a raiz de um disco ($full).`n`nIniciar o Git aqui faria o Git enxergar todo o disco. Escolha uma pasta de projeto." } }
    $sys = @($env:windir, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData) | Where-Object { $_ }
    foreach ($s in $sys) {
        $sf = $s.TrimEnd('\')
        if ($full -ieq $sf -or $full.StartsWith($sf + '\', [StringComparison]::OrdinalIgnoreCase)) { return @{ Level = 'block'; Text = "Esta é uma pasta do sistema do Windows ou de programas instalados:`n$full`n`nEscolha uma pasta de projeto sua." } }
    }
    $up = $env:USERPROFILE
    if ($up) {
        $upf = $up.TrimEnd('\')
        $usersDir = Split-Path -Parent $upf
        if ($usersDir -and $full -ieq $usersDir.TrimEnd('\')) { return @{ Level = 'block'; Text = "Esta pasta contém os perfis de todos os usuários do Windows.`n`nEscolha uma pasta de projeto." } }
        $personal = @($upf, (Join-Path $upf 'Desktop'), (Join-Path $upf 'Documents'), (Join-Path $upf 'Downloads'), [Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('MyDocuments'))
        foreach ($pp in $personal) {
            if ($pp -and $full -ieq $pp.TrimEnd('\')) { return @{ Level = 'warn'; Text = "Esta é uma pasta pessoal geral ($full), com muitos arquivos que não são de um único projeto.`n`nO ideal é criar uma subpasta para o projeto e iniciar o Git nela." } }
        }
    }
    return $null
}

# Resumo da pasta (limitado a 3000 arquivos para ser rapido)
function Get-FolderStats([string]$p) {
    $base = $p.TrimEnd('\')
    $items = @(Get-ChildItem -LiteralPath $base -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' } | Select-Object -First 3000)
    $bytes = 0; $names = @()
    foreach ($f in $items) {
        $bytes += $f.Length
        $names += $f.FullName.Substring($base.Length).TrimStart('\').Replace('\', '/')
    }
    $rep = Get-RiskReport $names $base
    return @{ Count = $items.Count; Bytes = $bytes; Truncated = ($items.Count -ge 3000); Names = $names; Sensitive = @($rep.Sensitive); Large = @($rep.Large) }
}
function Format-Bytes([double]$b) {
    if ($b -ge 1073741824) { return ('{0:N1} GB' -f ($b / 1073741824)) }
    if ($b -ge 1048576) { return ('{0:N1} MB' -f ($b / 1048576)) }
    if ($b -ge 1024) { return ('{0:N0} KB' -f ($b / 1024)) }
    return ('{0:N0} bytes' -f $b)
}

# ----------------------------------------------------------------------
# .GITIGNORE: modelos (nunca sobrescreve: cria, ou acrescenta um bloco novo)
# ----------------------------------------------------------------------
$GitignoreTemplates = @('Geral (recomendado)', 'Node.js / Web', 'Python', '.NET / Visual Studio', 'Java')
function Get-GitignoreText([string]$tpl) {
    $base = @'
# Sistema operacional
Thumbs.db
ehthumbs.db
Desktop.ini
$RECYCLE.BIN/
.DS_Store

# Editores e IDEs
.vscode/
.idea/
*.swp
*.suo
*.user

# Segredos e configurações locais (nunca envie ao GitHub)
.env
.env.*
!.env.example
*.pem
*.key
*.pfx
*.p12

# Logs e temporários
*.log
*.tmp
'@
    $extra = ''
    switch ($tpl) {
        'Node.js / Web' { $extra = "`n# Node.js / Web`nnode_modules/`ndist/`nbuild/`ncoverage/`nnpm-debug.log*`n.cache/" }
        'Python' { $extra = "`n# Python`n__pycache__/`n*.py[cod]`n.venv/`nvenv/`n*.egg-info/`n.pytest_cache/`ndist/`nbuild/" }
        '.NET / Visual Studio' { $extra = "`n# .NET / Visual Studio`nbin/`nobj/`n.vs/`npackages/`n*.userprefs`nTestResults/" }
        'Java' { $extra = "`n# Java`ntarget/`nbuild/`n.gradle/`n*.class`n*.jar`nout/" }
    }
    return (($base -replace "`r?`n", "`r`n") + ($extra -replace "`r?`n", "`r`n") + "`r`n")
}
function Get-DetectedTemplate([string[]]$names) {
    $l = @($names | ForEach-Object { ([string]$_).ToLowerInvariant() })
    if (@($l | Where-Object { $_ -match '(^|/)package\.json$' }).Count -gt 0) { return 'Node.js / Web' }
    if (@($l | Where-Object { $_ -match '\.(sln|csproj|vbproj|fsproj)$' }).Count -gt 0) { return '.NET / Visual Studio' }
    if (@($l | Where-Object { $_ -match '(^|/)(pom\.xml|build\.gradle|build\.gradle\.kts)$|\.java$' }).Count -gt 0) { return 'Java' }
    if (@($l | Where-Object { $_ -match '\.py$|(^|/)(requirements\.txt|pyproject\.toml)$' }).Count -gt 0) { return 'Python' }
    return 'Geral (recomendado)'
}
# Cria o .gitignore ou acrescenta o modelo ao final. Retorna 'created' | 'appended' | 'exists' | 'error'
function Write-GitignoreFile([string]$dir, [string]$tpl) {
    try {
        $file = Join-Path $dir '.gitignore'
        $enc = New-Object Text.UTF8Encoding($false)
        $marker = '# --- Modelo GitHub Team Helper: ' + $tpl + ' ---'
        $body = $marker + "`r`n" + (Get-GitignoreText $tpl)
        if (Test-Path -LiteralPath $file) {
            $cur = [IO.File]::ReadAllText($file)
            if ($cur.Contains($marker)) { return 'exists' }
            $pre = ''
            if ($cur.Length -gt 0) { if ($cur.EndsWith("`n")) { $pre = "`r`n" } else { $pre = "`r`n`r`n" } }
            [IO.File]::AppendAllText($file, ($pre + $body), $enc)
            return 'appended'
        }
        [IO.File]::WriteAllText($file, $body, $enc)
        return 'created'
    } catch { return 'error' }
}
function Acao-Gitignore {
    if (-not (Test-RepoReady -Title '.gitignore')) { return }
    $exists = Test-Path -LiteralPath (Join-Path $App.Path '.gitignore')
    $names = @(Get-ChildItem -LiteralPath $App.Path -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' } | Select-Object -First 1500 | ForEach-Object { $_.FullName.Substring($App.Path.TrimEnd('\').Length).TrimStart('\').Replace('\', '/') })
    $def = Get-DetectedTemplate $names
    $what = 'O arquivo .gitignore ainda não existe e será criado.'
    if ($exists) { $what = 'Já existe um .gitignore: o que você escreveu será mantido e o modelo entra no final.' }
    $tpl = Select-FromList 'Modelo de .gitignore' ("O .gitignore diz ao Git quais arquivos NÃO devem ir para o projeto (senhas, pastas de bibliotecas, temporários).`n`n$what`nSugestão para este projeto: $def") $GitignoreTemplates $def 'Aplicar'
    if (-not $tpl) { return }
    $res = Write-GitignoreFile $App.Path $tpl
    switch ($res) {
        'created'  { Show-Toast '.gitignore criado' ('Modelo aplicado: ' + $tpl) 'success' }
        'appended' { Show-Toast '.gitignore atualizado' ('Modelo acrescentado: ' + $tpl) 'success' }
        'exists'   { Show-Msg '.gitignore' "Este modelo já está no seu .gitignore. Nada foi alterado." 'info' }
        default    { Show-Msg 'Erro' 'Não foi possível gravar o .gitignore. Verifique se o arquivo não está aberto ou protegido.' 'error' }
    }
    Update-State
}

# ----------------------------------------------------------------------
# PASTA SEM GIT: assistente para iniciar o Git (git init) com seguranca
# ----------------------------------------------------------------------
function Show-InitDialog([string]$Folder, [string]$Summary, [string[]]$Templates, [string]$DefTpl, [bool]$HasIgnore) {
    $dlg = New-Object Windows.Forms.Form
    $dlg.Text = 'GitHub Team Helper'
    $dlg.FormBorderStyle = 'FixedDialog'; $dlg.StartPosition = 'CenterParent'
    $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false; $dlg.ShowInTaskbar = $false
    $dlg.BackColor = $Colors.bg; $dlg.ForeColor = $Colors.text; $dlg.Font = $Fnt.ui
    $dlg.ClientSize = (Sz 640 556); $dlg.Tag = $null
    $dlg.Add_HandleCreated({ param($sd, $ev) Set-DarkTitle $sd })

    $strip = New-Object Windows.Forms.Panel
    $strip.BackColor = $Colors.purple2; $strip.Location = (Pt 0 0); $strip.Size = (Sz 640 4)
    $dlg.Controls.Add($strip)
    $dlg.Controls.Add((New-Label 'Iniciar Git nesta pasta' $Fnt.h2 $Colors.text 28 20 584 28))
    $lp = New-Label $Folder $Fnt.small $Colors.accent 28 50 584 18
    $lp.AutoEllipsis = $true
    $dlg.Controls.Add($lp)
    $ls = New-Label $Summary $Fnt.ui $Colors.text 28 76 584 118
    $ls.AutoEllipsis = $false
    $dlg.Controls.Add($ls)

    $dlg.Controls.Add((New-Label 'Nome da branch inicial:' $Fnt.bold $Colors.text 28 202 300 20))
    $tbB = New-Object Windows.Forms.TextBox
    $tbB.Name = 'tbBranch'; $tbB.Text = 'main'; $tbB.Location = (Pt 28 226); $tbB.Size = (Sz 220 28)
    $tbB.BackColor = $Colors.panel2; $tbB.ForeColor = $Colors.text; $tbB.BorderStyle = 'FixedSingle'; $tbB.Font = $Fnt.ui
    $dlg.Controls.Add($tbB)

    $cbI = New-Object Windows.Forms.CheckBox
    $cbI.Name = 'cbIgn'; $cbI.Text = 'Criar .gitignore (evita enviar senhas, bibliotecas e temporários)'
    $cbI.Location = (Pt 28 270); $cbI.Size = (Sz 584 24); $cbI.FlatStyle = 'Flat'; $cbI.ForeColor = $Colors.text; $cbI.BackColor = $Colors.bg
    $cbI.Checked = (-not $HasIgnore)
    if ($HasIgnore) { $cbI.Text = 'Já existe um .gitignore: ele será mantido'; $cbI.Enabled = $false }
    $dlg.Controls.Add($cbI)
    $cm = New-Object Windows.Forms.ComboBox
    $cm.Name = 'cmbTpl'; $cm.DropDownStyle = 'DropDownList'; $cm.FlatStyle = 'Flat'
    $cm.Location = (Pt 52 298); $cm.Size = (Sz 300 26); $cm.BackColor = $Colors.panel2; $cm.ForeColor = $Colors.text; $cm.Font = $Fnt.ui
    foreach ($t in $Templates) { [void]$cm.Items.Add($t) }
    $ix = $cm.Items.IndexOf($DefTpl); if ($ix -lt 0) { $ix = 0 }
    $cm.SelectedIndex = $ix; $cm.Enabled = (-not $HasIgnore)
    $dlg.Controls.Add($cm)
    $cbI.Add_CheckedChanged({ param($sd, $ev) $sd.FindForm().Controls['cmbTpl'].Enabled = $sd.Checked })

    $cbC = New-Object Windows.Forms.CheckBox
    $cbC.Name = 'cbCommit'; $cbC.Text = 'Fazer o primeiro commit com os arquivos da pasta'
    $cbC.Location = (Pt 28 340); $cbC.Size = (Sz 584 24); $cbC.FlatStyle = 'Flat'; $cbC.ForeColor = $Colors.text; $cbC.BackColor = $Colors.bg
    $cbC.Checked = $true
    $dlg.Controls.Add($cbC)

    $cbR = New-Object Windows.Forms.CheckBox
    $cbR.Name = 'cbRemote'; $cbR.Text = 'Conectar a um repositório do GitHub (remoto origin)'
    $cbR.Location = (Pt 28 374); $cbR.Size = (Sz 584 24); $cbR.FlatStyle = 'Flat'; $cbR.ForeColor = $Colors.text; $cbR.BackColor = $Colors.bg
    $dlg.Controls.Add($cbR)
    $tbU = New-Object Windows.Forms.TextBox
    $tbU.Name = 'tbUrl'; $tbU.Location = (Pt 52 402); $tbU.Size = (Sz 560 28); $tbU.Enabled = $false
    $tbU.BackColor = $Colors.panel2; $tbU.ForeColor = $Colors.text; $tbU.BorderStyle = 'FixedSingle'; $tbU.Font = $Fnt.ui
    $dlg.Controls.Add($tbU)
    $cbR.Add_CheckedChanged({ param($sd, $ev) $sd.FindForm().Controls['tbUrl'].Enabled = $sd.Checked })
    $dlg.Controls.Add((New-Label 'Exemplo: https://github.com/usuario/projeto.git' $Fnt.small $Colors.muted 52 432 560 18))

    $le = New-Label '' $Fnt.ui $Colors.error 28 458 584 44
    $le.Name = 'lblErr'; $le.AutoEllipsis = $false
    $dlg.Controls.Add($le)

    $bo = New-Btn 'Iniciar Git aqui' 'primary' 190 38
    $bo.Location = (Pt 422 504)
    $bc = New-Btn 'Cancelar' 'secondary' 120 38
    $bc.Location = (Pt 292 504)
    $bo.Add_Click({ param($sd, $ev)
        $fm = $sd.FindForm()
        $br = $fm.Controls['tbBranch'].Text.Trim()
        $e = Get-BranchNameError $br
        $url = $fm.Controls['tbUrl'].Text.Trim()
        if (-not $e -and $fm.Controls['cbRemote'].Checked) { $e = Get-RepoUrlError $url }
        if ($e) { $fm.Controls['lblErr'].Text = $e; return }
        $fm.Tag = @{ Branch = $br; Gitignore = $fm.Controls['cbIgn'].Checked; Template = [string]$fm.Controls['cmbTpl'].SelectedItem; Commit = $fm.Controls['cbCommit'].Checked; Remote = $fm.Controls['cbRemote'].Checked; Url = $url }
        $fm.Close()
    })
    $bc.Add_Click({ param($sd, $ev) $sd.FindForm().Close() })
    $dlg.Controls.Add($bo); $dlg.Controls.Add($bc)
    $dlg.AcceptButton = $bo; $dlg.CancelButton = $bc
    Fit-Dialog $dlg
    [void](Show-Modal $dlg)
    $res = $dlg.Tag
    $dlg.Dispose()
    return $res
}

function Start-InitWizard([string]$p) {
    $unsafe = Get-UnsafeFolder $p
    if ($unsafe -and $unsafe.Level -eq 'block') { Show-Msg 'Pasta não recomendada' ($unsafe.Text + "`n`nNada foi alterado.") 'error'; return }
    if ($unsafe) {
        if (-not (Confirm-Action 'Atenção' ($unsafe.Text + "`n`nDeseja continuar mesmo assim?") 'Continuar mesmo assim' 'danger')) { Write-Info 'Cancelado. Nada foi alterado.'; return }
    }
    Set-Activity 'Analisando a pasta...'
    [Windows.Forms.Application]::DoEvents()
    $st = Get-FolderStats $p
    Set-Activity ''
    $hasIgnore = Test-Path -LiteralPath (Join-Path $p '.gitignore')
    $def = Get-DetectedTemplate $st.Names
    $sum = 'Esta pasta ainda não é um repositório Git.'
    if ($st.Count -eq 0) { $sum += "`nEla está vazia." }
    else {
        $more = ''; if ($st.Truncated) { $more = '+' }
        $sum += "`nConteúdo: $($st.Count)$more arquivo(s), cerca de " + (Format-Bytes $st.Bytes) + '.'
    }
    if ($def -ne 'Geral (recomendado)') { $sum += "`nTipo de projeto provável: $def." }
    if ($st.Sensitive.Count -gt 0) { $sum += "`n! $($st.Sensitive.Count) arquivo(s) parecem conter senhas ou chaves (ex.: $($st.Sensitive[0])). Isso será conferido antes do commit." }
    if ($st.Large.Count -gt 0) { $sum += "`n! $($st.Large.Count) arquivo(s) com mais de 50 MB (o GitHub recusa acima de 100 MB)." }
    $sum += "`nNenhum arquivo seu será apagado ou alterado; o Git cria apenas uma pasta oculta chamada .git."
    $o = Show-InitDialog $p $sum $GitignoreTemplates $def $hasIgnore
    if (-not $o) { Write-Info 'Cancelado. Nada foi alterado.'; return }

    Assert-SafeRef $o.Branch
    $r = Invoke-Git @('init') -WorkDir $p
    if (-not $r.Ok) { Show-GitError $r 'Nada foi alterado na pasta.'; return }
    [void](Invoke-Git @('symbolic-ref', 'HEAD', ('refs/heads/' + $o.Branch)) -WorkDir $p)
    $App.Path = $p
    $notes = @('Repositório Git criado (branch ' + $o.Branch + ').')

    if ($o.Gitignore -and -not $hasIgnore) {
        $w = Write-GitignoreFile $p $o.Template
        if ($w -eq 'created') { $notes += '.gitignore criado (' + $o.Template + ').' } else { $notes += 'Não foi possível criar o .gitignore.' }
    }
    if ($o.Commit) {
        if ($st.Count -eq 0 -and -not ($o.Gitignore -and -not $hasIgnore)) { $notes += 'Sem arquivos para o primeiro commit.' }
        elseif (-not (Ensure-GitUser)) { $notes += 'Primeiro commit não feito: usuário Git não configurado.' }
        elseif (-not (Confirm-RiskFiles)) { $notes += 'Primeiro commit cancelado na conferência de arquivos.' }
        else {
            $a = Svc-Add @()
            if (-not $a.Ok) { Show-GitError $a; $notes += 'O primeiro commit não foi feito.' }
            else {
                $q = Invoke-Git @('diff', '--cached', '--quiet') -Quiet
                if ($q.ExitCode -eq 0) { $notes += 'Nada para commitar (tudo ignorado).' }
                else {
                    $c = Svc-Commit 'Commit inicial'
                    if ($c.Ok) { $notes += 'Primeiro commit criado ("Commit inicial").' } else { Show-GitError $c; $notes += 'O primeiro commit não foi feito.' }
                }
            }
        }
    }
    if ($o.Remote) {
        $rr = Invoke-Git @('remote', 'add', 'origin', $o.Url)
        if ($rr.Ok) { $notes += 'Conectado ao GitHub (origin). Use Enviar/Publicar para mandar o projeto.' } else { Show-GitError $rr; $notes += 'Não foi possível conectar ao GitHub.' }
    }
    Show-ProjectPanel $p
    Show-Msg 'Projeto pronto' (($notes | ForEach-Object { [string][char]0x2022 + ' ' + $_ }) -join "`n") 'success'
}

# Abre uma pasta: repositorio existente -> painel; pasta sem Git -> assistente (nunca inicia sem confirmar)
function Open-FolderFlow([string]$p) {
    if (-not $p -or -not (Test-Path -LiteralPath $p -PathType Container)) {
        Show-Msg 'Pasta não encontrada' "A pasta não existe mais:`n$p`n`nNada foi alterado." 'error'
        return
    }
    $root = Resolve-RepoRoot $p
    if ($root) {
        if ($root -ne $p) { Write-Info ('O repositório está na pasta: ' + $root) }
        Show-ProjectPanel $root
        return
    }
    if (Test-Path -LiteralPath (Join-Path $p '.git')) {
        $chk = Invoke-Git @('rev-parse', '--show-toplevel') -WorkDir $p -Quiet
        Show-GitError $chk 'Já existe uma pasta .git aqui, mas o Git recusou abri-la. Nada foi alterado.'
        return
    }
    Start-InitWizard $p
}
function Acao-IniciarGitPasta {
    $p = Select-Folder 'Escolha a pasta que ainda não usa Git (ou crie uma nova)' '' $true
    if ($p) { Open-FolderFlow $p }
}

# ----------------------------------------------------------------------
# REMOTO, GITHUB E PASTA
# ----------------------------------------------------------------------
function Acao-ConfigurarRemoto {
    if (-not (Test-RepoReady -Title 'Configurar remoto')) { return }
    $cur = ''
    if (Test-Origin) { $cur = (Invoke-Git @('remote', 'get-url', 'origin') -Quiet).Out.Trim() }
    $txt = "Informe a URL do repositório no GitHub.`n`nExemplo: https://github.com/usuario/projeto.git"
    if ($cur) { $txt = "Remoto atual:`n" + (Protect-Text $cur) + "`n`nInforme a nova URL para trocar o endereço." }
    $url = $null
    while ($true) {
        $url = Ask-Text 'Configurar remoto (origin)' $txt 'URL do repositório:' '' 'Continuar'
        if ($null -eq $url) { return }
        $e = Get-RepoUrlError $url
        if (-not $e) { break }
        Show-Msg 'URL inválida' $e 'error'
    }
    if ($cur) {
        if (-not (Confirm-Action 'Trocar o remoto' "O endereço do GitHub deste projeto será trocado.`n`nDe:`n$(Protect-Text $cur)`nPara:`n$(Protect-Text $url)`n`nComando:`ngit remote set-url origin <URL>" 'Trocar' 'warn')) { Write-Info 'Cancelado.'; return }
        $r = Invoke-Git @('remote', 'set-url', 'origin', $url)
    } else {
        $r = Invoke-Git @('remote', 'add', 'origin', $url)
    }
    Update-State
    if ($r.Ok) { Show-Toast 'Remoto configurado' 'O projeto está conectado ao GitHub (origin).' 'success' } else { Show-GitError $r }
}
function Get-GitHubWebUrl([string]$u) {
    $u = $u.Trim()
    if ($u -match '^git@github\.com:(?<p>[\w.\-]+/[\w.\-]+?)(\.git)?/?$') { return 'https://github.com/' + $Matches['p'] }
    if ($u -match '^(?:https?|ssh)://(?:[^/@\s]+@)?github\.com(?::\d+)?/(?<p>[\w.\-]+/[\w.\-]+?)(\.git)?/?$') { return 'https://github.com/' + $Matches['p'] }
    return $null
}
function Acao-AbrirGitHub {
    if (-not (Test-RepoReady -Title 'Abrir no GitHub')) { return }
    if (-not (Test-Origin)) { Show-Msg 'Abrir no GitHub' "Este projeto ainda não está conectado ao GitHub.`n`nUse 'Configurar remoto' em Mais comandos." 'warn'; return }
    $u = (Invoke-Git @('remote', 'get-url', 'origin') -Quiet).Out.Trim()
    $web = Get-GitHubWebUrl $u
    if (-not $web) { Show-Msg 'Abrir no GitHub' "O remoto não é um endereço do github.com, então não foi aberto:`n$(Protect-Text $u)" 'info'; return }
    try { Start-Process $web; Write-Info ('Aberto no navegador: ' + $web) }
    catch { Show-Msg 'Erro' ('Não foi possível abrir o navegador: ' + (Protect-Text $_.Exception.Message)) 'error' }
}
function Acao-AbrirPasta {
    if (-not $App.Path -or -not (Test-Path -LiteralPath $App.Path -PathType Container)) { Show-Msg 'Abrir pasta' 'A pasta do projeto não foi encontrada.' 'error'; return }
    try { [void][Diagnostics.Process]::Start('explorer.exe', ('"' + $App.Path + '"')) }
    catch { Show-Msg 'Erro' ('Não foi possível abrir a pasta: ' + (Protect-Text $_.Exception.Message)) 'error' }
}

# ----------------------------------------------------------------------
# DESFAZER COM SEGURANCA: tirar da preparacao e desfazer o ultimo commit (sem perder arquivos)
# ----------------------------------------------------------------------
function Acao-Unstage {
    if (-not (Test-RepoReady -NoBusy -Title 'Desfazer preparação')) { return }
    $st = @(Get-StatusEntries | Where-Object { $_.X -ne ' ' -and $_.X -ne '?' -and $_.X -ne '!' })
    if ($st.Count -eq 0) { Show-Msg 'Desfazer preparação' 'Não há nada preparado (staged) para desfazer.' 'info'; return }
    $lines = @($st | ForEach-Object { $_.X + ' ' + $_.Path })
    $txt = "Tirar da preparação ($($st.Count) item(ns))?`n`n" + (Format-Changes $lines 8) + "`n`nOs arquivos NÃO são alterados nem apagados: eles só deixam de estar marcados para o próximo commit.`n`nComando:`ngit restore --staged"
    if (-not (Confirm-Action 'Desfazer preparação' $txt 'Desfazer preparação' 'info')) { Write-Info 'Cancelado.'; return }
    $r = Svc-Unstage @()
    Update-State
    if ($r.Ok) { Show-Toast 'Preparação desfeita' 'Seus arquivos continuam como estavam.' 'success' } else { Show-GitError $r }
}
function Acao-DesfazerCommit {
    if (-not (Test-RepoReady -NeedBranch -NoBusy -Title 'Desfazer último commit')) { return }
    if (-not (Test-HasCommits)) { Show-Msg 'Desfazer último commit' 'Ainda não há commits neste projeto.' 'info'; return }
    if (-not (Invoke-Git @('rev-parse', '-q', '--verify', 'HEAD~1') -Quiet).Ok) {
        Show-Msg 'Desfazer último commit' 'Este é o primeiro commit do projeto, então não há um commit anterior para voltar por aqui.' 'info'
        return
    }
    $pushed = Invoke-Git @('branch', '-r', '--contains', 'HEAD') -Quiet
    if ($pushed.Ok -and $pushed.Out.Trim()) {
        Show-Msg 'Commit já enviado' "O último commit já foi enviado ao GitHub.`n`nDesfazê-lo aqui deixaria o seu projeto diferente do GitHub e exigiria um envio forçado, que esta ferramenta não faz por segurança.`n`nSe precisar corrigir, crie um novo commit com a correção." 'warn'
        return
    }
    $last = (Invoke-Git @('log', '-1', '--pretty=format:%h %s') -Quiet).Out.Trim()
    $txt = "Desfazer o último commit?`n`n$last`n`nOs arquivos e as alterações PERMANECEM na sua pasta e voltam a ficar preparados (staged) para um novo commit.`n`nComando:`ngit reset --soft HEAD~1"
    if (-not (Confirm-Action 'Desfazer último commit' $txt 'Desfazer commit' 'warn')) { Write-Info 'Cancelado.'; return }
    $r = Invoke-Git @('reset', '--soft', 'HEAD~1')
    Update-State
    if ($r.Ok) { Show-Toast 'Commit desfeito' 'As alterações voltaram para a área de preparação.' 'success' } else { Show-GitError $r }
}

# ----------------------------------------------------------------------
# STATUS AMIGAVEL, HISTORICO, DIAGNOSTICO E AJUDA
# ----------------------------------------------------------------------
function Acao-Status {
    if (-not $App.Path) { return }
    [void](Invoke-Git @('status'))
    Update-State
    $ent = @(Get-StatusEntries)
    $conf = @($ent | Where-Object { ($_.X + $_.Y) -match '^(DD|AU|UD|UA|DU|AA|UU)$' })
    $staged = @($ent | Where-Object { $_.X -ne ' ' -and $_.X -ne '?' -and $_.X -ne '!' -and $conf -notcontains $_ })
    $modif = @($ent | Where-Object { $_.Y -ne ' ' -and $_.Y -ne '?' -and $_.Y -ne '!' -and $conf -notcontains $_ })
    $new = @($ent | Where-Object { $_.X -eq '?' })
    $ok = [string][char]0x2713
    $t = "Projeto: $($App.Name)`nBranch atual: $($App.Branch)`nSituação: $($App.StatusText)`n"
    if ($App.Tip) { $t += "`nPróximo passo sugerido:`n$($App.Tip)`n" }
    if ($conf.Count -gt 0) { $t += "`n" + [string][char]0x00D7 + " CONFLITOS ($($conf.Count)) - resolva nestes arquivos:`n" + (($conf | Select-Object -First 15 | ForEach-Object { '   ' + $_.Path }) -join "`n") + "`n" }
    if ($staged.Count -gt 0) { $t += "`n$ok Preparados para o commit ($($staged.Count)):`n" + (($staged | Select-Object -First 15 | ForEach-Object { '   ' + $_.X + ' ' + $_.Path }) -join "`n") + "`n" }
    if ($modif.Count -gt 0) { $t += "`n! Alterados, ainda não preparados ($($modif.Count)):`n" + (($modif | Select-Object -First 15 | ForEach-Object { '   ' + $_.Y + ' ' + $_.Path }) -join "`n") + "`n" }
    if ($new.Count -gt 0) { $t += "`n! Arquivos novos ainda sem Git ($($new.Count)):`n" + (($new | Select-Object -First 15 | ForEach-Object { '   ' + $_.Path }) -join "`n") + "`n" }
    if ($ent.Count -eq 0) { $t += "`n$ok Nenhuma alteração pendente.`n" }
    $t += "`nLegenda: M = modificado, A = adicionado, D = apagado, R = renomeado"
    Show-TextDialog 'Status do projeto' $t 'info'
}
function Acao-Historico {
    if (-not (Test-RepoReady -Title 'Histórico')) { return }
    if (-not (Test-HasCommits)) { Show-Msg 'Histórico' 'Ainda não há commits neste projeto.' 'info'; return }
    $r = Invoke-Git @('log', '--graph', '--decorate', '--all', '-n', '80', '--pretty=format:%h  %s  (%ar)%d')
    if (-not $r.Ok) { Show-GitError $r; return }
    Show-TextDialog 'Histórico de commits (últimos 80)' $r.Text 'info'
}
function Add-DiagLine($list, [string]$kind, [string]$text) {
    $mark = '  '
    switch ($kind) {
        'ok'   { $mark = [string][char]0x2713 + ' ' }
        'warn' { $mark = '! ' }
        'bad'  { $mark = [string][char]0x00D7 + ' ' }
    }
    [void]$list.Add($mark + $text)
}
function Acao-Diagnostico {
    if (-not (Test-RepoReady -Title 'Diagnóstico')) { return }
    $L = New-Object Collections.Generic.List[string]
    Add-DiagLine $L 'ok' ('Git instalado: ' + [string]$gv.Out)
    Add-DiagLine $L 'info' ('Pasta: ' + $App.Path)
    $br = Get-CurrentBranchName
    Add-DiagLine $L 'info' ('Branch atual: ' + $br)
    $hasC = Test-HasCommits
    if ($hasC) { $n = (Invoke-Git @('rev-list', '--count', 'HEAD') -Quiet).Out.Trim(); Add-DiagLine $L 'ok' ("Commits no projeto: $n") } else { Add-DiagLine $L 'warn' 'Ainda não há commits.' }
    $un = (Invoke-Git @('config', '--local', '--get', 'user.name') -Quiet).Out.Trim()
    $ue = (Invoke-Git @('config', '--local', '--get', 'user.email') -Quiet).Out.Trim()
    if ($un -and $ue) { Add-DiagLine $L 'ok' 'Usuário do projeto configurado (nome e e-mail).' } else { Add-DiagLine $L 'warn' 'Usuário do projeto não configurado (use o botão USUÁRIO).' }
    if (Test-Origin) {
        $u = (Invoke-Git @('remote', 'get-url', 'origin') -Quiet).Out.Trim()
        Add-DiagLine $L 'ok' ('Remoto origin: ' + (Protect-Text $u))
        if ($hasC) { if (Test-HasUpstream) { Add-DiagLine $L 'ok' 'A branch atual está ligada ao GitHub.' } else { Add-DiagLine $L 'warn' 'A branch atual ainda não foi enviada ao GitHub (use Enviar/Publicar).' } }
    } else { Add-DiagLine $L 'warn' 'Sem remoto (origin): o projeto não está conectado ao GitHub.' }
    $cred = (Invoke-Git @('config', '--get', 'credential.helper') -Quiet).Out.Trim()
    if ($cred) { Add-DiagLine $L 'ok' ('Login do GitHub: gerenciador de credenciais ativo (' + ($cred -split "`n")[0] + ').') } else { Add-DiagLine $L 'warn' 'Nenhum gerenciador de credenciais do Git encontrado: enviar ao GitHub pode falhar por falta de login.' }
    $busy = Get-RepoBusyState
    if ($busy) { Add-DiagLine $L 'bad' ("O repositório está com $busy.") } else { Add-DiagLine $L 'ok' 'Nenhum merge, rebase ou cherry-pick em andamento.' }
    $cf = @(Get-ConflictFiles)
    if ($cf.Count -gt 0) { Add-DiagLine $L 'bad' ("Arquivos em conflito: $($cf.Count)") }
    if (Test-Path -LiteralPath (Join-Path $App.Path '.gitignore')) { Add-DiagLine $L 'ok' 'Arquivo .gitignore presente.' } else { Add-DiagLine $L 'warn' 'Não há .gitignore (Mais comandos > .gitignore).' }
    $ent = @(Get-StatusEntries)
    Add-DiagLine $L 'info' ("Alterações pendentes: $($ent.Count)")
    $rep = Get-RiskReport @($ent | Where-Object { $_.X -ne 'D' -and $_.Y -ne 'D' } | ForEach-Object { $_.Path }) $App.Path
    if ($rep.Sensitive.Count -gt 0) { Add-DiagLine $L 'bad' ("Arquivos que parecem conter segredos (pendentes): " + (@($rep.Sensitive | Select-Object -First 5) -join ', ')) } else { Add-DiagLine $L 'ok' 'Nenhum arquivo suspeito de conter segredos entre as alterações pendentes.' }
    if ($rep.Large.Count -gt 0) { Add-DiagLine $L 'warn' ("Arquivos muito grandes pendentes: $($rep.Large.Count)") }
    Show-TextDialog 'Diagnóstico do projeto' ($L -join "`n") 'info'
}
function Show-Help {
    $t = @"
ATALHOS
  F1            esta ajuda
  F5            atualizar as informações do projeto
  F11 / Esc     tela cheia / sair da tela cheia
  Ctrl+O        abrir uma pasta (com Git ou sem Git)

PRIMEIROS PASSOS
  Abrir Projeto Existente: abre uma pasta. Se a pasta não tiver Git, o programa oferece iniciar o Git com segurança (git init, .gitignore e primeiro commit opcionais).
  Novo Projeto / Clonar: cria uma pasta nova ou baixa um projeto do GitHub.
  Projetos recentes: ative em Configurações para reabrir projetos com um clique.

SEGURANÇA
  Nada é apagado automaticamente. Comandos destrutivos (reset --hard, clean, push --force, branch -D) nunca são executados.
  Antes de preparar arquivos, o programa avisa sobre arquivos que parecem conter senhas ou chaves e sobre arquivos muito grandes.
  Para integrar na main é preciso digitar CONFIRMAR.
  Senhas e tokens nunca são guardados: o login é feito pelo Gerenciador de Credenciais do Git.

DICAS
  O botão "i" dos cards explica cada operação.
  Em Configurações você escolhe a área de trabalho (Single User, Team Easy, Team Dev) e a visibilidade do log.
"@
    Show-TextDialog 'Ajuda e atalhos' $t 'info'
}
function Refresh-View { if ($App.Path) { Update-State; Show-Toast 'Atualizado' 'As informações do projeto foram recarregadas.' 'info' } }

# ----------------------------------------------------------------------
# PROXIMO PASSO SUGERIDO (calculado em Update-State, exibido no painel)
# ----------------------------------------------------------------------
function Get-NextStep([int]$conf, [bool]$merging, [int]$changes, [bool]$hasRemote, [bool]$hasCommits, [bool]$hasUp, [int]$ahead, [bool]$hasUser) {
    $saveName = 'Registrar alterações'
    if ($App.Settings.Workspace -eq 'single') { $saveName = 'Salvar' } elseif ($App.Settings.Workspace -eq 'dev') { $saveName = 'Add + Commit' }
    $sendName = 'Publicar branch'
    if ($App.Settings.Workspace -eq 'single') { $sendName = 'Enviar' } elseif ($App.Settings.Workspace -eq 'dev') { $sendName = 'Push' }
    if ($conf -gt 0) { return 'Resolva os conflitos nos arquivos marcados e depois registre as alterações.' }
    if ($merging) { return 'Há um merge em andamento: finalize registrando as alterações.' }
    if (-not $hasUser) { return 'Configure seu nome e e-mail no botão USUÁRIO para poder fazer commits.' }
    if ($changes -gt 0) { return "Você tem $changes alteração(ões). Use '$saveName' para guardá-las em um commit." }
    if (-not $hasCommits) { return 'Projeto vazio: coloque arquivos na pasta e use ' + "'$saveName'" + ' para o primeiro commit.' }
    if (-not $hasRemote) { return "Conecte o projeto ao GitHub: Comandos > 'Configurar remoto'." }
    if (-not $hasUp) { return "Envie a branch ao GitHub com '$sendName'." }
    if ($ahead -gt 0) { return "Você tem $ahead commit(s) para enviar ao GitHub: use '$sendName'." }
    return 'Tudo em dia. Use Atualizar/Pull de vez em quando para buscar novidades.'
}
# Captura erros inesperados da interface (a janela nunca fecha sozinha por causa de uma excecao)
try { [Windows.Forms.Application]::SetUnhandledExceptionMode([Windows.Forms.UnhandledExceptionMode]::CatchException) } catch {}
try {
    [Windows.Forms.Application]::add_ThreadException({ param($sd, $ev)
        try { Show-Msg 'Erro inesperado' ("Ocorreu um erro inesperado, mas o programa continua aberto.`n`n" + (Protect-Text $ev.Exception.Message)) 'error' } catch {}
    })
} catch {}

# ======================================================================
# PREFERENCIAS E VERIFICACAO DO GIT
# ======================================================================
Load-Settings
$gv = Invoke-Git @('--version') -WorkDir ((Get-Location).Path) -Quiet
if (-not $gv.Ok) {
    Show-Msg 'Git não encontrado' "Git não encontrado.`n`nInstale o Git e tente novamente.`n`nhttps://git-scm.com/download/win" 'error'
    return
}

# ======================================================================
# CONSTRUCAO DA GUI
# ======================================================================
$form = New-Object Windows.Forms.Form
$App.Form = $form
$form.Text = 'GitHub Team Helper'
$form.StartPosition = 'CenterScreen'
$form.ClientSize = (Sz 1140 800)
$form.MinimumSize = (Sz 940 640)
$form.BackColor = $Colors.bg; $form.ForeColor = $Colors.text; $form.Font = $Fnt.ui
$form.KeyPreview = $true
$form.Add_HandleCreated({ param($sd, $ev) Set-DarkTitle $sd })
try { $form.Icon = New-AppIcon } catch {}

# Estrutura: [barra lateral | (cabecalho / paginas / log)]
$outer = New-TL 2 1
Add-Col $outer 'A' 100; Add-Col $outer 'P' 100; Add-Row $outer 'P' 100
$form.Controls.Add($outer)
$App.outer = $outer
# Rodape de status (adicionado depois do painel principal: o Fill e adicionado antes de Top/Bottom)
$footer = New-Object Windows.Forms.Panel
$footer.Dock = 'Bottom'; $footer.Height = 28; $footer.BackColor = $Colors.bg
Set-DB $footer
$footer.Add_Paint({ param($sd, $ev) Paint-Footer $sd $ev })
$form.Controls.Add($footer)
$App.footer = $footer

# --- Barra lateral
$sidebar = New-Object Windows.Forms.Panel
$sidebar.Dock = 'Fill'; $sidebar.BackColor = $Colors.side; $sidebar.Margin = (New-Object Windows.Forms.Padding(0))
$sidebar.AutoScroll = $true; $sidebar.AutoScrollMinSize = (Sz 100 520)
$outer.Controls.Add($sidebar, 0, 0)
$App.Sidebar = $sidebar
$logo = New-Object Windows.Forms.Panel
$logo.Location = (Pt 0 16); $logo.Size = (Sz 100 64); $logo.BackColor = $Colors.side
Set-DB $logo
$logo.Add_Paint({ param($sd, $ev) Paint-Logo $sd $ev })
$sidebar.Controls.Add($logo)

$navDefs = @(
    @{ Key = 'home';     Label = 'PAINEL';   Icon = 'home';  Action = 'Nav-Home' },
    @{ Key = 'graph';    Label = 'BRANCHES'; Icon = 'graph'; Action = 'Nav-Graph' },
    @{ Key = 'cmds';     Label = 'COMANDOS'; Icon = 'term';  Action = 'Nav-Cmds' },
    @{ Key = 'settings'; Label = 'CONFIG.';  Icon = 'cog';   Action = 'Nav-Settings' },
    @{ Key = '';         Label = 'USUÁRIO';  Icon = 'user';  Action = 'Acao-ConfigurarUsuario' },
    @{ Key = '';         Label = 'CREDENC.'; Icon = 'key';   Action = 'Acao-RemoverCredenciais' },
    @{ Key = '';         Label = 'TROCAR';   Icon = 'swap';  Action = 'Acao-TrocarProjeto' },
    @{ Key = '';         Label = 'SAIR';     Icon = 'exit';  Action = 'Acao-Sair' }
)
$App.NavItems = @()
foreach ($nd in $navDefs) {
    $nv = New-Object Windows.Forms.Panel
    $nv.Size = (Sz 100 66); $nv.BackColor = $Colors.side
    $nd.Selected = $false; $nd.Hover = $false
    $nv.Tag = $nd
    $nv.Cursor = [Windows.Forms.Cursors]::Hand
    Set-DB $nv
    $nv.Add_Paint({ param($sd, $ev) Paint-Nav $sd $ev })
    $nv.Add_MouseEnter({ param($sd, $ev) $sd.Tag.Hover = $true; $sd.Invalidate() })
    $nv.Add_MouseLeave({ param($sd, $ev) $sd.Tag.Hover = $false; $sd.Invalidate() })
    $nv.Add_Click({ param($sd, $ev) Guard $sd.Tag.Action })
    $nv.Add_EnabledChanged({ param($sd, $ev) $sd.Invalidate() })
    $sidebar.Controls.Add($nv)
    $App.NavItems += $nv
}
$sidebar.Add_Resize({ Layout-Sidebar })
Layout-Sidebar

# --- Coluna principal: cabecalho | paginas | log
$main = New-TL 1 3
Add-Col $main 'P' 100
Add-Row $main 'A' 78; Add-Row $main 'P' 100; Add-Row $main 'A' 0
$outer.Controls.Add($main, 1, 0)
$App.main = $main

# Cabecalho
$hdr = New-Object Windows.Forms.Panel
$hdr.Dock = 'Fill'; $hdr.BackColor = $Colors.bg; $hdr.Margin = (New-Object Windows.Forms.Padding(0))
$App.Header = $hdr
$App.hTitle = New-Label '' $Fnt.h1 $Colors.white 28 10 560 38
$App.hSub = New-Label '' $Fnt.small $Colors.muted 30 48 560 20
$hdr.Controls.Add($App.hTitle); $hdr.Controls.Add($App.hSub)
$App.pillStatus = New-Object Windows.Forms.Panel
$App.pillStatus.Size = (Sz 150 30); $App.pillStatus.Top = 24; $App.pillStatus.BackColor = $Colors.bg; $App.pillStatus.Visible = $false
$App.pillBranch = New-Object Windows.Forms.Panel
$App.pillBranch.Size = (Sz 150 30); $App.pillBranch.Top = 24; $App.pillBranch.BackColor = $Colors.bg; $App.pillBranch.Visible = $false
foreach ($pl in @($App.pillStatus, $App.pillBranch)) {
    Set-DB $pl
    $pl.Add_Paint({ param($sd, $ev) Paint-Pill $sd $ev })
    $hdr.Controls.Add($pl)
}
$hdr.Add_Resize({ Layout-Header })
$main.Controls.Add($hdr, 0, 0)

# Hospedeiro das paginas (rola quando a janela e pequena: AutoScrollMinSize e definido por pagina)
$pagesHost = New-Object Windows.Forms.Panel
$pagesHost.Dock = 'Fill'; $pagesHost.BackColor = $Colors.bg; $pagesHost.Margin = (New-Object Windows.Forms.Padding(0))
$pagesHost.AutoScroll = $true
$main.Controls.Add($pagesHost, 0, 1)
$App.pagesHost = $pagesHost
$App.Lockables = @($sidebar, $pagesHost)
$App.Pages = @{}

# ---- Pagina INICIAL (sem projeto aberto)
$pgStart = New-TL 3 5
Add-Col $pgStart 'P' 33.33; Add-Col $pgStart 'P' 33.33; Add-Col $pgStart 'P' 33.34
Add-Row $pgStart 'A' 168; Add-Row $pgStart 'A' 190; Add-Row $pgStart 'A' 190; Add-Row $pgStart 'P' 100; Add-Row $pgStart 'A' 64
$pgStart.Padding = (New-Object Windows.Forms.Padding(22, 8, 22, 10))
$startBanner = New-Banner @{
    Title = 'Bem-vindo ao GitHub Team Helper'
    Sub = 'Git e GitHub para equipes, mostrando cada comando executado'
    Path = 'Crie, clone ou abra um projeto (até pastas sem Git) para começar.'
    Chips = @(@{ Text = $gv.Out; Color = $Colors.success })
}
$pgStart.Controls.Add($startBanner, 0, 0); $pgStart.SetColumnSpan($startBanner, 3)
$startCards = @(
    @{ Title = 'Novo Projeto'; Desc = 'Cria uma pasta e inicia um repositório Git vazio.'; Cmd = 'git init'; G1 = $Colors.purple1; G2 = $Colors.purple2; Action = 'Acao-NovoProjeto' },
    @{ Title = 'Clonar Repositório'; Desc = 'Baixa para o seu computador um projeto que já está no GitHub.'; Cmd = 'git clone'; G1 = $Colors.orange2; G2 = $Colors.orange1; Action = 'Acao-Clonar' },
    @{ Title = 'Abrir Projeto Existente'; Desc = 'Abre uma pasta com Git. Se ela ainda não tiver Git, você pode iniciá-lo com segurança.'; Cmd = 'abrir pasta'; G1 = $Colors.blue1; G2 = $Colors.blue2; Action = 'Acao-AbrirProjeto' }
)
$ci = 0
foreach ($sc in $startCards) { $pgStart.Controls.Add((New-Card $sc), $ci, 1); $ci++ }
$pgStart.Controls.Add((New-Card @{ Title = 'Pasta sem Git'; Desc = 'Transforme uma pasta que já tem arquivos em um projeto Git: .gitignore, conferência de segredos e primeiro commit.'; Cmd = 'git init guiado'; G1 = $Colors.purple1; G2 = $Colors.orange2; Action = 'Acao-IniciarGitPasta' }), 0, 2)
$App.recentPanel = New-Object Windows.Forms.Panel
$App.recentPanel.Dock = 'Fill'; $App.recentPanel.Margin = (New-Object Windows.Forms.Padding(6)); $App.recentPanel.BackColor = $Colors.bg
Set-DB $App.recentPanel
$App.recentPanel.Add_Paint({ param($sd, $ev) Paint-RecentProjects $sd $ev })
$App.recentPanel.Add_MouseMove({ param($sd, $ev)
    $i = Get-RecentHit $ev.X $ev.Y $sd.ClientSize.Width $sd.ClientSize.Height
    $link = ($App.Settings.Remember -eq 'on' -and @($App.RecentItems).Count -gt 0 -and $ev.Y -lt 40 -and $ev.X -gt ($sd.ClientSize.Width - 130))
    if ($i -ne $App.RecentHover) { $App.RecentHover = $i; $sd.Invalidate() }
    if ($i -ge 0 -or $link) { $sd.Cursor = [Windows.Forms.Cursors]::Hand } else { $sd.Cursor = [Windows.Forms.Cursors]::Default }
})
$App.recentPanel.Add_MouseLeave({ param($sd, $ev) if ($App.RecentHover -ne -1) { $App.RecentHover = -1; $sd.Invalidate() } })
$App.recentPanel.Add_MouseClick({ param($sd, $ev)
    if ($ev.Button -ne 'Left') { return }
    $i = Get-RecentHit $ev.X $ev.Y $sd.ClientSize.Width $sd.ClientSize.Height
    if ($i -ge 0) { Guard 'Open-RecentIndex' ([string]$i); return }
    if ($App.Settings.Remember -eq 'on' -and @($App.RecentItems).Count -gt 0 -and $ev.Y -lt 40 -and $ev.X -gt ($sd.ClientSize.Width - 130)) { Guard 'Acao-LimparRecentes' }
})
$pgStart.Controls.Add($App.recentPanel, 1, 2); $pgStart.SetColumnSpan($App.recentPanel, 2)
$exitBtn = New-Card @{ Mode = 'solid'; Title = 'Sair'; G1 = $Colors.gray1; G2 = $Colors.gray2; Action = 'Acao-Sair' }
$exitBtn.Dock = 'None'; $exitBtn.Anchor = 'Left'; $exitBtn.Size = (Sz 150 42)
$pgStart.Controls.Add($exitBtn, 0, 4)
$credBtn = New-Card @{ Mode = 'solid'; Title = 'Remover credenciais do GitHub'; G1 = $Colors.red1; G2 = $Colors.red2; Action = 'Acao-RemoverCredenciais' }
$credBtn.Dock = 'None'; $credBtn.Anchor = 'Left'; $credBtn.Size = (Sz 250 42)
$pgStart.Controls.Add($credBtn, 1, 4)
$cfgBtn = New-Card @{ Mode = 'solid'; Title = 'Configurações'; G1 = $Colors.purple1; G2 = $Colors.purple2; Action = 'Nav-Settings' }
$cfgBtn.Dock = 'None'; $cfgBtn.Anchor = 'Left'; $cfgBtn.Size = (Sz 170 42)
$pgStart.Controls.Add($cfgBtn, 2, 4)
$App.Pages['start'] = $pgStart

# ---- Pagina PAINEL (projeto aberto): coluna esquerda fixa, coluna direita depende da area de trabalho
$pgHome = New-TL 2 1
Add-Col $pgHome 'P' 42; Add-Col $pgHome 'P' 58; Add-Row $pgHome 'P' 100
$pgHome.Padding = (New-Object Windows.Forms.Padding(22, 6, 22, 10))
$leftCol = New-TL 1 3
Add-Col $leftCol 'P' 100
Add-Row $leftCol 'A' 170; Add-Row $leftCol 'P' 100; Add-Row $leftCol 'A' 62
$App.bannerHome = New-Banner @{ Title = 'Olá!'; Sub = ''; Path = ''; Chips = @() }
$App.recentCard = New-Object Windows.Forms.Panel
$App.recentCard.Dock = 'Fill'; $App.recentCard.Margin = (New-Object Windows.Forms.Padding(6)); $App.recentCard.BackColor = $Colors.bg
Set-DB $App.recentCard
$App.recentCard.Add_Paint({ param($sd, $ev) Paint-Recent $sd $ev })
$moreBar = New-Card @{ Mode = 'wide'; Title = 'Visualizar mais comandos individuais'; Action = 'Nav-Cmds' }
$leftCol.Controls.Add($App.bannerHome, 0, 0)
$leftCol.Controls.Add($App.recentCard, 0, 1)
$leftCol.Controls.Add($moreBar, 0, 2)
$pgHome.Controls.Add($leftCol, 0, 0)
$App.rightHost = New-Object Windows.Forms.Panel
$App.rightHost.Dock = 'Fill'; $App.rightHost.BackColor = $Colors.bg; $App.rightHost.Margin = (New-Object Windows.Forms.Padding(0))
$pgHome.Controls.Add($App.rightHost, 1, 0)
Build-Workspace
$App.Pages['home'] = $pgHome

# ---- Pagina BRANCHES (mapa: main + ate 10 ramificacoes por pagina)
$pgGraph = New-TL 1 2
Add-Col $pgGraph 'P' 100; Add-Row $pgGraph 'S' 0; Add-Row $pgGraph 'P' 100
$pgGraph.Padding = (New-Object Windows.Forms.Padding(22, 4, 22, 14))
$gTool = New-Object Windows.Forms.FlowLayoutPanel
$gTool.Dock = 'Top'; $gTool.AutoSize = $true; $gTool.AutoSizeMode = 'GrowAndShrink'; $gTool.WrapContents = $true
$gTool.BackColor = $Colors.bg; $gTool.Margin = (New-Object Windows.Forms.Padding(0, 0, 0, 6))
$bRef = New-Btn 'Atualizar' 'primary' 110 34; $bRef.Margin = (New-Object Windows.Forms.Padding(6, 4, 6, 4))
$App.brPrev = New-Btn ([string][char]0x2039) 'secondary' 44 34; $App.brPrev.Margin = (New-Object Windows.Forms.Padding(6, 4, 2, 4))
$App.brNext = New-Btn ([string][char]0x203A) 'secondary' 44 34; $App.brNext.Margin = (New-Object Windows.Forms.Padding(2, 4, 6, 4))
$App.brInfo = New-Object Windows.Forms.Label
$App.brInfo.AutoSize = $true; $App.brInfo.ForeColor = $Colors.muted; $App.brInfo.Font = $Fnt.small
$App.brInfo.Margin = (New-Object Windows.Forms.Padding(6, 13, 12, 4)); $App.brInfo.Text = ''
$bAll = New-Btn 'Ver lista completa' 'secondary' 150 34; $bAll.Margin = (New-Object Windows.Forms.Padding(6, 4, 6, 4))
$bRef.Add_Click({ Guard 'Refresh-BranchMap' })
$App.brPrev.Add_Click({ Guard 'Br-Prev' })
$App.brNext.Add_Click({ Guard 'Br-Next' })
$bAll.Add_Click({ Guard 'Acao-Branch' })
foreach ($c in @($bRef, $App.brPrev, $App.brNext, $App.brInfo, $bAll)) { $gTool.Controls.Add($c) }
$pgGraph.Controls.Add($gTool, 0, 0)

$App.gCont = New-Object Windows.Forms.Panel
$App.gCont.Dock = 'Fill'; $App.gCont.BackColor = $Colors.panel; $App.gCont.AutoScroll = $true
$App.gCont.Margin = (New-Object Windows.Forms.Padding(6, 0, 6, 0))
$App.gCanvas = New-Object Windows.Forms.Panel
$App.gCanvas.Location = (Pt 0 0); $App.gCanvas.Size = (Sz 900 300); $App.gCanvas.BackColor = $Colors.panel
Set-DB $App.gCanvas
$App.gCanvas.Add_Paint({ param($sd, $ev) Paint-BranchMap $sd $ev })
$App.gCanvas.Add_MouseEnter({ param($sd, $ev) [void]$App.gCont.Focus() })
$App.gCanvas.Add_MouseMove({ param($sd, $ev)
    $hit = $null
    foreach ($h in @($App.Br.Hits)) { if ($ev.X -ge $h.X -and $ev.X -le ($h.X + $h.W) -and $ev.Y -ge $h.Y -and $ev.Y -le ($h.Y + $h.H)) { $hit = $h; break } }
    $name = ''; if ($hit) { $name = $hit.Name }
    if ($name -ne $App.Br.Hover) {
        $App.Br.Hover = $name
        if ($name) {
            $e = $App.Br.Index[$name]
            $tip = $name
            if ($e) { $tip += "`n" + $e.Subject + ' (' + $e.When + ')' }
            $App.tt.SetToolTip($sd, $tip)
            $sd.Cursor = [Windows.Forms.Cursors]::Hand
        } else { $App.tt.SetToolTip($sd, ''); $sd.Cursor = [Windows.Forms.Cursors]::Default }
    }
})
$App.gCanvas.Add_MouseClick({ param($sd, $ev)
    foreach ($h in @($App.Br.Hits)) { if ($ev.X -ge $h.X -and $ev.X -le ($h.X + $h.W) -and $ev.Y -ge $h.Y -and $ev.Y -le ($h.Y + $h.H)) { Guard 'Show-BranchDetail' $h.Name; break } }
})
$App.gCont.Controls.Add($App.gCanvas)
$App.gCont.Add_Resize({ Resize-BranchCanvas })
$pgGraph.Controls.Add($App.gCont, 0, 1)
$App.Pages['graph'] = $pgGraph

# ---- Pagina COMANDOS (mais comandos individuais)
$P1 = $Colors.purple1; $P2 = $Colors.purple2
$O1 = $Colors.orange1; $O2 = $Colors.orange2; $B1 = $Colors.blue1; $B2 = $Colors.blue2
$cmdGroups = @(
    @{ Title = 'Branches e sincronização'; Cards = @(
        @{ Title = 'Listar branches'; Desc = 'Mostra as branches locais e permite trocar de uma delas.'; Cmd = 'git branch'; G1 = $P1; G2 = $P2; Action = 'Acao-Branch' },
        @{ Title = 'Trocar de branch'; Desc = 'Muda para outra branch que já existe.'; Cmd = 'git switch'; G1 = $P1; G2 = $P2; Action = 'Acao-Switch' },
        @{ Title = 'Mesclar branch'; Desc = 'Traz outra branch para dentro da branch atual.'; Cmd = 'git merge <branch>'; G1 = $O2; G2 = $O1; Action = 'Acao-Merge' },
        @{ Title = 'Buscar novidades'; Desc = 'Baixa o que há no GitHub sem mexer nos seus arquivos.'; Cmd = 'git fetch origin'; G1 = $P1; G2 = $P2; Action = 'Acao-Fetch' },
        @{ Title = 'Enviar branch atual'; Desc = 'Envia os commits da branch atual ao GitHub (serve também para o primeiro envio).'; Cmd = 'git push'; G1 = $O2; G2 = $O1; Action = 'Acao-Push' },
        @{ Title = 'Excluir branch'; Desc = 'Remove uma branch local já integrada (seguro).'; Cmd = 'git branch -d'; G1 = $Colors.red1; G2 = $Colors.red2; Border = (Get-Col '#7a2a4d'); Action = 'Acao-ExcluirBranch' }
    ) },
    @{ Title = 'Alterações'; Cards = @(
        @{ Title = 'Preparar tudo'; Desc = 'Marca todas as alterações para o próximo commit (com conferência de segredos).'; Cmd = 'git add .'; G1 = $P1; G2 = $P2; Action = 'Acao-AddTudo' },
        @{ Title = 'Desfazer preparação'; Desc = 'Tira arquivos da preparação sem alterar nem apagar nada na pasta.'; Cmd = 'git restore --staged'; G1 = $P1; G2 = $P2; Action = 'Acao-Unstage' },
        @{ Title = 'Desfazer último commit'; Desc = 'Volta o último commit (ainda não enviado) e mantém seus arquivos.'; Cmd = 'git reset --soft'; G1 = $O2; G2 = $O1; Action = 'Acao-DesfazerCommit' },
        @{ Title = 'Guardar alterações'; Desc = 'Guarda as mudanças em andamento para trocar de branch.'; Cmd = 'git stash'; G1 = $P1; G2 = $P2; Action = 'Acao-Stash' },
        @{ Title = 'Recuperar guardadas'; Desc = 'Reaplica as alterações guardadas pelo stash.'; Cmd = 'git stash pop'; G1 = $P1; G2 = $P2; Action = 'Acao-StashPop' },
        @{ Title = 'Ver diferenças'; Desc = 'Resumo do que mudou desde o último commit.'; Cmd = 'git diff --stat'; G1 = $B1; G2 = $B2; Action = 'Acao-Diff' }
    ) },
    @{ Title = 'Projeto e GitHub'; Cards = @(
        @{ Title = 'Histórico'; Desc = 'Linha do tempo dos commits em uma janela com rolagem.'; Cmd = 'git log --graph'; G1 = $B1; G2 = $B2; Action = 'Acao-Historico' },
        @{ Title = 'Diagnóstico'; Desc = 'Confere usuário, remoto, login, conflitos e arquivos de risco.'; Cmd = 'verificação'; G1 = $B1; G2 = $B2; Action = 'Acao-Diagnostico' },
        @{ Title = 'Arquivos sensíveis'; Desc = 'Procura senhas, chaves e arquivos enormes antes de enviar.'; Cmd = 'verificação'; G1 = $O2; G2 = $O1; Action = 'Acao-VerificarSensiveis' },
        @{ Title = 'Configurar remoto'; Desc = 'Conecta o projeto a um repositório do GitHub ou troca o endereço.'; Cmd = 'git remote'; G1 = $P1; G2 = $P2; Action = 'Acao-ConfigurarRemoto' },
        @{ Title = 'Ver remotos'; Desc = 'Mostra para onde o projeto envia e de onde recebe.'; Cmd = 'git remote -v'; G1 = $B1; G2 = $B2; Action = 'Acao-Remotos' },
        @{ Title = '.gitignore'; Desc = 'Cria ou complementa a lista de arquivos que o Git deve ignorar.'; Cmd = '.gitignore'; G1 = $P1; G2 = $P2; Action = 'Acao-Gitignore' },
        @{ Title = 'Abrir no GitHub'; Desc = 'Abre a página do repositório no navegador.'; Cmd = 'github.com'; G1 = $B1; G2 = $B2; Action = 'Acao-AbrirGitHub' },
        @{ Title = 'Abrir pasta'; Desc = 'Abre a pasta do projeto no Explorador de Arquivos.'; Cmd = 'explorer'; G1 = $B1; G2 = $B2; Action = 'Acao-AbrirPasta' }
    ) }
)
$totalRows = 0
foreach ($gp in $cmdGroups) { $totalRows += 1 + [int][Math]::Ceiling(@($gp.Cards).Count / 3) }
$pgCmds = New-TL 3 $totalRows
Add-Col $pgCmds 'P' 33.33; Add-Col $pgCmds 'P' 33.33; Add-Col $pgCmds 'P' 33.34
$pgCmds.Padding = (New-Object Windows.Forms.Padding(22, 4, 22, 10))
$rowIx = 0
foreach ($gp in $cmdGroups) {
    Add-Row $pgCmds 'A' 40
    $hl = New-Label $gp.Title $Fnt.h2 $Colors.white 0 0 100 30
    $hl.Dock = 'Fill'; $hl.TextAlign = 'BottomLeft'; $hl.Padding = (New-Object Windows.Forms.Padding(6, 0, 0, 4))
    $pgCmds.Controls.Add($hl, 0, $rowIx); $pgCmds.SetColumnSpan($hl, 3)
    $rowIx++
    $nrows = [int][Math]::Ceiling(@($gp.Cards).Count / 3)
    for ($rr = 0; $rr -lt $nrows; $rr++) { Add-Row $pgCmds 'P' 100 }
    $qi = 0
    foreach ($cc in $gp.Cards) { $pgCmds.Controls.Add((New-Card $cc), ($qi % 3), ($rowIx + [int][Math]::Floor($qi / 3))); $qi++ }
    $rowIx += $nrows
}
$App.Pages['cmds'] = $pgCmds

# ---- Pagina CONFIGURACOES (area de trabalho + visualizacao do log)
$pgSet = New-TL 1 8
Add-Col $pgSet 'P' 100
Add-Row $pgSet 'A' 46; Add-Row $pgSet 'A' 140; Add-Row $pgSet 'A' 58; Add-Row $pgSet 'A' 140; Add-Row $pgSet 'A' 58; Add-Row $pgSet 'A' 120; Add-Row $pgSet 'P' 100; Add-Row $pgSet 'A' 60
$pgSet.Padding = (New-Object Windows.Forms.Padding(22, 6, 22, 10))
function New-SectionTitle([string]$text) {
    $l = New-Label $text $Fnt.h2 $Colors.white 0 0 100 30
    $l.Dock = 'Fill'; $l.TextAlign = 'BottomLeft'; $l.Padding = (New-Object Windows.Forms.Padding(6, 0, 0, 4))
    return $l
}
function New-ChoiceRow($defs) {
    $nc = @($defs).Count
    $row = New-TL 3 1
    Add-Col $row 'P' 33.33; Add-Col $row 'P' 33.33; Add-Col $row 'P' 33.34; Add-Row $row 'P' 100
    $i = 0
    foreach ($d in $defs) {
        $d.Mode = 'choice'; $d.Action = 'Choose-Setting'; $d.Selected = $false
        $cc = New-Card $d
        $App.ChoiceCards += $cc
        $row.Controls.Add($cc, $i, 0); $i++
    }
    return $row
}
$pgSet.Controls.Add((New-SectionTitle 'Tipo de área de trabalho'), 0, 0)
$pgSet.Controls.Add((New-ChoiceRow @(
    @{ Title = 'Single User'; Desc = 'Para quem trabalha sozinho. Um botão Salvar faz git add, commit e pull, com mensagem, conferência e confirmação.'; Arg = 'ws:single' },
    @{ Title = 'Team Easy'; Desc = 'Fluxo em equipe com 5 passos numerados (atualizar, criar branch, registrar, publicar, concluir) e botão Info.'; Arg = 'ws:easy' },
    @{ Title = 'Team Dev'; Desc = 'O mesmo fluxo, mas cada comando Git é uma ação separada (fetch, pull, add, commit, merge, push...), para mais controle.'; Arg = 'ws:dev' }
)), 0, 1)
$pgSet.Controls.Add((New-SectionTitle 'Visualização do log de comandos'), 0, 2)
$pgSet.Controls.Add((New-ChoiceRow @(
    @{ Title = 'Não mostrar (padrão)'; Desc = 'O painel de log fica oculto e nada é registrado nele. Os comandos continuam funcionando normalmente.'; Arg = 'log:none' },
    @{ Title = 'Não mostrar na área inicial'; Desc = 'O log aparece nas demais áreas (painel, branches...), mas não na tela inicial.'; Arg = 'log:nostart' },
    @{ Title = 'Mostrar'; Desc = 'Mostra o log com os comandos Git executados. Senhas, tokens e e-mails são ocultados automaticamente.'; Arg = 'log:show' }
)), 0, 3)
$setNote = New-Label 'As preferências ficam salvas só neste computador (apenas estas escolhas; senhas, tokens e dados pessoais nunca são guardados).' $Fnt.small $Colors.muted 0 0 100 20
$setNote.Dock = 'Fill'; $setNote.AutoEllipsis = $false; $setNote.Padding = (New-Object Windows.Forms.Padding(6, 10, 6, 0))
$pgSet.Controls.Add((New-SectionTitle 'Projetos recentes'), 0, 4)
$pgSet.Controls.Add((New-ChoiceRow @(
    @{ Title = 'Não lembrar (padrão)'; Desc = 'Nenhum caminho de pasta é guardado. A lista de recentes fica vazia.'; Arg = 'rem:off' },
    @{ Title = 'Lembrar projetos recentes'; Desc = 'Guarda só os caminhos das últimas pastas abertas, neste computador, para reabrir com um clique. Pode limpar quando quiser.'; Arg = 'rem:on' }
)), 0, 5)
$pgSet.Controls.Add($setNote, 0, 6)
$backBtn = New-Card @{ Mode = 'solid'; Title = 'Voltar'; G1 = $Colors.gray1; G2 = $Colors.gray2; Action = 'Settings-Back' }
$backBtn.Dock = 'None'; $backBtn.Anchor = 'Left'; $backBtn.Size = (Sz 150 42)
$pgSet.Controls.Add($backBtn, 0, 7)
$App.Pages['settings'] = $pgSet
Refresh-Choices

foreach ($k in @($App.Pages.Keys)) { $App.Pages[$k].Visible = $false; $pagesHost.Controls.Add($App.Pages[$k]) }

# --- Area de LOG (altura proporcional; oculta conforme a preferencia)
$logWrap = New-Object Windows.Forms.Panel
$logWrap.Dock = 'Fill'; $logWrap.BackColor = $Colors.bg; $logWrap.Padding = (New-Object Windows.Forms.Padding(28, 0, 28, 16))
$logWrap.Margin = (New-Object Windows.Forms.Padding(0)); $logWrap.Visible = $false
$ltl = New-TL 1 2
Add-Col $ltl 'P' 100
Add-Row $ltl 'A' 30; Add-Row $ltl 'P' 100
$topBar = New-Object Windows.Forms.Panel
$topBar.Dock = 'Fill'; $topBar.BackColor = $Colors.bg; $topBar.Margin = (New-Object Windows.Forms.Padding(0))
$topBar.Controls.Add((New-Label 'LOG DE COMANDOS' $Fnt.smallB $Colors.muted 2 9 300 16))
$bClear = New-Btn 'Limpar' 'secondary' 72 24
$bClear.Font = $Fnt.small; $bClear.Dock = 'Right'
$topBar.Controls.Add($bClear)
$rt = New-Object Windows.Forms.RichTextBox
$rt.Dock = 'Fill'; $rt.ReadOnly = $true; $rt.BorderStyle = 'None'
$rt.BackColor = $Colors.logbg; $rt.ForeColor = $Colors.text; $rt.Font = $Fnt.mono
$rt.DetectUrls = $false; $rt.WordWrap = $true; $rt.ScrollBars = 'Vertical'
$rt.Margin = (New-Object Windows.Forms.Padding(0))
$App.LogBox = $rt
$ltl.Controls.Add($topBar, 0, 0)
$ltl.Controls.Add($rt, 0, 1)
$logWrap.Controls.Add($ltl)
$main.Controls.Add($logWrap, 0, 2)
$App.logWrap = $logWrap

# --- Eventos gerais (acoes passam por Guard: erros inesperados nunca derrubam a GUI)
$bClear.Add_Click({ $App.LogBox.Clear() })
$form.Add_FormClosing({ param($sd, $ev) if ($App.Running) { $ev.Cancel = $true } })   # nao fechar no meio de um comando
$form.Add_Resize({ Apply-LogVisibility; Layout-Header })
$form.Add_KeyDown({ param($sd, $ev)
    if ($ev.KeyCode -eq 'F11') { Toggle-Fullscreen; $ev.Handled = $true }
    elseif ($ev.KeyCode -eq 'Escape' -and $App.Full) { Toggle-Fullscreen; $ev.Handled = $true }
    elseif ($ev.KeyCode -eq 'F1') { Guard 'Show-Help'; $ev.Handled = $true }
    elseif ($ev.KeyCode -eq 'F5') { Guard 'Refresh-View'; $ev.Handled = $true }
    elseif ($ev.Control -and $ev.KeyCode -eq 'O') { Guard 'Acao-AbrirProjeto'; $ev.Handled = $true }
})
$form.Add_Shown({ $App.Form.Activate(); Layout-Header; Layout-Sidebar })

Refresh-RecentList
Show-StartPanel
Write-Log 'GitHub Team Helper' 'accent' $true
Write-Info $gv.Out
Write-Info 'Escolha uma opção para começar. (F11 alterna tela cheia)'
Write-Log ''
[Windows.Forms.Application]::Run($form)