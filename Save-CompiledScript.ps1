function Save-CompiledScript
{
    <#
.SYNOPSIS
    Script to create exe files from PowerShell scripts
.DESCRIPTION
    This script generates exe files in .NET with the C# Compiler csc.exe to wrap any PowerShell script in an exe
.PARAMETER ScriptPath
    The full or relative path to the PowerShell script.
.PARAMETER ExePath
    The full or relative path to the output exe file
.NOTES
# Disclaimer
# This module and it's scripts are not supported under any Microsoft standard support program or service.
# The scripts are provided AS IS without warranty of any kind.
# Microsoft further disclaims all implied warranties including, without limitation, any implied warranties of merchantability
# or of fitness for a particular purpose.
# The entire risk arising out of the use or performance of the scripts and documentation remains with you.
# In no event shall Microsoft, its authors, or anyone else involved in the creation, production,
# or delivery of the scripts be liable for any damages whatsoever (including, without limitation, damages
# for loss of business profits, business interruption, loss of business information, or other pecuniary loss)
# arising out of the use of or inability to use the sample scripts or documentation,
# even if Microsoft has been advised of the possibility of such damages.
#>
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateScript(
            {
                Test-Path $_
            })]
        [System.String]
        $ScriptPath,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ExePath,

        [switch]
        $IncludeFolderContents
    )

    # Get script content at runtime, replace special characters that confuse .NET
    $scriptContent = (Get-Content $ScriptPath -Raw -Encoding UTF8) -replace "\\", "\\" -replace "`r`n", "\n" -replace '"', '\"'

    if ($IncludeFolderContents)
    {
        $referencedFiles = Get-ChildItem -File -Path (Split-Path -Path $ScriptPath -Parent) | Where-Object -Property Name -ne (Split-Path -Path $ScriptPath -Leaf)
        Write-Verbose -Message "Found $($referencedFiles.Count) additional files that will be included"
    }

    # Create a temporary script file
    $temp = [System.IO.Path]::GetTempFileName() -replace "\.tmp", ".cs"
    Write-Verbose -Message "Using temporary file $temp for source code"


@"
using System;
using System.Management.Automation;
namespace POSHRocks
{
    public class Wrapper
    {
        public static void Main(string[] args)
        {
            ExtractResources();
            PowerShell ps = PowerShell.Create();
            ps.Commands.AddScript("$scriptContent");
            ps.Invoke();
        }

        public static void ExtractResources()
        {
            var targetAssembly = System.Reflection.Assembly.GetExecutingAssembly();
            foreach (var resourceName in targetAssembly.GetManifestResourceNames())
            {
                var filePath = resourceName.Replace("POSHRocks.","");
                using (System.IO.Stream s = targetAssembly.GetManifestResourceStream(resourceName))
                {
                    if (s == null)
                    {
                        throw new Exception("Cannot find embedded resource '" + resourceName + "'");
                    }
                    byte[] buffer = new byte[s.Length];
                    s.Read(buffer, 0, buffer.Length);
                    using (System.IO.BinaryWriter sw = new System.IO.BinaryWriter(System.IO.File.Open(filePath, System.IO.FileMode.Create)))
                    {
                        sw.Write(buffer);
                    }
                }
            }
        }
    }
}
"@ | Out-File $temp

    # Locate default compiler for .NET runtime
    $compiler = Join-Path -Path ([Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory() ) -ChildPath csc.exe

    if (-not $compiler)
    {
        throw ".NET compiler for C# (csc.exe) could not be found."
    }

    write-Verbose -Message "Located the compiler at $compiler"

    # Compile the exe
    $arguments = @(
        "/target:exe"
        "/out:$ExePath"
        "/r:`"$([psobject].Assembly.Location)`""
        $temp
    )

    if ($referencedFiles)
    {
        foreach ($file in $referencedFiles)
        {
            $arguments += "/res:`"$($file.FullName)`",POSHRocks.$($file.Name),Public"
        }
    }

    Write-Verbose -Message "Compiling with the following arguments:`r`n$($arguments -join ' ')"
    $compilation = Start-Process -FilePath $compiler -ArgumentList $arguments -Wait -NoNewWindow -PassThru

    # $? always returns true/false depending on the last action on the command line. Useful for external tools.
    if ($compilation.ExitCode)
    {
        Write-Error "Error compiling $ScriptPath" -ErrorAction Stop
    }

    # Remove the temporary file
    Remove-Item $temp -Force

    $exeFile = Get-Item -Path $ExePath -ErrorAction SilentlyContinue

    if (-not $exeFile)
    {
        Write-Error -Message "$ExePath could not be found" -ErrorAction Stop
    }

    return $exeFile
}
