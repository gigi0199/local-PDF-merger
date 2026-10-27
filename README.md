# Local PDF Merger - GUI Wrapper per PSWritePDF

Applicazione con interfaccia grafica nativa (GUI) per Windows scritta in PowerShell, progettata per unire facilmente più documenti PDF in un unico file sequenziale.

Lo script funge da wrapper per il modulo PowerShell [`PSWritePDF`](https://github.com/EvotecIT/PSWritePDF) e gestisce l'intero ciclo di vita: dai requisiti di sistema fino all'elaborazione finale.

---

## 📋 Flusso di Esecuzione Sequenziale

1. **Controllo e aggiornamento automatico di PowerShell**:
   - Rileva la versione corrente (`$PSVersionTable.PSVersion`).
   - Se inferiore a PowerShell 7 (es. Windows PowerShell 5.1 nativo di sistema), avvia l'installazione automatica/aggiornamento tramite `winget install Microsoft.PowerShell --silent`.
   - Mostra un avviso all'utente indicando di riavviare lo script tramite la nuova versione di PowerShell (sfondo nero) e interrompe l'esecuzione corrente.

2. **Controllo e installazione del modulo `PSWritePDF`**:
   - Verifica se il modulo è già presente nel sistema.
   - In caso contrario, forza l'abilitazione di TLS 1.2 / TLS 1.3 per evitare blocchi con PowerShell Gallery e installa il modulo in modo silenzioso per l'utente corrente:
     ```powershell
     [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
     Install-Module -Name PSWritePDF -Scope CurrentUser -Force -AllowClobber
     ```
   - Importa il modulo nella sessione attiva.

3. **Interfaccia Grafica Nativa (Windows Forms)**:
   - **Elenco PDF (ListBox)**: visualizza i file aggiunti e supporta sia l'aggiunta da dialogo che il **Drag & Drop** diretto da Esplora Risorse.
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

---

## 🚀 Come eseguire lo script

### Metodo 1: Da Terminale (PowerShell 7 o Windows PowerShell)
Apri il terminale nella cartella del progetto ed esegui:
```powershell
pwsh -File .\Merge-PDF-GUI.ps1
```
*Se eseguito in Windows PowerShell 5.1, lo script verificherà la versione e guiderà all'installazione di PowerShell 7 tramite WinGet.*

### Metodo 2: Click Destro
Fai click destro sul file `Merge-PDF-GUI.ps1` e seleziona:
> **Esegui con PowerShell**

