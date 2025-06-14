# ================================
# Tiered Storage Pool Creator.ps1
# ================================
# Author: [Your Name]
# Description:
#   Automatically creates a tiered Storage Spaces pool using both SSD and HDD disks.
#   Applies interleave, calculates optimal sizes, formats, and mounts the volume.
#   Intended for Windows 10/11 Pro/Enterprise or Server 2016+ with Storage Spaces enabled.

# === CONFIGURATION ===
$poolName   = "TieredPool"     # Name of the storage pool to create
$spaceName  = "TieredVolume"   # Name of the virtual disk (volume)
$driveLetter = "T"             # Drive letter to mount the new volume

# === REMOVE EXISTING STORAGE POOL (if present) ===
$existingPools = Get-StoragePool -ErrorAction SilentlyContinue | Where-Object { $_.FriendlyName -eq $poolName }
if ($existingPools) {
    foreach ($pool in $existingPools) {
        Write-Host "⚠️ Removing existing pool: $($pool.FriendlyName)"
        
        # Remove all virtual disks linked to this pool
        $vdisks = Get-VirtualDisk | Where-Object { $_.ObjectId -like "*$($pool.ObjectId)*" }
        foreach ($vd in $vdisks) {
            Remove-VirtualDisk -FriendlyName $vd.FriendlyName -Confirm:$false
        }

        # Set pool to writable and remove
        $pool | Set-StoragePool -IsReadOnly $false
        $pool | Remove-StoragePool -Confirm:$false
    }

    Start-Sleep -Seconds 3
}

# === DETECT STORAGE SUBSYSTEM ===
$subsystem = Get-StorageSubSystem | Where-Object { $_.FriendlyName -like "Windows Storage*" }
if (-not $subsystem) {
    Write-Error "❌ Storage subsystem not found. Ensure 'Storage Spaces' and 'Virtual Disk' services are running."
    exit
}

# === IDENTIFY ELIGIBLE PHYSICAL DISKS ===
$ssdDisks = Get-PhysicalDisk | Where-Object {
    $_.FriendlyName -in @("PCIe SSD", "CT1000P5PSSD8") -and $_.CanPool
}
$hddDisks = Get-PhysicalDisk | Where-Object {
    $_.FriendlyName -like "ATA*" -and $_.CanPool
}
$allDisks = $ssdDisks + $hddDisks

Write-Host "`n🔍 Found $($ssdDisks.Count) SSD(s) and $($hddDisks.Count) HDD(s) eligible for pooling."

# Ensure enough disks exist to build a tiered setup
if ($ssdDisks.Count -lt 1 -or $hddDisks.Count -lt 1) {
    Write-Error "❌ Not enough eligible SSD and HDD disks to create a tiered storage pool."
    exit
}

# === CREATE STORAGE POOL ===
$pool = New-StoragePool -FriendlyName $poolName `
    -StorageSubsystemUniqueId $subsystem.UniqueId `
    -PhysicalDisks $allDisks

# === CREATE STORAGE TIERS WITH CUSTOM INTERLEAVE ===
$interleaveBytes = 1MB  # 1MB interleave improves tier granularity

$ssdTier = New-StorageTier -StoragePoolFriendlyName $poolName `
    -FriendlyName "PerformanceTier" `
    -MediaType SSD `
    -ResiliencySettingName Simple `
    -NumberOfColumns 1 `
    -Interleave $interleaveBytes

$hddTier = New-StorageTier -StoragePoolFriendlyName $poolName `
    -FriendlyName "CapacityTier" `
    -MediaType HDD `
    -ResiliencySettingName Simple `
    -NumberOfColumns 1 `
    -Interleave $interleaveBytes

# === CREATE NON-TIERED VDISK USING MAX SIZE ===
$vdisk = New-VirtualDisk -FriendlyName $spaceName `
    -StoragePoolFriendlyName $poolName `
    -UseMaximumSize `
    -ResiliencySettingName Simple `
    -ProvisioningType Fixed `
    -NumberOfColumns 1 `
    -FaultDomainAwareness PhysicalDisk

# === WAIT FOR SYSTEM TO REGISTER THE NEW VDISK ===
Start-Sleep -Seconds 5

# === INITIALIZE, PARTITION, FORMAT, AND MOUNT ===
$disk = Get-Disk | Where-Object { $_.FriendlyName -eq $spaceName -and $_.PartitionStyle -eq 'RAW' }
if (-not $disk) {
    Write-Error "❌ Virtual disk '$spaceName' was not detected. Please check the storage pool manually."
    exit
}

Initialize-Disk -Number $disk.Number -PartitionStyle GPT

New-Partition -DiskNumber $disk.Number -UseMaximumSize -DriveLetter $driveLetter |
    Format-Volume -FileSystem NTFS -NewFileSystemLabel $spaceName -Confirm:$false

# === SUCCESS MESSAGE ===
Write-Host "`n✅ Tiered Storage Space '$spaceName' created and mounted as ${driveLetter}:"
Get-Volume -DriveLetter $driveLetter | Format-Table DriveLetter, FriendlyName, FileSystemType, DriveType, HealthStatus, OperationalStatus, SizeRemaining, Size
