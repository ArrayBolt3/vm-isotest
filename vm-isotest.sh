#! /bin/bash

# vm-isotest - Automatically zsync and verify ISOs, and build quick testing VMs out of them.

# Checks to see if the virtual disk repo exists, creates it if it doesn't, and throws a fit if something gets in its way.
if [ -e "$HOME/vm-isotest-virtdisks" ] && [ -d "$HOME/vm-isotest-virtdisks" ]; then
    if [ ! -e "$HOME/vm-isotest-virtdisks/vmisotestmark" ]; then
        echo "Fatal error: ~/vm-isotest-virtdisks directory exists and is not marked safe."
        exit
    fi
else
    if [ -e "$HOME/vm-isotest-virtdisks" ]; then
        echo "Fatal error: a file named ~/vm-isotest-virtdisks exists."
        exit
    else
        mkdir "$HOME/vm-isotest-virtdisks"
        echo 0 > "$HOME/vm-isotest-virtdisks/vmisotestmark"
    fi
fi

# Argument parser
initMode=0
finalArgCount=0
getArgValue="no"
hitArgListEnd="no"
cntr=0
params=( "$@" )
while [ $cntr -le $(($# - 1)) ]; do
    arg=${params[$cntr]}
    if [ "$arg" = "-d" ]; then
        if [ $initMode -eq 0 ]; then
            vmmode="d"
            initMode=1
            cntr=$(($cntr + 1))
            continue
        else
            echo "Fatal error: unexpected argument -d"
            exit
        fi
    elif [ "$arg" = "-l" ]; then
        if [ $initMode -eq 0 ]; then
            vmmode="l"
            initMode=1
            cntr=$(($cntr + 1))
            continue
        else
            echo "Fatal error: unexpected argument -l"
            exit
        fi
    elif [ "$arg" = "-b" ]; then
        if [ $initMode -eq 0 ]; then
            vmmode="b"
            initMode=1
            cntr=$(($cntr + 1))
            continue
        else
            echo "Fatal error: unexpected argument -b"
            exit
        fi
    elif [ "$arg" = "-dlonly" ]; then
        if [ $initMode -eq 0 ]; then
            vmmode="dlonly"
            initMode=1
            cntr=$(($cntr + 1))
            continue
        else
            echo "Fatal error: unexpected argument -dlonly"
            exit
        fi
    fi
    if [ "$getArgValue" = "no" ]; then
        hitArgListEnd="yes"
        if [ "$arg" = "-cpus" ]; then
            hitArgListEnd="no"
            getArgValue="cpus"
        elif [ "$arg" = "-m" ]; then
            hitArgListEnd="no"
            getArgValue="m"
        elif [ "$arg" = "-space" ]; then
            hitArgListEnd="no"
            getArgValue="space"
        elif [ "$arg" = "-graphics" ]; then
            hitArgListEnd="no"
            getArgValue="graphics"
        elif [ "$arg" = "-efi" ]; then
            hitArgListEnd="no"
            efiFirmware="yes"
        elif [ "$arg" = "-persist" ]; then
            hitArgListEnd="no"
            persistDisk="yes"
        elif [ "$arg" = "-ramdisk" ]; then
            hitArgListEnd="no"
            useRAMDisk="yes"
        elif [ "$arg" = "-live" ]; then
            hitArgListEnd="no"
            liveTest="yes"
        elif [ "$arg" = "-nodisk" ]; then
            hitArgListEnd="no"
            noDisk="yes"
        elif [ "$arg" = "-nonet" ]; then
            hitArgListEnd="no"
            noNet="yes"
        fi
    else
        if [ "$getArgValue" = "cpus" ]; then
            numCPUs=$arg
        elif [ "$getArgValue" = "m" ]; then
            ramSize=$arg
        elif [ "$getArgValue" = "space" ]; then
            diskSpace=$arg
        elif [ "$getArgValue" = "graphics" ]; then
            graphicsMode=$arg
        fi
        getArgValue="no"
    fi
    if [ "$hitArgListEnd" = "yes" ]; then
        if [ "$vmmode" = "d" ] || [ "$vmmode" = "dlonly" ]; then
            if [ $cntr -lt $(($# - 3)) ]; then
                echo "Fatal error: unrecognized argument $arg."
                exit
            elif [ $finalArgCount -eq 0 ]; then
                zsyncURL=$arg
            elif [ $finalArgCount -eq 1 ]; then
                gpgURL=$arg
            elif [ $finalArgCount -eq 2 ]; then
                sha256URL=$arg
            fi
            finalArgCount=$(($finalArgCount + 1))
        else
            if [ $cntr -ne $(($# - 1)) ]; then
                echo "Fatal error: unrecognized argument $arg."
                exit
            else
                imgPath=$arg
            fi
        fi
    fi
    cntr=$(($cntr + 1))
done

# Do sanity checks and set defaults
if [ "$vmmode" = "d" ] || [ "$vmmode" = "dlonly" ]; then
    if [ "$zsyncURL" = "" ]; then
        echo "Fatal error: no zsync URL provided."
        exit
    elif [ "$gpgURL" = "" ]; then
        echo "Fatal error: no GPG verification URL provided."
        exit
    elif [ "$sha256URL" = "" ]; then
        echo "Fatal error: no SHA256SUMS URL provided."
        exit
    fi
fi

if [ "$numCPUs" = "" ]; then
    numCPUs=2
fi
if [ "$ramSize" = "" ]; then
    ramSize="4G"
fi
if [ "$diskSpace" = "" ]; then
    if [ "$useRAMDisk" = "yes" ]; then
        diskSpace=15G
    else
        diskSpace=20G
    fi
fi
if [ "$graphicsMode" = "" ]; then
    graphicsMode="qxl"
fi

# zsync the ISO
if [ "$vmmode" = "d" ] || [ "$vmmode" = "dlonly" ]; then
    zsync $zsyncURL
    rm SHA256SUMS
    rm SHA256SUMS.gpg
    wget $gpgURL > /dev/null
    wget $sha256URL > /dev/null
    gpg --keyid-format=long --verify SHA256SUMS.gpg SHA256SUMS
    sha256sum -c --ignore-missing SHA256SUMS
    read -n1 -s # Wait for the user to check the results of the download and test before proceeding.
fi

# Create the VM
if [ "$vmmode" = "d" ] || [ "$vmmode" = "l" ]; then
    if [ "$noDisk" != "yes" ]; then
        # Read the counter from the vmisotestmark file, and increment the counter. This counter is used to ensure unique VM disk image names.
        vmNameCounter=`cat ~/vm-isotest-virtdisks/vmisotestmark`
        vmNameCounter=$(($vmNameCounter + 1))
        rm ~/vm-isotest-virtdisks/vmisotestmark
        echo $vmNameCounter > ~/vm-isotest-virtdisks/vmisotestmark

        # Now do the actual VM creation.
        if [ "$useRAMDisk" = "yes" ]; then
            if [ ! -e /dev/shm/vm-isotest/img$vmNameCounter ]; then
                qemu-img create -f qcow2 "/dev/shm/vm-isotest-img$vmNameCounter" $diskSpace
            else
                echo "Fatal error - could not create VM disk image. Attempting to run the command again, unmodified, should work."
                exit
            fi
        else
            if [ ! -e ~/vm-isotest-virtdisks/vm-isotest-img$vmNameCounter ]; then
                qemu-img create -f qcow2 "$HOME/vm-isotest-virtdisks/vm-isotest-img$vmNameCounter" $diskSpace
            else
                echo "Fatal error - could not create VM disk image. Attempting to run the command again, unmodified, should work."
                exit
            fi
        fi
    fi
fi

# Determine ISO name when in d mode
if [ "$vmmode" = "d" ]; then
    zsyncFilename=`echo "$zsyncURL" | cut -f7 -d "/"`
    if [ "$zsyncFilename" = "" ]; then # The plain Ubuntu ISOs have a path with one fewer slashes in it than the Ubuntu flavours' paths, so if the 7th field is empty, we try the 6th instead.
        zsyncFilename=`echo "$zsyncURL" | cut -f6 -d "/"`
    fi
    imgPath=`echo $zsyncFilename | head -c -7 -`
fi

# Launch and clean up the VM
if [ "$vmmode" != "dlonly" ]; then
    qemuCmdline="-enable-kvm -smp $numCPUs -m $ramSize -machine q35 -device qemu-xhci -device usb-tablet -device usb-kbd -device intel-hda -device hda-duplex"
    if [ "$efiFirmware" = "yes" ]; then
        qemuCmdline="$qemuCmdline -bios /usr/share/ovmf/OVMF.fd"
    fi
    if [ "$noNet" = "yes" ]; then
        qemuCmdline="$qemuCmdline -nic none"
    fi
    if [ "$graphicsMode" = "qxl" ]; then
        qemuCmdline="$qemuCmdline -vga qxl"
    elif [ "$graphicsMode" = "virgl" ]; then
        qemuCmdline="$qemuCmdline -vga virtio -display gtk,gl=on"
    else # VGA graphics, unaccelerated
        qemuCmdline="$qemuCmdline -vga std"
    fi
    if [ "$vmmode" = "b" ]; then
        qemuInitCmdline="$qemuCmdline -hda $imgPath"
    else
        if [ "$noDisk" = "yes" ]; then
            qemuInitCmdline="$qemuCmdline -cdrom $imgPath"
        else
            if [ "$useRAMDisk" = "yes" ]; then
                qemuInitCmdline="$qemuCmdline -boot dc -cdrom $imgPath -hda /dev/shm/vm-isotest-img$vmNameCounter"
                qemuCmdline="$qemuCmdline -hda /dev/shm/vm-isotest-img$vmNameCounter"
            else
                qemuInitCmdline="$qemuCmdline -boot dc -cdrom $imgPath -hda $HOME/vm-isotest-virtdisks/vm-isotest-img$vmNameCounter"
                qemuCmdline="$qemuCmdline -hda $HOME/vm-isotest-virtdisks/vm-isotest-img$vmNameCounter"
            fi
        fi
    fi
    qemu-system-x86_64 $qemuInitCmdline
    if [ "$liveTest" != "yes" ] && [ "$vmmode" != "b" ]; then
        qemu-system-x86_64 $qemuCmdline
    fi
    if [ "$persistDisk" != "yes" ] && [ "$vmmode" != "b" ] && [ "$noDisk" != "yes" ]; then
        if [ "$useRAMDisk" = "yes" ]; then
            rm "/dev/shm/vm-isotest-img$vmNameCounter"
        else
            rm "$HOME/vm-isotest-virtdisks/vm-isotest-img$vmNameCounter"
        fi
    fi
fi
