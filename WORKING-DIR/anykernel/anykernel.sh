# AnyKernel2 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
script="$0"

# begin properties
properties() { '
kernel.string=Gabriel Kernel by mostafaz @ xda-developers
do.devicecheck=1
do.modules=1
do.cleanup=1
do.system=1
do.cleanuponabort=1
do.osversion=1
do.f2fs_patch=1
do.rem_encryption=0
do.force_encryption=0
do.66hz=0
device.name1=santoni
device.name2=Xiaomi
device.name3=Redmi 4X
'; } # end properties

# shell variables
block=/dev/block/bootdevice/by-name/boot;
is_slot_device=0;
ramdisk_compression=auto;


## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. /tmp/anykernel/tools/ak2-core.sh;


## AnyKernel file attributes
# set permissions/ownership for included ramdisk files
chmod -R 750 $ramdisk/*;
chmod -R 755 $ramdisk/sbin;
chown -R root:root $ramdisk/*;


## AnyKernel install
dump_boot;

# begin ramdisk changes

# fstab.qcom
if [ -e fstab.qcom ]; then
	fstab=fstab.qcom;
elif [ -e /system/vendor/etc/fstab.qcom ]; then
	fstab=/system/vendor/etc/fstab.qcom;
elif [ -e /system/etc/fstab.qcom ]; then
	fstab=/system/etc/fstab.qcom;
fi;

if [ "$(file_getprop $script do.f2fs_patch)" == 1 ]; then
if [ $(mount | grep f2fs | wc -l) -gt "0" ] &&
   [ $(cat $fstab | grep f2fs | wc -l) -eq "0" ]; then
ui_print " "; ui_print "Found fstab: $fstab";
ui_print "- Adding f2fs support to fstab...";

insert_line $fstab "data        f2fs" before "data        ext4" "/dev/block/bootdevice/by-name/userdata     /data        f2fs    nosuid,nodev,noatime,inline_xattr,data_flush      wait,check,encryptable=footer,formattable,length=-16384";
insert_line $fstab "cache        f2fs" after "data        ext4" "/dev/block/bootdevice/by-name/cache     /cache        f2fs    nosuid,nodev,noatime,inline_xattr,flush_merge,data_flush wait,formattable,check";

	if [ $(cat $fstab | grep f2fs | wc -l) -eq "0" ]; then
		ui_print "- Failed to add f2fs support!";
		exit 1;
	fi;
elif [ $(mount | grep f2fs | wc -l) -gt "0" ] &&
     [ $(cat $fstab | grep f2fs | wc -l) -gt "0" ]; then
	ui_print " "; ui_print "Found fstab: $fstab";
	ui_print "- F2FS supported!";
fi;
fi; #f2fs_patch

if [ $(cat $fstab | grep forceencypt | wc -l) -gt "0" ]; then
	ui_print " "; ui_print "Force encryption is enabled";
	if [ "$(file_getprop $script do.rem_encryption)" == 0 ]; then
		ui_print "- Force encryption removal is off!";
	else
		ui_print "- Force encryption removal is on!";
	fi;
elif [ $(cat $fstab | grep encryptable | wc -l) -gt "0" ]; then
	ui_print " "; ui_print "Force encryption is not enabled";
	if [ "$(file_getprop $script do.force_encryption)" == 0 ]; then
		ui_print "- Force encryption is off!";
	else
		ui_print "- Force encryption is on!";
	fi;
fi;

if [ "$(file_getprop $script do.rem_encryption)" == 1 ] &&
   [ $(cat $fstab | grep forceencypt | wc -l) -gt "0" ]; then
	sed -i 's/forceencrypt/encryptable/g' $fstab
	if [ $(cat $fstab | grep forceencrypt | wc -l) -eq "0" ]; then
		ui_print "- Removed force encryption flag!";
	else
		ui_print "- Failed to remove force encryption!";
		exit 1;
	fi;
elif [ "$(file_getprop $script do.force_encryption)" == 1 ] &&
     [ $(cat $fstab | grep encryptable | wc -l) -gt "0" ]; then
	sed -i 's/encryptable/forceencrypt/g' $fstab
	if [ $(cat $fstab | grep encryptable | wc -l) -eq "0" ]; then
		ui_print "- Added force encryption flag!";
	else
		ui_print "- Failed to add force encryption!";
		exit 1;
	fi;
fi;

# init.qcom.rc
if [ -e init.qcom.rc ]; then
if [ -e init.qcom.rc~ ]; then
	cp init.qcom.rc~ init.qcom.rc;
fi;
backup_file init.qcom.rc;
append_file init.qcom.rc "bbinstall" init.qcom.patch;
else
if [ -e init.rc~ ]; then
	cp init.rc~ init.rc;
fi;
backup_file init.rc;
insert_line init.rc "init.gabriel.rc" before "import /init.usb.rc" "import /init.gabriel.rc";
fi;

decompressed_image=/tmp/anykernel/kernel/Image
compressed_image=$decompressed_image.gz
# Hexpatch the kernel if Magisk is installed ('skip_initramfs' -> 'want_initramfs')
if [ -d $ramdisk/.backup ]; then
  ui_print " "; ui_print "Magisk detected! Patching kernel so reflashing Magisk is not necessary...";
  $bin/magiskboot --decompress $compressed_image $decompressed_image;
  $bin/magiskboot --hexpatch $decompressed_image 736B69705F696E697472616D6673 77616E745F696E697472616D6673;
  $bin/magiskboot --compress=gz $decompressed_image $compressed_image;
  $bin/magiskboot --dtb-patch /tmp/anykernel/treble*/*;
fi;

# end ramdisk changes

write_boot;

## end install

