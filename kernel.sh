#CONFIGURATION
kernelsource=https://github.com/xxblebleblexx/moonbeam_gale_kernel.git # Must be edited
kernelname=$(basename "$kernelsource" .git) # No need to edit
branch_kernel=moonbeam # Must be edited
defconfig_path=arch/arm64/configs/gale_defconfig # Must be edited
defconfig=gale_defconfig # Must be edited
fast_path=$GITHUB_WORKSPACE # This where kernelsource saved
hooks=manual #only manual hook/kprobes hook, must be edited
susfs=y # only 4.19 y/n or u can change another susfs patch

cd $fast_path
git clone -b $branch_kernel --depth=1 $kernelsource;wait
cd $fast_path/$kernelname

#KSU DRIVER
if [ "$susfs" = "n" ]; then
curl -LSs "https://raw.githubusercontent.com/xxblebleblexx/MultiSU/refs/heads/legacy/kernel/setup.sh" | bash -s legacy
fi

if [ "$susfs" = "y" ]; then
curl -LSs "https://raw.githubusercontent.com/xxblebleblexx/MultiSU/refs/heads/legacy/kernel/setup.sh" | bash -s legacy_susfs
fi

#KSU ACTIVATION
echo "CONFIG_KSU=y" >> $defconfig_path

if [ "$hooks" = "kprobes" ]; then
#KPROBES HOOK
echo "CONFIG_KPROBES=y" >> $defconfig_path
echo "CONFIG_KPROBE_EVENTS=y" >> $defconfig_path
echo "CONFIG_KSU_KPROBES_HOOK=y" >> $defconfig_path
fi

if [ "$hooks" = "manual" ]; then
#MANUAL HOOK
echo "CONFIG_KSU_MANUAL_HOOK=y" >> $defconfig_path
wget https://raw.githubusercontent.com/xxblebleblexx/manual_hook_fix/refs/heads/main/manualhook_1.6_fixed.patch;wait;patch -p1 < manualhook_1.6_fixed.patch
fi

if [ "$susfs" = "y" ]; then
wget https://raw.githubusercontent.com/xxblebleblexx/susfs_patch/refs/heads/mainline/susfix-419.patch;wait;patch -p1 < susfix-419.patch
echo "CONFIG_KSU_SUSFS=y" >> $defconfig_path
echo "CONFIG_KSU_SUSFS_SUS_PATH=y" >> $defconfig_path
echo "CONFIG_KSU_SUSFS_SUS_MOUNT=y" >> $defconfig_path
echo "CONFIG_KSU_SUSFS_SUS_KSTAT=y" >> $defconfig_path
echo "CONFIG_KSU_SUSFS_TRY_UMOUNT=n" >> $defconfig_path
echo "CONFIG_KSU_SUSFS_SPOOF_UNAME=y" >> $defconfig_path
echo "CONFIG_KSU_SUSFS_ENABLE_LOG=n" >> $defconfig_path
echo "CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y" >> $defconfig_path
echo "CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y" >> $defconfig_path
echo "CONFIG_KSU_SUSFS_OPEN_REDIRECT=y" >> $defconfig_path
echo "CONFIG_KSU_SUSFS_SUS_MAP=y" >> $defconfig_path
fi

make O=out ARCH=arm64 $defconfig; printf "Y\n2\n\n\n\nY\n" | make -j$(nproc --all) CC=clang O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 LD=ld.lld AS=llvm-as AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf STRIP=llvm-strip CROSS_COMPILE=aarch64-linux-gnu-
