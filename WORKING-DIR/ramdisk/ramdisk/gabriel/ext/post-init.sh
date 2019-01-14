#!/gabriel/busybox sh

# Kernel Tuning by Dorimanx.
# Kernel Tuning by Mostafaz.

BB=/gabriel/busybox

MEM_ALL=`free | grep Mem | $BB awk '{ print $2 }'`;
echo 1 > /cache/boot_state;

# protect init from oom
if [ -f /system/xbin/su ]; then
	su -c echo "-1000" > /proc/1/oom_score_adj;
fi;

OPEN_RW()
{
	if [ "$($BB mount | grep rootfs | cut -c 26-27 | grep -c ro)" -ge "0" ]; then
		$BB mount -o remount,rw /;
	fi;
	$BB mount -o remount,rw /system;
}
OPEN_RW;

if [ ! -e /sbin/busybox ];then
	$BB cp /gabriel/busybox /sbin/busybox;
	$BB chmod 06755 /sbin/busybox;
fi;

$BB ln -sf /sbin/busybox /sbin/cp
$BB ln -sf /sbin/busybox /sbin/grep
$BB ln -sf /sbin/busybox /sbin/sed
$BB ln -sf /sbin/busybox /sbin/mount
$BB ln -sf /sbin/busybox /sbin/awk
$BB ln -sf /sbin/busybox /sbin/sh
$BB ln -sf /sbin/busybox /sbin/echo

if [ ! -e /cache/sound_l ] || [ ! -e /cache/sound_r ]; then
	touch /cache/sound_l;
	touch /cache/sound_r;
else
	LEFT=`cat /cache/sound_l`;
	RIGHT=`cat /cache/sound_r`;

	sleep 0.5;
	echo "$LEFT"" ""$RIGHT" > /sys/kernel/sound_control/headphone_gain;
fi;

# some nice thing for dev
if [ ! -e /cpufreq ]; then
	$BB ln -s /sys/devices/system/cpu/cpu0/cpufreq/ /cpufreq_b;
	$BB ln -s /sys/devices/system/cpu/cpu4/cpufreq/ /cpufreq_l;
	$BB ln -s /sys/module/msm_thermal/parameters/ /cputemp;
fi;

# create init.d folder if missing
if [ ! -d /system/etc/init.d ]; then
	mkdir -p /system/etc/init.d/
	$BB chmod 755 /system/etc/init.d/;
fi;

OPEN_RW;

CRITICAL_PERM_FIX()
{
	# critical Permissions fix
	$BB chown -R root:root /tmp;
	$BB chown -R root:root /res;
	$BB chown -R root:root /sbin;
	$BB chown -R root:root /gabriel;
	$BB chmod -R 777 /tmp/;
	$BB chmod -R 775 /res/;
	$BB chmod -R 06755 /gabriel/ext/;
	$BB chmod 06755 /gabriel/busybox;
	$BB chmod 06755 /system/xbin/busybox;
}
CRITICAL_PERM_FIX;

$BB chmod 666 /sys/module/lowmemorykiller/parameters/cost;
$BB chmod 666 /sys/module/lowmemorykiller/parameters/adj;
$BB chmod 666 /sys/module/lowmemorykiller/parameters/minfree

$BB chmod 666 /sys/module/msm_thermal/parameters/*

for i in kcal kcal_cont kcal_hue kcal_invert kcal_sat kcal_val; do
	$BB chown system system /sys/devices/platform/kcal_ctrl.0/$i
	$BB chmod 0664 /sys/devices/platform/kcal_ctrl.0/$i
done;

for i in governor max_freq min_freq; do
	$BB chown system system /sys/class/devfreq/1c00000.qcom,kgsl-3d0/$i
	$BB chmod 0664 /sys/class/devfreq/1c00000.qcom,kgsl-3d0/$i
done;

for i in cpu1 cpu2 cpu3 cpu4 cpu5 cpu6 cpu7; do
	$BB chown system system /sys/devices/system/cpu/$i/online
	$BB chmod 0664 /sys/devices/system/cpu/$i/online
done;

for i in cpu0 cpu4; do
$BB chown system system /sys/devices/system/cpu/$i/cpufreq/*
$BB chown system system /sys/devices/system/cpu/$i/cpufreq/*
$BB chmod 0664 /sys/devices/system/cpu/$i/cpufreq/scaling_governor
$BB chmod 0664 /sys/devices/system/cpu/$i/cpufreq/scaling_max_freq
$BB chmod 0664 /sys/devices/system/cpu/$i/cpufreq/scaling_min_freq
$BB chmod 0444 /sys/devices/system/cpu/$i/cpufreq/cpuinfo_cur_freq
$BB chmod 0444 /sys/devices/system/cpu/$i/cpufreq/stats/*
done;

if [ -d /system/lib/modules ] &&
   [ "$(grep 'ro.miui*' /system/build.prop | wc -l)" -gt "0" ]; then
	cp /gabriel/modules/* /system/lib/modules/;
	echo "[Gabriel-Kernel] Modules have been copied to system" > /dev/kmsg;
fi;

# fix mtp, 4*4096=16384 length limitation in usb driver
# define CI13XXX_PAGE_SIZE  4096ul /* page size for TD's */
# credits to xpsviewer@git
if [ "$(cat /sys/module/g_android/parameters/mtp_tx_req_len)" -gt 16384 ]; then
	echo 16384 > /sys/module/g_android/parameters/mtp_tx_req_len;
fi;

SYSTEM_TUNING()
{
echo 1 > /sys/module/msm_thermal/core_control/enabled;
echo 0 > /cputemp/enabled;

# cpuset tuning
echo "$(cat /dev/cpuset/foreground/cpus)" > /cache/fore_cpu;
echo "$(cat /dev/cpuset/foreground/boost/cpus)" > /cache/fore_b_cpu;
echo "$(cat /dev/cpuset/top-app/cpus)" > /cache/top_cpu;
echo "$(cat /dev/cpuset/system-background/cpus)" > /cache/sysb_cpu;
echo "$(cat /dev/cpuset/background/cpus)" > /cache/backg_cpu;

echo 2 > /sys/devices/system/cpu/cpu0/core_ctl/min_cpus;
echo 2 > /sys/devices/system/cpu/cpu0/core_ctl/max_cpus;
sleep 2;
echo 4 > /sys/devices/system/cpu/cpu0/core_ctl/max_cpus;
echo 4 > /sys/devices/system/cpu/cpu4/core_ctl/min_cpus;
echo 4 > /sys/devices/system/cpu/cpu4/core_ctl/max_cpus;
}

OPEN_RW;

for f in /sys/class/devfreq/soc*; do
	DEVFREQ=`echo "$f" | awk -F/ '{print $NF}'`;
	echo "$(cat $f/governor)" > /cache/$DEVFREQ
done;

if [ ! -d /data/.gabriel ]; then
	$BB mkdir -p /data/.gabriel;
fi;
if [ ! -d /data/.gabriel/logs ]; then
	$BB mkdir -p /data/.gabriel/logs;
fi;

SYSTEM_TUNING;

# reset profiles auto trigger to be used by kernel ADMIN, in case of need, if new value added in default profiles
# just set numer $RESET_MAGIC + 1 and profiles will be reset one time on next boot with new kernel.
# incase that ADMIN feel that something wrong with global STweaks config and profiles, then ADMIN can add +1 to CLEAN_gabriel_DIR
# to clean all files on first boot from /data/.gabriel/ folder.
RESET_MAGIC=0;
CLEAN_gabriel_DIR=1;

if [ ! -e /data/.gabriel/reset_profiles ]; then
	echo "$RESET_MAGIC" > /data/.gabriel/reset_profiles;
fi;
if [ ! -e /data/reset_gabriel_dir ]; then
	echo "$CLEAN_gabriel_DIR" > /data/reset_gabriel_dir;
fi;
if [ -e /data/.gabriel/.active.profile ]; then
	PROFILE=$(cat /data/.gabriel/.active.profile);
else
	echo "default" > /data/.gabriel/.active.profile;
	PROFILE=$(cat /data/.gabriel/.active.profile);
fi;
if [ "$(cat /data/reset_gabriel_dir)" -eq "$CLEAN_gabriel_DIR" ]; then
	if [ "$(cat /data/.gabriel/reset_profiles)" != "$RESET_MAGIC" ]; then
		if [ ! -e /data/.gabriel_old ]; then
			mkdir /data/.gabriel_old;
		fi;
		cp -a /data/.gabriel/*.profile /data/.gabriel_old/;
		$BB rm -f /data/.gabriel/*.profile;
		if [ -e /data/data/com.af.synapse/databases ]; then
			$BB rm -R /data/data/com.af.synapse/databases;
		fi;
		echo "$RESET_MAGIC" > /data/.gabriel/reset_profiles;
	else
		echo "no need to reset profiles or delete .gabriel folder";
	fi;
else
	# Clean /data/.gabriel/ folder from all files to fix any mess but do it in smart way.
	if [ -e /data/.gabriel/"$PROFILE".profile ]; then
		cp /data/.gabriel/"$PROFILE".profile /sdcard/"$PROFILE".profile_backup;
	fi;
	if [ ! -e /data/.gabriel_old ]; then
		mkdir /data/.gabriel_old;
	fi;
	cp -a /data/.gabriel/* /data/.gabriel_old/;
	$BB rm -f /data/.gabriel/*
	if [ -e /data/data/com.af.synapse/databases ]; then
		$BB rm -R /data/data/com.af.synapse/databases;
	fi;
	echo "$CLEAN_gabriel_DIR" > /data/reset_gabriel_dir;
	echo "$RESET_MAGIC" > /data/.gabriel/reset_profiles;
	echo "$PROFILE" > /data/.gabriel/.active.profile;
fi;

# Fix critical perms again after init.d mess
CRITICAL_PERM_FIX;

if [ $MEM_ALL -gt 3000000000 ]; then
	ZRAM_SIZE=0;
elif [ $MEM_ALL -lt 2900000000 ]; then
	ZRAM_SIZE=1024;
else
	ZRAM_SIZE=512;
fi;

sed -i "s/zramtweaks=[0-9]*/zramtweaks=$ZRAM_SIZE/g" /res/customconfig/*.profile;

[ ! -f /data/.gabriel/default.profile ] && cp -a /res/customconfig/default.profile /data/.gabriel/default.profile;
[ ! -f /data/.gabriel/battery.profile ] && cp -a /res/customconfig/battery.profile /data/.gabriel/battery.profile;
[ ! -f /data/.gabriel/extreme_battery.profile ] && cp -a /res/customconfig/extreme_battery.profile /data/.gabriel/extreme_battery.profile;
[ ! -f /data/.gabriel/performance.profile ] && cp -a /res/customconfig/performance.profile /data/.gabriel/performance.profile;
[ ! -f /data/.gabriel/extreme_performance.profile ] && cp -a /res/customconfig/extreme_performance.profile /data/.gabriel/extreme_performance.profile;
[ ! -f /data/.gabriel/gabriel.profile ] && cp -a /res/customconfig/gabriel.profile /data/.gabriel/gabriel.profile;
[ ! -f /data/.gabriel/salvation.profile ] && cp -a /res/customconfig/salvation.profile /data/.gabriel/salvation.profile;
[ ! -f /data/.gabriel/ps217_mod.profile ] && cp -a /res/customconfig/salvation.profile /data/.gabriel/ps217_mod.profile;

$BB chmod -R 0777 /data/.gabriel/;

. /res/customconfig/customconfig-helper;
read_defaults;
read_config;

# start CORTEX by tree root, so it's will not be terminated.
sed -i "s/cortexbrain_background_process=[0-1]*/cortexbrain_background_process=1/g" /gabriel/ext/cortexbrain-tune.sh;
if [ "$(pgrep -f "cortexbrain-tune.sh" | wc -l)" -eq "0" ]; then
	nohup sh /gabriel/ext/cortexbrain-tune.sh > /data/.gabriel/cortex.txt &
fi;

if [ "$(grep 'ro.miui*' /system/build.prop | wc -l)" -gt "0" ]; then
	sed -i "s/cortexbrain_background_process=[0-1]*/cortexbrain_background_process=1/g" /gabriel/ext/kcal.sh;
	if [ "$(pgrep -f "kcal.sh" | wc -l)" -eq "0" ]; then
		nohup sh /gabriel/ext/kcal.sh > /data/.gabriel/kcal.txt &
	fi;
fi;

# Fentropy enForcer
# Thanks to ArjunrambZ (TweakDrypT)
if [ "$frandom_control" == "yes" ]; then
	if [ -e "/dev/frandom" ]; then
		chmod 666 /dev/frandom;
		for dom in /dev/*random; do
			if [ "\$dom" != "/dev/frandom" ] && [ ! "\`ls \$dom.*\`" ]; then
				mv \$dom \$dom.unsuper;
				ln /dev/frandom \$dom;
				chmod 666 \$dom;
			fi 2>/dev/null;
		done;
	fi;
fi;

# Load parameters for Synapse
DEBUG=/data/.gabriel/;
BUSYBOX_VER=$(busybox | grep "BusyBox v" | cut -c0-15);
echo "$BUSYBOX_VER" > $DEBUG/busybox_ver;

if [ "$stweaks_boot_control" == "yes" ]; then
	# apply Synapse monitor
	$BB sh /res/synapse/uci reset;
	# apply Gabriel settings
	$BB sh /res/uci_boot.sh apply;
	$BB mv /res/uci_boot.sh /res/uci.sh;
else
	$BB mv /res/uci_boot.sh /res/uci.sh;
	$BB pkill -f "/gabriel/ext/cortexbrain-tune.sh";
fi;

if [ "$wifi_on_boot" == "no" ]; then
	svc wifi disable;
fi;

if [ "$data_on_boot" == "no" ]; then
	svc data disable;
fi;

if [ "$fstrim_boot" == "yes" ]; then
	$BB fstrim -v /system > /data/.gabriel/fstrim_log;
	$BB fstrim -v /data >> /data/.gabriel/fstrim_log;
	$BB fstrim -v /cache >> /data/.gabriel/fstrim_log;
fi;

OPEN_RW;

# Start any init.d scripts that may be present in the rom or added by the user
$BB chmod -R 755 /system/etc/init.d/;
if [ "$init_d" == "on" ]; then
	(
		$BB nohup $BB run-parts /system/etc/init.d/ > /data/.gabriel/init.d.txt &
	)&
else
	if [ -e /system/etc/init.d/99SuperSUDaemon ]; then
		$BB nohup $BB sh /system/etc/init.d/99SuperSUDaemon > /data/.gabriel/root.txt &
	else
		echo "no root script in init.d";
	fi;
fi;

OPEN_RW;

# Fix critical perms again after init.d mess
CRITICAL_PERM_FIX;

(
	sleep 10;

	# get values from profile
	PROFILE=$(cat /data/.gabriel/.active.profile);
	. /data/.gabriel/"$PROFILE".profile;

	while [ "$(cat /sys/class/thermal/thermal_zone5/temp)" -ge "50" ]; do
		sleep 5;
	done;

	# stop google service and restart it on boot. this remove high cpu load and ram leak!
	if [ "$($BB pidof com.google.android.gms | wc -l)" -eq "1" ]; then
		$BB kill "$($BB pidof com.google.android.gms)";
	fi;
	if [ "$($BB pidof com.google.android.gms.unstable | wc -l)" -eq "1" ]; then
		$BB kill "$($BB pidof com.google.android.gms.unstable)";
	fi;
	if [ "$($BB pidof com.google.android.gms.persistent | wc -l)" -eq "1" ]; then
		$BB kill "$($BB pidof com.google.android.gms.persistent)";
	fi;
	if [ "$($BB pidof com.google.android.gms.wearable | wc -l)" -eq "1" ]; then
		$BB kill "$($BB pidof com.google.android.gms.wearable)";
	fi;

	# Google Services battery drain fixer by Alcolawl@xda
	# http://forum.xda-developers.com/google-nexus-5/general/script-google-play-services-battery-t3059585/post59563859
	pm enable com.google.android.gms/.update.SystemUpdateActivity
	pm enable com.google.android.gms/.update.SystemUpdateService
	pm enable com.google.android.gms/.update.SystemUpdateService$ActiveReceiver
	pm enable com.google.android.gms/.update.SystemUpdateService$Receiver
	pm enable com.google.android.gms/.update.SystemUpdateService$SecretCodeReceiver
	pm enable com.google.android.gsf/.update.SystemUpdateActivity
	pm enable com.google.android.gsf/.update.SystemUpdatePanoActivity
	pm enable com.google.android.gsf/.update.SystemUpdateService
	pm enable com.google.android.gsf/.update.SystemUpdateService$Receiver
	pm enable com.google.android.gsf/.update.SystemUpdateService$SecretCodeReceiver

	# user setup automatically sets to 0 after a random reboot
	# thanks to stephen
	pm enable com.google.android.setupwizard/com.google.android.setupwizard.SetupWizardActivity

	if [ "$(settings get secure user_setup_complete)" -ne "1" ]; then
		settings put secure user_setup_complete 1
	fi;

OPEN_RW;

if [ "$stweaks_init_proc_fixer" == "yes" ]; then
	# "init" process battery drain fixer
	# get 5 sample of top processes to seeking for init process
	# credits to xda@magic_doc & xda@justandy32
	if [ ! -e /data/init_proc_fixer ];then
		echo 0 > /data/init_proc_fixer;
	fi;

	if [ "$($BB top -n 10 -d 1 | grep init | wc -l)" -gt "5" ] &&
	   [ "$(cat /data/init_proc_fixer)" -ne "1" ];then
		if [ ! -e /system/bin/dpmd.bak ]; then
			$BB cp /system/bin/dpmd /system/bin/dpmd.bak;
			$BB sed -i '1d' /system/bin/dpmd;
		else
			$BB sed -i '1d' /system/bin/dpmd;
		fi;

		if [ ! -e /vendor/bin/msm_irqbalance.bak ]; then
			$BB cp /vendor/bin/msm_irqbalance /vendor/bin/msm_irqbalance.bak;
			$BB sed -i '1d' /vendor/bin/msm_irqbalance;
		else
			$BB sed -i '1d' /vendor/bin/msm_irqbalance;
		fi;

		echo 1 > /data/init_proc_fixer;
	fi;
fi;

if [ "$stweaks_boot_control" == "no" ]; then
	$BB pkill -f "/gabriel/ext/cortexbrain-tune.sh";
	echo cfq > /sys/block/mmcblk0/queue/scheduler;

	for i in 0 1 2 3; do
		if [ -e /sys/devices/system/cpu/cpu$i/online ];then
			if [ "$(cat /sys/devices/system/cpu/cpu$i/online)" == "1" ];then
				echo 1401000 > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_max_freq
				echo 960000 > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_min_freq
				break
			fi;
		fi;
	done;

	for i in 4 5 6 7; do
		if [ -e /sys/devices/system/cpu/cpu$i/online ];then
			if [ "$(cat /sys/devices/system/cpu/cpu$i/online)" == "1" ];then
				echo 1094400 > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_max_freq
				echo 768000 > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_min_freq
				break
			fi;
		fi;
	done;

	echo "0" > /proc/sys/vm/oom_kill_allocating_task;
	echo "0" > /proc/sys/vm/panic_on_oom;
	echo "30" > /proc/sys/kernel/panic;
	echo "0" > /proc/sys/kernel/panic_on_oops;
fi;

	# script finish here, so let me know when
	TIME_NOW=$(date)
	echo "$TIME_NOW" > /data/.gabriel/boot_log

	$BB mount -o remount,ro /system;

	echo 0 > /cache/boot_state;
)&
