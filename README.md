# vm-isotest - A rapid virtualization-based testing system for Linux alpha and beta testers.

For those who are wondering, yes, this project is still maintained, and will be for as long as I use this tool myself. Currently running it on Ubuntu Unity 22.10.

## Why?

As an Ubuntu tester, I make VMs. A **lot** of VMs. I generally use the exact same specs on my VMs, I use them for just long enough to do a test, and then I throw them away. Since my work involves so many disposable VMs, I started to get tired of the UI provided by Gnome Boxes that I was using. It worked well, and is slick for lots of uses, but for me, navigating a UI to spin up a VM is a bit of a hassle.

As is the usual programmer way, I decided to spend several hours making a script to save me a few seconds per test. The result is this seriously messy lump of Bash code that automates the job of downloading ISO files, verifying their integrity and authenticity, creating VMs with those files, and disposing of the VMs when they're done being used. It also allows users with lots of RAM (32 GB or more) to use their system's RAM as a storage device for holding a VM disk image during testing. This may speed up the VM installation process, and will definitely reduce wear-and-tear on your SSD.

## Features:

* Automatic downloading, hash-testing, and GPG-verifying of ISO images and verification files
* Automatic creation, configuration, management, and removal of VMs
* RAMDisk mode for quick testing of small VMs on systems with lots of RAM to reduce wear-and-tear on physical disks and speed up testing
* Unaccelerated VGA, 2d QXL acceleration, and 3d virgl acceleration for graphics
* BIOS and EFI firmware

## Dependencies:

* zsync
* wget
* gpg
* sha256sum
* qemu-system-x86_64
* ovmf (only if using the EFI option)
* coreutils

Additionally, you will have to recv-keys the key used by your distro's creator using GPG for the ISO downloader to work.

## Installation:

To install, clone the repository, enter the directory containing the cloned files, and run these commands:

    sudo cp ./vm-isotest.sh /usr/local/bin/vm-isotest
    sudo chown root:root /usr/local/bin/vm-isotest
    sudo chmod 0755 /usr/local/bin/vm-isotest

To uninstall, run `sudo rm /usr/local/bin/vm-isotest`. If you want to get rid of any disk images you created using vm-isotest, ensure that the directory `~/vm-isotest-virtdisks` doesn't contain any important data, then run `rm -R ~/vm-isotest-virtdisks`.

## Usage:

Download a new ISO file (or sync an existing one), verify it, and launch a testing VM. The VM will boot from the ISO, allowing you to install, then reboot from the disk image for testing, then will be automatically deleted.

    vm-isotest -d [options] http://www.example.com/path/to/file.iso.zsync http://www.example.com/path/to/SHA256SUMS.gpg http://www.example.com/path/to/SHA256SUMS

Create a new testing VM with a local ISO file. The VM will boot, allow you to install, reboot, allow you to test, then will be automatically deleted.

    vm-isotest -l [options] /path/to/local.iso

Boot an existing VM disk image. The VM will not be automatically deleted.

    vm-isotest -b [options] /path/to/local.qcow2

Download a new ISO file (or sync an existing one), verify it, and stop. The ISO can be used later.

    vm-isotest -dlonly http://www.example.com/path/to/file.iso.zsync http://www.example.com/path/to/SHA256SUMS.gpg http://www.example.com/path/to/SHA256SUMS

## Modes:

* -d: Download ISO and create VM.
* -l: Use local ISO and create VM.
* -b: Boot existing VM.
* -dlonly: Just download the ISO and don't do anything else.

## Options:

* -cpus: Set the number of CPU cores exposed to the VM. Default is 2.
* -m: Set the quantity of RAM given to the VM. Supports size suffixes. Default is 4G.
* -space: Set the quantity of disk space given to the VM. Supports size suffixes. Default is 20G for a normal installation, and 15G for a RAMDisk installation.
* -graphics: One of vga, qxl, or virgl. Sets the graphics acceleration mode. Default is qxl.

## Advanced options:

* -efi: Enables UEFI firmware on the VM, rather than the default SeaBIOS. Secure Boot is not enabled.
* -persist: Do not delete the VM at the end of the test.
* -ramdisk: Installs the VM in RAMDisk mode, where the virtual drive is stored entirely in your system's RAM. Not recommended on system with less than 32 GB of RAM.
* -live: Initiates a live test. The VM is not rebooted after you close it the first time.
* -nodisk: Does not create a virtual disk for the VM. Most useful in combination with -live.
* -nonet: Disables the virtual network adapter, resulting in no Internet access within the VM.

## Warnings:

vm-isotest cannot handle filenames or paths that contain spaces. You'll probably get a QEMU error if you try that. If your home folder somehow has a space in its name, that will almost certainly cause trouble.

## Notes:

vm-isotest is designed to automatically delete some files to clean up after itself and ensure that it functions correctly. The files it is able to delete automatically are:

* SHA256SUMS, in the working directory.
* SHA256SUMS.gpg, in the working directory.
* Any file named "vm-isotest-img*" located in ~/vm-isotest-virtdisks and /dev/shm, where * is a string stored in the ~/vm-isotest-virtdisks/vmisotestmark file.

The disk image file deletion is designed to dispose of an unneeded VM after it is used for testing, while the SHA256SUMS and SHA256SUMS.gpg files are assumed to be unneeded if you run the script in a directory containing those files. If you mess with the ~/vm-isotest-virtdisks/vmisotestmark file, you might accidentally delete a disk image you didn't mean to, and if you run the script in a directory containing important checksum and GPG files, you will lose those.

Bash is not my "native language" when it comes to programming - C# is. As a result, this code probably looks like dumpster fire to an experienced Bash coder. Shoot, parts of it look like dumpster fire to me. Feel free to clean up (or overhaul) the code as needed, and maybe shoot me a pull request so that this can turn from a functional disaster into a nice Bash app.

Also, I didn't do anything even close to unit testing this thing (is unit testing even a thing with Bash scripts?). I wrote it in one go, tweaked it until all the features seemed to work, then called it good enough. So you're probably gonna find bugs. Feel free to open bug reports if you do.

Lastly, there are some sanity checks, but a lot of user input is not validated. So don't expect things to go well if you hand it a path when it expects a URL, or anything like that. It's a utility script for people who know what they're doing - it does not do a good job of graceful error handling. (However, I did go out of my way to make sure it won't delete all your files.)

## TODO:

* Add the "-include" feature. This will package the contents of a folder into a FAT32 disk image and attach it to the VM, allowing the user to access tools within the VM.
* Add EFI Secure Boot support.
* Add a folder sharing feature that uses the virtfs feature of QEMU. This will probably replace the -include planned feature.
* Port this whole mess to Python so that future development is easy.

## Known problems:

virgl graphics don't seem to work on my desktop - I can tell that the VM is running due to the fact that the mouse cursor does stuff when hovering over the VM window, but the VM screen remains black. I'm using a GTX 1050 Ti NVIDIA card with proprietary drivers on Ubuntu Studio 22.04, so the NVIDIA stuff might have something to do with it. At any rate, when using `-graphics virgl`, it may or may not work.

The script doesn't automatically determine if the test results were successful - it just prints them on the terminal and then waits for you to press a key to acknowledge that you've seen the results. I'm not sure if this counts as a bug or a feature, so I've left it as it is for now.

## Legal

Copyright (c) Aaron Rainbolt. Licensed under the GNU GPL version 2. See LICENSE for the full license text.
