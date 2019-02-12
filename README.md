# PoshTS3
Powershell functions for connecting and controlling TeamSpeak 3 server

My personal PowerShell project to make interacting with a TeamSpeak 3 Server easier, and to keep the rust off my understanding of PowerShell. I used trial and error to learn about the control interface so it likely isn't perfect. The control interface is connected via Telnet protocol so there is no protection against traffic sniffing, including transmission of passwords in plain-text, or tampering via MitM. I'm only using it on my home LAN so I'm not too worried, but setting up some protections (such as tunneling via SSH or stunnel) would be advisable in most cases.

I was surprised to find that the functions worked as normal on Powershell Core (6.1 beta, I think) on Linux (I tested on Manjaro)

Thanks go to Martin Pugh/Martin9700/The Surley Admin for his Powershell telnet example that got me started.
https://thesurlyadmin.com/2013/04/04/using-powershell-as-a-telnet-client/

I (Michael M. Minor) am not responsible for any harm or damage anyone may do with these functions, accidential or intentional.  I have no affiliation with TeamSpeak.

Next step will probably be making a Module out of this, and better comments and documentation.
