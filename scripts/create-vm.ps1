# Creates the LFS build environment in VirtualBox:
#   VM   "lfs-buildhost"   - Debian 13.7 build host (6 CPU / 8 GB / 40 GB)
#   DISK "lfs-target.vdi"  - blank 80 GB target disk for the LFS system (SATA port 1)
#
# Boot: UEFI (matches the real laptop). Debian installer is attached as optical
# media; after the Debian install we flip boot order to the hard disk.
#
# Usage: .\scripts\create-vm.ps1 [-Name lfs-buildhost] [-Cpu 6] [-RamMB 8192]

param(
    [string]$Name       = 'lfs-buildhost',
    [string]$Iso        = '',
    [int]$Cpu           = 6,
    [int]$RamMB         = 8192,
    [int]$SystemDiskGB  = 40,
    [int]$TargetDiskGB  = 80,
    [string]$SshForward = '127.0.0.1:2222'
)

$ErrorActionPreference = 'Stop'
$VBoxManage = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
if (-not (Test-Path $VBoxManage)) { throw "VirtualBox not installed (missing $VBoxManage)" }

$repo = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not $Iso) { $Iso = Join-Path $repo '.cache\debian-13.7.0-amd64-netinst.iso' }
if (-not (Test-Path $Iso)) { throw "Debian ISO not found: $Iso (run the download step first)" }

function Invoke-VBox {
    param([string[]]$VBoxArgs)
    # VBoxManage writes progress ("0%...10%...") to stderr; don't let PS 5.1
    # promote redirected stderr to a terminating error.
    $eap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & $VBoxManage @VBoxArgs 2>&1
    $ErrorActionPreference = $eap
    if ($LASTEXITCODE -ne 0) {
        throw "VBoxManage failed ($LASTEXITCODE): $($VBoxArgs -join ' ')`n$($out -join "`n")"
    }
    return $out
}

# --- refuse to clobber -------------------------------------------------------
$existing = (& $VBoxManage list vms) -match "`"$Name`""
if ($existing) { throw "VM '$Name' already exists. Delete it first: VBoxManage unregistervm `"$Name`" --delete" }

$vmDir = Join-Path ([Environment]::GetFolderPath('UserProfile')) "VirtualBox VMs\$Name"
$sysDisk  = Join-Path $vmDir "$Name-system.vdi"
$tgtDisk  = Join-Path $vmDir "$Name-target.vdi"

Write-Host "==> Creating VM '$Name' ($Cpu CPUs, $RamMB MB RAM, UEFI)" -ForegroundColor Cyan
Invoke-VBox @('createvm','--name',$Name,'--ostype','Debian_64','--register')
$hp = $SshForward.Split(':')   # "127.0.0.1:2222" -> hostip,hostport
Invoke-VBox @('modifyvm',$Name,
    '--memory',$RamMB, '--cpus',$Cpu, '--vram','128',
    '--firmware','efi',
    '--nic1','nat',
    '--natpf1',"ssh,tcp,$($hp[0]),$($hp[1]),,22",
    '--graphicscontroller','vmsvga',
    '--ioapic','on')

Write-Host "==> Creating disks" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $vmDir | Out-Null
# Remove any stale media (file *or* registry entry) from a previously aborted run
foreach ($d in @($sysDisk, $tgtDisk)) {
    $eap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $VBoxManage closemedium disk $d 2>$null | Out-Null
    $ErrorActionPreference = $eap
    if (Test-Path $d) { Remove-Item $d -Force -ErrorAction SilentlyContinue }
}
Invoke-VBox @('createmedium','disk','--filename',$sysDisk,'--size',($SystemDiskGB*1024),'--format','VDI')
Invoke-VBox @('createmedium','disk','--filename',$tgtDisk,'--size',($TargetDiskGB*1024),'--format','VDI')

Invoke-VBox @('storagectl',$Name,'--name','SATA','--add','sata','--controller','IntelAhci','--portcount','3')
Invoke-VBox @('storageattach',$Name,'--storagectl','SATA','--port','0','--device','0','--type','hdd','--medium',$sysDisk)
Invoke-VBox @('storageattach',$Name,'--storagectl','SATA','--port','1','--device','0','--type','hdd','--medium',$tgtDisk)
Invoke-VBox @('storageattach',$Name,'--storagectl','SATA','--port','2','--device','0','--type','dvddrive','--medium',$Iso)

# Boot: optical first (Debian install), then system disk
Invoke-VBox @('modifyvm',$Name,'--boot1','dvd','--boot2','disk','--boot3','none','--boot4','none')

Write-Host @"

==> Done.

    VM:            $Name
    System disk:   $sysDisk  ($SystemDiskGB GB)
    Target disk:   $tgtDisk  ($TargetDiskGB GB)  <- LFS will live here
    Debian ISO:    $Iso
    SSH forward:   $SshForward -> guest:22

Next:
    1. Start the VM:   VBoxManage startvm "$Name"
    2. Install Debian 13 (UEFI path). IMPORTANT during partitioning:
         - Use the WHOLE first disk for Debian (the build host)
         - Do NOT touch the second (blank 80 GB) disk
         - Enable: OpenSSH server, standard system utilities
    3. After install, eject the ISO and set disk-first boot:
         VBoxManage storageattach "$Name" --storagectl SATA --port 2 --device 0 --medium emptydrive
         VBoxManage modifyvm "$Name" --boot1 disk --boot2 dvd
    4. SSH in:  ssh user@127.0.0.1 -p $($hp[1])
"@ -ForegroundColor Green
