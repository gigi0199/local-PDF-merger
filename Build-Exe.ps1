<#
.SYNOPSIS
    Compilatore per generare 'PDFMerger.exe' a partire dallo script PowerShell 'Merge-PDF-GUI.ps1'.

.DESCRIPTION
    Legge lo script 'Merge-PDF-GUI.ps1', lo incorpora in un eseguibile C# autonomo (.exe)
    utilizzando il compilatore nativo .NET di Windows (Add-Type).
    L'eseguibile risultante non richiede software di terze parti né installazioni esterne.
#>

[CmdletBinding()]
param(
    [string]$ScriptPath,
    [string]$OutputExe
)

if (-not $ScriptPath) {
    $currentDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $ScriptPath = Join-Path $currentDir "Merge-PDF-GUI.ps1"
}
if (-not $OutputExe) {
    $currentDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $OutputExe = Join-Path $currentDir "PDFMerger.exe"
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Compilazione di PDFMerger.exe" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $ScriptPath)) {
    Write-Error "File di script non trovato in: $ScriptPath"
    return
}

Write-Host "1. Lettura dello script: $ScriptPath" -ForegroundColor Gray
$scriptContent = Get-Content -LiteralPath $ScriptPath -Raw -Encoding UTF8
$scriptBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($scriptContent))

Write-Host "2. Preparazione del wrapper nativo C#..." -ForegroundColor Gray

$csharpCode = @"
using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Windows.Forms;

namespace PDFMergerApp
{
    static class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            try
            {
                // Script PowerShell incorporato in formato Base64
                string scriptBase64 = "$scriptBase64";
                byte[] scriptBytes = Convert.FromBase64String(scriptBase64);
                string scriptText = Encoding.UTF8.GetString(scriptBytes);

                // Cartella temporanea sicura per l'esecuzione
                string tempDir = Path.Combine(Path.GetTempPath(), "PDFMerger");
                if (!Directory.Exists(tempDir))
                {
                    Directory.CreateDirectory(tempDir);
                }

                string tempScript = Path.Combine(tempDir, "Merge-PDF-GUI.ps1");
                File.WriteAllText(tempScript, scriptText, Encoding.UTF8);

                // Ricerca dell'eseguibile PowerShell (PowerShell 7 prioritario, altrimenti 5.1)
                string psExe = FindPowerShell();

                // Costruzione argomenti di avvio con supporto passaggio file trascinati su .exe
                StringBuilder arguments = new StringBuilder();
                arguments.Append("-STA -NoProfile -ExecutionPolicy Bypass -File \"" + tempScript + "\"");

                if (args != null && args.Length > 0)
                {
                    foreach (string arg in args)
                    {
                        arguments.Append(" \"" + arg.Replace("\"", "\\\"") + "\"");
                    }
                }

                ProcessStartInfo psi = new ProcessStartInfo();
                psi.FileName = psExe;
                psi.Arguments = arguments.ToString();
                psi.UseShellExecute = true;

                Process proc = Process.Start(psi);
                if (proc != null)
                {
                    proc.WaitForExit();
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show(
                    "Impossibile avviare PDF Merger:\n\n" + ex.Message,
                    "Errore di avvio",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error
                );
            }
        }

        static string FindPowerShell()
        {
            // 1. Verifica se pwsh.exe risponde nel PATH (Store, WindowsApps, WinGet, ecc.) ed è versione >= 7
            try
            {
                ProcessStartInfo testPsi = new ProcessStartInfo();
                testPsi.FileName = "pwsh.exe";
                testPsi.Arguments = "-NoProfile -Command \"$PSVersionTable.PSVersion.Major\"";
                testPsi.UseShellExecute = false;
                testPsi.RedirectStandardOutput = true;
                testPsi.CreateNoWindow = true;

                using (Process testP = Process.Start(testPsi))
                {
                    if (testP != null)
                    {
                        string outStr = testP.StandardOutput.ReadToEnd().Trim();
                        testP.WaitForExit(3000);
                        int major = 0;
                        if (int.TryParse(outStr, out major) && major >= 7)
                        {
                            return "pwsh.exe";
                        }
                    }
                }
            }
            catch { }

            // 2. Controllo percorsi fisici noti (inclusi WindowsApps e cartelle x64/x86)
            string progFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
            string progFilesX86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
            string localApp = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);

            string[] paths = new string[]
            {
                Path.Combine(localApp, @"Microsoft\WindowsApps\pwsh.exe"),
                Path.Combine(progFiles, @"PowerShell\7\pwsh.exe"),
                Path.Combine(progFiles, @"PowerShell\7-preview\pwsh.exe"),
                Path.Combine(localApp, @"Microsoft\PowerShell\7\pwsh.exe"),
                Path.Combine(progFilesX86, @"PowerShell\7\pwsh.exe")
            };

            foreach (string p in paths)
            {
                if (File.Exists(p)) return p;
            }

            // 3. Fallback a Windows PowerShell nativo (5.1)
            string sysPwsh = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.System),
                @"WindowsPowerShell\v1.0\powershell.exe"
            );
            if (File.Exists(sysPwsh)) return sysPwsh;

            return "powershell.exe";
        }
    }
}
"@

Write-Host "3. Compilazione in corso con .NET Framework..." -ForegroundColor Yellow

try {
    Add-Type -TypeDefinition $csharpCode -OutputAssembly $OutputExe -OutputType WindowsApplication -ReferencedAssemblies "System.Windows.Forms.dll", "System.Drawing.dll"
    
    if (Test-Path -LiteralPath $OutputExe) {
        $fileInfo = Get-Item -LiteralPath $OutputExe
        Write-Host "==========================================================" -ForegroundColor Green
        Write-Host " Eseguibile creato con successo!" -ForegroundColor Green
        Write-Host " Percorso: $($fileInfo.FullName)" -ForegroundColor White
        Write-Host " Dimensione: $([math]::Round($fileInfo.Length / 1KB, 2)) KB" -ForegroundColor White
        Write-Host "==========================================================" -ForegroundColor Green
    } else {
        Write-Error "Compilazione terminata ma il file .exe non è stato generato."
    }
}
catch {
    Write-Error "Errore durante la compilazione dell'eseguibile: $($_.Exception.Message)"
}
