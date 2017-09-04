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
        $ExePath
    )

    # Get script content at runtime, replace special characters that confuse .NET
    $scriptContent = (Get-Content $ScriptPath -Raw -Encoding UTF8) -replace "\\", "\\" -replace "`r`n", "\n" -replace '"', '\"'

    # Create a temporary script file
    $temp = [System.IO.Path]::GetTempFileName() -replace "\.tmp", ".cs"
@"
using System;
using System.Management.Automation;
namespace POSHRocks
{
    public class Wrapper
    {
        public static void Main(string[] args)
        {
            PowerShell ps = PowerShell.Create();
            ps.Commands.AddScript("$scriptContent");
            ps.Invoke();
        }
    }
}
"@ | Out-File $temp

    # Locate default compiler for .NET runtime
    $compiler = Join-Path -Path ([Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory() ) -ChildPath csc.exe

    # Compile the exe
    $arguments = @(
        "/target:exe"
        "/out:$ExePath"
        "/r:`"$([psobject].Assembly.Location)`""
        $temp
    )

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
