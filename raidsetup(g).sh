#!/bin/bash

# Script to set up RAID, ZFS, or btrfs RAID arrays on Ubuntu Server

# --- Functions ---

# Function to check and install tools
check_and_install_tools() {
    local missing_tools=()
    for tool in "$@"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo "Installing missing tools: <span class="math-inline">\{missing\_tools\[@\]\}\.\.\."
sudo apt\-get update
sudo apt\-get install \-y "</span>{missing_tools[@]}"
        if [ <span class="math-inline">? \-ne 0 \]; then
echo "Error installing tools\. Please install them manually and rerun the script\."
exit 1
fi
echo "Tools installed successfully\."
fi
\}
\# Function to display main menu using dialog
display\_main\_menu\(\) \{
MAIN\_CHOICE\=</span>(dialog --clear --backtitle "RAID/ZFS/btrfs Setup Script" --menu "Main Menu:" 20 60 10 \
        1 "Regular RAID (mdadm)" "Set up using mdadm" \
        2 "ZFS" "Set up using ZFS" \
        3 "btrfs RAID" "Set up using btrfs RAID" \
        4 "Exit" "Quit the script" 3>&1 1>&2 2>&3)
    if [ -z "$MAIN_CHOICE" ]; then # User pressed Cancel or Esc
        MAIN_CHOICE=4 # Default to Exit
    fi
    echo "<span class="math-inline">MAIN\_CHOICE"
\}
\# Function to display RAID menu using dialog
display\_raid\_menu\(\) \{
RAID\_CHOICE\=</span>(dialog --clear --backtitle "RAID Setup (mdadm)" --menu "Regular RAID Configuration:" 20 60 10 \
        a "RAID0" "Striping - No redundancy, max performance/capacity" \
        b "RAID1" "Mirroring - Redundancy, good read performance" \
        c "RAID5" "Parity RAID - Redundancy, good capacity/performance balance (min 3 drives)" \
        d "RAID6" "Dual Parity RAID - Higher redundancy, fault tolerance (min 4 drives)" \
        e "RAID10" "Mirrored Striping - Best balance of performance and redundancy (min 4 drives)" \
        f "Back to Main Menu" "Return to the main menu" 3>&1 1>&2 2>&3)
    if [ -z "$RAID_CHOICE" ]; then # User pressed Cancel or Esc
        RAID_CHOICE=f # Default to Back
    fi
    echo "<span class="math-inline">RAID\_CHOICE"
\}
\# Function to display ZFS menu using dialog
display\_zfs\_menu\(\) \{
ZFS\_CHOICE\=</span>(dialog --clear --backtitle "ZFS Setup" --menu "ZFS Configuration:" 20 60 10 \
        a "Single Disk Pool" "No redundancy, single drive ZFS" \
        b "Mirrored Pool" "Mirroring - Redundancy, good read performance (min 2 drives)" \
        c "RAID-Z" "Single Parity RAID - Redundancy, good capacity/performance balance (min 3 drives)" \
        d "RAID-Z2" "Dual Parity RAID - Higher redundancy, fault tolerance (min 4 drives)" \
        e "RAID-Z3" "Triple Parity RAID - Highest redundancy, fault tolerance (min 5 drives)" \
        f "Back to Main Menu" "Return to the main menu" 3>&1 1>&2 2>&3)
    if [ -z "$ZFS_CHOICE" ]; then # User pressed Cancel or Esc
        ZFS_CHOICE=f # Default to Back
    fi
    echo "<span class="math-inline">ZFS\_CHOICE"
\}
\# Function to display btrfs RAID menu using dialog
display\_btrfs\_menu\(\) \{
BTRFS\_CHOICE\=</span>(dialog --clear --backtitle "btrfs RAID Setup" --menu "btrfs RAID Configuration:" 22 60 10 \
        a "RAID0" "Striping - No redundancy, max performance/capacity" \
        b "RAID1" "Mirroring - Redundancy, good read performance (min 2 drives)" \
        c "RAID10" "Mirrored Striping - Best balance of performance and redundancy (min 4 drives)" \
        d "RAID5 (WARNING: UNSTABLE)" "Parity RAID - Redundancy, good capacity/performance balance (min 3 drives) - DATA LOSS RISK" \
        e "RAID6 (WARNING: UNSTABLE)" "Dual Parity RAID - Higher redundancy, fault tolerance (min 4 drives) - DATA LOSS RISK" \
        f "Back to Main Menu" "Return to the main menu" 3>&1 1>&2 2>&3)
    if [ -z "$BTRFS_CHOICE" ]; then # User pressed Cancel or Esc
        BTRFS_CHOICE=f # Default to Back
    fi
    echo "<span class="math-inline">BTRFS\_CHOICE"
\}
\# Function to detect drives \>\= 1TB using dialog list
detect\_drives\(\) \{
echo "Detecting drives \(\>\= 1TB\)\.\.\."
DRIVES\_RAW\=</span>(lsblk -b -o NAME,SIZE,MODEL,TYPE | awk '$4=="disk" && $2 >= 1000000000000 {print $1, $2, $3}')
    if [ -z "<span class="math-inline">DRIVES\_RAW" \]; then
dialog \-\-msgbox "No drives \>\= 1TB detected\. Please ensure you have suitable drives connected\." 15 50
return 1 \# Indicate failure
else
DRIVE\_ARRAY\=\(\)
DRIVE\_OPTIONS\=""
COUNT\=1
while IFS\= read \-r line; do
DRIVE\=</span>(echo "$line" | awk '{print <span class="math-inline">1\}'\)
SIZE\=</span>(echo "$line" | awk '{printf "%.2f TB", <span class="math-inline">2/1000000000000\}'\)
MODEL\=</span>(echo "$line" | awk '{$1=""; $2=""; print $0}') # Remove first two fields (NAME SIZE)
            DRIVE_ARRAY+=("$DRIVE")
            DRIVE_OPTIONS+="$COUNT) /dev/$DRIVE ($SIZE <span class="math-inline">MODEL\)\\n"
COUNT\=</span>((COUNT+1))
        done <<< "$DRIVES_RAW"

        dialog --textbox <(echo -e "Detected drives:\n$DRIVE_OPTIONS\nSelect drives in the next step.") 25 70

        return 0 # Indicate success
    fi
}


# Function to select drives using dialog checklist
select_drives() {
    DRIVE_COUNT=${#DRIVE_ARRAY[@]}
    if [ "$DRIVE_COUNT" -eq 0 ]; then
        dialog --msgbox "No drives available to select." 10 50
        return 1
    fi

    local DRIVE_CHECKLIST_OPTIONS=""
    for i in $(seq 0 <span class="math-inline">\(\(DRIVE\_COUNT \- 1\)\)\); do
DRIVE\_NAME\=</span>{DRIVE_ARRAY[<span class="math-inline">i\]\}
SIZE\=</span>(lsblk -b -o SIZE /dev/"$DRIVE_NAME" | awk 'NR==2{printf "%.2f TB", <span class="math-inline">1/1000000000000\}'\)
MODEL\=</span>(lsblk -o MODEL /dev/"<span class="math-inline">DRIVE\_NAME" \| awk 'NR\=\=2\{print\}'\)
DRIVE\_CHECKLIST\_OPTIONS\+\="</span>((i+1)) /dev/$DRIVE_NAME ($SIZE <span class="math-inline">MODEL\) off "
done
local SELECTED\_INDEXES
SELECTED\_INDEXES\=</span>(dialog --clear --backtitle "Drive Selection" --checklist "Select drives to use for RAID/ZFS/btrfs setup:" 25 70 10 \
        ${DRIVE_CHECKLIST_OPTIONS} 3>&1 1>&2 2>&3)

    if [ -z "$SELECTED_INDEXES" ]; then # User pressed Cancel or Esc
        dialog --msgbox "No drives selected. Setup aborted." 10 50
        return 1
    fi

    DRIVE_LIST=()
    IFS=" " read -r -a SELECTED_INDEX_ARRAY <<< "<span class="math-inline">SELECTED\_INDEXES"
for INDEX in "</span>{SELECTED_INDEX_ARRAY[@]}"; do
        DRIVE_LIST+=("<span class="math-inline">\{DRIVE\_ARRAY\[</span>((INDEX-1))]}")
    done

    dialog --msgbox "You have selected drives:\n${DRIVE_LIST[@]}" 15 60

    return 0
}


# Function to get mount point using dialog inputbox
get_mount_point() {
    MOUNT_POINT=$(dialog --clear --backtitle "Mount Point" --inputbox "Enter mount point starting with /home/ (e.g., /home/\$USER/data):" 15 60 "/home/$USER/data" 3>&1 1>&2 2>&3)
    if [ -z "$MOUNT_POINT" ]; then # User pressed Cancel or Esc
        dialog --msgbox "No mount point entered. Setup aborted." 10 50
        return 1
    fi
    if [[ ! "$MOUNT_POINT" == /home/* ]]; then
        dialog --msgbox "Mount point must start with /home/. Setup aborted." 15 50
        return 1
    fi

    # Create mount point directory if it doesn't exist and set permissions
    sudo mkdir -p "$MOUNT_POINT"
    sudo chown "$USER":"$USER" "$MOUNT_POINT"
    sudo chmod 775 "$MOUNT_POINT" # Adjust permissions as needed - 775 for user/group read/write/execute, others read/execute
    dialog --msgbox "Mount point set to: $MOUNT_POINT" 10 50
    echo "Mount point set to: $MOUNT_POINT" # For script internal use
    return 0
}


# Function to perform RAID setup
setup_raid() {
    echo "--- RAID Setup ---"
    echo "Selected RAID level: $RAID_LEVEL"
    echo "Selected drives: ${DRIVE_LIST[@]}"
    echo "Mount point: <span class="math-inline">MOUNT\_POINT"
dialog \-\-infobox "Preparing drives and creating RAID array\. This may take some time\.\.\." 8 50
sleep 1 \# Short delay for infobox to show
\# Stop any existing arrays on selected drives \(important for re\-use\)
for DRIVE in "</span>{DRIVE_LIST[@]}"; do
        sudo mdadm --stop /dev/md* 2>/dev/null
        sudo umount "/dev/md*p*" 2>/dev/null
        sudo wipefs -a /dev/"$DRIVE" 2>/dev/null
        for part in $(lsblk -n -o NAME /dev/"<span class="math-inline">DRIVE" \| grep \-o 'p\[0\-9\]\*</span>'); do
            sudo wipefs -a /dev/"$DRIVE$part" 2>/dev/null
        done
    done

    # Partition drives for RAID (using parted - non-interactive)
    PARTITIONED_DRIVES=()
    for DRIVE in "${DRIVE_LIST[@]}"; do
        echo "Partitioning /dev/$DRIVE..."
        sudo parted -s /dev/"<span class="math-inline">DRIVE" mklabel gpt mkpart primary ext4 0% 100%
PARTITIONED\_DRIVES\+\=\("/dev/</span>{DRIVE}1") # Assuming single partition
    done
    DRIVE_LIST=("${PARTITIONED_DRIVES[@]}") # Update DRIVE_LIST to partitioned drives

    # Create RAID array
    case "<span class="math-inline">RAID\_LEVEL" in
raid0\) RAID\_DEVICE\="/dev/md0"; RAID\_ARGS\="\-\-level\=0 \-\-raid\-devices\=</span>{#DRIVE_LIST[@]} <span class="math-inline">\{DRIVE\_LIST\[@\]\}"; FILESYSTEM\_TYPE\="ext4"; ;;
raid1\) RAID\_DEVICE\="/dev/md0"; RAID\_ARGS\="\-\-level\=1 \-\-raid\-devices\=</span>{#DRIVE_LIST[@]} <span class="math-inline">\{DRIVE\_LIST\[@\]\}"; FILESYSTEM\_TYPE\="ext4"; ;;
raid5\) RAID\_DEVICE\="/dev/md0"; RAID\_ARGS\="\-\-level\=5 \-\-raid\-devices\=</span>{#DRIVE_LIST[@]} <span class="math-inline">\{DRIVE\_LIST\[@\]\}"; FILESYSTEM\_TYPE\="ext4"; ;;
raid6\) RAID\_DEVICE\="/dev/md0"; RAID\_ARGS\="\-\-level\=6 \-\-raid\-devices\=</span>{#DRIVE_LIST[@]} <span class="math-inline">\{DRIVE\_LIST\[@\]\}"; FILESYSTEM\_TYPE\="ext4"; ;;
raid10\) RAID\_DEVICE\="/dev/md0"; RAID\_ARGS\="\-\-level\=10 \-\-raid\-devices\=</span>{#DRIVE_LIST[@]} ${DRIVE_LIST[@]}"; FILESYSTEM_TYPE="ext4"; ;;
        *) dialog --msgbox "Error: Invalid RAID level." 10 50; return 1;;
    esac

    echo "Creating RAID array: mdadm --create $RAID_DEVICE $RAID_ARGS"
    sudo mdadm --create "$RAID_DEVICE" $RAID_ARGS | pv -pter -s 100 > /dev/null # Dummy progress bar - mdadm create doesn't give size

    # Format RAID array
    echo "Formatting RAID array ($RAID_DEVICE) with $FILESYSTEM_TYPE..."
    if [ "$FILESYSTEM_TYPE" == "xfs" ]; then
        sudo mkfs.xfs -f "<span class="math-inline">RAID\_DEVICE" \| pv \-pter \-s "</span>(blockdev --getsize64 $RAID_DEVICE)" > /dev/null
    else
        sudo mkfs."$FILESYSTEM_TYPE" -F "<span class="math-inline">RAID\_DEVICE" \| pv \-pter \-s "</span>(blockdev --getsize64 $RAID_DEVICE)" > /dev/null
    fi

    # Mount RAID array
    echo "Mounting RAID array ($RAID_DEVICE) to $MOUNT_POINT..."
    sudo mount "$RAID_DEVICE" "<span class="math-inline">MOUNT\_POINT"
\# Add to /etc/fstab for persistent mounting
echo "Adding to /etc/fstab\.\.\."
echo "</span>(blkid -o uuid -s UUID $RAID_DEVICE)  $MOUNT_POINT  $FILESYSTEM_TYPE  defaults,noatime,nodiratime  0 0" | sudo tee -a /etc/fstab

    dialog --msgbox "Regular RAID setup completed successfully!" 15 50
    echo "Regular RAID setup completed."
}


# Function to perform ZFS setup
setup_zfs() {
    echo "--- ZFS Setup ---"
    echo "Selected ZFS configuration: $ZFS_CONFIG"
    echo "Selected drives: ${DRIVE_LIST[@]}"
    echo "Mount point: <span class="math-inline">MOUNT\_POINT"
dialog \-\-infobox "Preparing drives and creating ZFS pool\. This may take some time\.\.\." 8 50
sleep 1 \# Short delay for infobox to show
\# Stop any existing pools or arrays on selected drives
for DRIVE in "</span>{DRIVE_LIST[@]}"; do
        sudo zpool export -f zp 2>/dev/null
        sudo wipefs -a /dev/"$DRIVE" 2>/dev/null
        for part in $(lsblk -n -o NAME /dev/"<span class="math-inline">DRIVE" \| grep \-o 'p\[0\-9\]\*</span>'); do
            sudo wipefs -a /dev/"$DRIVE$part" 2>/dev/null
        done
    done

    # Create ZFS pool
    case "<span class="math-inline">ZFS\_CONFIG" in
single\) ZPOOL\_NAME\="zp"; ZPOOL\_ARGS\="</span>{DRIVE_LIST[@]}"; ;;
        mirror) ZPOOL_NAME="zp"; ZPOOL_ARGS="mirror ${DRIVE_LIST[@]}"; ;;
        raidz) ZPOOL_NAME="zp"; ZPOOL_ARGS="raidz ${DRIVE_LIST[@]}"; ;;
        raidz2) ZPOOL_NAME="zp"; ZPOOL_ARGS="raidz2 ${DRIVE_LIST[@]}"; ;;
        raidz3) ZPOOL_NAME="zp"; ZPOOL_ARGS="raidz3 ${DRIVE_LIST[@]}"; ;;
        *) dialog --msgbox "Error: Invalid ZFS configuration." 10 50; return 1;;
    esac

    echo "Creating ZFS pool: sudo zpool create $ZPOOL_NAME $ZPOOL_ARGS"
    sudo zpool create -o ashift=12 -m none "$ZPOOL_NAME" $ZPOOL_ARGS | pv -pter -s 100 > /dev/null # Dummy progress bar - zpool create progress is complex

    # Create ZFS dataset for mount point
    DATASET_NAME="$ZPOOL_NAME/data"
    echo "Creating ZFS dataset: sudo zfs create -o mountpoint=$MOUNT_POINT $DATASET_NAME"
    sudo zfs create -o mountpoint="$MOUNT_POINT" -o compression=lz4 "$DATASET_NAME"

    dialog --msgbox "ZFS setup completed successfully!" 15 50
    echo "ZFS setup completed."
}

# Function to perform btrfs RAID setup
setup_btrfs() {
    echo "--- btrfs RAID Setup ---"
    echo "Selected btrfs RAID level: $BTRFS_RAID_LEVEL"
    echo "Selected drives: ${DRIVE_LIST[@]}"
    echo "Mount point: $MOUNT_POINT"

    # RAID5/6 Warning and Confirmation
    if [[ "$BTRFS_RAID_LEVEL" == "raid5" || "$BTRFS_RAID_LEVEL" == "raid6" ]]; then
        dialog --
