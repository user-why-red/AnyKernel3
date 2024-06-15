# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() { '
kernel.string=San-Kernel-Codename-RX.X.XXX by @user_why_red
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=whyred
supported.versions=
supported.patchlevels=
'; } # end properties

# shell variables
block=/dev/block/bootdevice/by-name/boot;
is_slot_device=0;
ramdisk_compression=auto;
patch_vbmeta_flag=auto;

## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. tools/ak3-core.sh;

################################ AROMA INSTALLER SPOTTED ################################
######## BY @USER_WHY_RED ######
######## THX PANDA KERNEL ######

aroma_show_progress() {
  # aroma_show_progress <amount> <time>
  # Note: In Aroma Installer, the unit of parameter "time" is milliseconds.
  show_progress $1 "-${2}"
}

# Get values from aroma
aroma_get_value() {
  [ -f /tmp/aroma/${1}.prop ] && cat /tmp/aroma/${1}.prop | head -n1 | cut -d'=' -f2 || echo ""
}
# End

# Function to apply patches using fdtput
apply_fdt_patch() {
  # apply_fdt_patch <dtb_img> <fdt_patch_file>
  [ -f "$2" ] || abort "! Can not found fdt patch file: $2!"
  cat $2 | sed -e 's/[  ]*#.*//' -e '/^[        ]*$/d' | while read line; do
    ${bin}/fdtput $1 $line || abort "! Failed to apply fdt patch: $2"
  done
}
# Function end

# Input UV lvl to aroma
parse_uv_level() {
  case "$1" in
    "1") echo 0;;
    "2") echo 20000;;  # 20 mV
    "3") echo 40000;;  # 40 mV
    "4") echo 80000;;  # 80 mV
    "5") echo 100000;; # 100 mV
    "6") echo 120000;; # 120 mV
    *) echo 0;;
  esac
}

# Input UV lvl end

# Parse zram size
# 1 is default, so no need to modify init.rc
parse_zram_size() {
  case "$1" in
    "2") echo 2684354560;;  # 2.5GB
    "3") echo 3211225472;;  # 3GB
    "4") echo 3851436032;;  # 3.5GB
    "5") echo 4820892928;; # 4.5GB
    "6") echo 6442450944;; # 6GB
    *) echo 2147483648;;
  esac
}
# Parse zram size end

# AnyKernel split boot install
split_boot;
# Split boot install end

# extract Image and dtb
ui_print "- Extracting files..."
set_progress 0.1
xz -d ${home}/Image.xz || abort
dtb_img=${home}/kernel.dtb
set_progress 0.3
# extract Image and dtb end

# Check tmp path if exists to verify encryption status
TMP="/data/local/tmp"

# Read value by user selected from aroma prop files
cpu_oc=$(aroma_get_value cpu_oc)
gpu_oc=$(aroma_get_value gpu_oc)
zram_size=$(aroma_get_value zram_size)
uv_confirm=$(aroma_get_value uv_confirm)
zram_confirm=$(aroma_get_value zram_confirm)
ecpu_uv_level=$(aroma_get_value ecpu_uv_level)
pcpu_uv_level=$(aroma_get_value pcpu_uv_level)
energy_model=$(aroma_get_value energy_model)
# Read value from aroma end

# Patch EM
fdt_patch_files=""
if [ "$energy_model" != "1" ]; then
    case "$energy_model" in
        "2") {
            ui_print "- Use kdrag0n's EAS energy model (for sdm660)"
            if [ "$cpu_oc" == "1" ]; then
		fdt_patch_files="$fdt_patch_files ${home}/fdt_patches/kdrag0n-energy-model-sdm660-oc.fdtp"
            else
                fdt_patch_files="$fdt_patch_files ${home}/fdt_patches/kdrag0n-energy-model-sdm660-nooc.fdtp"
            fi
        };;
        "3") {
            ui_print "- Use kdrag0n's EAS energy model (for sdm636)"
            [ "$cpu_oc" == "1" ] && abort "! This energy model is not suitable with overclock!"
            fdt_patch_files="$fdt_patch_files ${home}/fdt_patches/kdrag0n-energy-model-sdm636-nooc.fdtp"
        };;
        "4") {
            ui_print "- Use hypeartist's EAS energy model"
            if [ "$cpu_oc" == "1" ]; then
                fdt_patch_files="$fdt_patch_files ${home}/fdt_patches/hypeartist-energy-model-oc.fdtp"
            else
                fdt_patch_files="$fdt_patch_files ${home}/fdt_patches/hypeartist-energy-model-nooc.fdtp"
            fi
        };;
        *) abort "! Unknown parameter: energy_model: \"$energy_model\"";;
    esac
fi
# Patch EM end

# Patch selected files to dtb image
if [ -n "$fdt_patch_files" ]; then
    ui_print "- Patching dtb file..."
    for fdt_patch_file in $fdt_patch_files; do
        apply_fdt_patch $dtb_img $fdt_patch_file
    done
    sync
fi
# Patch selected files to dtb image end


# Apply uv voltages
if [ "$uv_confirm" == "2" ]; then
    ui_print "- Applying UV changes..."
    ecpu_uv=$(parse_uv_level $ecpu_uv_level)
    pcpu_uv=$(parse_uv_level $pcpu_uv_level)
    [ "$ecpu_uv" != "0" ]  && ${bin}/fdtput $dtb_img /soc/cprh-ctrl@179c8000/thread@0/regulator qcom,custom-voltage-reduce $ecpu_uv -tu
    [ "$pcpu_uv" != "0" ] && ${bin}/fdtput $dtb_img /soc/cprh-ctrl@179c4000/thread@0/regulator qcom,custom-voltage-reduce $pcpu_uv -tu
    sync
fi
set_progress 0.3
# Apply uv voltages end

# CPU oc
if [ "$cpu_oc" == "1" ]; then
	ui_print "- Applying CPU overclock changes..."
	patch_cmdline "androidboot.cpuoverclock" "androidboot.cpuoverclock=1"
else
	patch_cmdline "androidboot.cpuoverclock" ""
fi
sync
# CPU oc end

#GPU oc
if [ "$gpu_oc" == "1" ]; then
	ui_print "- Applying GPU overclock changes..."
        patch_cmdline "overclock.gpu" "overclock.gpu=1"
else
        patch_cmdline "overclock.gpu" ""
fi
sync
# GPU oc end

# Zram
if [ "$zram_confirm" == "2" ]; then

	if [ -d "$TMP" ]; then

	ui_print "- Applying zram changes..."
	size=$(parse_zram_size $zram_size)
	ui_print "- Mounting /system to edit init.rc..."
        mount /system_root
        mount -o rw,remount /system_root
	ui_print "- Successfully mounted /system!"
	mkdir -p /data/local/tmp/san-kernel-backup
	backup="/data/local/tmp/san-kernel-backup"
	ui_print "- Making backup of stock init.rc to /data/local/tmp/san-kernel-backup/init.rc..."
	if [ -f "$backup/init.rc" ]; then
		ui_print "- Init backup already found, using it..."
		cp "$backup/init.rc" /system_root/system/etc/init/hw/init.rc
		ui_print "- Writing new zram size..."
		echo "on boot" >> /system_root/system/etc/init/hw/init.rc
		echo "	write /sys/block/zram0/disksize $size" >> /system_root/system/etc/init/hw/init.rc
		ui_print "- Zram is resized to $zram_size"
	else
		ui_print "- Fresh installation detected!, creating init backup..."
		cp /system_root/system/etc/init/hw/init.rc "$backup/init.rc"
		cp "$backup/init.rc" /system_root/system/etc/init/hw/init.rc
		ui_print "- Writing new zram size..."
                echo "on boot" >> /system_root/system/etc/init/hw/init.rc
                echo "  write /sys/block/zram0/disksize $size" >> /system_root/system/etc/init/hw/init.rc
		ui_print "- Zram is resized to $zram_size"
	fi

	if [ "$zram_size" == "1" ]; then
		ui_print "- Resetting zram to default size..."
		ui_print "- Restoring init from backup..."
		cp "$backup/init.rc" /system_root/system/etc/init/hw/init.rc
	fi
	ui_print "- Done, unmounting /system..."
        mount -o ro,remount /system_root
        umount /system_root

	else
                ui_print "OS has /data partition encrypted, sorry you cant use this feature by this way!"
        fi
fi
# Zram end

# We are not really modifying ramdisk
cp -f $dtb_img ${split_img}/kernel_dtb
sync
# Split img end

# Install process
ui_print "- Everything is set, Installation going on :)"
aroma_show_progress 0.5 3500

flash_boot;
flash_dtbo;
## end boot install

################################ AROMA INSTALLER END ################################
