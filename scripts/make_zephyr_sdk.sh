#!/bin/bash
#
# The folder "toolchains" should contain the toolchains and host tools
# This script merges all files into a single installable file.
#
# SDK should follow a vM.m versioning scheme
#
# Major versions for big interface/usage changes
# Minor versions for additions of interfaces, transparent changes
#
# Default installation directory should be $HOME/zephyr-sdk/
#

product_name="zephyr-sdk"

root_dir=$(dirname $0)/..
sdk_version=$(cat $root_dir/VERSION)
arch_list="arm arm64 arc nios2 riscv64 x86_64 xtensa_sample_controller \
           xtensa_intel_apl_adsp xtensa_intel_s1000"

echo "Creating ${product_name}-${sdk_version}-setup.run"

# Create ./setup.sh


default_dir=\${HOME}/${product_name}/
version_dir=info-zephyr-sdk-${sdk_version}

# Identify files present in toolchains folder

parse_toolchain_name()
{
    local varname=$1
    local arch=$2
    local num
    local filename

    if [ -f toolchains/$arch.tar.bz2 ]; then
	filename="$arch.tar.bz2"
    else
        num=$(ls toolchains | grep $arch | wc -l)
        if [ "$num" -gt "1" ]; then
            echo "Error: Multiple toolchains for \"$arch\" "
            exit 1
        fi

        if [ "$num" -eq "0" ]; then
            echo "Warning: Missing toolchain for \"$arch\" "
        fi

        filename=$(ls toolchains | grep $arch)
    fi
    eval "$varname=\$filename"
}

setup_hdr()
{
	local setup=$1
	local toolchain_name=$2

	echo '#!/bin/bash' > $setup
	echo "DEFAULT_INSTALL_DIR=$default_dir" >> $setup
	echo "TOOLCHAIN_NAME=$toolchain_name" >> $setup
	echo "VERSION_DIR=$version_dir" >> $setup
	echo "SDK_VERSION=${sdk_version}" >> $setup

	cat template_dir >>$setup
}

setup_arch()
{
	local setup=$1
	local arch=$2

	var_file_arch=file_gcc_${arch}
	file_gcc_arch=${!var_file_arch}

	if [ -n "$file_gcc_arch" ]; then
	  echo "tar -C \$target_sdk_dir -jxf ./$file_gcc_arch > /dev/null &" >> $setup
	  echo "spinner \$! \"Installing $arch tools...\"" >> $setup
	  echo "[ \$? -ne 0 ] && echo \"Error(s) encountered during installation.\" && exit 1" >>$setup
	  echo "echo \"\"" >>$setup
	fi
}

setup_host()
{
	local setup=$1

	echo "./$file_hosttools -y -d \$target_sdk_dir > /dev/null &" >> $setup
	echo "spinner \$! \"Installing additional host tools...\"" >> $setup
	echo "[ \$? -ne 0 ] && echo \"Error(s) encountered during installation.\" && exit 1" >>$setup
	echo "echo \"\"" >>$setup
}

setup_ftr_common()
{
	local setup=$1
	local label=$2

	echo "" >>$setup
	echo "do_cleanup"  >>$setup
	echo "" >>$setup

	echo "echo \"Success installing $label.\"" >>$setup

	echo "" >>$setup
	echo "do_zephyrrc"  >>$setup
	echo "" >>$setup

	echo "echo \"$label is ready to be used.\"" >>$setup
	chmod 777 $setup
}

setup_ftr_sdk()
{
	setup_ftr_common $1 SDK
}

setup_ftr_toolchain()
{
	setup_ftr_common $1 Toolchain
}

create_toolchain()
{
	local arch=$1
	local setup=toolchains/${arch}/setup.sh
	local toolchain_name=zephyr-toolchain-${arch}-${sdk_version}-setup.run

	var_file_arch=file_gcc_${arch}
	file_gcc_arch=${!var_file_arch}

	if [ -n "$file_gcc_arch" ]; then
		mkdir -p toolchains/${arch}
		ln toolchains/${file_gcc_arch} toolchains/${arch}
		ln toolchains/${file_hosttools} toolchains/${arch}

		setup_hdr $setup $toolchain_name
		setup_arch $setup $arch
		setup_host $setup
		setup_ftr_toolchain $setup

		makeself toolchains/${arch} $toolchain_name "${arch} toolchain for Zephyr" ./setup.sh

		# cleanup
		rm $setup
		rm toolchains/${arch}/${file_gcc_arch}
		rm toolchains/${arch}/${file_hosttools}
		rmdir toolchains/${arch}
	fi
}

create_sdk()
{
	local setup=toolchains/setup.sh
	local toolchain_name=${product_name}-${sdk_version}-setup.run

	setup_hdr $setup $toolchain_name
	for arch in $arch_list; do
		setup_arch $setup $arch
	done

	setup_host $setup
	setup_ftr_sdk $setup

	makeself toolchains/ $toolchain_name  "SDK for Zephyr" ./setup.sh
}

parse_toolchain_name file_gcc_arm arm
parse_toolchain_name file_gcc_arm64 arm64
parse_toolchain_name file_gcc_arc arc
parse_toolchain_name file_gcc_nios2 nios2
parse_toolchain_name file_gcc_riscv64 riscv64
parse_toolchain_name file_gcc_x86_64 x86_64-zephyr-elf
parse_toolchain_name file_gcc_xtensa_sample_controller xtensa_sample_controller
parse_toolchain_name file_gcc_xtensa_intel_apl_adsp xtensa_intel_apl_adsp
parse_toolchain_name file_gcc_xtensa_intel_s1000 xtensa_intel_s1000
parse_toolchain_name file_hosttools hosttools

# Host tools are non-optional
if  [ -z "$file_hosttools" ]; then
  echo "Error: Missing host tools!"
  exit 1
fi

create_sdk

for arch in $arch_list; do
	create_toolchain $arch
done
