#Michael M. Minor

Function Connect-TS3server
{   Param (
        [Parameter(Mandatory=$true)]
		[String]$Username,
        [Parameter(Mandatory=$true)]
		[String]$Password, #It's telnet, no real security, perhaps tunnel through SSH or stunnel?
        [string]$Server = "HostnameOrIPAddress",
        [string]$Port = "10011",
        [Int]$VirtualServer = 1
    )
    
    <#
            .SYNOPSIS
            Establishes a connection to specified TeamSpeak 3 Server and returns a socket object for further communication.

            .DESCRIPTION
            Connects to, and logs onto, the specified TeamSpeak 3 server's telnet control interface (Default TCP port 10011).
            Telnet Code borrowed (and mangled) from Martin Pugh (Martin9700) thesurleyadmin.com

            .OUTPUTS
            System.Net.Sockets.TcpClient.  Returns a Network Socket object to communicate to connected server, or $False if connection failed. 
            #>

	$Socket = New-Object System.Net.Sockets.TcpClient($Server, $Port)
	If ($Socket.Connected) {
		$loginstr = "login client_login_name="+$Username+" client_login_password="+$Password
		$ret = Invoke-TS3ServerCMD -Socket $Socket -Command $loginstr
        If ($Debug) {
            $RC=0
            foreach ($RL in $rets) {
            Write-debug $RC,$RL #parse and then check output for success "error id=0 msg=ok" (eventually)
            $RC++
            }
        }
        #Set Virtual Server to talk to, default - 1
        $Command = "use " + $VirtualServer.ToString()
        $ret = Invoke-TS3ServerCMD -Socket $Socket -Command $Command          
		Return $Socket }
		Else { Write-Error $("Not connected to "+$Server+":"+$Port )
            Return $False
	        }
}
 
Function Invoke-TS3ServerCMD
{   Param (
		[Parameter(Mandatory=$true)]
		[System.Net.Sockets.TcpClient]$Socket, 
        [Parameter(Mandatory=$true)]
		[String]$Command,
        [int]$WaitTime = 500)
<#
    .SYNOPSIS
    Send a command to, and receive returned data from, the connected server.

    .DESCRIPTION
    Using the required socket object send a command to, and recieve returned data from, the connected server.
    Telnet Code borrowed (and mangled) from Martin Pugh (Martin9700) thesurleyadmin.com
	
    .OUTPUTS
    Returns command output as a string, or $False if the server isn't connected
#>
If ($Socket.Connected)
{  $Stream = $Socket.GetStream()
   $Writer = New-Object System.IO.StreamWriter($Stream)
   $Buffer = New-Object System.Byte[] 1024
   $Encoding = New-Object System.Text.AsciiEncoding
   $Writer.WriteLine($Command)
   $Writer.Flush()
   Start-Sleep -Milliseconds $WaitTime
   While($Stream.DataAvailable) 
       {   $Read = $Stream.Read($Buffer, 0, 1024) 
           $Result += ($Encoding.GetString($Buffer, 0, $Read))
       }
} Else 
    {   $Result = $False #"Unable to connect to host: $($Host):$Port"
        Write-Error "Not connected to host: $($Host):$Port" 
        }
    Return $Result
} 

Function Parse-Ts3ServerResponse
{   Param (
        [Parameter(ValueFromPipeline=$true,Mandatory=$true)]
	    $UnParsedStr
        ) # Should be a string ready to be dissected into client data and error level
    <#
    .SYNOPSIS
    Split string data returned from TeamSpeak3 Server

    .DESCRIPTION
    Splt server responses into data and error level, returning a data object that is split into an array of lines

    .OUTPUTS
    Server response in form of a string, or error level if a non-zero error level is returned
    #>
    $SplitOption = [System.StringSplitOptions]::RemoveEmptyEntries
    $Seperator = [string[]]@([char]13,[char]10)
    $a = $UnParsedStr.Split($Seperator,$SplitOption) 
    $RetCodePos = $a.count - 1 
    if ($RetCodePos -ge 1) { #if it is 0 then it I expect it to be an error
        $LastData = $RetCodePos - 1
        If ([string]$a[$RetCodePos][0..9] -eq [string]"error id=0"[0..9]) {
            return $a[0..$Lastdata]
            }
     }
     Else {return $a[$RetCodePos] #$False
            Write-Error $a[$RetCodePos] 
        } #If its an error just return The error level response$False
}

Function Parse-Ts3ServerClients
{Param (
        [Parameter(ValueFromPipeline=$true,Mandatory=$true)]
	    $ClientData
        )
$Clients = @() #initialize a blank array to hold clients
$CliNum = 0
$MyArray = $ClientData.Split('|')
foreach ($CliTmp in $MyArray) {
    $AttNum = 0
    write-debug 'Client number: '
    write-debug $CliNum
    $cli = new-object TS3Client #If $cli isn't reset each loop, every copy in $Clients gets over-written
    while ($AttNum -le 4) { #hard-coding 5 attributes (0-4) will probably bite me later!
        $Pair = $CliTmp.Split(' ')[$AttNum] #attribute=value pairs are seperated by spaces
        $Att,$Val = $Pair.Split('=') #break into attribute name and its value
        If ($Att -eq 'client_nickname') {
            $Val = $Val.Replace('\s',' ') #Client nickname spaces are escaped with \s, turn them back to spaces
            write-debug 'client_nickname'
            write-debug $Val 
        } 
        $Cli.$Att = $Val
        $AttNum++
    }
    $Clients += @($Cli)
    $CliNum++
}
return $Clients 
}

Function Disconnect-TS3server
{   Param (
    [Parameter(Mandatory=$true)]
	[System.Net.Sockets.TcpClient]$Socket)
$Seperator = [string[]]@([char]13,[char]10)
If ($Socket.Connected)
    {  $Command = "logout"
        Write-Debug "Sending logout"
       $Result = Invoke-TS3ServerCMD -Socket $Socket -Command $Command
       If (([string]$Result[0..9] -eq [string]"error id=0"[0..9]) -or ([string]$Result[0..11] -eq [string]"error id=518"[0..11]))
            {$Command = "quit"
            Write-Debug "Sending quit"
            $Result = Invoke-TS3ServerCMD -Socket $Socket -Command $Command}
     }
}

Add-Type -Language CSharp @"
public class TS3Client{
    public int clid;
    public int cid;
    public int client_database_id;
    public string client_nickname;
    public int client_type;
}
"@;

<# Went with above Add-Type declaration instead of this mess
$Client = New-Object PSObject
$Client | Add-Member -MemberType NoteProperty -Name clid -Value $Null
$Client | Add-Member -MemberType NoteProperty -Name cid -Value $Null
$Client | Add-Member -MemberType NoteProperty -Name client_database_id -Value $Null
$Client | Add-Member -MemberType NoteProperty -Name client_nickname -Value $Null
$Client | Add-Member -MemberType NoteProperty -Name client_type -Value $Null
#>

$NakedPassword = read-host -Prompt '(may be transmitted as plain text) Password: '
$MySocket = Connect-TS3server -Username serveradmin -Password $NakedPassword -Server localhost -Debug:$true  
while ($MySocket.Connected) {
     $MyData = Invoke-TS3ServerCMD -Socket $MySocket -Command "clientlist" | Parse-Ts3ServerResponse
     If ($MyData -ne $False ) {
		Parse-Ts3ServerClients -ClientData $MyData | Format-Table 
        }
     get-date #write-host '--'
     start-sleep -Seconds 5
     }


Parse-Ts3ServerClients -ClientData $MyData


Disconnect-TS3server $MySocket
