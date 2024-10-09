#!/bin/bash

echo
echo "--------------------------------------"
echo "          AOSP 14.0 Buildbot          "
echo "                  by                  "
echo "                ponces                "
echo "--------------------------------------"
echo

set -e

BL=$PWD/treble_aosp
BD=$HOME/builds
BV=$1
Sign=true

initRepos() {
    echo "--> Initializing workspace"
    repo init -u https://android.googlesource.com/platform/manifest -b android-14.0.0_r73 --git-lfs
    echo

    echo "--> Preparing local manifest"
    mkdir -p .repo/local_manifests
    cp $BL/build/default.xml .repo/local_manifests/default.xml
    cp $BL/build/remove.xml .repo/local_manifests/remove.xml
    echo
}

syncRepos() {
    echo "--> Syncing repos"
    repo sync -c --force-sync --no-clone-bundle --no-tags -j$(nproc --all) || repo sync -c --force-sync --no-clone-bundle --no-tags -j$(nproc --all)
    echo
}

applyPatches() {
    echo "Applying patch group ${1}"
    bash ./lineage_build_unified/apply_patches.sh ./lineage_patches_unified/${1}
}

setupEnv() {
    echo "--> Setting up build environment"
    source build/envsetup.sh &>/dev/null
    mkdir -p $BD
    echo
}

buildTrebleApp() {
    echo "--> Building treble_app"
    cd treble_app
    bash build.sh release
    cp TrebleApp.apk ../vendor/hardware_overlay/TrebleApp/app.apk
    cd ..
    echo
}

buildVariant() {
   echo "--> Building $1"
    lunch "$1"-ap2a-userdebug
    make -j6 installclean
    make -j6 systemimage
    make -j6 target-files-package otatools
    #bash $BL/sign.sh "vendor/ponces-priv/keys" $OUT/signed-target_files.zip
    if [ "$Sign" = true ]; then
    subject='/C=US/ST=California/L=Mountain View/O=Android/OU=Android/CN=Android/emailAddress=salvinoschillaci@gmail.com'
    mkdir ~/.android-certs
    for x in releasekey sdk_sandbox platform shared media networkstack; do ./development/tools/make_key ~/.android-certs/$x "$subject"; done
    fi
    #make dist
    sign_target_files_apks -o --default_key_mappings ~/.android-certs out/target/product/tdgsi_arm64_ab/obj/PACKAGING/target_files_intermediates/*-target_files*.zip signed-target_files.zip
    unzip -jo signed-target_files.zip IMAGES/system.img -d $BD
    mv $BD/system.img $BD/system-"$1"-tydu-$buildDate.img
    echo
}

buildVndkliteVariant() {
    echo "--> Building $1-vndklite"
    [[ "$1" == *"a64"* ]] && arch="32" || arch="64"
    cd treble_adapter
    sudo bash lite-adapter.sh "$arch" $BD/system-"$1".img
    mv s.img $BD/system-"$1"-vndklite.img
    sudo rm -rf d tmp
    cd ..
    echo
}

buildVariants() {
    #buildVariant treble_a64_bvN
    #buildVariant treble_a64_bgN
    #buildVariant treble_arm64_bvN
    buildVariant treble_arm64_bgN
    #buildVndkliteVariant treble_a64_bvN
    #buildVndkliteVariant treble_a64_bgN
    #buildVndkliteVariant treble_arm64_bvN
    #buildVndkliteVariant treble_arm64_bgN
}

START=$(date +%s)

initRepos
syncRepos
applyPatches
setupEnv
buildTrebleApp
[ ! -z "$BV" ] && buildVariant "$BV" || buildVariants
#generatePackages
#generateOta

END=$(date +%s)
ELAPSEDM=$(($(($END-$START))/60))
ELAPSEDS=$(($(($END-$START))-$ELAPSEDM*60))

echo "--> Buildbot completed in $ELAPSEDM minutes and $ELAPSEDS seconds"
echo
