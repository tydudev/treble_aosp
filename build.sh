#!/bin/bash

echo
echo "--------------------------------------"
echo "          AOSP 14.0 Buildbot          "
echo "                  by                  "
echo "                ponces                "
echo "--------------------------------------"
echo

#set -e

BL=$PWD/treble_aosp
BD=$HOME/builds
BV=$1

initRepos() {
    echo "--> Initializing workspace"
    repo init -u https://android.googlesource.com/platform/manifest -b android-14.0.0_r50 --git-lfs
    echo

    echo "--> Preparing local manifest"
    mkdir -p .repo/local_manifests
    cp $BL/build/default.xml .repo/local_manifests/default.xml
    cp $BL/build/remove.xml .repo/local_manifests/remove.xml
    echo
    choice
}

syncRepos() {
    echo "--> Syncing repos"
    repo sync --force-sync -j$(nproc --all) || repo sync --force-sync -j$(nproc --all)
    echo
    choice
}   

applyPatches() {
    echo "--> Applying TrebleDroid patches"
    bash $BL/patch.sh $BL trebledroid
    echo

    echo "--> Applying personal patches"
    bash $BL/patch.sh $BL personal
    echo

    echo "--> Generating makefiles"
    cd device/phh/treble
    cp $BL/build/aosp.mk .
    bash generate.sh aosp
    cd ../../..
    echo
    choice
}

setupEnv() {
    echo "--> Setting up build environment"
    source build/envsetup.sh &>/dev/null
    mkdir -p $BD
    echo
    choice
}

buildTrebleApp() {
    echo "--> Building treble_app"
    cd treble_app
    bash build.sh release
    cp TrebleApp.apk ../vendor/hardware_overlay/TrebleApp/app.apk
    cd ..
    echo
    choice
}

buildVariant() {
    echo "--> Building $1"
    lunch "$1"-ap2a-userdebug
    make -j$(nproc --all) installclean
    make -j$(nproc --all) systemimage
    #make -j$(nproc --all) target-files-package otatools
    #bash $BL/sign.sh "vendor/ponces-priv/keys" $OUT/signed-target_files.zip
    #unzip -jqo $OUT/signed-target_files.zip IMAGES/system.img -d $OUT
    #mv $OUT/system.img $BD/system-"$1".img
    echo
    choice
}

signImage(){
    echo "--> Sign $1"
    . build/envsetup.sh && lunch "$1"-ap2a-userdebug
    echo "----> Set key is needed---->"
    
subject='/C=IT/ST=Catania/L=Bronte/O=Android/OU=Android/CN=Android/emailAddress=salvinoschillaci@gmail.com'
rm -rf ~/.android-certs
mkdir ~/.android-certs
for x in releasekey platform shared media networkstack;
do ./development/tools/make_key ~/.android-certs/$x "$subject";
   done                                                    

    echo "---> make dist <---"
    make dist
    sign_target_files_apks -o --default_key_mappings ~/.android-certs out/dist/*-target_files-*.zip signed-target_files.zip
    echo
    choice
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
   # buildVariant treble_a64_bvN
   # buildVariant treble_a64_bgN
   # buildVariant treble_arm64_bvN
    buildVariant treble_arm64_bgN
   # buildVndkliteVariant treble_a64_bvN
   # buildVndkliteVariant treble_a64_bgN
   # buildVndkliteVariant treble_arm64_bvN
   # buildVndkliteVariant treble_arm64_bgN
}

signImages() {
   # buildVariant treble_a64_bvN
   # buildVariant treble_a64_bgN
   # buildVariant treble_arm64_bvN
    signImage treble_arm64_bgN
   # buildVndkliteVariant treble_a64_bvN
   # buildVndkliteVariant treble_a64_bgN
   # buildVndkliteVariant treble_arm64_bvN
   # buildVndkliteVariant treble_arm64_bgN
}
generatePackages() {
    echo "--> Generating packages"
    buildDate="$(date +%Y%m%d)"
    find $BD/ -name "system-treble_*.img" | while read file; do
        filename="$(basename $file)"
        [[ "$filename" == *"_a64"* ]] && arch="arm32_binder64" || arch="arm64"
        [[ "$filename" == *"_bvN"* ]] && variant="vanilla" || variant="gapps"
        [[ "$filename" == *"-vndklite"* ]] && vndk="-vndklite" || vndk=""
        name="aosp-${arch}-ab-${variant}${vndk}-14.0-$buildDate"
        xz -cv "$file" -T0 > $BD/"$name".img.xz
    done
    rm -rf $BD/system-*.img
    echo
}

generateOta() {
    echo "--> Generating OTA file"
    version="$(date +v%Y.%m.%d)"
    buildDate="$(date +%Y%m%d)"
    timestamp="$START"
    json="{\"version\": \"$version\",\"date\": \"$timestamp\",\"variants\": ["
    find $BD/ -name "aosp-*-14.0-$buildDate.img.xz" | sort | {
        while read file; do
            filename="$(basename $file)"
            [[ "$filename" == *"-arm32"* ]] && arch="a64" || arch="arm64"
            [[ "$filename" == *"-vanilla"* ]] && variant="v" || variant="g"
            [[ "$filename" == *"-vndklite"* ]] && vndk="-vndklite" || vndk=""
            name="treble_${arch}_b${variant}N${vndk}"
            size=$(wc -c $file | awk '{print $1}')
            url="https://github.com/ponces/treble_aosp/releases/download/$version/$filename"
            json="${json} {\"name\": \"$name\",\"size\": \"$size\",\"url\": \"$url\"},"
        done
        json="${json%?}]}"
        echo "$json" | jq . > $BL/config/ota.json
    }
    echo
}

choice() {

    echo -n "Enter choice: "
echo "1. Initializing Repos"
    
echo "2. Syncing Repos"
    
echo "3. Applying patches"
    
echo "4. Setting up build environment"
    
echo "5. Building treble_app"
    
echo "6. Building "$1" "
    
echo "7. Signing "$1" "

read C

case "$C" in
"1") 
    initRepos
    ;;
"2") 
    syncRepos
    ;;
"3") 
    applyPatches
    ;;
"4") 
    setupEnv
    ;;
"5") 
    buildTrebleApp
    ;;
"6") 
    [ ! -z "$BV" ] && buildVariant "$BV" || buildVariants
    ;;
"7") 
    [ ! -z "$BV" ] && signImage "$BV" || signImages
    ;;
esac
}

START=$(date +%s)

choice


END=$(date +%s)
ELAPSEDM=$(($(($END-$START))/60))
ELAPSEDS=$(($(($END-$START))-$ELAPSEDM*60))

echo "--> Buildbot completed in $ELAPSEDM minutes and $ELAPSEDS seconds"
echo
