#HEAD_CONFIGURATION
kernelsource=https://android.googlesource.com/kernel/manifest # No need to edit
kernelname=Revolute #Must be edited
branch_kernel=common-android15-6.6 # Must be edited
defconfig_path=arch/arm64/configs/gki_defconfig # No need to edit
defconfig=gki_defconfig # No need to edit
fast_path=$GITHUB_WORKSPACE/gki # This where kernelsource saved
helper=${branch_kernel#*-} # No need to edit
compile_type=${helper%%-*} # No need to edit
#adios
use_adios=n
 #BASEBAND GUARD (vc-teahouse) - LSM that blocks writes to critical partitions/device nodes
use_baseband_guard=y # y/n - set n to build a baseline kernel without it for A/B testing
#DISABLE KMI CHECK
disable_kmi_check=y # y/n - set y to disable KMI strict mode enforcement
#misc
use_misc=n

 #USE OWN SOURCE KERNEL
use_own_kernel=y # y/n 
link_ur_kernel=https://github.com/deryardi73/kernel_common.git #Must be edited
branch_ur_kernel=gki_6.6 #Must be edited

#END_CONFIGURATION

mkdir -p gki
cd $fast_path
#download kernel source from aosp
repo init -u $kernelsource -b $branch_kernel --depth 1 ;wait;repo sync -c -j$(nproc) --no-clone-bundle --no-tags

if [ "$use_own_kernel" = "y" ]; then
rm -rf common
git clone -b $branch_ur_kernel --depth=1 $link_ur_kernel common
fi

cd common

#DISABLE KMI CHECK
if [ "$disable_kmi_check" = "y" ]; then
echo "Disabling KMI strict mode enforcement..."
python3 - <<'PY'
from pathlib import Path
import re

paths = list(Path(".").glob("build.config*")) + list(Path("common").glob("build.config*")) if Path("common").is_dir() else list(Path(".").glob("build.config*"))

for path in paths:
    if not path.is_file():
        continue
    text = path.read_text(encoding="utf-8")
    original = text
    text = re.sub(r'(?m)^KMI_SYMBOL_LIST_STRICT_MODE=.*$', 'KMI_SYMBOL_LIST_STRICT_MODE=', text)
    text = re.sub(r'(?m)^TRIM_NONLISTED_KMI=.*$', 'TRIM_NONLISTED_KMI=', text)
    if text != original:
        path.write_text(text, encoding="utf-8")
        print(f"Modified: {path}")

print("KMI check disabled successfully!")
PY
fi

#KSU DRIVER
curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh" | bash -s stable;wait
#KSU ACTIVATION
echo "CONFIG_KSU=y" >> $defconfig_path
#verification ksu
cat $defconfig_path | grep CONFIG_KSU=y
#adios (pre-fixed patch: GKI 6.6 compatible API, no sed fixups needed)
#adios_gki66.patch must be committed to the root of this repo alongside kernel.sh
if [ "$use_adios" = "y" ]; then
git apply $GITHUB_WORKSPACE/adios_gki66.patch
echo "CONFIG_MQ_IOSCHED_DEFAULT_ADIOS=y" >> $defconfig_path
fi

#misc
if [ "$use_misc" = "y" ]; then
echo "CONFIG_TCP_CONG_ADVANCED=y" >> $defconfig_path
echo "CONFIG_TCP_CONG_BBR=y" >> $defconfig_path
echo "CONFIG_DEFAULT_BBR=y" >> $defconfig_path
echo "CONFIG_DEFAULT_TCP_CONG="bbr"" >> $defconfig_path
echo "CONFIG_THERMAL_DEFAULT_GOV_STEP_WISE=y" >> $defconfig_path
cat $defconfig_path | grep CONFIG_THERMAL_DEFAULT_GOV_STEP_WISE=y
echo "CONFIG_HZ_300=y" >> $defconfig_path
echo "CONFIG_HZ=300" >> $defconfig_path
echo "CONFIG_NET_SCH_DEFAULT=y" >> $defconfig_path
echo "CONFIG_DEFAULT_FQ_CODEL=y" >> $defconfig_path
echo "CONFIG_SCHED_CLUSTER=y" >> $defconfig_path
fi

#baseband guard (vc-teahouse)
if [ "$use_baseband_guard" = "y" ]; then
export GKI_ROOT=$PWD
curl -LSs https://github.com/vc-teahouse/Baseband-guard/raw/main/setup.sh | bash
echo "CONFIG_BBG=y" >> $defconfig_path
#set LSM init order directly in defconfig - this overrides Kconfig's "default" string
#regardless of which DEFAULT_SECURITY_* branch the kernel resolves to, so it's not
#dependent on security/Kconfig's exact wording (see upstream setup.sh's own printed "else:" suggestion)
echo 'CONFIG_LSM="landlock,lockdown,yama,loadpin,safesetid,selinux,smack,tomoyo,apparmor,bpf,baseband_guard"' >> $defconfig_path
#verification bbg
grep CONFIG_BBG=y $defconfig_path
grep CONFIG_LSM= $defconfig_path
fi

if [ "$use_own_kernel" = "n" ]; then
#Set name for linux kernel
echo "CONFIG_LOCALVERSION=\"-$kernelname\"" >> $defconfig_path
fi

echo "CONFIG_TCP_CONG_BIC=n" >> $defconfig_path

echo "CONFIG_LOCALVERSION_AUTO=n" >> $defconfig_path
#disable post_defconfig
sed -i 's/POST_DEFCONFIG_CMDS="check_defconfig"/POST_DEFCONFIG_CMDS=""/g' build.config.gki
#disable abi export protection
sed -i 'd' android/abi_gki_protected_exports_aarch64
#Compile
cd ../

cd $fast_path

case "$compile_type" in
    android13|android14|android15|android16)
        ./tools/bazel build --config=fast //common:kernel_aarch64_dist
        ;;
    android12)
        LTO=thin BUILD_CONFIG=common/build.config.gki.aarch64 build/build.sh
        ;;
esac
