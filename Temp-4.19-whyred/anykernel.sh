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

# Input OV lvl to aroma
parse_ov_level() {
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
# Input OV lvl end

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

# Read value by user selected from aroma prop files
cpu_oc=$(aroma_get_value cpu_oc)
cpu_uc=$(aroma_get_value cpu_uc)
gpu_oc=$(aroma_get_value gpu_oc)
zram_size=$(aroma_get_value zram_size)
uv_confirm=$(aroma_get_value uv_confirm)
ov_confirm=$(aroma_get_value ov_confirm)
ecpu_ov_level=$(aroma_get_value ecpu_ov_level)
pcpu_ov_level=$(aroma_get_value pcpu_ov_level)
ecpu_uv_level=$(aroma_get_value ecpu_uv_level)
pcpu_uv_level=$(aroma_get_value pcpu_uv_level)
energy_model=$(aroma_get_value energy_model)
# Read value from aroma end

# Patch EM
fdt_patch_files=""
if [ "$energy_model" -ne 1 ]; then
    case "$energy_model" in
        "2") {
            ui_print "- Use kdrag0n's EAS energy model (for sdm660)"
            if [ "$cpu_oc" -eq 1 ]; then
		fdt_patch_files="$fdt_patch_files ${home}/fdt_patches/kdrag0n-energy-model-sdm660-oc.fdtp"
            else
                fdt_patch_files="$fdt_patch_files ${home}/fdt_patches/kdrag0n-energy-model-sdm660-nooc.fdtp"
            fi
        };;
        "3") {
            ui_print "- Use kdrag0n's EAS energy model (for sdm636)"
            [ "$cpu_oc" -eq 1 ] && abort "! This energy model is not suitable with overclock!"
            fdt_patch_files="$fdt_patch_files ${home}/fdt_patches/kdrag0n-energy-model-sdm636-nooc.fdtp"
        };;
        "4") {
            ui_print "- Use hypeartist's EAS energy model"
            if [ "$cpu_oc" -eq 1 ]; then
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
if [ "$uv_confirm" -eq 2 ]; then
    ui_print "- Applying UV changes..."
    ecpu_uv=$(parse_uv_level $ecpu_uv_level)
    pcpu_uv=$(parse_uv_level $pcpu_uv_level)
    [ "$ecpu_uv" -ne 0 ]  && ${bin}/fdtput $dtb_img /soc/cprh-ctrl@179c8000/thread@0/regulator qcom,custom-voltage-reduce $ecpu_uv -tu
    [ "$pcpu_uv" -ne 0 ] && ${bin}/fdtput $dtb_img /soc/cprh-ctrl@179c4000/thread@0/regulator qcom,custom-voltage-reduce $pcpu_uv -tu
    ui_print "- $ecpu_uv uV is reduced for LITTLE-cluster!"
    ui_print "- $pcpu_uv uV is reduced for BIG-cluster!"
    sync
fi
set_progress 0.3
# Apply uv voltages end

# Apply ov voltages
if [ "$ov_confirm" -eq 2 ]; then
    ui_print "- Applying OV changes..."
    ecpu_ov=$(parse_ov_level $ecpu_ov_level)
    pcpu_ov=$(parse_ov_level $pcpu_ov_level)
    [ "$ecpu_ov" -ne 0 ]  && ${bin}/fdtput $dtb_img /soc/cprh-ctrl@179c8000/thread@0/regulator qcom,custom-voltage-increase $ecpu_ov -tu
    [ "$pcpu_ov" -ne 0 ] && ${bin}/fdtput $dtb_img /soc/cprh-ctrl@179c4000/thread@0/regulator qcom,custom-voltage-increase $pcpu_ov -tu
    ui_print "- $ecpu_ov uV is increased for LITTLE-cluster!"
    ui_print "- $pcpu_ov uV is increased for BIG-cluster!"
    sync
fi
set_progress 0.3
# Apply ov voltages end

# Print final voltage
if [ "$uv_confirm" -eq 2 ] && [ "$ov_confirm" -eq 2 ]; then
    ui_print "- Final voltage = reference voltage - undervoltage + overvoltage."
fi
# Final voltage end

# CPU oc
if [ "$cpu_oc" -eq 1 ]; then
        ui_print "- Applying CPU overclock changes..."
        ui_print "- CPU is overclocked to 2.2Ghz!"
        patch_cmdline "overclock.cpu" "overclock.cpu=1"
elif [ "$cpu_oc" -eq 2 ]; then
        ui_print "- Applying CPU overclock changes..."
        ui_print "- CPU is overclocked to 2.4Ghz!"
        patch_cmdline "overclock.cpu" "overclock.cpu=2"
else
	patch_cmdline "overclock.cpu" ""
fi
sync
# CPU oc end

#GPU oc
if [ "$gpu_oc" -eq 1 ]; then
	ui_print "- Applying GPU overclock changes..."
	ui_print "- GPU is overclocked to 585Mhz(Adreno 509) or 750Mhz(Adreno 512)!"
        patch_cmdline "overclock.gpu" "overclock.gpu=1"
else
        patch_cmdline "overclock.gpu" ""
fi
sync
# GPU oc end

# CPU uc
if [ "$cpu_uc" -eq 1 ]; then
        ui_print "- Applying CPU underclock changes..."
        ui_print "- CPU is underclocked to 1.4Ghz!"
        patch_cmdline "underclock.cpu" "underclock.cpu=1"
elif [ "$cpu_uc" -eq 2 ]; then
        ui_print "- Applying CPU underclock changes..."
        ui_print "- CPU is underclocked to 1.8Ghz!"
        patch_cmdline "underclock.cpu" "underclock.cpu=2"
else
        patch_cmdline "underclock.cpu" ""
fi
sync
# CPU uc end

# Zram
if [ "$zram_size" -ne 7 ]; then
        ui_print "- Applying zram changes..."
	ui_print "- ZRAM is resized to $zram_size GB!"
        patch_cmdline "zram.resize" "zram.resize=$zram_size"
else
        patch_cmdline "zram.resize" ""
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
