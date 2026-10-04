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
#    NUCLEO (estado, cores, desenho, botoes, dialogos, log, execucao do git)
#    PINTURA (cards, banner, navegacao, grafo de branches)
#    MENU_PRINCIPAL | NOVO_PROJETO | CLONAR_REPOSITORIO | ABRIR_PROJETO
#    CONFIGURAR_USUARIO | MENU_PROJETO | CRIAR_BRANCH
#    REGISTRAR_ALTERACOES | PUBLICAR_BRANCH | CONCLUIR_TRABALHO
#    STATUS | ATUALIZAR | MAIS_COMANDOS | CONFIRMACOES
#    TRATAMENTO_DE_ERROS | SAIR
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
    Path = $null; Name = ''; Branch = ''; StatusText = ''; Running = $false
    Form = $null; LogBox = $null; Lockables = $null; Page = 'start'
    Recent = @(); Graph = $null
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
# Cores/canetas das linhas do grafo (uma por "pista" de branch)
$LaneCols = @((Get-Col '#9b6bff'), (Get-Col '#ff9a5a'), (Get-Col '#3ddc97'), (Get-Col '#ff5fa2'), (Get-Col '#5aa9ff'), (Get-Col '#ffd400'), (Get-Col '#35d6e0'), (Get-Col '#ff6b6b'))
$LanePens = @(); $LaneBrushes = @()
foreach ($lc in $LaneCols) {
    $lp = New-Object Drawing.Pen($lc, 2.6); $lp.StartCap = 'Round'; $lp.EndCap = 'Round'
    $LanePens += $lp
    $LaneBrushes += (New-Object Drawing.SolidBrush($lc))
}

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

# Decoracao do banner: linhas de branches com "commits" (lembra a ilustracao do modelo)
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
function Add-Col($tl, [string]$kind, [double]$v) {
    $t = [Windows.Forms.SizeType]::Percent; if ($kind -eq 'A') { $t = [Windows.Forms.SizeType]::Absolute }
    [void]$tl.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle($t, [single]$v)))
}
function Add-Row($tl, [string]$kind, [double]$v) {
    $t = [Windows.Forms.SizeType]::Percent; if ($kind -eq 'A') { $t = [Windows.Forms.SizeType]::Absolute }
    [void]$tl.RowStyles.Add((New-Object Windows.Forms.RowStyle($t, [single]$v)))
}
function Set-Locked([bool]$lock) {
    if (-not $App.Lockables) { return }
    foreach ($c in $App.Lockables) { $c.Enabled = (-not $lock) }
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
        $tb.Font = $Fnt.ui; $tb.Text = $InputDefault
        $tb.Tag = @{ Mode = $Require; Exact = $Exact }
        $dlg.Controls.Add($tb)
        $y += 40
    }
    $y += 8

    # Botoes alinhados a direita (ordem da lista = ordem visual, esquerda -> direita)
    $bxnX = $W - 24
    $okBtn = $null; $cancelBtn = $null
    for ($i = $Buttons.Count - 1; $i -ge 0; $i--) {
        $bd = $Buttons[$i]
        $bw = [Math]::Max(110, [int]([Windows.Forms.TextRenderer]::MeasureText($bd.Text, $Fnt.bold).Width + 40))
        $b = New-Btn $bd.Text $bd.Style $bw 38
        $bxnX -= $bw
        $b.Location = (Pt $bxnX $y)
        $bxnX -= 10
        $b.Tag = $bd.Result
        $b.Add_Click({ param($sd, $ev) $fm = $sd.FindForm(); $fm.Tag = $sd.Tag; $fm.Close() })
        if ($bd.Result -eq 'ok') { $b.Name = 'okbtn'; $okBtn = $b }
        if ($bd.Result -eq 'cancel') { $cancelBtn = $b }
        $dlg.Controls.Add($b)
    }
    if ($tb -and $okBtn) {
        $okBtn.Enabled = (Test-InputOk $tb)
        $tb.Add_TextChanged({ param($sd, $ev) $o = $sd.FindForm().Controls['okbtn']; if ($o) { $o.Enabled = (Test-InputOk $sd) } })
    }
    if ($okBtn) { $dlg.AcceptButton = $okBtn }
    if ($cancelBtn) { $dlg.CancelButton = $cancelBtn } elseif ($okBtn) { $dlg.CancelButton = $okBtn }
    $dlg.Add_Shown({ param($sd, $ev) $t = $sd.Controls['inp']; if ($t) { [void]$t.Focus(); $t.SelectAll() } })
    $dlg.ClientSize = (Sz $W ($y + 38 + 24))

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
# LOG DE COMANDOS (area de log da GUI)
# ----------------------------------------------------------------------
function Write-Log([string]$t, [string]$c = 'text', [bool]$b = $false) {
    $rt = $App.LogBox
    if (-not $rt) { return }
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
# EXECUCAO DO GIT (sem passar pelo CMD: argumentos seguros, sem expansao de % ou !)
# ----------------------------------------------------------------------
function ConvertTo-WinArg([string]$a) {
    if ($a.Length -eq 0) { return '""' }
    if ($a -notmatch '[\s"]') { return $a }
    $s = [regex]::Replace($a, '(\\*)"', '$1$1\"')
    $s = [regex]::Replace($s, '(\\+)$', '$1$1')
    return ('"' + $s + '"')
}

# Executa "git <args>" e devolve objeto {Ok, ExitCode, Out, Err, Text, Display}
# -Quiet: nao escreve no log (consultas internas)
function Invoke-Git {
    param([string[]]$GitArgs, [string]$WorkDir = '', [switch]$Quiet)
    if (-not $WorkDir) { if ($App.Path) { $WorkDir = $App.Path } else { $WorkDir = (Get-Location).Path } }
    $disp = 'git ' + (($GitArgs | ForEach-Object { if ($_ -match '[\s"]') { '"' + $_ + '"' } else { $_ } }) -join ' ')
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
        $m = $_.Exception.Message
        $res = [pscustomobject]@{ Ok = $false; ExitCode = -1; Out = ''; Err = $m; Text = $m; Display = $disp }
        if (-not $Quiet) { Write-GitResult $res }
        return $res
    }

    $App.Running = $true
    $lock = $false
    if (-not $Quiet -and $App.Lockables) { $lock = $true; Set-Locked $true; $App.Form.UseWaitCursor = $true }
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
        if ($lock) { Set-Locked $false; $App.Form.UseWaitCursor = $false }
        $p.Dispose()
    }
    $txt = (@($out, $err) | Where-Object { $_ }) -join "`n"
    $res = [pscustomobject]@{ Ok = ($code -eq 0); ExitCode = $code; Out = $out; Err = $err; Text = $txt; Display = $disp }
    if (-not $Quiet) { Write-GitResult $res }
    return $res
}

# ----------------------------------------------------------------------
# TRATAMENTO_DE_ERROS
# ----------------------------------------------------------------------
function Show-GitError($r, [string]$Extra = '') {
    $reason = $r.Text
    if (-not $reason) { $reason = '(o Git não retornou mensagem; código ' + $r.ExitCode + ')' }
    if ($reason.Length -gt 700) { $reason = $reason.Substring(0, 700) + ' [...]' }
    $hint = ''
    if ($r.Text -match 'could not read Username|Authentication failed|terminal prompts disabled|Permission denied|error: 403|HTTP 403') {
        $hint = "`n`nDica: verifique suas credenciais do GitHub (Git Credential Manager ou token de acesso pessoal) e se você tem permissão no repositório."
    }
    $m = "O comando não pôde ser executado.`n`nComando:`n" + $r.Display + "`n`nMotivo:`n" + $reason + $hint
    if ($Extra) { $m += "`n`n" + $Extra }
    Show-Msg 'Erro' $m 'error'
}

# Executa uma acao protegendo a GUI contra excecoes inesperadas
function Guard([string]$fn) {
    if ($App.Running) { return }
    try { & $fn }
    catch {
        $m = $_.Exception.Message
        Write-Log ([string][char]0x00D7 + ' Erro interno: ' + $m) 'error'
        Show-Msg 'Erro inesperado' ("Ocorreu um erro inesperado na ferramenta:`n`n" + $m) 'error'
    }
}

# ----------------------------------------------------------------------
# FUNCOES AUXILIARES DE REPOSITORIO
# ----------------------------------------------------------------------
function Get-Changes([switch]$TrackedOnly) {
    $a = @('status', '--porcelain')
    if ($TrackedOnly) { $a += '--untracked-files=no' }
    $r = Invoke-Git $a -Quiet
    if (-not $r.Ok -or -not $r.Out.Trim()) { return @() }
    return @($r.Out -split '\r?\n' | Where-Object { $_.Trim() })
}
function Format-Changes($lines) {
    $n = @($lines).Count
    $show = @($lines | Select-Object -First 8)
    $t = ($show -join "`n")
    if ($n -gt 8) { $t += "`n... e mais $($n - 8) item(ns)" }
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

function Resolve-RepoRoot([string]$dir) {
    $r = Invoke-Git @('rev-parse', '--show-toplevel') -WorkDir $dir -Quiet
    if (-not $r.Ok -or -not $r.Out.Trim()) { return $null }
    return (($r.Out.Trim()) -replace '/', '\')
}
function Test-FolderName([string]$n) {
    if (-not $n) { return 'Informe um nome.' }
    if ($n -ne $n.Trim() -or $n.EndsWith('.')) { return 'O nome não pode terminar com ponto nem começar/terminar com espaço.' }
    if ($n.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0) { return 'O nome contém caracteres não permitidos: \ / : * ? " < > |' }
    if ($n -match '^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\..*)?$') { return 'Esse nome é reservado pelo Windows.' }
    return $null
}
function Test-RepoUrl([string]$u) { return ($u -match '^(https?://|ssh://|git@)\S+$') }

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
        Draw-Text $g $t.Title $Fnt.bold $Bx.white 0 0 $w $h $SFC
    } else {
        if ($t.Hover) { $g.FillPath($Bx.cardH, $path) } else { $g.FillPath($Bx.card, $path) }
        $bc = $Colors.border
        if ($t.Hover) { $bc = $Colors.borderH }
        if ($t.Border -and -not $t.Hover) { $bc = $t.Border }
        $pen = New-Object Drawing.Pen($bc, 1.5); $g.DrawPath($pen, $path); $pen.Dispose()
        if ($t.Mode -eq 'wide') {
            Draw-Text $g $t.Title $Fnt.bold $Bx.white 20 0 ($w - 70) $h $SFV
            Draw-Text $g ([string][char]0x203A) $Fnt.h1 $Bx.orange1 ($w - 52) 0 34 ($h - 4) $SFC
        } else {
            Draw-Text $g $t.Title $Fnt.h3 $Bx.text 18 14 ($w - 36) 26 $SFL
            Draw-Text $g $t.Desc $Fnt.small $Bx.muted 18 44 ($w - 36) ([Math]::Max(10, $h - 44 - 44)) $SFW
            $tw = [int]$g.MeasureString($t.Cmd, $Fnt.monoS).Width + 24
            $pw = [Math]::Min($tw, $w - 36); $py = $h - 40
            $pp = New-RoundPath 18 $py $pw 24 12
            $gb = New-Grad 18 $py $pw 24 $t.G1 $t.G2 0
            $g.FillPath($gb, $pp); $gb.Dispose(); $pp.Dispose()
            Draw-Text $g $t.Cmd $Fnt.monoS $Bx.white 18 $py $pw 24 $SFC
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
    $p.Add_Click({ param($sd, $ev) if ($sd.Tag.Action) { Guard $sd.Tag.Action } })
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
    $tw = $w - 300; if ($tw -lt 220) { $tw = $w - 40 }
    Draw-Text $g $t.Title $Fnt.h1 $Bx.white 26 16 $tw 36 $SFL
    Draw-Text $g $t.Sub $Fnt.ui $Bx.text 28 56 $tw 22 $SFL
    if ($t.Path) { Draw-Text $g $t.Path $Fnt.small $Bx.muted 28 80 $tw 18 $SFL }
    $x = 28
    foreach ($ch in @($t.Chips)) { if ($ch) { $x += (Draw-Chip $g $x ($h - 42) $ch.Text $ch.Color) } }
    if ($w -gt 560) { Draw-Deco $g ($w - 250) 8 230 ($h - 16) }
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
    if ($w -lt 20) { return }
    $p = New-RoundPath 1 1 ($w - 3) ($h - 3) (($h - 3) / 2)
    $g.FillPath($Bx.panel2, $p)
    $pen = New-Object Drawing.Pen($Colors.border, 1.2); $g.DrawPath($pen, $p); $pen.Dispose(); $p.Dispose()
    $b = New-Object Drawing.SolidBrush($t.Color)
    $g.FillEllipse($b, [single]14, [single]($h / 2 - 4), [single]8, [single]8); $b.Dispose()
    Draw-Text $g $t.Text $Fnt.bold $Bx.text 28 0 ($w - 34) $h $SFV
}
function Set-Pill($p, [string]$text, [string]$colorName) {
    $p.Tag = @{ Text = $text; Color = $Colors[$colorName] }
    $w = [Windows.Forms.TextRenderer]::MeasureText($text, $Fnt.bold).Width + 46
    $p.Width = [int][Math]::Min($w, 360)
    $p.Invalidate()
}
function Layout-Header {
    if (-not $App.Header) { return }
    $x = $App.Header.ClientSize.Width - 28
    $App.pillStatus.Left = $x - $App.pillStatus.Width
    $x = $App.pillStatus.Left - 10
    $App.pillBranch.Left = $x - $App.pillBranch.Width
}

# Barra lateral (itens de navegacao)
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
    $pen = New-Object Drawing.Pen($col, 2); $pen.StartCap = 'Round'; $pen.EndCap = 'Round'; $pen.LineJoin = 'Round'
    Draw-Icon $g $t.Icon ($w / 2) 26 $pen
    $pen.Dispose()
    $sb = New-Object Drawing.SolidBrush($col)
    Draw-Text $g $t.Label $Fnt.nav $sb 0 48 $w 16 $SFC
    $sb.Dispose()
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

# Card "Atividade recente" (ultimos commits)
function Paint-Recent($c, $ev) {
    $g = $ev.Graphics; $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'ClearTypeGridFit'
    $w = $c.ClientSize.Width; $h = $c.ClientSize.Height
    if ($w -lt 60 -or $h -lt 60) { return }
    $path = New-RoundPath 1 1 ($w - 3) ($h - 3) 16
    $g.FillPath($Bx.card, $path)
    $pen = New-Object Drawing.Pen($Colors.border, 1.5); $g.DrawPath($pen, $path); $pen.Dispose(); $path.Dispose()
    Draw-Text $g 'Atividade recente' $Fnt.h3 $Bx.text 20 14 ($w - 40) 26 $SFL
    Draw-Text $g 'Últimos commits da branch atual' $Fnt.small $Bx.muted 20 40 ($w - 40) 18 $SFL
    $rows = @($App.Recent)
    if ($rows.Count -eq 0) {
        Draw-Text $g 'Nenhum commit ainda. Use "Registrar Alterações" para criar o primeiro.' $Fnt.ui $Bx.muted 20 76 ($w - 40) 50 $SFW
        return
    }
    $y = 70
    $sep = New-Object Drawing.Pen($Colors.border, 1)
    foreach ($r in $rows) {
        if ($y + 34 -gt $h) { break }
        Draw-Text $g $r.Hash $Fnt.mono $Bx.orange1 20 $y 70 32 $SFV
        Draw-Text $g $r.Msg $Fnt.ui $Bx.text 96 $y ($w - 96 - 130) 32 $SFV
        Draw-Text $g $r.When $Fnt.small $Bx.muted ($w - 130) $y 110 32 $SFR
        DL $g $sep 20 ($y + 34) ($w - 20) ($y + 34)
        $y += 38
    }
    $sep.Dispose()
}

# ----------------------------------------------------------------------
# GRAFO DE BRANCHES (linhas, nos e rotulos)
# ----------------------------------------------------------------------
# Atribui "pistas" (colunas) aos commits. Retorna o numero maximo de pistas.
function Build-Graph($rows) {
    $lanes = New-Object System.Collections.ArrayList
    $maxL = 1
    foreach ($row in $rows) {
        $before = $lanes.ToArray()
        $l = -1
        for ($k = 0; $k -lt $lanes.Count; $k++) { if ($lanes[$k] -eq $row.Hash) { $l = $k; break } }
        if ($l -lt 0) {
            for ($k = 0; $k -lt $lanes.Count; $k++) { if ($null -eq $lanes[$k]) { $l = $k; break } }
            if ($l -lt 0) { [void]$lanes.Add($null); $l = $lanes.Count - 1 }
        }
        for ($k = 0; $k -lt $lanes.Count; $k++) { if ($k -ne $l -and $lanes[$k] -eq $row.Hash) { $lanes[$k] = $null } }
        $assigned = @()
        $par = @($row.Parents)
        if ($par.Count -eq 0) {
            $lanes[$l] = $null
        } else {
            $lanes[$l] = $par[0]; $assigned += $l
            for ($pi2 = 1; $pi2 -lt $par.Count; $pi2++) {
                $k = -1
                for ($j = 0; $j -lt $lanes.Count; $j++) { if ($lanes[$j] -eq $par[$pi2]) { $k = $j; break } }
                if ($k -lt 0) {
                    for ($j = 0; $j -lt $lanes.Count; $j++) { if ($null -eq $lanes[$j]) { $k = $j; break } }
                    if ($k -lt 0) { [void]$lanes.Add($null); $k = $lanes.Count - 1 }
                    $lanes[$k] = $par[$pi2]
                }
                $assigned += $k
            }
        }
        while ($lanes.Count -gt 0 -and $null -eq $lanes[$lanes.Count - 1]) { $lanes.RemoveAt($lanes.Count - 1) }
        $after = $lanes.ToArray()
        $row.Lane = $l; $row.Before = $before; $row.After = $after; $row.Assigned = $assigned
        $maxL = [Math]::Max($maxL, [Math]::Max($before.Count, [Math]::Max($after.Count, $l + 1)))
    }
    return $maxL
}

function Resize-Canvas {
    if (-not $App.gCanvas) { return }
    $n = 0
    if ($App.Graph) { $n = $App.Graph.Rows.Count }
    $App.gCanvas.Width = [Math]::Max(640, $App.gCont.ClientSize.Width)
    $App.gCanvas.Height = [Math]::Max(140, $n * 36 + 30)
    $App.gCanvas.Invalidate()
}

function Refresh-Graph {
    if (-not $App.Path) { return }
    $a = @('log')
    if ($App.chkAll.Checked) { $a += '--all' }
    $a += @('--topo-order', '-n', '80', '--pretty=format:%H%x1f%P%x1f%an%x1f%ar%x1f%D%x1f%s')
    $r = Invoke-Git $a -Quiet
    $rows = New-Object System.Collections.ArrayList
    $msg = ''
    if ($r.Ok -and $r.Out) {
        foreach ($ln in ($r.Out -split '\r?\n')) {
            if (-not $ln) { continue }
            $parts = $ln.Split([char]0x1f)
            if ($parts.Count -lt 6) { continue }
            $refs = @()
            foreach ($x in ($parts[4] -split ', ')) {
                $rf = $x.Trim()
                if (-not $rf -or $rf -eq 'origin/HEAD') { continue }
                if ($rf.StartsWith('HEAD -> ')) { $refs += @{ Text = $rf.Substring(8); Kind = 'head' } }
                elseif ($rf -eq 'HEAD') { $refs += @{ Text = 'HEAD'; Kind = 'head' } }
                elseif ($rf.StartsWith('tag: ')) { $refs += @{ Text = $rf.Substring(5); Kind = 'tag' } }
                elseif ($rf.StartsWith('origin/')) { $refs += @{ Text = $rf; Kind = 'remote' } }
                else { $refs += @{ Text = $rf; Kind = 'branch' } }
            }
            [void]$rows.Add(@{
                Hash = $parts[0]; Parents = @($parts[1] -split ' ' | Where-Object { $_ }); Author = $parts[2]; When = $parts[3]
                Refs = $refs; Msg = $parts[5]; IsHead = [bool]($parts[4] -match '(^|, )HEAD( ->|,|$)')
            })
        }
    }
    if ($rows.Count -eq 0) {
        if (-not $r.Ok -and $r.Text -notmatch 'does not have any commits|bad default revision|unknown revision') {
            $msg = 'Não foi possível ler o histórico: ' + $r.Text
        } else {
            $msg = "Nenhum commit ainda.`n`nFaça o primeiro commit com 'Registrar Alterações' e o grafo aparecerá aqui."
        }
    }
    $lanes = 1
    if ($rows.Count -gt 0) { $lanes = Build-Graph $rows }
    $App.Graph = @{ Rows = $rows; Lanes = $lanes; Msg = $msg }
    Write-Info ('Grafo atualizado (' + $r.Display + ')')
    Resize-Canvas
}

function Draw-Badge($g, [double]$x, [double]$y, $b) {
    $tw = $g.MeasureString($b.Text, $Fnt.smallB).Width
    $w = [Math]::Min($tw + 16, 190)
    $p = New-RoundPath $x $y $w 20 10
    $tc = $Bx.white
    switch ($b.Kind) {
        'head'   { $fill = New-Grad $x $y $w 20 $Colors.orange1 $Colors.orange2 0 }
        'tag'    { $fill = New-Object Drawing.SolidBrush($Colors.yellow); $tc = $Bx.dark }
        'remote' { $fill = New-Object Drawing.SolidBrush($Colors.gray1); $tc = $Bx.muted }
        default  { $fill = New-Object Drawing.SolidBrush($Colors.purple1) }
    }
    $g.FillPath($fill, $p); $fill.Dispose(); $p.Dispose()
    Draw-Text $g $b.Text $Fnt.smallB $tc $x $y $w 20 $SFC
    return ($w + 6)
}

function Paint-Graph($c, $ev) {
    $g = $ev.Graphics; $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'ClearTypeGridFit'
    $gr = $App.Graph
    if (-not $gr) { return }
    $rows = $gr.Rows; $n = $rows.Count
    $w = $c.ClientSize.Width
    if ($n -eq 0) { Draw-Text $g $gr.Msg $Fnt.ui $Bx.muted 28 24 ($w - 56) 120 $SFW; return }
    $rowH = 36; $laneW = 22; $x0 = 30; $y0 = 10
    $clip = $ev.ClipRectangle
    $first = [Math]::Max(0, [int][Math]::Floor(($clip.Top - $y0) / $rowH) - 1)
    $last = [Math]::Min($n - 1, [int][Math]::Ceiling(($clip.Bottom - $y0) / $rowH) + 1)
    $textX = $x0 + $gr.Lanes * $laneW + 18
    $metaX = [Math]::Max($textX + 260, $w - 350)
    for ($i = $first; $i -le $last; $i++) {
        $row = $rows[$i]
        $yt = $y0 + $i * $rowH; $ym = $yt + $rowH / 2; $yb = $yt + $rowH
        $xl = $x0 + $row.Lane * $laneW
        if ($row.IsHead) {
            $hp = New-RoundPath 8 ($yt + 2) ($w - 16) ($rowH - 4) 10
            $g.FillPath($Bx.panel2, $hp); $hp.Dispose()
        }
        # metade de cima: linhas que chegam ao commit
        for ($k = 0; $k -lt $row.Before.Count; $k++) {
            $hk = $row.Before[$k]
            if ($null -eq $hk) { continue }
            $xk = $x0 + $k * $laneW; $pen = $LanePens[$k % $LanePens.Count]
            if ($hk -eq $row.Hash -and $k -ne $row.Lane) { DB $g $pen $xk $yt $xk $ym $xl $yt $xl $ym }
            else { DL $g $pen $xk $yt $xk $ym }
        }
        # metade de baixo: linhas que saem do commit (para os pais) ou continuam
        for ($k = 0; $k -lt $row.After.Count; $k++) {
            $ha = $row.After[$k]
            if ($null -eq $ha) { continue }
            $xk = $x0 + $k * $laneW; $pen = $LanePens[$k % $LanePens.Count]
            $isAssigned = ($row.Assigned -contains $k)
            $wasThere = ($k -lt $row.Before.Count -and $row.Before[$k] -eq $ha)
            if ($isAssigned -and $k -ne $row.Lane) { DB $g $pen $xl $ym $xl $yb $xk $ym $xk $yb }
            if ($k -eq $row.Lane -or $wasThere) { DL $g $pen $xk $ym $xk $yb }
        }
        # no (commit)
        $nb = $LaneBrushes[$row.Lane % $LaneBrushes.Count]
        $rad = 6
        if ($row.IsHead) { $rad = 8 }
        $g.FillEllipse($Bx.panel, [single]($xl - $rad - 3), [single]($ym - $rad - 3), [single]($rad * 2 + 6), [single]($rad * 2 + 6))
        $g.FillEllipse($nb, [single]($xl - $rad), [single]($ym - $rad), [single]($rad * 2), [single]($rad * 2))
        if (@($row.Parents).Count -gt 1) { $g.FillEllipse($Bx.panel, [single]($xl - 2.5), [single]($ym - 2.5), [single]5, [single]5) }
        if ($row.IsHead) {
            $wp = New-Object Drawing.Pen($Colors.white, 2)
            DE $g $wp ($xl - $rad - 2) ($ym - $rad - 2) ($rad * 2 + 4) ($rad * 2 + 4)
            $wp.Dispose()
        }
        # textos: rotulos de branch/tag, mensagem, hash, autor, data
        $x = $textX
        foreach ($bd in $row.Refs) { $x += (Draw-Badge $g $x ($ym - 10) $bd) }
        $mw = $metaX - $x - 12
        if ($mw -gt 40) { Draw-Text $g $row.Msg $Fnt.ui $Bx.text $x ($ym - 11) $mw 22 $SFV }
        Draw-Text $g $row.Hash.Substring(0, 7) $Fnt.mono $Bx.orange1 $metaX ($ym - 11) 70 22 $SFV
        Draw-Text $g $row.Author $Fnt.small $Bx.muted ($metaX + 76) ($ym - 11) 120 22 $SFV
        Draw-Text $g $row.When $Fnt.small $Bx.muted ($metaX + 200) ($ym - 11) ([Math]::Max(10, $w - ($metaX + 200) - 12)) 22 $SFV
    }
}

# ----------------------------------------------------------------------
# MENU_PRINCIPAL / MENU_PROJETO: paginas e navegacao
# ----------------------------------------------------------------------
function Show-Page([string]$name) {
    $App.Page = $name
    foreach ($k in @($App.Pages.Keys)) { $App.Pages[$k].Visible = ($k -eq $name) }
    switch ($name) {
        'start' { $App.hTitle.Text = 'Bem-vindo'; $App.hSub.Text = 'Escolha como deseja começar' }
        'home'  { $App.hTitle.Text = 'Painel do projeto'; $App.hSub.Text = [string]$App.Path }
        'graph' { $App.hTitle.Text = 'Grafo de branches'; $App.hSub.Text = 'Cada linha colorida é uma branch; o círculo grande é onde você está (HEAD)' }
        'cmds'  { $App.hTitle.Text = 'Mais comandos individuais'; $App.hSub.Text = 'Cada card executa um único comando Git, com confirmação quando há risco' }
    }
    foreach ($n in $App.NavItems) { $n.Tag.Selected = ($n.Tag.Key -eq $name); $n.Invalidate() }
    $hasProj = [bool]$App.Path
    $App.pillBranch.Visible = $hasProj; $App.pillStatus.Visible = $hasProj
    Layout-Header
    if ($name -eq 'graph') { Refresh-Graph }
}
function Nav-Home { Show-Page 'home' }
function Nav-Graph { Show-Page 'graph' }
function Nav-Cmds { Show-Page 'cmds' }

function Show-StartPanel {
    $App.Path = $null
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
    Show-Page 'home'
    Write-Info ('Projeto aberto: ' + $dir)
    Update-State
}

# Atualiza branch atual / status / commits recentes na GUI (apos cada operacao)
function Update-State {
    if (-not $App.Path) { return }
    $b = Invoke-Git @('branch', '--show-current') -Quiet
    $name = ''
    if ($b.Ok) { $name = $b.Out.Trim() }
    if (-not $name) {
        $b2 = Invoke-Git @('symbolic-ref', '--short', '-q', 'HEAD') -Quiet
        if ($b2.Ok) { $name = $b2.Out.Trim() }
    }
    if (-not $name) { $name = '(HEAD destacado)' }
    $App.Branch = $name
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

    Set-Pill $App.pillBranch ('Branch: ' + $App.Branch) 'accent'
    Set-Pill $App.pillStatus $txt $col
    $chipCh = @{ Text = ('Alterações: ' + $lines.Count); Color = $Colors.success }
    if ($lines.Count -gt 0) { $chipCh.Color = $Colors.warn }
    $chipRm = @{ Text = 'Remoto: origin'; Color = $Colors.success }
    if (-not $hasRemote) { $chipRm = @{ Text = 'Sem remoto (origin)'; Color = $Colors.orange2 } }
    $title = 'Olá!'
    if ($first) { $title = 'Olá, ' + $first + '!' }
    $App.bannerHome.Tag.Title = $title
    $App.bannerHome.Tag.Sub = 'Você está trabalhando em ' + $App.Name
    $App.bannerHome.Tag.Path = $App.Path
    $App.bannerHome.Tag.Chips = @($chipCh, $chipRm)
    $App.bannerHome.Invalidate()
    $App.recentCard.Invalidate()
    if ($App.Page -eq 'home') { $App.hSub.Text = [string]$App.Path }
    Layout-Header
    if ($App.Page -eq 'graph') { Refresh-Graph }
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
    catch { Show-Msg 'Erro' ("Não foi possível criar a pasta:`n$target`n`n" + $_.Exception.Message) 'error'; return }
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
            if (-not (Test-RepoUrl $url)) { Show-Msg 'URL inválida' "Use uma URL como:`nhttps://github.com/usuario/projeto.git" 'error'; continue }
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
        if (Test-RepoUrl $url) { break }
        Show-Msg 'URL inválida' "Use um link como:`nhttps://github.com/usuario/projeto.git" 'error'
    }

    $txt = "Você está prestes a clonar:`n`n$url`n`nDestino:`n`n$target`n`nComando:`ngit clone <URL> <destino>"
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
# ABRIR_PROJETO (nunca executa git init / git clone)
# ----------------------------------------------------------------------
function Acao-AbrirProjeto {
    $p = Select-Folder 'Selecione a pasta do projeto (que contém o repositório Git)' '' $false
    if (-not $p) { return }
    $root = Resolve-RepoRoot $p
    if (-not $root) {
        Show-Msg 'Repositório não encontrado' "A pasta selecionada não é um repositório Git válido:`n$p`n`nNada foi alterado. Use 'Novo Projeto' ou 'Clonar Repositório' se precisar criar um." 'error'
        return
    }
    if ($root -ne $p) { Write-Info ('O repositório está na pasta: ' + $root) }
    Show-ProjectPanel $root
}

# ----------------------------------------------------------------------
# ATUALIZAR (git pull origin)
# ----------------------------------------------------------------------
function Acao-Atualizar {
    if (-not $App.Path) { return }
    if (-not (Test-Origin)) {
        Show-Msg 'Sem remoto configurado' "Este projeto não tem um remoto chamado 'origin'.`n`nConecte o projeto ao GitHub (git remote add origin <URL>) antes de atualizar." 'warn'
        return
    }
    # Se a branch ainda nao esta ligada ao GitHub (sem upstream), o pull precisa dizer qual branch puxar
    $hasUp = (Invoke-Git @('rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}') -Quiet).Ok
    if ($App.Branch -eq '(HEAD destacado)') { Show-Msg 'Atualizar' 'Você está sem branch (HEAD destacado). Volte para uma branch antes de atualizar.' 'error'; return }
    if ($hasUp) { $pullArgs = @('pull', 'origin') } else { $pullArgs = @('pull', 'origin', $App.Branch) }
    $pullDisp = 'git ' + ($pullArgs -join ' ')
    $ch = @(Get-Changes)
    if ($ch.Count -gt 0) {
        $txt = "Existem $($ch.Count) alteração(ões) local(is) não registrada(s):`n`n" + (Format-Changes $ch) + "`n`nO pull pode falhar ou gerar conflitos com essas alterações.`n`nComando:`n$pullDisp"
        $ok = Confirm-Action 'Atualizar projeto' $txt 'Continuar mesmo assim' 'warn'
    } else {
        $txt = "Branch atual:`n$($App.Branch)`n`nSerá executado:`n$pullDisp`n`nTrazer as novidades do GitHub para o seu projeto?"
        $ok = Confirm-Action 'Atualizar projeto' $txt 'Atualizar' 'info'
    }
    if (-not $ok) { Write-Info 'Atualização cancelada.'; return }
    $r = Invoke-Git $pullArgs
    if ($r.Ok -and -not $hasUp) {
        # guarda a ligacao com o GitHub para os proximos pulls/pushes
        [void](Invoke-Git @('branch', ('--set-upstream-to=origin/' + $App.Branch), $App.Branch))
    }
    Update-State
    if ($r.Ok) {
        $t = $r.Text; if ($t.Length -gt 500) { $t = $t.Substring(0, 500) + ' [...]' }
        Show-Msg 'Projeto atualizado' ("Operação concluída.`n`n" + $t) 'success'
    } else {
        $extra = ''
        if (@(Get-ConflictFiles).Count -gt 0) { $extra = 'Há arquivos em conflito. Resolva-os manualmente e registre as alterações.' }
        elseif ($r.Text -match 'unrelated histories') { $extra = 'O repositório local e o do GitHub têm históricos diferentes (ambos já têm commits próprios). Nada foi alterado.' }
        elseif ($r.Text -match "couldn't find remote ref|Couldn.t find remote ref") { $extra = 'Essa branch ainda não existe no GitHub. Use Publicar Branch (ou envie a primeira vez com git push -u origin <branch>).' }
        Show-GitError $r $extra
    }
}

# ----------------------------------------------------------------------
# CRIAR_BRANCH
# ----------------------------------------------------------------------
function Acao-CriarBranch {
    if (-not $App.Path) { return }
    $txt = "Será executado:`ngit switch -c <nome>`n`nA nova branch parte da branch atual ($($App.Branch)). Use nomes sem espaços, como feature-login."
    $name = Ask-Text 'Criar branch' $txt 'Nome da branch:' '' 'Criar branch'
    if ($null -eq $name) { return }
    if ($name.StartsWith('-')) { Show-Msg 'Nome inválido' "O nome da branch não pode começar com '-'." 'error'; return }
    $v = Invoke-Git @('check-ref-format', '--branch', $name) -Quiet
    if (-not $v.Ok) {
        Show-Msg 'Nome inválido' "O Git não aceita esse nome de branch.`n`nEvite espaços e os caracteres ~ ^ : ? * [ \ além de '..' e '@{'." 'error'
        return
    }
    $r = Invoke-Git @('switch', '-c', $name)
    Update-State
    if ($r.Ok) { Show-Msg 'Branch criada' "Branch atual:`n$name" 'success' } else { Show-GitError $r }
}

# ----------------------------------------------------------------------
# REGISTRAR_ALTERACOES (git add + git commit)
# ----------------------------------------------------------------------
function Acao-Registrar {
    if (-not $App.Path) { return }
    $ch = @(Get-Changes)
    if ($ch.Count -eq 0) { Show-Msg 'Nada para registrar' 'Não há alterações pendentes neste projeto.' 'info'; return }

    $un = (Invoke-Git @('config', '--local', '--get', 'user.name') -Quiet).Out.Trim()
    $ue = (Invoke-Git @('config', '--local', '--get', 'user.email') -Quiet).Out.Trim()
    if (-not $un -or -not $ue) {
        $go = Confirm-Action 'Usuário Git não configurado' "Este projeto ainda não tem nome e e-mail configurados para os commits.`n`nDeseja configurar agora? (git config --local)" 'Configurar' 'info'
        if (-not $go) { return }
        if (-not (Configurar-Usuario)) { return }
    }

    $txt = "Existem $($ch.Count) alteração(ões) pendente(s):`n`n" + (Format-Changes $ch) + "`n`nEscolha o que será incluído no commit."
    $c = Show-Dialog -Title 'Como deseja adicionar os arquivos?' -Message $txt -Kind 'info' -Buttons @((New-BtnDef 'Cancelar' 'cancel' 'secondary'), (New-BtnDef 'Arquivo específico' 'file' 'secondary'), (New-BtnDef 'Todos os arquivos' 'all' 'primary'))
    if ($c.Result -ne 'all' -and $c.Result -ne 'file') { return }

    $addArgs = @('add', '.')
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
        $rel = @()
        foreach ($file in $sel) {
            if (-not $file.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) {
                Show-Msg 'Arquivo fora do projeto' "Escolha apenas arquivos dentro da pasta do projeto:`n$($App.Path)`n`nArquivo escolhido:`n$file" 'error'
                return
            }
            $rel += $file.Substring($base.Length).Replace('\', '/')
        }
        $addArgs = @('add', '--') + $rel
        $addDisp = 'git add -- ' + (($rel | ForEach-Object { '"' + $_ + '"' }) -join ' ')
    }

    $txt2 = "Serão executados:`n$addDisp`ngit commit -m `"mensagem`"`n`nDescreva o que foi feito. Exemplo: Adiciona sistema de login"
    $msg = Ask-Text 'Mensagem do commit' $txt2 'Mensagem do commit:' '' 'Registrar'
    if ($null -eq $msg) { Write-Info 'Registro cancelado. Nada foi adicionado.'; return }

    $r = Invoke-Git $addArgs
    if (-not $r.Ok) { Show-GitError $r; Update-State; return }
    $staged = Invoke-Git @('diff', '--cached', '--quiet') -Quiet
    if ($staged.ExitCode -eq 0) {
        Update-State
        Show-Msg 'Nada para registrar' 'Nenhuma alteração ficou preparada para o commit (os arquivos escolhidos não têm mudanças).' 'info'
        return
    }
    $r = Invoke-Git @('commit', '-m', $msg)
    Update-State
    if ($r.Ok) {
        $t = $r.Text; if ($t.Length -gt 600) { $t = $t.Substring(0, 600) + ' [...]' }
        Show-Msg 'Alterações registradas' ("Commit criado com sucesso.`n`n" + $t) 'success'
    } else { Show-GitError $r 'Os arquivos continuam preparados (git add já foi feito).' }
}

# ----------------------------------------------------------------------
# PUBLICAR_BRANCH (git merge main  ->  git push)
# ----------------------------------------------------------------------
function Acao-Publicar {
    if (-not $App.Path) { return }
    Update-State
    $br = $App.Branch
    if ($br -eq '(HEAD destacado)') { Show-Msg 'Publicar Branch' 'Você está sem branch (HEAD destacado). Volte para uma branch de trabalho antes de publicar.' 'error'; return }
    if ($br -eq 'main') { Show-Msg 'Publicar Branch' "Você está na main.`n`nEsta opção serve para branches de trabalho (ex.: feature-login). Crie uma branch com 'Criar Branch'.`n`nPara enviar a própria main (primeiro envio), use Mais comandos > git push." 'warn'; return }
    if (Test-Merging) { Show-Msg 'Merge em andamento' 'Há um merge em andamento. Resolva os conflitos e registre as alterações antes de publicar.' 'warn'; return }
    if (-not (Test-Origin)) { Show-Msg 'Sem remoto configurado' "Este projeto não tem um remoto chamado 'origin'.`n`nConecte o projeto ao GitHub (git remote add origin <URL>) antes de publicar." 'warn'; return }
    if (-not (Test-LocalMain)) { Show-Msg 'Branch main não encontrada' "A branch local 'main' não existe neste projeto, então não há com o que atualizar a sua branch." 'error'; return }

    $pend = @(Get-Changes -TrackedOnly)
    $warnTxt = ''
    if ($pend.Count -gt 0) { $warnTxt = "`n`n! Há $($pend.Count) alteração(ões) não registrada(s). Elas NÃO farão parte da publicação (use 'Registrar Alterações' antes)." }
    $txt = "Branch atual:`n$br`n`nComando:`ngit merge main`n`nO merge usa a main local do seu computador.$warnTxt"
    if (-not (Confirm-Action 'Atualizar branch com a main?' $txt 'Continuar' 'warn')) { Write-Info 'Publicação cancelada.'; return }

    $m = Invoke-Git @('merge', 'main')
    Update-State
    if (-not $m.Ok) {
        $cf = @(Get-ConflictFiles)
        if ($cf.Count -gt 0) {
            $t = "O merge encontrou conflitos e foi interrompido. O push NÃO foi feito.`n`nArquivos em conflito:`n" + (Format-Changes $cf) + "`n`nResolva os conflitos nos arquivos, use 'Registrar Alterações' para concluir o merge e publique novamente.`n`nPara desfazer o merge, rode 'git merge --abort' em um terminal."
            Show-Msg 'Conflito no merge' $t 'error'
        } else {
            Show-GitError $m 'O push não foi feito.'
        }
        return
    }

    $txt2 = "Enviar a branch para o GitHub?`n`nBranch:`n$br`n`nComando:`ngit push -u origin $br`n`n(-u guarda a ligação com o GitHub, para o 'Atualizar' funcionar depois.)"
    if (-not (Confirm-Action 'Publicar branch' $txt2 'Publicar' 'info')) { Write-Info 'Push cancelado. O merge com a main já foi feito localmente.'; return }
    $p = Invoke-Git @('push', '-u', 'origin', $br)
    Update-State
    if ($p.Ok) { Show-Msg 'Branch publicada' "A branch '$br' foi enviada ao GitHub." 'success' }
    else { Show-GitError $p 'O merge local foi feito, mas a branch não foi enviada.' }
}

# ----------------------------------------------------------------------
# CONCLUIR_TRABALHO (operacao de alto risco: exige digitar CONFIRMAR)
#   git switch main -> git merge <branch> -> git push -> git branch -d <branch>
# ----------------------------------------------------------------------
function Acao-Concluir {
    if (-not $App.Path) { return }
    Update-State
    $br = $App.Branch
    if ($br -eq '(HEAD destacado)') { Show-Msg 'Concluir Trabalho' 'Você está sem branch (HEAD destacado). Volte para uma branch de trabalho antes de concluir.' 'error'; return }
    if ($br -eq 'main') { Show-Msg 'Concluir Trabalho' "Você já está na main.`n`nUse esta opção a partir de uma branch de trabalho (ex.: feature-login)." 'warn'; return }
    if (Test-Merging) { Show-Msg 'Merge em andamento' 'Há um merge em andamento. Finalize-o antes de concluir o trabalho.' 'warn'; return }
    if (-not (Test-Origin)) { Show-Msg 'Sem remoto configurado' "Este projeto não tem um remoto chamado 'origin'. Conecte-o ao GitHub antes de concluir." 'warn'; return }
    if (-not (Test-LocalMain)) { Show-Msg 'Branch main não encontrada' "A branch local 'main' não existe neste projeto." 'error'; return }
    $pend = @(Get-Changes -TrackedOnly)
    if ($pend.Count -gt 0) {
        Show-Msg 'Alterações pendentes' ("Há alterações não registradas:`n`n" + (Format-Changes $pend) + "`n`nUse 'Registrar Alterações' antes de concluir o trabalho.") 'warn'
        return
    }

    # Se a main local ainda nao tem ligacao com o GitHub, o primeiro push precisa de -u
    $up = (Invoke-Git @('rev-parse', '--abbrev-ref', '--symbolic-full-name', 'main@{u}') -Quiet).Ok
    if ($up) { $pushArgs = @('push') } else { $pushArgs = @('push', '-u', 'origin', 'main') }
    $pushDisp = 'git ' + ($pushArgs -join ' ')

    $txt = "Branch atual:`n$br`n`nDestino:`nmain`n`nSerão realizadas:`n`ngit switch main`ngit merge $br`n$pushDisp`ngit branch -d $br`n`nIsso irá integrar o trabalho à main e remover a branch local."
    $r = Show-Dialog -Title 'CONCLUIR TRABALHO' -Message $txt -Kind 'danger' -InputLabel 'Digite CONFIRMAR para continuar:' -Require 'exact' -Exact 'CONFIRMAR' -Buttons @((New-BtnDef 'Cancelar' 'cancel' 'secondary'), (New-BtnDef 'Concluir trabalho' 'ok' 'danger'))
    if ($r.Result -ne 'ok') { Write-Info 'Conclusão cancelada. Nada foi alterado.'; return }

    # Uma operacao por vez; qualquer falha interrompe tudo e preserva a branch
    $steps = @(
        @{ A = @('switch', 'main'); D = 'git switch main' },
        @{ A = @('merge', $br); D = "git merge $br" },
        @{ A = $pushArgs; D = $pushDisp },
        @{ A = @('branch', '-d', $br); D = "git branch -d $br" }
    )
    $done = @()
    for ($i = 0; $i -lt $steps.Count; $i++) {
        $st = $steps[$i]
        $res = Invoke-Git $st.A
        Update-State
        if (-not $res.Ok) {
            if ($done.Count -gt 0) { $head = "Etapas concluídas:`n" + ($done -join "`n") } else { $head = 'Nenhuma etapa foi concluída.' }
            switch ($i) {
                0 { $why = 'Não foi possível trocar para a main. Nada foi alterado e a branch não foi excluída.' }
                1 {
                    $why = "A integração falhou. Você está na main e a branch '$br' foi mantida (não foi excluída)."
                    $cf = @(Get-ConflictFiles)
                    if ($cf.Count -gt 0) { $why += "`n`nArquivos em conflito:`n" + (Format-Changes $cf) + "`n`nResolva-os manualmente e registre as alterações, ou desfaça com 'git merge --abort' em um terminal." }
                }
                2 { $why = "O push falhou. O merge já está na main LOCAL, mas não foi enviado ao GitHub. A branch '$br' foi mantida." }
                default { $why = "A integração e o envio foram concluídos, mas a exclusão da branch local '$br' falhou. O Git recusa excluir branches não integradas (nada foi forçado)." }
            }
            Show-GitError $res ($head + "`n`n" + $why)
            return
        }
        $done += ([string][char]0x2713 + ' ' + $st.D)
    }
    Show-Msg 'Trabalho concluído' "A branch '$br' foi integrada à main, enviada ao GitHub e removida localmente.`n`nBranch atual: main" 'success'
}

# ----------------------------------------------------------------------
# STATUS
# ----------------------------------------------------------------------
function Acao-Status {
    if (-not $App.Path) { return }
    [void](Invoke-Git @('status'))
    Update-State
    $ch = @(Get-Changes)
    Write-Info ('Projeto: ' + $App.Name)
    Write-Info ('Branch atual: ' + $App.Branch)
    Write-Info ('Alterações pendentes: ' + $ch.Count)
    Write-Info ('Situação do repositório: ' + $App.StatusText)
    Write-Log ''
}

# ----------------------------------------------------------------------
# MAIS_COMANDOS: comandos Git individuais (pagina "Comandos")
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
    $r = Invoke-Git @('switch', $name)
    Update-State
    if ($r.Ok) { Show-Msg 'Branch alterada' "Branch atual:`n$name" 'success' } else { Show-GitError $r }
}

function Invoke-BranchSwitcher([string]$Title) {
    if (-not $App.Path) { return }
    $bl = Get-BranchList
    if ($null -eq $bl) { return }
    if ($bl.Items.Count -eq 0) {
        Show-Msg 'Branches' "Ainda não há branches com commits neste projeto.`n`nFaça o primeiro commit com 'Registrar Alterações'." 'info'
        return
    }
    $pick = Select-FromList $Title "Resultado de git branch.`nBranch atual: $($bl.Current)`n`nSelecione uma branch para trocar (git switch) ou feche." $bl.Items $bl.Current 'Trocar para esta' 'primary'
    if ($null -eq $pick) { return }
    Switch-ToBranch $pick $bl.Current
}
function Acao-Branch { Invoke-BranchSwitcher 'Branches locais (git branch)' }
function Acao-Switch { Invoke-BranchSwitcher 'Trocar de branch (git switch)' }

function Acao-ExcluirBranch {
    if (-not $App.Path) { return }
    Update-State
    $cur = $App.Branch
    $bl = Get-BranchList
    if ($null -eq $bl) { return }
    $items = @($bl.Items | Where-Object { $_ -ne $cur -and $_ -ne 'main' })
    if ($items.Count -eq 0) { Show-Msg 'Excluir branch' "Não há outras branches locais para excluir.`n`n(A branch atual e a main não aparecem nesta lista.)" 'info'; return }
    $pick = Select-FromList 'Excluir branch (git branch -d)' "Escolha a branch local que deseja excluir.`n`nO Git só exclui se ela já estiver integrada; caso contrário, recusa e nada é perdido." $items '' 'Excluir...' 'danger'
    if ($null -eq $pick) { return }
    $txt = "Excluir a branch local:`n$pick`n`nComando:`ngit branch -d $pick`n`nO comando -d é seguro: o Git recusa se houver commits não integrados."
    if (-not (Confirm-Action 'Excluir branch' $txt 'Excluir branch' 'danger')) { Write-Info 'Exclusão cancelada.'; return }
    $r = Invoke-Git @('branch', '-d', $pick)
    Update-State
    if ($r.Ok) { Show-Msg 'Branch excluída' "A branch '$pick' foi excluída localmente." 'success' }
    else { Show-GitError $r 'Nada foi forçado. A branch foi mantida.' }
}

function Acao-Merge {
    if (-not $App.Path) { return }
    Update-State
    $cur = $App.Branch
    if ($cur -eq '(HEAD destacado)') { Show-Msg 'Mesclar branch' 'Você está sem branch (HEAD destacado). Volte para uma branch antes de mesclar.' 'error'; return }
    if (Test-Merging) { Show-Msg 'Merge em andamento' 'Há um merge em andamento. Finalize-o antes de iniciar outro.' 'warn'; return }
    $bl = Get-BranchList
    if ($null -eq $bl) { return }
    $items = @($bl.Items | Where-Object { $_ -ne $cur })
    if ($items.Count -eq 0) { Show-Msg 'Mesclar branch' 'Não há outras branches locais para mesclar.' 'info'; return }
    $pick = Select-FromList 'Mesclar branch (git merge)' "Escolha a branch que será trazida para '$cur'." $items '' 'Continuar' 'primary'
    if ($null -eq $pick) { return }
    $txt = "Branch atual (receberá as mudanças):`n$cur`n`nBranch que será mesclada:`n$pick`n`nComando:`ngit merge $pick"
    if (-not (Confirm-Action 'Mesclar branch' $txt 'Mesclar' 'warn')) { Write-Info 'Merge cancelado.'; return }
    $m = Invoke-Git @('merge', $pick)
    Update-State
    if ($m.Ok) { Show-Msg 'Merge concluído' ("A branch '$pick' foi mesclada em '$cur'.`n`n" + $m.Text) 'success'; return }
    $cf = @(Get-ConflictFiles)
    if ($cf.Count -gt 0) {
        Show-Msg 'Conflito no merge' ("O merge encontrou conflitos e foi interrompido.`n`nArquivos em conflito:`n" + (Format-Changes $cf) + "`n`nResolva-os nos arquivos e use 'Registrar Alterações' para concluir. Para desfazer, rode 'git merge --abort' em um terminal.") 'error'
    } else { Show-GitError $m }
}

function Acao-Fetch {
    if (-not $App.Path) { return }
    if (-not (Test-Origin)) { Show-Msg 'Sem remoto configurado' "Este projeto não tem um remoto chamado 'origin'." 'warn'; return }
    $r = Invoke-Git @('fetch', 'origin')
    Update-State
    if ($r.Ok) { Show-Msg 'Busca concluída' ("Seus arquivos não foram alterados.`n`n" + $(if ($r.Text) { $r.Text } else { 'Nada novo no GitHub.' })) 'success' } else { Show-GitError $r }
}

function Acao-Push {
    if (-not $App.Path) { return }
    Update-State
    $b = $App.Branch
    if ($b -eq '(HEAD destacado)') { Show-Msg 'Enviar branch' 'Você está sem branch (HEAD destacado).' 'error'; return }
    if (-not (Test-Origin)) { Show-Msg 'Sem remoto configurado' "Este projeto não tem um remoto chamado 'origin'.`n`nConecte-o ao GitHub (git remote add origin <URL>) antes de enviar." 'warn'; return }
    $up = (Invoke-Git @('rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}') -Quiet).Ok
    if ($up) { $pushArgs = @('push') } else { $pushArgs = @('push', '-u', 'origin', $b) }
    $disp = 'git ' + ($pushArgs -join ' ')
    $pend = @(Get-Changes -TrackedOnly)
    $note = ''
    if ($pend.Count -gt 0) { $note = "`n`n! Há $($pend.Count) alteração(ões) não registrada(s); elas não serão enviadas." }
    if ($b -eq 'main') { $note += "`n`nVocê está enviando a main." }
    $kind = 'info'; if ($b -eq 'main') { $kind = 'warn' }
    $txt = "Enviar ao GitHub os commits da branch:`n$b`n`nComando:`n$disp$note"
    if (-not (Confirm-Action 'Enviar branch' $txt 'Enviar' $kind)) { Write-Info 'Envio cancelado.'; return }
    $r = Invoke-Git $pushArgs
    Update-State
    if ($r.Ok) { Show-Msg 'Envio concluído' "A branch '$b' foi enviada ao GitHub." 'success' } else { Show-GitError $r }
}

function Acao-AddTudo {
    if (-not $App.Path) { return }
    $ch = @(Get-Changes)
    if ($ch.Count -eq 0) { Show-Msg 'Nada para preparar' 'Não há alterações pendentes.' 'info'; return }
    $txt = "Marcar todas as alterações para o próximo commit?`n`n" + (Format-Changes $ch) + "`n`nComando:`ngit add ."
    if (-not (Confirm-Action 'Preparar tudo' $txt 'Preparar' 'info')) { Write-Info 'Cancelado.'; return }
    $r = Invoke-Git @('add', '.')
    Update-State
    if ($r.Ok) { Show-Msg 'Alterações preparadas' "Tudo foi marcado para o commit.`n`nUse 'Registrar Alterações' para criar o commit." 'success' } else { Show-GitError $r }
}

function Acao-Stash {
    if (-not $App.Path) { return }
    $pend = @(Get-Changes -TrackedOnly)
    if ($pend.Count -eq 0) { Show-Msg 'Nada para guardar' 'Não há alterações em arquivos rastreados para guardar.' 'info'; return }
    $txt = "Guardar temporariamente estas alterações?`n`n" + (Format-Changes $pend) + "`n`nOs arquivos voltam ao último commit; depois você pode recuperá-las.`n`nComando:`ngit stash"
    if (-not (Confirm-Action 'Guardar alterações' $txt 'Guardar' 'warn')) { Write-Info 'Cancelado.'; return }
    $r = Invoke-Git @('stash')
    Update-State
    if ($r.Ok) { Show-Msg 'Alterações guardadas' ("Para trazê-las de volta, use 'Recuperar guardadas'.`n`n" + $r.Text) 'success' } else { Show-GitError $r }
}

function Acao-StashPop {
    if (-not $App.Path) { return }
    $l = Invoke-Git @('stash', 'list') -Quiet
    if (-not $l.Ok -or -not $l.Out.Trim()) { Show-Msg 'Nada guardado' 'Não há alterações guardadas (git stash) neste projeto.' 'info'; return }
    $txt = "Reaplicar a alteração guardada mais recente?`n`n$($l.Out.Split([char]10)[0])`n`nComando:`ngit stash pop"
    if (-not (Confirm-Action 'Recuperar guardadas' $txt 'Recuperar' 'warn')) { Write-Info 'Cancelado.'; return }
    $r = Invoke-Git @('stash', 'pop')
    Update-State
    if ($r.Ok) { Show-Msg 'Alterações recuperadas' 'As alterações guardadas voltaram para os seus arquivos.' 'success' }
    else { Show-GitError $r 'Se houve conflito, resolva os arquivos manualmente. A alteração guardada é mantida pelo Git nesse caso.' }
}

function Acao-LogTexto {
    if (-not $App.Path) { return }
    $r = Invoke-Git @('log', '--oneline', '--graph', '--all', '--decorate', '-n', '20')
    if (-not $r.Ok -and $r.Text -match 'does not have any commits') { Show-Msg 'Histórico' 'Ainda não há commits neste projeto.' 'info'; return }
    Show-Output 'Histórico (git log)' $r 'Sem commits.'
}
function Acao-Diff {
    if (-not $App.Path) { return }
    $r = Invoke-Git @('diff', '--stat')
    Show-Output 'Diferenças (git diff --stat)' $r 'Nenhuma diferença em arquivos rastreados (arquivos novos não aparecem aqui).'
}
function Acao-Remotos {
    if (-not $App.Path) { return }
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
        return [pscustomobject]@{ Ok = $false; ExitCode = -1; Out = ''; Text = $_.Exception.Message }
    }
    $tx = (@($so.TrimEnd(), $se.TrimEnd()) | Where-Object { $_ }) -join "`n"
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
# SAIR / TROCAR PROJETO
# ----------------------------------------------------------------------
function Acao-Sair { $App.Form.Close() }
function Acao-TrocarProjeto { Show-StartPanel; Write-Info 'Projeto fechado. Escolha como deseja continuar.' }

# ======================================================================
# VERIFICACAO DO GIT
# ======================================================================
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
$form.MinimumSize = (Sz 1060 760)
$form.BackColor = $Colors.bg; $form.ForeColor = $Colors.text; $form.Font = $Fnt.ui
$form.Add_HandleCreated({ param($sd, $ev) Set-DarkTitle $sd })

# Estrutura: [barra lateral | (cabecalho / paginas / log)]
$outer = New-TL 2 1
Add-Col $outer 'A' 100; Add-Col $outer 'P' 100; Add-Row $outer 'P' 100
$form.Controls.Add($outer)
$App.outer = $outer

# --- Barra lateral
$sidebar = New-Object Windows.Forms.Panel
$sidebar.Dock = 'Fill'; $sidebar.BackColor = $Colors.side; $sidebar.Margin = (New-Object Windows.Forms.Padding(0))
$outer.Controls.Add($sidebar, 0, 0)
$App.Sidebar = $sidebar
$logo = New-Object Windows.Forms.Panel
$logo.Location = (Pt 0 16); $logo.Size = (Sz 100 64); $logo.BackColor = $Colors.side
Set-DB $logo
$logo.Add_Paint({ param($sd, $ev) Paint-Logo $sd $ev })
$sidebar.Controls.Add($logo)

$navDefs = @(
    @{ Key = 'home';  Label = 'PAINEL';   Icon = 'home';  Action = 'Nav-Home' },
    @{ Key = 'graph'; Label = 'BRANCHES'; Icon = 'graph'; Action = 'Nav-Graph' },
    @{ Key = 'cmds';  Label = 'COMANDOS'; Icon = 'term';  Action = 'Nav-Cmds' },
    @{ Key = '';      Label = 'USUÁRIO';  Icon = 'user';  Action = 'Acao-ConfigurarUsuario' },
    @{ Key = '';      Label = 'CREDENC.'; Icon = 'key';   Action = 'Acao-RemoverCredenciais' },
    @{ Key = '';      Label = 'TROCAR';   Icon = 'swap';  Action = 'Acao-TrocarProjeto' },
    @{ Key = '';      Label = 'SAIR';     Icon = 'exit';  Action = 'Acao-Sair' }
)
$App.NavItems = @()
$ny = 96
foreach ($nd in $navDefs) {
    $nv = New-Object Windows.Forms.Panel
    $nv.Location = (Pt 0 $ny); $nv.Size = (Sz 100 70); $nv.BackColor = $Colors.side
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
    $ny += 74
}

# --- Coluna principal: cabecalho | paginas | log
$main = New-TL 1 3
Add-Col $main 'P' 100
Add-Row $main 'A' 78; Add-Row $main 'P' 100; Add-Row $main 'A' 190
$outer.Controls.Add($main, 1, 0)

# Cabecalho
$hdr = New-Object Windows.Forms.Panel
$hdr.Dock = 'Fill'; $hdr.BackColor = $Colors.bg; $hdr.Margin = (New-Object Windows.Forms.Padding(0))
$App.Header = $hdr
$App.hTitle = New-Label '' $Fnt.h1 $Colors.white 28 10 560 38
$App.hSub = New-Label '' $Fnt.small $Colors.muted 30 48 560 20
$hdr.Controls.Add($App.hTitle); $hdr.Controls.Add($App.hSub)
$App.pillStatus = New-Object Windows.Forms.Panel
$App.pillStatus.Size = (Sz 150 30); $App.pillStatus.Top = 24; $App.pillStatus.BackColor = $Colors.bg
$App.pillBranch = New-Object Windows.Forms.Panel
$App.pillBranch.Size = (Sz 150 30); $App.pillBranch.Top = 24; $App.pillBranch.BackColor = $Colors.bg
foreach ($pl in @($App.pillStatus, $App.pillBranch)) {
    Set-DB $pl
    $pl.Add_Paint({ param($sd, $ev) Paint-Pill $sd $ev })
    $hdr.Controls.Add($pl)
}
$hdr.Add_Resize({ Layout-Header })
$main.Controls.Add($hdr, 0, 0)

# Hospedeiro das paginas
$pagesHost = New-Object Windows.Forms.Panel
$pagesHost.Dock = 'Fill'; $pagesHost.BackColor = $Colors.bg; $pagesHost.Margin = (New-Object Windows.Forms.Padding(0))
$main.Controls.Add($pagesHost, 0, 1)
$App.Lockables = @($sidebar, $pagesHost)
$App.Pages = @{}

# ---- Pagina INICIAL (sem projeto aberto)
$pgStart = New-TL 3 4
Add-Col $pgStart 'P' 33.33; Add-Col $pgStart 'P' 33.33; Add-Col $pgStart 'P' 33.34
Add-Row $pgStart 'A' 168; Add-Row $pgStart 'A' 190; Add-Row $pgStart 'P' 100; Add-Row $pgStart 'A' 64
$pgStart.Padding = (New-Object Windows.Forms.Padding(22, 8, 22, 10))
$startBanner = New-Banner @{
    Title = 'Bem-vindo ao GitHub Team Helper'
    Sub = 'Git e GitHub para equipes, mostrando cada comando executado'
    Path = 'Crie, clone ou abra um projeto para começar.'
    Chips = @(@{ Text = $gv.Out; Color = $Colors.success })
}
$pgStart.Controls.Add($startBanner, 0, 0); $pgStart.SetColumnSpan($startBanner, 3)
$startCards = @(
    @{ Title = 'Novo Projeto'; Desc = 'Cria uma pasta e inicia um repositório Git vazio.'; Cmd = 'git init'; G1 = $Colors.purple1; G2 = $Colors.purple2; Action = 'Acao-NovoProjeto' },
    @{ Title = 'Clonar Repositório'; Desc = 'Baixa para o seu computador um projeto que já está no GitHub.'; Cmd = 'git clone'; G1 = $Colors.orange2; G2 = $Colors.orange1; Action = 'Acao-Clonar' },
    @{ Title = 'Abrir Projeto Existente'; Desc = 'Usa uma pasta que já é um repositório Git. Nada é recriado.'; Cmd = 'abrir pasta'; G1 = $Colors.blue1; G2 = $Colors.blue2; Action = 'Acao-AbrirProjeto' }
)
$ci = 0
foreach ($sc in $startCards) { $pgStart.Controls.Add((New-Card $sc), $ci, 1); $ci++ }
$exitBtn = New-Card @{ Mode = 'solid'; Title = 'Sair'; G1 = $Colors.gray1; G2 = $Colors.gray2; Action = 'Acao-Sair' }
$exitBtn.Dock = 'None'; $exitBtn.Anchor = 'Left'; $exitBtn.Size = (Sz 170 42)
$pgStart.Controls.Add($exitBtn, 0, 3)
$credBtn = New-Card @{ Mode = 'solid'; Title = 'Remover credenciais do GitHub'; G1 = $Colors.red1; G2 = $Colors.red2; Action = 'Acao-RemoverCredenciais' }
$credBtn.Dock = 'None'; $credBtn.Anchor = 'Left'; $credBtn.Size = (Sz 280 42)
$pgStart.Controls.Add($credBtn, 1, 3)
$App.Pages['start'] = $pgStart

# ---- Pagina PAINEL (projeto aberto)
$pgHome = New-TL 2 1
Add-Col $pgHome 'P' 45; Add-Col $pgHome 'P' 55; Add-Row $pgHome 'P' 100
$pgHome.Padding = (New-Object Windows.Forms.Padding(22, 6, 22, 10))
$leftCol = New-TL 1 3
Add-Col $leftCol 'P' 100
Add-Row $leftCol 'A' 160; Add-Row $leftCol 'P' 100; Add-Row $leftCol 'A' 62
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

$rightCol = New-TL 2 3
Add-Col $rightCol 'P' 50; Add-Col $rightCol 'P' 50
Add-Row $rightCol 'P' 33.33; Add-Row $rightCol 'P' 33.33; Add-Row $rightCol 'P' 33.34
$mainCards = @(
    @{ Title = 'Atualizar Projeto'; Desc = 'Traz as novidades do GitHub para o seu projeto.'; Cmd = 'git pull origin'; G1 = $Colors.purple1; G2 = $Colors.purple2; Action = 'Acao-Atualizar' },
    @{ Title = 'Criar Branch'; Desc = 'Cria e entra em uma nova branch de trabalho.'; Cmd = 'git switch -c'; G1 = $Colors.purple1; G2 = $Colors.purple2; Action = 'Acao-CriarBranch' },
    @{ Title = 'Registrar Alterações'; Desc = 'Salva o que você mudou em um novo commit.'; Cmd = 'git add + commit'; G1 = $Colors.purple1; G2 = $Colors.purple2; Action = 'Acao-Registrar' },
    @{ Title = 'Publicar Branch'; Desc = 'Atualiza com a main e envia a branch ao GitHub.'; Cmd = 'merge main + push'; G1 = $Colors.orange2; G2 = $Colors.orange1; Action = 'Acao-Publicar' },
    @{ Title = 'Concluir Trabalho'; Desc = 'Integra na main e remove a branch local. Alto risco.'; Cmd = 'merge + push + branch -d'; G1 = $Colors.red1; G2 = $Colors.red2; Border = (Get-Col '#7a2a4d'); Action = 'Acao-Concluir' },
    @{ Title = 'Status'; Desc = 'Mostra a situação atual do repositório.'; Cmd = 'git status'; G1 = $Colors.blue1; G2 = $Colors.blue2; Action = 'Acao-Status' }
)
$mi = 0
foreach ($mc in $mainCards) { $rightCol.Controls.Add((New-Card $mc), ($mi % 2), [int][Math]::Floor($mi / 2)); $mi++ }
$pgHome.Controls.Add($rightCol, 1, 0)
$App.Pages['home'] = $pgHome

# ---- Pagina GRAFO
$pgGraph = New-TL 1 2
Add-Col $pgGraph 'P' 100; Add-Row $pgGraph 'A' 52; Add-Row $pgGraph 'P' 100
$pgGraph.Padding = (New-Object Windows.Forms.Padding(22, 4, 22, 14))
$gTool = New-Object Windows.Forms.Panel
$gTool.Dock = 'Fill'; $gTool.BackColor = $Colors.bg; $gTool.Margin = (New-Object Windows.Forms.Padding(0))
$App.chkAll = New-Object Windows.Forms.CheckBox
$App.chkAll.Text = 'Mostrar todas as branches'; $App.chkAll.Checked = $true; $App.chkAll.AutoSize = $true
$App.chkAll.ForeColor = $Colors.text; $App.chkAll.BackColor = $Colors.bg; $App.chkAll.Font = $Fnt.ui
$App.chkAll.Location = (Pt 8 14); $App.chkAll.Cursor = [Windows.Forms.Cursors]::Hand
$App.chkAll.Add_CheckedChanged({ Guard 'Refresh-Graph' })
$gTool.Controls.Add($App.chkAll)
$gBtn = New-Card @{ Mode = 'solid'; Title = 'Atualizar grafo'; G1 = $Colors.purple1; G2 = $Colors.purple2; Action = 'Refresh-Graph' }
$gBtn.Dock = 'None'; $gBtn.Size = (Sz 160 36); $gBtn.Location = (Pt 230 6); $gBtn.Margin = (New-Object Windows.Forms.Padding(0))
$gTool.Controls.Add($gBtn)
$gTool.Controls.Add((New-Label 'Mostra os 80 commits mais recentes (git log --graph).' $Fnt.small $Colors.muted 410 15 420 20))
$pgGraph.Controls.Add($gTool, 0, 0)

$App.gCont = New-Object Windows.Forms.Panel
$App.gCont.Dock = 'Fill'; $App.gCont.BackColor = $Colors.panel; $App.gCont.AutoScroll = $true
$App.gCont.Margin = (New-Object Windows.Forms.Padding(6, 0, 6, 0))
$App.gCanvas = New-Object Windows.Forms.Panel
$App.gCanvas.Location = (Pt 0 0); $App.gCanvas.Size = (Sz 900 300); $App.gCanvas.BackColor = $Colors.panel
Set-DB $App.gCanvas
$App.gCanvas.Add_Paint({ param($sd, $ev) Paint-Graph $sd $ev })
$App.gCanvas.Add_MouseEnter({ param($sd, $ev) [void]$App.gCont.Focus() })
$App.gCont.Controls.Add($App.gCanvas)
$App.gCont.Add_Resize({ Resize-Canvas })
$pgGraph.Controls.Add($App.gCont, 0, 1)
$App.Pages['graph'] = $pgGraph

# ---- Pagina COMANDOS (mais comandos individuais)
$pgCmds = New-TL 3 4
Add-Col $pgCmds 'P' 33.33; Add-Col $pgCmds 'P' 33.33; Add-Col $pgCmds 'P' 33.34
Add-Row $pgCmds 'P' 25; Add-Row $pgCmds 'P' 25; Add-Row $pgCmds 'P' 25; Add-Row $pgCmds 'P' 25
$pgCmds.Padding = (New-Object Windows.Forms.Padding(22, 4, 22, 10))
$P1 = $Colors.purple1; $P2 = $Colors.purple2
$cmdCards = @(
    @{ Title = 'Listar branches'; Desc = 'Mostra as branches locais e permite trocar de uma delas.'; Cmd = 'git branch'; G1 = $P1; G2 = $P2; Action = 'Acao-Branch' },
    @{ Title = 'Trocar de branch'; Desc = 'Muda para outra branch que já existe.'; Cmd = 'git switch'; G1 = $P1; G2 = $P2; Action = 'Acao-Switch' },
    @{ Title = 'Excluir branch'; Desc = 'Remove uma branch local já integrada (seguro).'; Cmd = 'git branch -d'; G1 = $Colors.red1; G2 = $Colors.red2; Border = (Get-Col '#7a2a4d'); Action = 'Acao-ExcluirBranch' },
    @{ Title = 'Mesclar branch'; Desc = 'Traz outra branch para dentro da branch atual.'; Cmd = 'git merge <branch>'; G1 = $Colors.orange2; G2 = $Colors.orange1; Action = 'Acao-Merge' },
    @{ Title = 'Buscar novidades'; Desc = 'Baixa o que há no GitHub sem mexer nos seus arquivos.'; Cmd = 'git fetch origin'; G1 = $P1; G2 = $P2; Action = 'Acao-Fetch' },
    @{ Title = 'Enviar branch atual'; Desc = 'Envia os commits da branch atual ao GitHub (serve também para o primeiro envio da main).'; Cmd = 'git push'; G1 = $Colors.orange2; G2 = $Colors.orange1; Action = 'Acao-Push' },
    @{ Title = 'Preparar tudo'; Desc = 'Marca todas as alterações para o próximo commit.'; Cmd = 'git add .'; G1 = $P1; G2 = $P2; Action = 'Acao-AddTudo' },
    @{ Title = 'Guardar alterações'; Desc = 'Guarda as mudanças em andamento para trocar de branch.'; Cmd = 'git stash'; G1 = $P1; G2 = $P2; Action = 'Acao-Stash' },
    @{ Title = 'Recuperar guardadas'; Desc = 'Reaplica as alterações guardadas pelo stash.'; Cmd = 'git stash pop'; G1 = $P1; G2 = $P2; Action = 'Acao-StashPop' },
    @{ Title = 'Histórico em texto'; Desc = 'Últimos commits em formato de grafo (resultado no log).'; Cmd = 'git log --graph'; G1 = $Colors.blue1; G2 = $Colors.blue2; Action = 'Acao-LogTexto' },
    @{ Title = 'Ver diferenças'; Desc = 'Resumo do que mudou desde o último commit.'; Cmd = 'git diff --stat'; G1 = $Colors.blue1; G2 = $Colors.blue2; Action = 'Acao-Diff' },
    @{ Title = 'Ver remotos'; Desc = 'Mostra para onde o projeto envia e de onde recebe.'; Cmd = 'git remote -v'; G1 = $Colors.blue1; G2 = $Colors.blue2; Action = 'Acao-Remotos' }
)
$qi = 0
foreach ($cc in $cmdCards) { $pgCmds.Controls.Add((New-Card $cc), ($qi % 3), [int][Math]::Floor($qi / 3)); $qi++ }
$App.Pages['cmds'] = $pgCmds

foreach ($k in @($App.Pages.Keys)) { $App.Pages[$k].Visible = $false; $pagesHost.Controls.Add($App.Pages[$k]) }

# --- Area de LOG
$logWrap = New-Object Windows.Forms.Panel
$logWrap.Dock = 'Fill'; $logWrap.BackColor = $Colors.bg; $logWrap.Padding = (New-Object Windows.Forms.Padding(28, 0, 28, 16))
$logWrap.Margin = (New-Object Windows.Forms.Padding(0))
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

# --- Eventos gerais (acoes passam por Guard: erros inesperados nunca derrubam a GUI)
$bClear.Add_Click({ $App.LogBox.Clear() })
$form.Add_FormClosing({ param($sd, $ev) if ($App.Running) { $ev.Cancel = $true } })   # nao fechar no meio de um comando
$form.Add_Shown({ $App.Form.Activate(); Layout-Header })

# Mensagens iniciais no log
Write-Log 'GitHub Team Helper' 'accent' $true
Write-Info $gv.Out
Write-Info 'Escolha uma opção para começar.'
Write-Info 'Cada comando Git executado aparece aqui, para você aprender enquanto usa.'
Write-Log ''

Show-StartPanel
[Windows.Forms.Application]::Run($form)