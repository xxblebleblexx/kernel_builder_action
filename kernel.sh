#CONFIGURATION
kernelsource=https://github.com/xxblebleblexx/moonbeam_gale_kernel.git # Must be edited
kernelname=$(basename "$kernelsource" .git) # No need to edit
branch_kernel=moonbeam # Must be edited
defconfig_path=arch/arm64/configs/gale_defconfig # Must be edited
defconfig=${defconfig_path##*/}
clang_path=/home/runner/work/kernel_builder_action/kernel_builder_action/clang/bin # No need to edit
fast_path=/home/runner/work/kernel_builder_action/kernel_builder_action # This where kernelsource saved
hooks=manual #only manual hook/kprobes hook, must be edited

cd $fast_path
git clone -b $branch_kernel --depth=1 $kernelsource;wait
cd $fast_path/$kernelname

#KSU DRIVER
curl -LSs "https://raw.githubusercontent.com/xxblebleblexx/MultiSU/refs/heads/legacy/kernel/setup.sh" | bash -s legacy

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

export PATH=$clang_path:$PATH

make O=out ARCH=arm64 $defconfig; printf "Y\n2\n\n\n\nY\n" | make -j1 CC=clang O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 LD=ld.lld AS=llvm-as AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf STRIP=llvm-strip CROSS_COMPILE=aarch64-linux-gnu-
