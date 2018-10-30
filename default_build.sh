#!/bin/bash

LANG=C
green='\033[01;32m'
red='\033[01;31m'
blink_red='\033[05;31m'
restore='\033[0m'

# ST stands for Stweaks while SP is Spectrum
# Location of "toolchains" folder
export TOOLCHAIN_FOLDER=($HOME/toolchains)
export KERNEL_NAME=Gabriel
export KSCHED=HMP
export TWEAKER=ST
export ARCH=arm64
export BUILD_CROSS_COMPILE=$TOOLCHAIN_FOLDER/gcc/bin/aarch64-linux-gnu-
export TS=TOOLSET/
export BUILD_JOB_NUMBER=`grep processor /proc/cpuinfo|wc -l`
export GIT_LOG1=`git log --oneline --decorate -n 1`
export GIT_BRANCH=`git branch | grep \* | cut -d ' ' -f2`
export VER=$(grep Gabriel arch/arm64/configs/gabriel_defconfig | cut -c 31-34)
export DATE=$(date +"[%Y-%m-%d]");

export RDIR=$(readlink -f .)
export OUTDIR=$RDIR/arch/$ARCH/boot
export WD=$RDIR/WORKING-DIR
export RK=$RDIR/READY-KERNEL

KBUILD_LOUP_CFLAGS="-Wno-unknown-warning-option -Wno-sometimes-uninitialized -Wno-vectorizer-no-neon -Wno-pointer-sign -Wno-sometimes-uninitialized -Wno-tautological-constant-out-of-range-compare -Wno-literal-conversion -Wno-enum-conversion -Wno-parentheses-equality -Wno-typedef-redefinition -Wno-constant-logical-operand -Wno-array-bounds -Wno-empty-body -Wno-non-literal-null-conversion -Wno-shift-overflow -Wno-logical-not-parentheses -Wno-strlcpy-strlcat-size -Wno-section -Wno-stringop-truncation -Wno-return-stack-address -mtune=cortex-a53 -march=armv8-a+crc+simd+crypto -mcpu=cortex-a53 -O2"

FUNC_CLEAN_DTB()
{
	make ARCH=$ARCH mrproper;
	make clean;

	rm -f arch/$ARCH/boot/*.dtb
	rm -f arch/$ARCH/boot/*.cmd
	rm -f arch/$ARCH/boot/*.gz

	if [ -d $WD/temp ]; then
		rm -rf $WD/temp/*
	else
		mkdir $WD/temp
	fi;

### cleanup files creted previously
	for i in $(find "$RDIR"/ -name "boot.img"); do
		rm -fv "$i";
	done;
	for i in $(find "$RDIR"/ -name "Image"); do
		rm -fv "$i";
	done;
	for i in $(find "$RDIR"/ -name "dtb.img"); do
		rm -fv "$i";
	done;
	for i in $(find "$RDIR"/ -name "zImage"); do
		rm -fv "$i";
	done;
}

FUNC_ADB()
{
	if [ "$(adb devices | wc -l)" -eq "3" ]; then
		echo -e "${green}"
		adb push $RK/$FILENAME.zip /sdcard/ | grep 100
		echo -e "${restore}"
	fi;
}

FUNC_BUILTIN()
{
sed -i 's/=m/=y/g' arch/$ARCH/configs/$KERNEL_DEFCONFIG

# enable rfkill_input only for aosp builds/p-gsi
sed -i 's/# CONFIG_RFKILL_INPUT is not set/CONFIG_RFKILL_INPUT=y/g' arch/$ARCH/configs/$KERNEL_DEFCONFIG

sed -i 's/CONFIG_LCD_CLASS_DEVICE=y/CONFIG_LCD_CLASS_DEVICE=n/g' arch/$ARCH/configs/$KERNEL_DEFCONFIG
sed -i 's/CONFIG_BACKLIGHT_CLASS_DEVICE=y/CONFIG_BACKLIGHT_CLASS_DEVICE=n/g' arch/$ARCH/configs/$KERNEL_DEFCONFIG

sed -i 's/CONFIG_MSM_RDBG=y/CONFIG_MSM_RDBG=n/g' arch/$ARCH/configs/$KERNEL_DEFCONFIG
}

FUNC_ZIP_NAME()
{
	ZIPFILE=$FILENAME
	if [[ -e $RK/$ZIPFILE.zip ]] ; then
			i=0
		while [[ -e $RK/$ZIPFILE-$i.zip ]] ; do
			let i++
		done
	    FILENAME=$ZIPFILE-$i
	fi
}

FUNC_CLANG_COMM()
{
export CC=$TOOLCHAIN_FOLDER/clang/bin/clang
export CLANG_VERSION=$($CC --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
export CLANG_TRIPLE=aarch64-linux-gnu-
export CLANG_LD_PATH=$TOOLCHAIN_FOLDER/clang/lib
export LLVM_DIS=$TOOLCHAIN_FOLDER/clang/bin/llvm-dis
}

FUNC_DTC_COMM()
{
export CC=$TOOLCHAIN_FOLDER/dragontc/bin/clang
export CLANG_TRIPLE=aarch64-linux-gnu-
export CLANG_LD_PATH=$TOOLCHAIN_FOLDER/dragontc/lib64
export LLVM_DIS=$TOOLCHAIN_FOLDER/dragontc/bin/llvm-dis
}

FUNC_BUILD_KERNEL()
{
	echo "build config: "$KERNEL_DEFCONFIG ""
	echo "git info: "$GIT_LOG1 ""
if [ $CLANG -eq "1" ];then
	echo "compiling with clang"
else
	echo "compiling with gcc"
fi;

	echo -e "\ncleaning..."
	FUNC_CLEAN_DTB | grep :

	echo "generating .config"
	make -j$BUILD_JOB_NUMBER ARCH=$ARCH \
			CROSS_COMPILE=$BUILD_CROSS_COMPILE \
			$KERNEL_DEFCONFIG | grep :

	echo "compiling..."

if [ $CLANG -eq "1" ];then
	LD_LIBRARY_PATH="$CLANG_LD_PATH:$LD_LIBARY_PATH" \
	make -j$BUILD_JOB_NUMBER ARCH=$ARCH \
			CROSS_COMPILE="$BUILD_CROSS_COMPILE" \
			CC="ccache $CC" CLANG_TRIPLE="$CLANG_TRIPLE" \
			KBUILD_COMPILER_STRING="$CLANG_VERSION" \
			LLVM_DIS="$LLVM_DIS" \
			KBUILD_LOUP_CFLAGS="$KBUILD_LOUP_CFLAGS" \
			KCFLAGS="-mllvm -polly \
					-mllvm -polly-run-dce \
					-mllvm -polly-run-inliner \
					-mllvm -polly-opt-fusion=max \
					-mllvm -polly-ast-use-context \
					-mllvm -polly-vectorizer=stripmine \
					-mllvm -polly-detect-keep-going" | grep :
else
	make -j$BUILD_JOB_NUMBER ARCH=$ARCH \
			CROSS_COMPILE=$BUILD_CROSS_COMPILE \
			CC='ccache '${BUILD_CROSS_COMPILE}gcc \
			KBUILD_LOUP_CFLAGS="$KBUILD_LOUP_CFLAGS" | grep :
fi;

if [ "$(grep "=m" .config | wc -l)" -gt 0 ];then
	echo -e "compiling modules..."

if [ $CLANG -eq "1" ];then
	LD_LIBRARY_PATH="$CLANG_LD_PATH:$LD_LIBARY_PATH" \
	make -j$BUILD_JOB_NUMBER ARCH=$ARCH \
			CROSS_COMPILE="$BUILD_CROSS_COMPILE" \
			CC="$CC" CLANG_TRIPLE="$CLANG_TRIPLE" \
			LLVM_DIS="$LLVM_DIS" \
			KBUILD_LOUP_CFLAGS="$KBUILD_LOUP_CFLAGS" \
			KCFLAGS="-mllvm -polly \
					-mllvm -polly-run-dce \
					-mllvm -polly-run-inliner \
					-mllvm -polly-opt-fusion=max \
					-mllvm -polly-ast-use-context \
					-mllvm -polly-vectorizer=stripmine \
					-mllvm -polly-detect-keep-going" \
					modules | grep :
else
	make -j$BUILD_JOB_NUMBER ARCH=$ARCH \
			CROSS_COMPILE=$BUILD_CROSS_COMPILE \
			KBUILD_LOUP_CFLAGS="$KBUILD_LOUP_CFLAGS" \
			modules | grep :
fi;

	if [ -d $WD/package/system/lib/modules ]; then
		rm -rf $WD/package/system/lib/modules/*
	else
		mkdir -p $WD/package/system/lib/modules
	fi;

	find . -name '*ko' ! -path "*.git/*" -exec \cp '{}' $WD/package/system/lib/modules/ \;
	chmod 755 $WD/package/system/lib/modules/*

	# strip not needed debugs from modules.
	"$BUILD_CROSS_COMPILE"strip --strip-unneeded $WD/package/system/lib/modules/* 2>/dev/null
	"$BUILD_CROSS_COMPILE"strip --strip-debug $WD/package/system/lib/modules/* 2>/dev/null

	mkdir -p $WD/package/system/lib/modules/pronto
	mv $WD/package/system/lib/modules/wlan.ko $WD/package/system/lib/modules/pronto/pronto_wlan.ko
fi;

if [ ! -f $RDIR/arch/$ARCH/boot/Image.gz ]; then
	echo -e "${red}"
	echo -e "Kernel STUCK in BUILD! no Image exist !"
	echo -e "${restore}"
	exit 1
fi;
}

FUNC_THERMAL()
{
	local driver="$1";

	if [ "$driver" == "intelli" ]; then
		if [ ! -e $WD/ramdisk/ramdisk/res/customconfig/actions/msm_thermal ]; then
			patch -p1 --ignore-whitespace < patch/intelli_ramdisk.patch
		fi;

		if [ "$(cat drivers/thermal/msm_thermal.c | grep "intelli_enabled" | wc -l)" -eq "0" ]; then
			patch -p1 --ignore-whitespace < patch/intelli_driver.patch
		fi;
	elif [ "$driver" == "stock" ]; then
		if [ -e $WD/ramdisk/ramdisk/res/customconfig/actions/msm_thermal ]; then
			patch -p1 -R --ignore-whitespace < patch/intelli_ramdisk.patch
		fi;

		if [ "$(cat drivers/thermal/msm_thermal.c | grep "intelli_enabled" | wc -l)" -gt "0" ]; then
			patch -p1 -R --ignore-whitespace < patch/intelli_driver.patch
		fi;
	fi;
}

# Export version variable
function evv() {
    FILE=$RDIR/include/generated/compile.h
    export "$(grep "${1}" "${FILE}" | cut -d'"' -f1 | awk '{print $2}')"="$(grep "${1}" "${FILE}" | cut -d'"' -f2)"
}

# Show the version as if looking at "/proc/version"
function parse_version() {
    evv UTS_VERSION
    evv LINUX_COMPILE_BY
    evv LINUX_COMPILE_HOST
    evv LINUX_COMPILER
    VERSION=$(cat $RDIR/include/config/kernel.release)
    echo "Linux version ${VERSION} (${LINUX_COMPILE_BY}@${LINUX_COMPILE_HOST}) (${LINUX_COMPILER}) ${UTS_VERSION}"
}

FUNC_BUILD_RAMDISK_STK()
{
	rm -f $WD/boot.img

	# copy all selected ramdisk files to temp folder
	\cp -r $WD/ramdisk/* $WD/temp
	\cp -r $WD/$MODEL/* $WD/temp/ramdisk

	DTB=$WD/anykernel/treble-unsupported;
	cat $RDIR/arch/$ARCH/boot/Image.gz $DTB/*.dtb > $WD/temp/zImage;
	rm -f $RDIR/arch/$ARCH/boot/Image.gz;

	./$TS/mkboot $WD/temp $WD/boot.img
}

FUNC_BUILD_ZIP_STK()
{
	if [ -d $WD/temp ]; then
		rm -rf $WD/temp/*
	else
		mkdir $WD/temp
	fi;

#	FILENAME=$KERNEL_NAME-$TARGET-$KSCHED-$TWEAKER-$COMPILER-$VER-$DATE
	FILENAME=$KERNEL_NAME-$TARGET-$BRANCH-$DRIVER-$COMPILER-$VER-$DATE
	FUNC_ZIP_NAME

	\cp -r $WD/package/* $WD/temp

	if [ ! -d $WD/temp/boot ]; then
		mkdir $WD/temp/boot/
	fi;
	mv -f $WD/boot.img $WD/temp/boot/boot.img
if [ "$BUILD_PROCESS" = "1" ]; then
	mv -f $RDIR/build.log $WD/temp/build.log
fi;
	\cp $RDIR/.config $WD/temp/kernel_config_view_only
	echo "ROM Target: $TARGET" > $WD/temp/banner
	echo $(parse_version) >> $WD/temp/banner

	cd $WD/temp
	zip -r9 kernel.zip -r * -x README kernel.zip > /dev/null
	cd $RDIR

	java -jar "$TS/zipsigner-2.1.jar" \
	          "$WD/temp/kernel.zip" \
	          "$RK/$FILENAME.zip"
	md5sum $RK/$FILENAME.zip > $RK/$FILENAME.zip.md5

	FUNC_ADB
}

FUNC_BUILD_RAMDISK_ANY()
{
	if [ -d $WD/temp ]; then
		rm -rf $WD/temp/*
	else
		mkdir $WD/temp
	fi;

	# copy all selected ramdisk files to temp folder
	\cp -r $WD/anykernel/* $WD/temp
	if [ ! -d $WD/temp/kernel ]; then
		mkdir -p $WD/temp/kernel
	fi;
	mv -f $RDIR/arch/$ARCH/boot/Image.gz $WD/temp/kernel/Image.gz

	if [ ! -d $WD/temp/ramdisk ]; then
		mkdir -p $WD/temp/ramdisk
	fi;

	\cp -r $WD/ramdisk/ramdisk/* $WD/temp/ramdisk/

if [ "$(grep "=m" .config | wc -l)" -gt 0 ];then
	mkdir -p $WD/temp/modules/pronto/
	\cp -r $WD/package/system/lib/modules/* $WD/temp/modules/
	mv $WD/package/system/lib/modules/pronto/pronto_wlan.ko $WD/temp/modules/pronto/pronto_wlan.ko
fi;
}

FUNC_BUILD_ZIP_ANY()
{
#	FILENAME=$KERNEL_NAME-$TARGET-$KSCHED-$TWEAKER-$COMPILER-$VER-$DATE
	FILENAME=$KERNEL_NAME-$TARGET-$BRANCH-$DRIVER-$COMPILER-$VER-$DATE
	FUNC_ZIP_NAME

if [ "$BUILD_PROCESS" = "1" ]; then
	mv -f $RDIR/build.log $WD/temp/build.log
fi;
	mv -f $RDIR/.config $WD/temp/kernel_config_view_only
	echo "ROM Target: $TARGET" > $WD/temp/banner
	echo $(parse_version) >> $WD/temp/banner

	cd $WD/temp
	zip -r9 kernel.zip -r * -x README kernel.zip > /dev/null
	cd $RDIR

	java -jar "$TS/zipsigner-2.1.jar" \
	          "$WD/temp/kernel.zip" \
	          "$RK/$FILENAME.zip"
	md5sum $RK/$FILENAME.zip > $RK/$FILENAME.zip.md5

	FUNC_ADB
}

if [ $GIT_BRANCH == master-santoni-cpu8998 ]; then
    export BRANCH="CPU8998"
else
    export BRANCH="CPU8940"
fi

FUNC_MULTI_BUILD()
{
	local compiler="$1";
	local target="$2";
	KERNEL_DEFCONFIG=gabriel_defconfig
	RAMDTYPE=ANY

	if [ "$compiler" == "gcc" ]; then
		if [ "$target" == "miui" ]; then
			#gcc
			ccache -c -C
			#miui
			CLANG=0
			COMPILER=GCC
			TARGET=MIUI
			FUNC_BUILD_PROC_INFO
			FUNC_BUILD_KERNEL
			FUNC_BUILD_RAMDISK_$RAMDTYPE
			FUNC_BUILD_ZIP_$RAMDTYPE
			echo "$(parse_version)"
			echo " "
		elif [ "$target" == "aosp" ]; then
			#aosp
			CLANG=0
			COMPILER=GCC
			TARGET=AOSP
			FUNC_BUILTIN
			FUNC_BUILD_PROC_INFO
			FUNC_BUILD_KERNEL
			FUNC_BUILD_RAMDISK_$RAMDTYPE
			FUNC_BUILD_ZIP_$RAMDTYPE
			git checkout arch/$ARCH/configs/$KERNEL_DEFCONFIG
			echo "$(parse_version)"
			echo " "
		fi;
	elif [ "$compiler" == "dtc" ]; then
		if [ "$target" == "miui" ]; then
			#dragontc
			ccache -c -C
			#miui
			CLANG=1
			COMPILER=DTC
			FUNC_DTC_COMM
			TARGET=MIUI
			FUNC_BUILD_PROC_INFO
			FUNC_BUILD_KERNEL
			FUNC_BUILD_RAMDISK_$RAMDTYPE
			FUNC_BUILD_ZIP_$RAMDTYPE
			echo "$(parse_version)"
			echo " "
		elif [ "$target" == "aosp" ]; then
			#aosp
			CLANG=1
			COMPILER=DTC
			FUNC_DTC_COMM
			TARGET=AOSP
			FUNC_BUILTIN
			FUNC_BUILD_PROC_INFO
			FUNC_BUILD_KERNEL
			FUNC_BUILD_RAMDISK_$RAMDTYPE
			FUNC_BUILD_ZIP_$RAMDTYPE
			git checkout arch/$ARCH/configs/$KERNEL_DEFCONFIG
			echo "$(parse_version)"
			echo " "
		fi;
	elif [ "$compiler" == "clang" ]; then
		if [ "$target" == "miui" ]; then
			#clang
			ccache -c -C
			#miui
			CLANG=1
			COMPILER=CLANG
			FUNC_CLANG_COMM
			TARGET=MIUI
			FUNC_BUILD_PROC_INFO
			FUNC_BUILD_KERNEL
			FUNC_BUILD_RAMDISK_$RAMDTYPE
			FUNC_BUILD_ZIP_$RAMDTYPE
			echo "$(parse_version)"
			echo " "
		elif [ "$target" == "aosp" ]; then
			#aosp
			CLANG=1
			COMPILER=CLANG
			FUNC_CLANG_COMM
			TARGET=AOSP
			FUNC_BUILTIN
			FUNC_BUILD_PROC_INFO
			FUNC_BUILD_KERNEL
			FUNC_BUILD_RAMDISK_$RAMDTYPE
			FUNC_BUILD_ZIP_$RAMDTYPE
			git checkout arch/$ARCH/configs/$KERNEL_DEFCONFIG
			echo "$(parse_version)"
			echo " "
		fi;
	fi;
}

FUNC_BUILD_PROC_INFO()
{
echo -e "${blink_red}"
echo "starting build of $TARGET - $COMPILER"
echo -e "${restore}"
}

echo -e "${green}"
echo "----------------"
echo "Build Process ?!";
echo "----------------"
echo -e "${restore}"
select CHOICE in all custom; do
	case "$CHOICE" in
		"all")
			BUILD_PROCESS=0
			break;;
		"custom")
			BUILD_PROCESS=1
			break;;
	esac;
done;

if [ "$BUILD_PROCESS" = "0" ]; then
DATE_START=$(date +"%s")

	DRIVER=INTELLI
	FUNC_THERMAL "intelli";
	FUNC_MULTI_BUILD "gcc" "miui";
	FUNC_MULTI_BUILD "gcc" "aosp";
	FUNC_MULTI_BUILD "dtc" "miui";
	FUNC_MULTI_BUILD "dtc" "aosp";
	FUNC_MULTI_BUILD "clang" "miui";
	FUNC_MULTI_BUILD "clang" "aosp";

	DRIVER=STOCK
	FUNC_THERMAL "stock";
	FUNC_MULTI_BUILD "gcc" "miui";
	FUNC_MULTI_BUILD "gcc" "aosp";
	FUNC_MULTI_BUILD "dtc" "miui";
	FUNC_MULTI_BUILD "dtc" "aosp";
	FUNC_MULTI_BUILD "clang" "miui";
	FUNC_MULTI_BUILD "clang" "aosp";

DATE_END=$(date +"%s")
DIFF=$(($DATE_END - $DATE_START))
echo "Time: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
#end of all build process
else
#start of custom build process
echo -e "${green}"
echo "------------------"
echo "Which Toolchain ?!";
echo "------------------"
echo -e "${restore}"
select CHOICE in gcc clang dragontc; do
	case "$CHOICE" in
		"gcc")
			CLANG=0
			COMPILER=GCC
			break;;
		"clang")
			CLANG=1
			COMPILER=CLANG
			FUNC_CLANG_COMM
			break;;
		"dragontc")
			CLANG=1
			COMPILER=DTC
			FUNC_DTC_COMM
			break;;
	esac;
done;

echo -e "${green}"
echo "----------------"
echo "Which Ramdisk ?!";
echo "----------------"
echo -e "${restore}"
select CHOICE in stock anykernel; do
	case "$CHOICE" in
		"stock")
			RAMDTYPE=STK
			break;;
		"anykernel")
			RAMDTYPE=ANY
			break;;
	esac;
done;

echo -e "${green}"
echo "----------------------"
echo "Which kernel config ?!";
echo "----------------------"
echo -e "${restore}"
select CHOICE in santoni-stock santoni-gabriel; do
	case "$CHOICE" in
		"santoni-stock")
			KERNEL_DEFCONFIG=santoni_defconfig
			break;;
		"santoni-gabriel")
			KERNEL_DEFCONFIG=gabriel_defconfig
			break;;
	esac;
done;

echo -e "${green}"
echo "----------------------"
echo "Modular or Built-in ?!";
echo "----------------------"
echo -e "${restore}"
select CHOICE in module built-in; do
	case "$CHOICE" in
		"module")
			TARGET=MIUI
			break;;
		"built-in")
			TARGET=AOSP
			FUNC_BUILTIN
			break;;
	esac;
done;

echo -e "${green}"
echo "-------------------------"
echo "Intelli-Thermal driver ?!";
echo "-------------------------"
echo -e "${restore}"
select CHOICE in intelli stock; do
	case "$CHOICE" in
		"intelli")
			DRIVER=INTELLI
			FUNC_THERMAL "intelli";
			break;;
		"stock")
			DRIVER=STOCK
			FUNC_THERMAL "stock";
			break;;
	esac;
done;
#end of custom build process
fi;

# MAIN FUNCTION
# Run for custom build process
if [ "$BUILD_PROCESS" = "1" ]; then
rm -rf ./build.log
(
	DATE_START=$(date +"%s")

	FUNC_BUILD_KERNEL
	FUNC_BUILD_RAMDISK_$RAMDTYPE
	FUNC_BUILD_ZIP_$RAMDTYPE

	git checkout arch/$ARCH/configs/$KERNEL_DEFCONFIG
	[[ ${DRIVER} = "INTELLI" ]] && FUNC_THERMAL "stock";

	DATE_END=$(date +"%s")

	echo "$(parse_version)"

	if [ "$(adb devices | wc -l)" -eq "3" ]; then
		echo "" # shown adb pushed file
	else
		echo -e "${green}"
		echo "File Name is: "$FILENAME
		echo -e "${restore}"
	fi;

	DATE_END=$(date +"%s")
	DIFF=$(($DATE_END - $DATE_START))
	echo "Time: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
) 2>&1	| tee -a ./build.log
fi;
