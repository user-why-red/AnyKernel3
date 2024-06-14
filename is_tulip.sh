#!/sbin/sh
for p in "ro.product.device" "ro.build.product" "ro.product.vendor.device" "ro.vendor.product.device"; do
    device="$(getprop "$p")"
    if [ "$device" = "tulip" ] || [ "$device" = "twolip" ]; then
        exit 0
    fi
done

exit 1
