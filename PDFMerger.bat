<# :
@echo off
setlocal
cd /d "%~dp0"

where pwsh.exe >nul 2>&1
if %ERRORLEVEL% equ 0 (
    start "" pwsh.exe -STA -NoProfile -ExecutionPolicy Bypass -Command "& ([ScriptBlock]::Create((Get-Content -LiteralPath '%~f0' -Raw -Encoding UTF8)))" %*
) else (
    start "" powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -Command "& ([ScriptBlock]::Create((Get-Content -LiteralPath '%~f0' -Raw -Encoding UTF8)))" %*
)
exit /b %ERRORLEVEL%
#>

<#
.SYNOPSIS
    PDF Merger - File Unico Ibrido (Batch + PowerShell)
    Non richiede file esterni: fa tutto da solo con un doppio clic.
#>

[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FileIniziali
)

# Codifica console UTF-8 per la corretta gestione di accenti e caratteri speciali
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# =============================================================================
# 1. CONTROLLO E AGGIORNAMENTO DELLA VERSIONE DI POWERSHELL
# =============================================================================
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " 1. Controllo della versione di PowerShell in uso..." -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$versioneCorrente = $PSVersionTable.PSVersion
Write-Host "Versione PowerShell rilevata: $versioneCorrente" -ForegroundColor Gray

if ($versioneCorrente.Major -lt 7) {
    Write-Warning "La sessione corrente ($versioneCorrente) è in esecuzione con Windows PowerShell."
    
    # 1. Verifica se PowerShell 7 (pwsh.exe) è già installato nel sistema
    $pwshPath = $null
    $pwshCmd = Get-Command pwsh.exe -ErrorAction SilentlyContinue
    if ($pwshCmd) {
        $pwshPath = $pwshCmd.Source
    }
    else {
        $candidati = @(
            "$env:LOCALAPPDATA\Microsoft\WindowsApps\pwsh.exe",
            "$env:ProgramFiles\PowerShell\7\pwsh.exe",
            "$env:LOCALAPPDATA\Microsoft\PowerShell\7\pwsh.exe",
            "${env:ProgramFiles(x86)}\PowerShell\7\pwsh.exe"
        )
        foreach ($c in $candidati) {
            if (Test-Path -LiteralPath $c) {
                $pwshPath = $c
                break
            }
        }
    }

    # Se PowerShell 7 è già presente, effettua il passaggio immediato a PowerShell 7 evitando il loop
    if ($pwshPath) {
        Write-Host "PowerShell 7 è già installato nel sistema ($pwshPath)." -ForegroundColor Green
        Write-Host "Rilancio automatico con PowerShell 7..." -ForegroundColor Cyan

        $targetScript = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Definition }
        if ($targetScript) {
            $argList = @("-STA", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$targetScript`"")
            if ($FileIniziali) {
                foreach ($f in $FileIniziali) {
                    $argList += "`"$f`""
                }
            }
            Start-Process -FilePath $pwshPath -ArgumentList $argList
            return
        }
    }

    # Se PowerShell 7 NON è installato, procedi con l'installazione tramite WinGet
    Write-Host "Avvio dell'installazione automatica a PowerShell 7 tramite WinGet..." -ForegroundColor Yellow
    
    # Verifica presenza di winget
    $wingetCmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($wingetCmd) {
        try {
            winget install Microsoft.PowerShell --silent --accept-source-agreements --accept-package-agreements
        }
        catch {
            Write-Error "Si è verificato un errore durante l'esecuzione di WinGet: $($_.Exception.Message)"
        }
    }
    else {
        Write-Warning "WinGet non è disponibile nel sistema. Installare PowerShell 7 dallo Store o da GitHub."
    }

    # Messaggio informativo per l'utente (a video e tramite popup grafico)
    $msgRiavvio = "È stata avviata l'installazione o l'aggiornamento a PowerShell 7.`n`nAl termine, riavvia l'applicazione (userà automaticamente PowerShell 7)."
    
    Write-Host ""
    Write-Host "************************************************************************" -ForegroundColor Yellow
    Write-Host " ATTENZIONE: RIAVVIO RICHIESTO CON POWERSHELL 7" -ForegroundColor Yellow
    Write-Host " 1. Attendi il completamento dell'installazione di PowerShell 7." -ForegroundColor White
    Write-Host " 2. Chiudi questa finestra di Windows PowerShell (sfondo blu)." -ForegroundColor White
    Write-Host " 3. Riavvia l'applicazione." -ForegroundColor White
    Write-Host "************************************************************************" -ForegroundColor Yellow
    Write-Host ""

    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    [System.Windows.Forms.MessageBox]::Show(
        $msgRiavvio,
        "Riavvio Richiesto - PowerShell 7",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null

    return
}

Write-Host "Versione di PowerShell idonea (PowerShell 7+)." -ForegroundColor Green

# Assicura l'esecuzione in modalità STA (Single Threaded Apartment), richiesta da Windows Forms
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne [System.Threading.ApartmentState]::STA) {
    if ($PSCommandPath) {
        $pwshProcess = (Get-Process -Id $PID).Path
        Start-Process -FilePath $pwshProcess -ArgumentList "-STA -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        return
    }
}


# =============================================================================
# 2. CONTROLLO E INSTALLAZIONE DEL MODULO 'PSWritePDF'
# =============================================================================
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " 2. Controllo del modulo 'PSWritePDF'..." -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$moduloNome = "PSWritePDF"
$moduloInstallato = Get-Module -ListAvailable -Name $moduloNome

if (-not $moduloInstallato) {
    Write-Host "Modulo '$moduloNome' non trovato. Configurazione protocolli di sicurezza e installazione..." -ForegroundColor Yellow

    # Forza l'abilitazione del protocollo TLS 1.2 e TLS 1.3 per evitare blocchi di rete
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
    }
    catch {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }

    # Verifica package provider NuGet
    if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) {
        try {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        }
        catch { }
    }

    # Installazione silenziosa per l'utente corrente
    try {
        Install-Module -Name $moduloNome -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        Write-Host "Modulo '$moduloNome' installato correttamente!" -ForegroundColor Green
    }
    catch {
        Write-Error "Errore durante l'installazione del modulo '$moduloNome': $($_.Exception.Message)"
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        [System.Windows.Forms.MessageBox]::Show(
            "Impossibile installare il modulo '$moduloNome':`n$($_.Exception.Message)`n`nVerifica la connessione ad internet e riprova.",
            "Errore Installazione Modulo",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return
    }
}
else {
    Write-Host "Modulo '$moduloNome' già presente nel sistema." -ForegroundColor Green
}

# Importazione del modulo
try {
    Import-Module -Name $moduloNome -ErrorAction Stop
    Write-Host "Modulo '$moduloNome' importato con successo." -ForegroundColor Green
}
catch {
    Write-Error "Errore durante l'importazione del modulo '$moduloNome': $($_.Exception.Message)"
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    [System.Windows.Forms.MessageBox]::Show(
        "Errore durante l'importazione del modulo '$moduloNome':`n$($_.Exception.Message)",
        "Errore Importazione",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    return
}


# =============================================================================
# 3. INTERFACCIA GRAFICA (GUI MINIMALE)
# =============================================================================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Finestra Principale (Form)
$form = New-Object System.Windows.Forms.Form
$form.Text = "PDF Merger - Unione Documenti PDF"
$form.Size = New-Object System.Drawing.Size(740, 580)
$form.MinimumSize = New-Object System.Drawing.Size(740, 580)
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(248, 249, 250)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# Intestazione
$lblTitolo = New-Object System.Windows.Forms.Label
$lblTitolo.Text = "Unione File PDF"
$lblTitolo.Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
$lblTitolo.ForeColor = [System.Drawing.Color]::FromArgb(33, 37, 41)
$lblTitolo.Location = New-Object System.Drawing.Point(20, 15)
$lblTitolo.Size = New-Object System.Drawing.Size(500, 26)
$form.Controls.Add($lblTitolo)

$lblDescrizione = New-Object System.Windows.Forms.Label
$lblDescrizione.Text = "Aggiungi i PDF da unire e usa 'Muovi Su' / 'Muovi Giù' per stabilirne la sequenza."
$lblDescrizione.ForeColor = [System.Drawing.Color]::FromArgb(108, 117, 125)
$lblDescrizione.Location = New-Object System.Drawing.Point(20, 42)
$lblDescrizione.Size = New-Object System.Drawing.Size(680, 20)
$form.Controls.Add($lblDescrizione)

# ListBox con elenco file PDF
$listBoxPDF = New-Object System.Windows.Forms.ListBox
$listBoxPDF.Location = New-Object System.Drawing.Point(20, 70)
$listBoxPDF.Size = New-Object System.Drawing.Size(540, 250)
$listBoxPDF.HorizontalScrollbar = $true
$listBoxPDF.AllowDrop = $true
$listBoxPDF.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$listBoxPDF.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$form.Controls.Add($listBoxPDF)

# Supporto Drag & Drop diretto da Esplora Risorse
$listBoxPDF.Add_DragEnter({
    param($sender, $e)
    if ($e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
        $e.Effect = [System.Windows.Forms.DragDropEffects]::Copy
    } else {
        $e.Effect = [System.Windows.Forms.DragDropEffects]::None
    }
})

$listBoxPDF.Add_DragDrop({
    param($sender, $e)
    $trascinati = $e.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop)
    foreach ($elemento in $trascinati) {
        if ([System.IO.Path]::GetExtension($elemento) -like ".pdf") {
            if (-not $listBoxPDF.Items.Contains($elemento)) {
                $listBoxPDF.Items.Add($elemento) | Out-Null
            }
        }
    }
})

# Caricamento iniziale se sono stati passati argomenti o trascinati file sull'eseguibile
if ($FileIniziali) {
    foreach ($fileArg in $FileIniziali) {
        if ([System.IO.Path]::GetExtension($fileArg) -like ".pdf" -and (Test-Path -LiteralPath $fileArg -PathType Leaf)) {
            if (-not $listBoxPDF.Items.Contains($fileArg)) {
                $listBoxPDF.Items.Add($fileArg) | Out-Null
            }
        }
    }
    if ($listBoxPDF.Items.Count -gt 0) {
        $listBoxPDF.SelectedIndex = 0
    }
}

# Pulsanti di gestione elenco (colonna laterale destra)
$btnWidth = 140
$btnHeight = 36
$btnX = 575

# Pulsante: Aggiungi PDF
$btnAggiungi = New-Object System.Windows.Forms.Button
$btnAggiungi.Text = "➕ Aggiungi PDF"
$btnAggiungi.Location = New-Object System.Drawing.Point($btnX, 70)
$btnAggiungi.Size = New-Object System.Drawing.Size($btnWidth, $btnHeight)
$btnAggiungi.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnAggiungi.UseVisualStyleBackColor = $true
$btnAggiungi.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnAggiungi)

# Pulsante: Muovi Su
$btnMuoviSu = New-Object System.Windows.Forms.Button
$btnMuoviSu.Text = "▲ Muovi Su"
$btnMuoviSu.Location = New-Object System.Drawing.Point($btnX, 115)
$btnMuoviSu.Size = New-Object System.Drawing.Size($btnWidth, $btnHeight)
$btnMuoviSu.UseVisualStyleBackColor = $true
$btnMuoviSu.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnMuoviSu)

# Pulsante: Muovi Giù
$btnMuoviGiu = New-Object System.Windows.Forms.Button
$btnMuoviGiu.Text = "▼ Muovi Giù"
$btnMuoviGiu.Location = New-Object System.Drawing.Point($btnX, 160)
$btnMuoviGiu.Size = New-Object System.Drawing.Size($btnWidth, $btnHeight)
$btnMuoviGiu.UseVisualStyleBackColor = $true
$btnMuoviGiu.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnMuoviGiu)

# Pulsante: Rimuovi
$btnRimuovi = New-Object System.Windows.Forms.Button
$btnRimuovi.Text = "❌ Rimuovi"
$btnRimuovi.Location = New-Object System.Drawing.Point($btnX, 205)
$btnRimuovi.Size = New-Object System.Drawing.Size($btnWidth, $btnHeight)
$btnRimuovi.UseVisualStyleBackColor = $true
$btnRimuovi.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnRimuovi)

# Pulsante: Svuota Tutto
$btnSvuota = New-Object System.Windows.Forms.Button
$btnSvuota.Text = "🗑️ Svuota Tutto"
$btnSvuota.Location = New-Object System.Drawing.Point($btnX, 250)
$btnSvuota.Size = New-Object System.Drawing.Size($btnWidth, $btnHeight)
$btnSvuota.UseVisualStyleBackColor = $true
$btnSvuota.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnSvuota)

# Sezione File di destinazione (Output)
$lblOutput = New-Object System.Windows.Forms.Label
$lblOutput.Text = "File PDF di destinazione (Output):"
$lblOutput.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$lblOutput.Location = New-Object System.Drawing.Point(20, 340)
$lblOutput.Size = New-Object System.Drawing.Size(540, 20)
$form.Controls.Add($lblOutput)

$txtOutput = New-Object System.Windows.Forms.TextBox
$txtOutput.Location = New-Object System.Drawing.Point(20, 363)
$txtOutput.Size = New-Object System.Drawing.Size(540, 27)
$txtOutput.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$txtOutput.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$form.Controls.Add($txtOutput)

$btnSalvaCome = New-Object System.Windows.Forms.Button
$btnSalvaCome.Text = "Salva come..."
$btnSalvaCome.Location = New-Object System.Drawing.Point($btnX, 362)
$btnSalvaCome.Size = New-Object System.Drawing.Size($btnWidth, 29)
$btnSalvaCome.UseVisualStyleBackColor = $true
$btnSalvaCome.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnSalvaCome)

# Grande pulsante "Unisci PDF"
$btnUnisci = New-Object System.Windows.Forms.Button
$btnUnisci.Text = "⚡ UNISCI PDF"
$btnUnisci.Location = New-Object System.Drawing.Point(20, 420)
$btnUnisci.Size = New-Object System.Drawing.Size(695, 52)
$btnUnisci.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$btnUnisci.BackColor = [System.Drawing.Color]::FromArgb(16, 124, 65)
$btnUnisci.ForeColor = [System.Drawing.Color]::White
$btnUnisci.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnUnisci.FlatAppearance.BorderSize = 0
$btnUnisci.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnUnisci)


# ----------------- EVENTI DELLA GUI -----------------

# Click: Aggiungi PDF
$btnAggiungi.Add_Click({
    $openDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openDialog.Title = "Seleziona i file PDF da unire"
    $openDialog.Filter = "File PDF (*.pdf)|*.pdf|Tutti i file (*.*)|*.*"
    $openDialog.Multiselect = $true

    if ($openDialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
        foreach ($file in $openDialog.FileNames) {
            if (-not $listBoxPDF.Items.Contains($file)) {
                $listBoxPDF.Items.Add($file) | Out-Null
            }
        }
        if ($listBoxPDF.SelectedIndex -eq -1 -and $listBoxPDF.Items.Count -gt 0) {
            $listBoxPDF.SelectedIndex = 0
        }
    }
})

# Click: Muovi Su
$btnMuoviSu.Add_Click({
    $index = $listBoxPDF.SelectedIndex
    if ($index -gt 0) {
        $elemento = $listBoxPDF.Items[$index]
        $listBoxPDF.Items.RemoveAt($index)
        $listBoxPDF.Items.Insert($index - 1, $elemento)
        $listBoxPDF.SelectedIndex = $index - 1
    }
})

# Click: Muovi Giù
$btnMuoviGiu.Add_Click({
    $index = $listBoxPDF.SelectedIndex
    if ($index -ge 0 -and $index -lt ($listBoxPDF.Items.Count - 1)) {
        $elemento = $listBoxPDF.Items[$index]
        $listBoxPDF.Items.RemoveAt($index)
        $listBoxPDF.Items.Insert($index + 1, $elemento)
        $listBoxPDF.SelectedIndex = $index + 1
    }
})

# Click: Rimuovi
$btnRimuovi.Add_Click({
    $index = $listBoxPDF.SelectedIndex
    if ($index -ge 0) {
        $listBoxPDF.Items.RemoveAt($index)
        if ($listBoxPDF.Items.Count -gt 0) {
            $nuovoIndice = [Math]::Min($index, $listBoxPDF.Items.Count - 1)
            $listBoxPDF.SelectedIndex = $nuovoIndice
        }
    }
})

# Click: Svuota Tutto
$btnSvuota.Add_Click({
    if ($listBoxPDF.Items.Count -gt 0) {
        $listBoxPDF.Items.Clear()
    }
})

# Click: Salva come...
$btnSalvaCome.Add_Click({
    $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveDialog.Title = "Seleziona percorso e nome del file di output"
    $saveDialog.Filter = "File PDF (*.pdf)|*.pdf"
    $saveDialog.DefaultExt = "pdf"
    $saveDialog.FileName = "PDF_Unito.pdf"

    if ($txtOutput.Text.Trim() -ne "") {
        try {
            $cartellaCorrente = Split-Path -Path $txtOutput.Text.Trim() -Parent
            if ($cartellaCorrente -and (Test-Path -LiteralPath $cartellaCorrente)) {
                $saveDialog.InitialDirectory = $cartellaCorrente
            }
        }
        catch { }
    }

    if ($saveDialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtOutput.Text = $saveDialog.FileName
    }
})


# =============================================================================
# 4. ESECUZIONE DELL'UNIONE (CLICK SU "UNISCI PDF")
# =============================================================================
$btnUnisci.Add_Click({
    # Validazione: presenza di almeno 2 file
    if ($listBoxPDF.Items.Count -lt 2) {
        [System.Windows.Forms.MessageBox]::Show(
            $form,
            "Seleziona almeno 2 file PDF dall'elenco prima di procedere all'unione.",
            "Attenzione - File insufficienti",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return
    }

    # Validazione: percorso di output indicato
    $PercorsoOutput = $txtOutput.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($PercorsoOutput)) {
        [System.Windows.Forms.MessageBox]::Show(
            $form,
            "Specificare il percorso e il nome del file di destinazione (cliccando su 'Salva come...' o scrivendolo nel campo di testo).",
            "Attenzione - Percorso mancante",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return
    }

    # Assicura estensione .pdf
    if (-not $PercorsoOutput.EndsWith(".pdf", [System.StringComparison]::OrdinalIgnoreCase)) {
        $PercorsoOutput += ".pdf"
        $txtOutput.Text = $PercorsoOutput
    }

    # Crea la directory di destinazione se inesistente
    $cartellaDestinazione = Split-Path -Path $PercorsoOutput -Parent
    if ($cartellaDestinazione -and -not (Test-Path -LiteralPath $cartellaDestinazione)) {
        try {
            New-Item -ItemType Directory -Path $cartellaDestinazione -Force | Out-Null
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                $form,
                "Impossibile creare la cartella di destinazione:`n$cartellaDestinazione`n`n$($_.Exception.Message)",
                "Errore Percorso Output",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
            return
        }
    }

    # Raccogli i file nell'ordine esatto stabilito dall'utente nella ListBox
    $ElencoFile = @($listBoxPDF.Items)

    # Verifica esistenza fisica dei file prima dell'unione
    $fileMancanti = @()
    foreach ($file in $ElencoFile) {
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
            $fileMancanti += $file
        }
    }

    if ($fileMancanti.Count -gt 0) {
        [System.Windows.Forms.MessageBox]::Show(
            $form,
            "Uno o più file PDF selezionati non esistono più nel percorso specificato:`n`n" + ($fileMancanti -join "`n"),
            "Errore - File non trovati",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return
    }

    # Feedback visivo
    $btnUnisci.Enabled = $false
    $btnUnisci.Text = "⏳ Unione in corso... Attendere..."
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    $form.Refresh()

    try {
        # Esecuzione del comando di unione del modulo PSWritePDF
        Merge-PDF -InputFile $ElencoFile -OutputFile $PercorsoOutput -ErrorAction Stop

        # Messaggio grafico di successo
        $risposta = [System.Windows.Forms.MessageBox]::Show(
            $form,
            "PDF uniti con successo!`n`nFile generato in:`n$PercorsoOutput`n`nVuoi aprire la cartella del file generato?",
            "Operazione Riuscita",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )

        if ($risposta -eq [System.Windows.Forms.DialogResult]::Yes) {
            Start-Process explorer.exe -ArgumentList "/select,`"$PercorsoOutput`""
        }
    }
    catch {
        # Messaggio grafico di errore
        [System.Windows.Forms.MessageBox]::Show(
            $form,
            "Si è verificato un errore durante l'unione dei file PDF:`n`n$($_.Exception.Message)",
            "Errore Unione PDF",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
    finally {
        $btnUnisci.Enabled = $true
        $btnUnisci.Text = "⚡ UNISCI PDF"
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
})

# Visualizzazione della Finestra Grafica (e occultamento della console di sfondo)
$form.Add_Shown({
    $form.Activate()
    try {
        $consoleDef = '[DllImport("Kernel32.dll")] public static extern IntPtr GetConsoleWindow(); [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);'
        $winType = Add-Type -MemberDefinition $consoleDef -Name "ConsoleWindowMgr" -Namespace "Win32Utils" -PassThru -ErrorAction SilentlyContinue
        $hWnd = [Win32Utils.ConsoleWindowMgr]::GetConsoleWindow()
        if ($hWnd -ne [IntPtr]::Zero) {
            [Win32Utils.ConsoleWindowMgr]::ShowWindow($hWnd, 0) | Out-Null
        }
    } catch { }
})
[void]$form.ShowDialog()

# Rilascio risorse
$form.Dispose()

