#!bin/bash

do_symlink() {
    local npm_folder="$1"
    local root_folder="$2"

    if [[ -z "$npm_folder" ]]; then
        return 1
    fi
    if [[ -z "$root_folder" ]]; then
        return 2
    fi

    # set a helper variable
    npm_path=~/npm/$npm_folder

    if [[ -L "$root_folder/node_modules" ]]; then
        return 4
    fi 

    echo "symlinking:"
    echo " -- from $npm_path/node_modules"
    echo " -- to $root_folder/node_modules"

    # create the npm folder
    mkdir -p $npm_path/

    # copy over the original node_modules folder, preserving the symlinks, then delete the original
    cp -RP $root_folder/node_modules $npm_path/node_modules
    rm -rf $root_folder/node_modules

    # link the new version to the right folder
    ln -s $npm_path/node_modules $root_folder

    return 0
}

main() {

    # root is the current location
    local root_folder=$PWD

    # first input will be the npm source location
    local npm_folder=$1

    # second input will be the -r flag
    local recursive=0
    if [ "-r" = "$2" ]; then
        recursive=1
    fi

    do_symlink $npm_folder $root_folder

    # recursive loops will be done in the case of lerna, so 
    if [[ recursive -eq 1 ]]; then
        for dir in packages/*/; do
            local folder_name="${dir%"${dir##*[!/]}"}"
            echo ""
            do_symlink "$npm_folder/$folder_name" "$root_folder/$folder_name"
        done
    fi
}

main "$@"



