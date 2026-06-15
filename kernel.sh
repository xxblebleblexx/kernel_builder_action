#CONFIGURATION
kernelsource=https://android.googlesource.com/kernel/manifest # No need to edit
kernelname=Galactic #Must be edited
branch_kernel=common-android15-6.6-lts # Must be edited
defconfig_path=arch/arm64/configs/gki_defconfig # No need to edit
defconfig=gki_defconfig
fast_path=$GITHUB_WORKSPACE/gki # This where kernelsource saved
helper=${branch_kernel#*-}
compile_type=${helper%%-*}

mkdir -p gki
cd $fast_path
#download kernel source from aosp
repo init -u $kernelsource -b $branch_kernel --depth=1 ;wait;repo sync -c -j$(nproc) --no-clone-bundle --no-tags

cd common
#Set name for linux kernel
echo "CONFIG_LOCALVERSION=\"-$kernelname-LTS\"" >> $defconfig_path
echo "CONFIG_LOCALVERSION_AUTO=n" >> $defconfig_path
#KSU DRIVER
curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh" | bash -s stable
#KSU ACTIVATION
echo "CONFIG_KSU=y" >> $defconfig_path
#disable post_defconfig
sed -i 's/POST_DEFCONFIG_CMDS="check_defconfig"/POST_DEFCONFIG_CMDS=""/g' build.config.gki
#disable abi export protection
sed -i 'd' android/abi_gki_protected_exports_aarch64
#Compile
cd ../
if [[ "$compile_type" =~ ^android(13|14|15|16)$ ]]; then
tools/bazel build --config=fast //common:kernel_aarch64_dist
fi

if [ "$compile_type" = "android12" ]; then
LTO=thin BUILD_CONFIG=common/build.config.gki.aarch64 build/build.sh
fi
