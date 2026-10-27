# Rapid Start

1. Avvia il tool: Fai doppio clic sul file PDFMerger.exe (consigliato) oppure esegui il file .bat.
2. Carica i PDF: Trascina i file PDF direttamente nell'elenco (Drag & Drop) oppure clicca su Aggiungi PDF per selezionarli.
3. Ordina e Salva: Usa i pulsanti Muovi Su / Giù per definire la sequenza delle pagine, premi Salva come... per scegliere la cartella e il nome del nuovo documento e clicca su Unisci PDF.
(Nota: Al primo avvio lo script configurerà in automatico i requisiti di sistema mancanti).

# Local PDF Merger - GUI Wrapper per PSWritePDF

Applicazione con interfaccia grafica nativa (GUI) per Windows scritta in PowerShell, progettata per unire facilmente più documenti PDF in un unico file sequenziale.

Lo script funge da wrapper per il modulo PowerShell [`PSWritePDF`](https://github.com/EvotecIT/PSWritePDF) e gestisce l'intero ciclo di vita: dai requisiti di sistema fino all'elaborazione finale.

---

## 🎯 Formati disponibili per l'esecuzione

Per la massima comodità, sono disponibili diverse modalità d'uso:

| File | Tipo | Descrizione |
| :--- | :---: | :--- |
| [`PDFMerger.exe`](./PDFMerger.exe) | **Eseguibile (.exe)** | **Consigliato**. Singolo file autonomo eseguibile con doppio clic. Non richiede finestre PowerShell aperte e supporta il trascinamento di file PDF direttamente sull'icona. |
| [`PDFMerger.bat`](./PDFMerger.bat) | **Script Ibrido (.bat)** | Singolo file script batch/PowerShell unificato. Doppio clic immediato, non richiede compilazione ed è ispezionabile con qualsiasi editor di testo. |
| [`Merge-PDF-GUI.ps1`](./Merge-PDF-GUI.ps1) | **Script PowerShell (.ps1)** | Il codice sorgente PowerShell puro, eseguibile da terminale o tramite menu contestuale. |
| [`Build-Exe.ps1`](./Build-Exe.ps1) | **Strumento di Build** | Script che ricompila `PDFMerger.exe` a partire da `Merge-PDF-GUI.ps1` usando il compilatore .NET nativo di Windows. |

---

## 📋 Flusso di Esecuzione Sequenziale

1. **Controllo e aggiornamento automatico di PowerShell**:
   - Rileva la versione corrente (`$PSVersionTable.PSVersion`).
   - Se inferiore a PowerShell 7 (es. Windows PowerShell 5.1 nativo), avvia l'installazione automatica/aggiornamento tramite `winget install Microsoft.PowerShell --silent`.
   - Mostra un avviso all'utente indicando di riavviare con la nuova versione a sfondo nero (`pwsh`) e termina l'esecuzione.

2. **Controllo e installazione del modulo `PSWritePDF`**:
   - Verifica se il modulo è già presente nel sistema.
   - In caso contrario, forza l'abilitazione di TLS 1.2 / TLS 1.3 per evitare blocchi con PowerShell Gallery e installa il modulo in modo silenzioso per l'utente corrente:
     ```powershell
     [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
     Install-Module -Name PSWritePDF -Scope CurrentUser -Force -AllowClobber
     ```
   - Importa il modulo nella sessione attiva.

3. **Interfaccia Grafica Nativa (Windows Forms)**:
   - **Elenco PDF (ListBox)**: visualizza i file aggiunti e supporta sia l'aggiunta da dialogo che il **Drag & Drop** diretto da Esplora Risorse (o trascinandoli direttamente sull'icona dell'eseguibile).
   - **Aggiungi PDF**: apre una finestra di dialogo con supporto alla selezione multipla.
   - **Muovi Su / Muovi Giù**: riordina i file in qualsiasi momento per stabilire con precisione la sequenza delle pagine nel documento finale.
   - **Rimuovi / Svuota Tutto**: elimina elementi selezionati o resetta l'elenco.
   - **Salva come...**: seleziona il percorso e il nome del file di output (con estensione `.pdf` automatica).
   - **Grande pulsante "Unisci PDF"**: avvia il processo di unione.

4. **Esecuzione dell'unione**:
   - Legge i file nell'ordine esatto definito nella ListBox.
   - Esegue il cmdlet:
     ```powershell
     Merge-PDF -InputFile $ElencoFile -OutputFile $PercorsoOutput
     ```
   - Mostra un messaggio grafico di successo con opzione per aprire direttamente la cartella del file generato, oppure un messaggio di errore dettagliato in caso di problemi.
