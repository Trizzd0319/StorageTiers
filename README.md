# Tiered Storage Pool Creator (PowerShell)

This PowerShell script automatically creates a **tiered Storage Spaces pool** using both SSDs and HDDs. It is ideal for Windows 10/11 Pro/Enterprise or Server 2016+ systems where you want to:

- Combine SSDs and HDDs into a single volume
- Use SSDs as a fast performance tier
- Store large volumes of data on slower HDDs
- Automatically mount the new virtual disk as a local drive (default `T:`)

---

## Features

- Automatically detects eligible **SSD** and **HDD** disks
- Destroys any previous pool with the same name to prevent conflicts
- Sets **1MB interleave** for optimized performance
- Creates **fixed provisioning**, **simple resiliency**, **tiered layout**
- Formats and mounts the new storage volume automatically
- Fully commented for easy customization

---

## Requirements

- PowerShell (Run as Administrator)
- Windows 10/11 Pro, Enterprise or Windows Server 2016+
- Storage Spaces feature enabled
- Virtual Disk and Storage Spaces services running
- At least 1 SSD and 1 HDD available and marked `CanPool=True`

---

## Usage

1. Clone the repo or download the script:
   ```bash
   git clone https://github.com/Trizzd03139/StorageTiers
