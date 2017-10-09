# PowerShell Executable Generator
## Why
Every now and then I get asked "JHP, how can I create an executable from my PowerShell script?" While my go-to answer is "Don't do that!" it does not satisfy everyone.  
This led me to quickly code this small .NET bit which is compiled together with the accompanying script file into one executable.
## How
The small script at the moment only contains one function which could be dot-sourced, Save-CompiledScript. This function is very easy to use:  
```powershell
Save-CompiledScript -ScriptPath D:\BlogTester.ps1 -ExePath D:\blog.exe
```  
It returns a System.IO.FileInfo object retaining the executable that has just been created.  
In order to include additional dependencies the switch parameter IncludeFolderContents will include everything except the script itself in the resulting binary file.  
```powershell
Save-CompiledScript -ScriptPath D:\BlogTester.ps1 -ExePath D:\blog.exe -IncludeFolderContents
```
In the future this small script might grow. Since you probably would want to wrap more than a single script into an exe file, I will update it periodically to do more stuff.
