#!/bin/bash
#
# Compile script for Quantum kernel
# Copyright (C) 2020-2021 Adithya R.

cyan="\033[96m"
green="\033[92m"
red="\033[91m"
blue="\033[94m"
yellow="\033[93m"

echo -e "$cyan===========================\033[0m"
echo -e "$cyan= START COMPILING KERNEL  =\033[0m"
echo -e "$cyan===========================\033[0m"

echo -e "$yellow...LOADING...\033[0m"

echo -e -ne "$green## (10%\r"
sleep 0.7
echo -e -ne "$green#####                     (33%)\r"
sleep 0.7
echo -e -ne "$green#############             (66%)\r"
sleep 0.7
echo -e -ne "$green#######################   (100%)\r"
echo -ne "\n"

echo -e -n "$yellow\033[104mPRESS ENTER TO CONTINUE\033[0m"
read P
echo  $P

SECONDS=0 # builtin bash timer

KERNEL="Quantum:[Moon]"
ZIPNAME="Quantum_Moon-kernel-surya-$(date '+%Y%m%d-%H%M').zip"
TC_DIR="/workspace/clang-r498229"
AK3_DIR="$(pwd)/android/AnyKernel3"
DEFCONFIG="surya_defconfig"
DEVICE="Poco X3 NFC (Surya)"
VERSION="4.14.340"
KERNELTYPE="Moon"
CSTRING=$("$TC_DIR"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')

if test -z "$(git rev-parse --show-cdup 2>/dev/null)" &&
   head=$(git rev-parse --verify HEAD 2>/dev/null); then
	ZIPNAME="${ZIPNAME::-4}-$(echo $head | cut -c1-8).zip"
fi

export PATH="$TC_DIR/bin:$PATH"

if ! [ -d "$TC_DIR" ]; then
   echo "Google AOSP Clang not found! Cloning to $TC_DIR..."
   if ! git clone --depth=1 -b 17 https://gitlab.com/ThankYouMario/android_prebuilts_clang-standalone "$TC_DIR"; then
      echo "Cloning failed! Aborting..."
      exit 1
   fi
fi

if [[ $1 = "-r" || $1 = "--regen" ]]; then
	make O=out ARCH=arm64 $DEFCONFIG savedefconfig
	cp out/defconfig arch/arm64/configs/$DEFCONFIG
	echo -e "\nSuccessfully regenerated defconfig at $DEFCONFIG"
	exit
fi

if [[ $1 = "-rf" || $1 = "--regen-full" ]]; then
	make O=out ARCH=arm64 $DEFCONFIG
	cp out/.config arch/arm64/configs/$DEFCONFIG
	echo -e "\nSuccessfully regenerated full defconfig at $DEFCONFIG"
	exit
fi

if [[ $1 = "-c" || $1 = "--clean" ]]; then
	rm -rf out
fi

mkdir -p out
make O=out ARCH=arm64 $DEFCONFIG

echo -e "\nStarting compilation...\n"
make -j$(nproc --all) O=out ARCH=arm64 CC=clang LD=ld.lld AS=llvm-as AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi- LLVM=1 LLVM_IAS=1 Image.gz dtb.img dtbo.img 2> >(tee log.txt >&2) || exit $?

kernel="out/arch/arm64/boot/Image.gz"
dtb="out/arch/arm64/boot/dtb.img"
dtbo="out/arch/arm64/boot/dtbo.img"

if [ -f "$kernel" ] && [ -f "$dtb" ] && [ -f "$dtbo" ]; then
	echo -e "\nKernel compiled succesfully! Zipping up...\n"
	if [ -d "$AK3_DIR" ]; then
		cp -r $AK3_DIR AnyKernel3
	elif ! git clone -q https://github.com/QuantumPrjkt/AnyKernel3.git -b Quantum AnyKernel3; then
		echo -e "\nAnyKernel3 repo not found locally and could not clone from GitHub! Aborting..."
		exit 1
	fi
	cp $kernel $dtb $dtbo AnyKernel3
	rm -rf out/arch/arm64/boot
	cd AnyKernel3
	git checkout Quantum &> /dev/null
	zip -r9 "../$ZIPNAME" * -x .git README.md *placeholder
	cd ..
	rm -rf AnyKernel3
	echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
	echo "Zip: $ZIPNAME"
else
	echo -e "\nCompilation failed!"
	exit 1
fi

# Telegram
CHATID="-1002063590324" # Group/channel chatid (use rose/userbot to get it)
TELEGRAM_TOKEN="6779607065:AAEzVWDTx1OFDE_gQu-FzhrS87rXd68LxSE"

# Export Telegram.sh
TELEGRAM_FOLDER="${HOME}"/telegram
if ! [ -d "${TELEGRAM_FOLDER}" ]; then
    git clone https://github.com/fabianonline/telegram.sh/ "${TELEGRAM_FOLDER}"
fi

TELEGRAM="${TELEGRAM_FOLDER}"/telegram
tg_cast() {
        curl -s -X POST https://api.telegram.org/bot"$TELEGRAM_TOKEN"/sendMessage -d disable_web_page_preview="true" -d chat_id="$CHATID" -d "parse_mode=MARKDOWN" -d text="$(
                for POST in "${@}"; do
                        echo "${POST}"
                done
        )" &> /dev/null
}
tg_ship() {
    "${TELEGRAM}" -f "${ZIPNAME}" -t "${TELEGRAM_TOKEN}" -c "${CHATID}" -H \
    "$(
                for POST in "${@}"; do
                        echo "${POST}"
                done
    )"
}
tg_fail() {
    "${TELEGRAM}" -f "${LOGS}" -t "${TELEGRAM_TOKEN}" -c "${CHATID}" -H \
    "$(
                for POST in "${@}"; do
                        echo "${POST}"
                done
    )"
}

# Ship it to the CI channel
NOW=$(date +%d/%m/%Y-%H:%M)
DATE=$(TZ='Asia/Jakarta' date)
DISTRO=$(source /etc/os-release && echo ${PRETTY_NAME})
LINUX="4.14.340"
    tg_ship "<b>-------- NEW UPDATES --------</b>" \
            "Compiling with <code>$(nproc --all)</code> CPUs" \
	    "------------------------------------" \
	    "<b>Host :</b><code> ${DISTRO}</code>" \
	    "<b>Version :</b><code> ${KERNELTYPE}</code>" \
	    "<b>Linux :</b><code> ${LINUX}</code>" \
	    "<b>Kernel :</b><code> ${KERNEL}</code>" \
            "<b>Device :</b><code> ${DEVICE}</code>" \
	    "<b>Kernel :</b><code> ${KERNEL}</code>" \
	    "<b>Date :</b><code> ${DATE}" \
	    "------------------------------------" \
	    "<b>Changelog :</b> " \
	    " " \
            "<b>Notes :</b> Tell me if encountered any bugs!"
