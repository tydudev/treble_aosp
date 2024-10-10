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

# Set a variable based on user input (choice of true/false)
echo "Do you want to enable signatures? (y/n)"
read -r choice

case "$choice" in
    y|Y|yes|YES)
        Sign=true
        ;;
    n|N|no|NO)
        Sign=false
        ;;
    *)
        echo "Invalid choice! Please enter y or n."
        exit 1
        ;;
esac

# Print the variable to confirm
echo "The variable is set to: $Sign"



initRepos() {
    echo "--> Initializing workspace"
    repo init -u https://android.googlesource.com/platform/manifest -b android-14.0.0_r73 --git-lfs
    echo

    echo "--> Preparing local manifest"
    mkdir -p .repo/local_manifests
    cp $BL/build/default.xml .repo/local_manifests/default.xml
    cp $BL/build/remove.xml .repo/local_manifests/remove.xml
    echo

    echo "Cloning lineage patches"
    git clone https://github.com/tydudev/lineage_patches_unified treble_aosp/patches/lineage_patches_unified -b lineage-21-td
    echo
}

syncRepos() {
    echo "--> Syncing repos"
    repo sync -j6
    echo
}

apply_patches() {
        echo "--> Applying TrebleDroid patches"
    bash $BL/patch.sh $BL trebledroid
    echo

    echo "--> Applying personal patches"
    bash $BL/patch.sh $BL personal
    echo
}

apply_lineage_patches(){
    
    echo -n "Press [ENTER] to continue and apply the lineage patches: "
    read
    echo "Applying patch group ${1}"
    bash ./treble_aosp/apply_patches.sh ./treble_aosp/patches/lineage_patches_unified/${1}

}


prep_treble() {
    :
}

generate_makefiles() {

echo "--> Generating makefiles"
    cd device/phh/treble
    cp $BL/build/aosp.mk .
    bash generate.sh aosp
    cd ../../..
    echo
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

# Function to display the menu
show_menu() {
    echo "================================="
    echo "          MAIN MENU              "
    echo "================================="
    echo "1. Initialize Repos"
    echo "2. Sync Repos"
    echo "3. Apply Patches"
    echo "4. Apply lineage patches"
    echo "5. Generate Makefiles"
    echo "6. Setup Environment"
    echo "7. Build Treble App"
    echo "8. Build Variants"
    echo "9. Exit"
    echo "================================="
}

# Function to read user choice and perform the action
read_choice() {
    local choice
    read -p "Enter your choice [1-8]: " choice
    case $choice in
        1)
            initRepos
            ;;
        2)
            syncRepos
            ;;
        3)
            apply_patches
            ;;

        4)
            prep_treble
    apply_lineage_patches patches_platform
    apply_lineage_patches patches_treble
            ;;
        
        5)
            generate_makefiles
            ;;
        6)
            setupEnv
            ;;
        7)
            buildTrebleApp
            ;;
        8)
            [ ! -z "$BV" ] && buildVariant "$BV" || buildVariants
            ;;
        9)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid choice. Please choose between 1-8."
            ;;
    esac
}

# Main loop to show the menu until the user exits
while true; do
    show_menu
    read_choice
    echo
done

END=$(date +%s)
ELAPSEDM=$(($(($END-$START))/60))
ELAPSEDS=$(($(($END-$START))-$ELAPSEDM*60))

echo "--> Buildbot completed in $ELAPSEDM minutes and $ELAPSEDS seconds"
echo
