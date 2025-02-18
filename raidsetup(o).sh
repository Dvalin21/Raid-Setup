#!/bin/bash

# Function to check and install required tools
install_tools() {
    echo "Checking required tools..."
    required_packages=("mdadm" "btrfs-progs" "xfsprogs" "zfsutils-linux" "udisks2" "smartmontools" "parted" "gdisk" "lvm2" "fio" "blkdiscard" "scrub" "nvme-cli")
    for pkg in "${required_packages[@]}"; do
        if ! dpkg -s "$pkg" &>/dev/null; then
            echo "Installing $pkg..."
            sudo apt-get install -y "$pkg"
        fi
    done
}

# Function to perform drive health check
check_drive_health() {
    for drive in "${selected_drives[@]}"; do
        echo "Checking SMART status for $drive..."
        sudo smartctl -H "$drive"
    done
}

# Function to perform disk benchmark
benchmark_disk() {
    echo "Running disk performance benchmark..."
    fio --name=benchmark --rw=randread --bs=4k --size=100M --numjobs=4 --runtime=30 --group_reporting
}

# Function to display RAID options
display_raid_options() {
    echo "Select the RAID configuration:"
    echo "1) RAID 0 (Striping)"
    echo "2) RAID 1 (Mirroring)"
    echo "3) RAID 5 (Striping with Parity)"
    echo "4) RAID 6 (Striping with Double Parity)"
    echo "5) RAID 10 (Mirroring + Striping)"
    echo "6) Btrfs RAID 0"
    echo "7) Btrfs RAID 1"
    echo "8) Btrfs RAID 10"
    echo "9) Btrfs RAID 5 (Warning: Experimental and may have issues)"
    echo "10) Btrfs RAID 6 (Warning: Experimental and may have issues)"
    echo "11) ZFS RAID-Z1 (Single Parity)"
    echo "12) ZFS RAID-Z2 (Double Parity)"
    echo "13) ZFS RAID-Z3 (Triple Parity)"
}

# Function to display filesystem options based on RAID type
display_filesystem_options() {
    local raid_type=$1
    echo "Select the filesystem format:"
    case $raid_type in
        1|2|3|4|5)
            echo "1) ext4"
            echo "2) xfs"
            ;;
        6|7|8|9|10)
            echo "1) btrfs"
            ;;
        11|12|13)
            echo "1) zfs"
            ;;
        *)
            echo "Invalid RAID type selected."
            exit 1
            ;;
    esac
}

# Function to detect drives >= 1TB
detect_drives() {
    echo "Detecting drives of size >= 1TB..."
    lsblk -d -o NAME,SIZE | awk '$2 ~ /T/ {print NR ") /dev/" $1 " - " $2}'
}

# Function to create mount point
create_mount_point() {
    local mount_point=$1
    if [ ! -d "$mount_point" ]; then
        echo "Creating mount point at $mount_point..."
        mkdir -p "$mount_point"
        chown "$USER":"$USER" "$mount_point"
        chmod 755 "$mount_point"
    else
        echo "Mount point $mount_point already exists."
    fi
}

# Main script starts here
echo "Welcome to the RAID, Btrfs, and ZFS Setup Script."
install_tools

display_raid_options
read -p "Enter the number corresponding to your choice: " raid_choice

display_filesystem_options $raid_choice
read -p "Enter the number corresponding to your filesystem choice: " fs_choice

detect_drives
read -p "Enter the numbers of the drives to use (e.g., 1 2 3): " -a drive_choices

selected_drives=()
for choice in "${drive_choices[@]}"; do
    device=$(lsblk -d -o NAME,SIZE | awk '$2 ~ /T/ {print NR ") /dev/" $1}' | awk -v num=$choice '$1 == num")" {print $2}')
    if [ -n "$device" ]; then
        selected_drives+=("$device")
    else
        echo "Invalid selection: $choice"
        exit 1
    fi
done

check_drive_health

read -p "Enter the desired mount point (e.g., /home/username/mountpoint): " mount_point
create_mount_point "$mount_point"

benchmark_disk

echo "RAID Configuration: $raid_choice"
echo "Filesystem: $fs_choice"
echo "Selected Drives: ${selected_drives[@]}"
echo "Mount Point: $mount_point"
read -p "Are these selections correct? (y/n): " confirm
if [ "$confirm" != "y" ]; then
    echo "Setup aborted."
    exit 1
fi

case $raid_choice in
    1)  mdadm --create --verbose /dev/md0 --level=0 --raid-devices=${#selected_drives[@]} "${selected_drives[@]}"
        mkfs.ext4 /dev/md0
        mount /dev/md0 "$mount_point"
        ;;
    2)  mdadm --create --verbose /dev/md0 --level=1 --raid-devices=${#selected_drives[@]} "${selected_drives[@]}"
        mkfs.ext4 /dev/md0
        mount /dev/md0 "$mount_point"
        ;;
    3|4|5)  mdadm --create --verbose /dev/md0 --level=$raid_choice --raid-devices=${#selected_drives[@]} "${selected_drives[@]}"
        mkfs.ext4 /dev/md0
        mount /dev/md0 "$mount_point"
        ;;
    6|7|8|9|10)  
        mkfs.btrfs -f -d raid$raid_choice -m raid$raid_choice "${selected_drives[@]}"
        mount "${selected_drives[0]}" "$mount_point"
        ;;
    11) zpool create -f mypool raidz "${selected_drives[@]}"
        zfs create mypool/mydataset
        zfs set mountpoint="$mount_point" mypool/mydataset
        ;;
    12) zpool create -f mypool raidz2 "${selected_drives[@]}"
        zfs create mypool/mydataset
        zfs set mountpoint="$mount_point" mypool/mydataset
        ;;
    13) zpool create -f mypool raidz3 "${selected_drives[@]}"
        zfs create mypool/mydataset
        zfs set mountpoint="$mount_point" mypool/mydataset
        ;;
    *)
        echo "Invalid RAID choice."
        exit 1
        ;;
esac

echo "Setup complete. Your storage is mounted at $mount_point."
