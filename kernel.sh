#CONFIGURATION
kernelsource=https://android.googlesource.com/kernel/common # Must be edited
kernelname=Galactic #Must be edited
branch_kernel=android15-6.6-lts # Must be edited
defconfig_path=arch/arm64/configs/gki_defconfig # No need to edit
defconfig=gki_defconfig
fast_path=$GITHUB_WORKSPACE # This where kernelsource saved

cd $fast_path
git clone -b $branch_kernel --depth=1 $kernelsource $kernelname ;wait
cd $fast_path/$kernelname

#Set name for linux kernel
echo "CONFIG_LOCALVERSION=\"-$kernelname-LTS\"" >> $defconfig_path
echo "CONFIG_LOCALVERSION_AUTO=n" >> $defconfig_path
#KSU DRIVER
curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh" | bash -s stable
#KSU ACTIVATION
echo "CONFIG_KSU=y" >> $defconfig_path
#Compile
make O=out ARCH=arm64 $defconfig; printf "Y\n\n\n\n\n\n3\n\n\n\n" | make -j$(nproc --all) CC=clang O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 LD=ld.lld AS=llvm-as AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf STRIP=llvm-strip CROSS_COMPILE=aarch64-linux-gnu-
