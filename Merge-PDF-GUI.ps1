<#
.SYNOPSIS
    Wrapper grafico (GUI) per l'unione di file PDF tramite il modulo 'PSWritePDF'.
    Compatibile con Windows PowerShell 5.1 e PowerShell 7.

.DESCRIPTION
    Lo script automatizza in ordine sequenziale:
    1. Verifica e aggiornamento di PowerShell tramite WinGet (se inferiore alla versione 7).
    2. Controllo e installazione automatica e silenziosa del modulo 'PSWritePDF' (con forzatura TLS 1.2/1.3).
    3. Creazione di un'interfaccia grafica (GUI Windows.Forms) con:
       - Elenco file PDF selezionati (con supporto Drag & Drop).
       - Pulsanti "Aggiungi PDF", "Muovi Su", "Muovi Giù", "Rimuovi" e "Svuota Tutto".
       - Selezione del file di output tramite campo di testo e dialogo "Salva come...".
       - Grande pulsante "Unisci PDF".
    4. Esecuzione dell'unione con il cmdlet 'Merge-PDF' e visualizzazione di messaggi grafici di esito.
#>

[CmdletBinding()]
param()

# Imposta la codifica della console su UTF-8 per la corretta visualizzazione di caratteri speciali e accenti
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
    Write-Warning "La versione in uso ($versioneCorrente) è inferiore a PowerShell 7."
    Write-Host "Avvio dell'installazione automatica o aggiornamento a PowerShell 7 tramite WinGet..." -ForegroundColor Yellow
    
    # Verifica la presenza di winget nel sistema
    $wingetCmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($wingetCmd) {
        try {
            # Comando richiesto per l'installazione/aggiornamento silenzioso
            winget install Microsoft.PowerShell --silent --accept-source-agreements --accept-package-agreements
        }
        catch {
            Write-Error "Si è verificato un errore durante l'esecuzione di WinGet: $($_.Exception.Message)"
        }
    }
    else {
        Write-Warning "WinGet non è stato trovato nel sistema. Scaricare PowerShell 7 manualmente dallo Store Microsoft o da GitHub."
    }

    # Messaggio di avviso per l'utente (a video e tramite finestra grafica)
    $msgRiavvio = "È stata avviata l'installazione/aggiornamento a PowerShell 7.`n`nPer proseguire, è necessario chiudere questa finestra e riavviare lo script utilizzando la nuova versione di PowerShell (sfondo nero / pwsh)."
    
    Write-Host ""
    Write-Host "************************************************************************" -ForegroundColor Yellow
    Write-Host " ATTENZIONE: È NECESSARIO RIAVVIARE LO SCRIPT CON POWERSHELL 7" -ForegroundColor Yellow
    Write-Host " 1. Attendi il completamento dell'installazione di PowerShell 7." -ForegroundColor White
    Write-Host " 2. Chiudi questa finestra di Windows PowerShell (sfondo blu)." -ForegroundColor White
    Write-Host " 3. Riavvia lo script usando PowerShell 7 (sfondo nero / icona 'pwsh')." -ForegroundColor White
    Write-Host "************************************************************************" -ForegroundColor Yellow
    Write-Host ""

    # Notifica popup grafica
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    [System.Windows.Forms.MessageBox]::Show(
        $msgRiavvio,
        "Riavvio Richiesto - PowerShell 7",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null

    # Interruzione dell'esecuzione corrente
    return
}

Write-Host "Versione di PowerShell idonea (PowerShell 7+)." -ForegroundColor Green

# Assicura l'esecuzione in modalità STA (Single Threaded Apartment), richiesta da Windows Forms per finestre di dialogo e Drag & Drop
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
    Write-Host "Il modulo '$moduloNome' non è presente nel sistema." -ForegroundColor Yellow
    Write-Host "Configurazione protocolli di sicurezza e installazione silenziosa in corso..." -ForegroundColor Yellow

    # Forza l'abilitazione del protocollo TLS 1.2 e TLS 1.3 per evitare blocchi di rete
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
    }
    catch {
        # Fallback nel caso in cui Tls13 non sia disponibile nel runtime sottostante
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }

    # Assicura la presenza del package provider NuGet (necessario su alcune installazioni pulite)
    if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) {
        try {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        }
        catch { }
    }

    # Installazione del modulo in modo silenzioso per l'utente corrente
    try {
        Install-Module -Name $moduloNome -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        Write-Host "Modulo '$moduloNome' installato correttamente per l'utente corrente!" -ForegroundColor Green
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
    Write-Host "Il modulo '$moduloNome' è già installato nel sistema." -ForegroundColor Green
}

# Importazione del modulo nella sessione corrente
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
# Caricamento delle librerie grafiche Windows Forms e Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Creazione della Finestra Principale (Form)
$form = New-Object System.Windows.Forms.Form
$form.Text = "PDF Merger - Unione Documenti PDF"
$form.Size = New-Object System.Drawing.Size(740, 580)
$form.MinimumSize = New-Object System.Drawing.Size(740, 580)
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(248, 249, 250)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# ----------------- INTESTAZIONE (HEADER) -----------------
$lblTitolo = New-Object System.Windows.Forms.Label
$lblTitolo.Text = "Unione File PDF"
$lblTitolo.Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
$lblTitolo.ForeColor = [System.Drawing.Color]::FromArgb(33, 37, 41)
$lblTitolo.Location = New-Object System.Drawing.Point(20, 15)
$lblTitolo.Size = New-Object System.Drawing.Size(500, 26)
$form.Controls.Add($lblTitolo)

$lblDescrizione = New-Object System.Windows.Forms.Label
$lblDescrizione.Text = "Aggiungi i PDF da unire e usa 'Muovi Su' / 'Muovi Giù' per definirne la sequenza esatta."
$lblDescrizione.ForeColor = [System.Drawing.Color]::FromArgb(108, 117, 125)
$lblDescrizione.Location = New-Object System.Drawing.Point(20, 42)
$lblDescrizione.Size = New-Object System.Drawing.Size(680, 20)
$form.Controls.Add($lblDescrizione)

# ----------------- LISTBOX (ELENCO DEI FILE) -----------------
$listBoxPDF = New-Object System.Windows.Forms.ListBox
$listBoxPDF.Location = New-Object System.Drawing.Point(20, 70)
$listBoxPDF.Size = New-Object System.Drawing.Size(540, 250)
$listBoxPDF.HorizontalScrollbar = $true
$listBoxPDF.AllowDrop = $true
$listBoxPDF.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$listBoxPDF.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$form.Controls.Add($listBoxPDF)

# Supporto Drag & Drop per trascinare file PDF direttamente da Esplora Risorse
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

# ----------------- PULSANTI DI CONTROLLO LISTBOX (A DESTRA) -----------------
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

# Pulsante: Svuota Tutto (funzione di supporto rapido)
$btnSvuota = New-Object System.Windows.Forms.Button
$btnSvuota.Text = "🗑️ Svuota Tutto"
$btnSvuota.Location = New-Object System.Drawing.Point($btnX, 250)
$btnSvuota.Size = New-Object System.Drawing.Size($btnWidth, $btnHeight)
$btnSvuota.UseVisualStyleBackColor = $true
$btnSvuota.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnSvuota)

# ----------------- SEZIONE FILE DI DESTINAZIONE (OUTPUT) -----------------
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

# ----------------- GRANDE PULSANTE "UNISCI PDF" IN BASSO -----------------
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


# ----------------- GESTIONE EVENTI (LOGICA INTERFACCIA) -----------------

# Evento: Click su "Aggiungi PDF"
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

# Evento: Click su "Muovi Su"
$btnMuoviSu.Add_Click({
    $index = $listBoxPDF.SelectedIndex
    if ($index -gt 0) {
        $elemento = $listBoxPDF.Items[$index]
        $listBoxPDF.Items.RemoveAt($index)
        $listBoxPDF.Items.Insert($index - 1, $elemento)
        $listBoxPDF.SelectedIndex = $index - 1
    }
})

# Evento: Click su "Muovi Giù"
$btnMuoviGiu.Add_Click({
    $index = $listBoxPDF.SelectedIndex
    if ($index -ge 0 -and $index -lt ($listBoxPDF.Items.Count - 1)) {
        $elemento = $listBoxPDF.Items[$index]
        $listBoxPDF.Items.RemoveAt($index)
        $listBoxPDF.Items.Insert($index + 1, $elemento)
        $listBoxPDF.SelectedIndex = $index + 1
    }
})

# Evento: Click su "Rimuovi"
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

# Evento: Click su "Svuota Tutto"
$btnSvuota.Add_Click({
    if ($listBoxPDF.Items.Count -gt 0) {
        $listBoxPDF.Items.Clear()
    }
})

# Evento: Click su "Salva come..."
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
    # Validazione 1: Verifica che ci siano almeno 2 file PDF nella ListBox
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

    # Validazione 2: Verifica che sia stato indicato un percorso di output
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

    # Assicura l'estensione .pdf sul file di destinazione
    if (-not $PercorsoOutput.EndsWith(".pdf", [System.StringComparison]::OrdinalIgnoreCase)) {
        $PercorsoOutput += ".pdf"
        $txtOutput.Text = $PercorsoOutput
    }

    # Verifica e creazione automatica della cartella di destinazione se inesistente
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

    # Verifica che tutti i file selezionati siano effettivamente presenti su disco
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

    # Feedback visivo: disabilita pulsante e imposta cursore di attesa
    $btnUnisci.Enabled = $false
    $btnUnisci.Text = "⏳ Unione in corso... Attendere..."
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    $form.Refresh()

    try {
        # Esecuzione del comando di unione del modulo PSWritePDF
        Merge-PDF -InputFile $ElencoFile -OutputFile $PercorsoOutput -ErrorAction Stop

        # Mostra messaggio grafico di successo
        $risposta = [System.Windows.Forms.MessageBox]::Show(
            $form,
            "PDF uniti con successo!`n`nFile generato in:`n$PercorsoOutput`n`nVuoi aprire la cartella del file generato?",
            "Operazione Riuscita",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )

        # Apertura della cartella con selezione del file generato
        if ($risposta -eq [System.Windows.Forms.DialogResult]::Yes) {
            Start-Process explorer.exe -ArgumentList "/select,`"$PercorsoOutput`""
        }
    }
    catch {
        # Mostra messaggio grafico di errore in caso di problemi
        [System.Windows.Forms.MessageBox]::Show(
            $form,
            "Si è verificato un errore durante l'unione dei file PDF:`n`n$($_.Exception.Message)",
            "Errore Unione PDF",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
    finally {
        # Ripristino dello stato originale del pulsante e del cursore
        $btnUnisci.Enabled = $true
        $btnUnisci.Text = "⚡ UNISCI PDF"
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
})

# Visualizzazione della Finestra Grafica
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()

# Rilascio delle risorse grafiche alla chiusura
$form.Dispose()
