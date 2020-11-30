#!/bin/sh

declare m_Mode="react"
declare m_Name=""
declare m_Description=""
declare m_Filename="index"
declare m_IsLibrary=0
declare m_LibraryName=""
declare m_SubDirectory=""
declare m_IncludeRedux=1
declare m_IncludeEmotion=0

declare -a m_Libraries=()

declare m_CurrentStep=0
declare -r STEP_COUNT=10

declare -r REACT_DIRECTORY="react_templates"
declare -r TOOLKIP_DIRECTORY="toolkip_templates"

declare -r SHARED_DEV_DEPENDENCIES="typescript jest jest-cli ts-jest @types/jest tslint"
declare -r TOOLKIP_DEV_DEPENDENCIES="terser-webpack-plugin"
declare -r WEBPACK_DEV_DEPENDENCIES="webpack@4 webpack-cli webpack-dev-server ts-loader"

declare -r BABEL_DEV_DEPENDENCIES="@babel/core @babel/plugin-proposal-class-properties @babel/plugin-proposal-object-rest-spread @babel/plugin-transform-runtime @babel/preset-env @babel/preset-react @babel/preset-typescript @babel/runtime babel-loader"

declare -r REACT_DEPENDENCIES="react react-dom"
declare -r REACT_DEV_DEPENDENCIES="@types/react @types/react-dom tslint-immutable"

declare -r REDUX_DEPENDENCIES="react-redux redux redux-thunk"
declare -r REDUX_DEV_DEPENDENCIES="@types/redux @types/react-redux"

declare -r CSS_MODULES_DEV_DEPENDENCIES="css-loader style-loader sass sass-loader"
# TODO: support emotion 11 at some point
declare -r EMOTION_DEPENDENCIES="@emotion/core@10 @emotion/styled@10"

declare -r DEFAULT_DIRECTORY="src"
declare -r LIB_DIRECTORY="lib"
declare -r EXAMPLE_DIRECTORY="docs"
declare -r ROOT_DIRECTORY="."

# =======
# HELPERS
# =======
get_directory() {
	DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
}

prompt() {
	printf "\t$1 "
}

readInput() {
	read -r in
	echo $in
}

yn(){
	prompt "$1 [y/n]"
	local input=`readInput`

	if [ "$input" = "y" ]; then
		return 1
	elif [ "$input" =  "Y" ]; then
		return 1
	elif [ "$input" = "yes" ]; then
		return 1
	else
		return 0
	fi
}

canCreateFile() {
	filename=$1

	# if the file doesn't exist, we're good
	if [ ! -f "$filename" ]; then
		return 1
	fi

	# if the file exists, check that we can overwrite
	yn "$filename already exists; would you like to replace it?"
	local canCreate=$?
	if [ "$canCreate" = "0" ]; then
		echo "\t(skipping $filename)"
	else
		return 1
	fi
}

safeMkdir() {
	foldername=$1

	if [ ! -d "$foldername" ]; then
		mkdir -p $foldername
	fi
}

safeCp() {
	from_file="$1"
	to_file="$2"

	canCreateFile "$to_file"
	if [[ "$?" = "0" ]]; then return; fi

	cp "$from_file" "$to_file"
}

step_title() {
	title="$1"
	m_CurrentStep=$(($m_CurrentStep+1))
	echo "\n>> $title [$m_CurrentStep/$STEP_COUNT]"
}

# ===========================
# MODE SPECIFIC FUNCTIONALITY
# ===========================

get_directory_for_mode() {
	if [[ "$m_Mode" = "toolkip" ]]; then
		echo $TOOLKIP_DIRECTORY
	else
		echo $REACT_DIRECTORY
	fi
}

add_dev_dependencies_for_mode() {
	is_lib=$1

	dependencies="$SHARED_DEV_DEPENDENCIES"

	# ==> mode differentiation
	if [[ "$m_Mode" = "toolkip" ]]; then
		dependencies="$dependencies $TOOLKIP_DEV_DEPENDENCIES"
	else
		dependencies="$dependencies $REACT_DEV_DEPENDENCIES $BABEL_DEV_DEPENDENCIES"
	fi

	# ==> library differentiation (libraries don't use webpack)
	if [[ "$is_lib" != "1" ]]; then
		dependencies="$dependencies $WEBPACK_DEV_DEPENDENCIES"
	else 
		dependencies="$dependencies @babel/cli"
	fi

	yarn add --dev $dependencies
}

add_dependencies_for_mode() {
	is_lib=$1

	if [[ "$m_Mode" = "toolkip" ]]; then return; fi

	if [[ "$is_lib" = "1" ]]; then
		echo "adding as peer"
		yarn add --peer $REACT_DEPENDENCIES
		yarn add --dev $REACT_DEPENDENCIES
	else
		yarn add $REACT_DEPENDENCIES
	fi
}

add_state_dependencies() {
	if [ "$m_IncludeRedux" = "1" ]; then
		yarn add $REDUX_DEPENDENCIES
	fi
}

add_state_dev_dependencies() {
	if [ "$m_IncludeRedux" = "1" ]; then
		yarn add $REDUX_DEV_DEPENDENCIES
	fi
}

add_style_dependencies() {
	if [ "$m_IncludeEmotion" = "1" ]; then
		yarn add $EMOTION_DEPENDENCIES
	fi
}

add_style_dev_dependencies() {
	if [ "$m_IncludeEmotion" = "0" ]; then
		yarn add --dev $CSS_MODULES_DEV_DEPENDENCIES
	fi
}

# ==============
# MAIN FUNCTIONS
# ==============

collect_info() {
	step_title "collecting information"

	prompt "Package name : "; m_Name=`readInput`
	prompt "Description : "; m_Description=`readInput`

	if [[ "$m_Mode" = "toolkip" ]]; then
		prompt "Output Filename : "; m_Filename=`readInput`
	fi

	yn "Is this a library? "; m_IsLibrary=$? 

	if [[ "$m_Mode" = "toolkip" ]]; then
		return
	fi

	# TODO: respect this answer
	# yn "Include Redux?"; m_IncludeRedux=$?
	yn "Include Emotion?"; m_IncludeEmotion=$?
}

generate_folders() {
	step_title "generating folders"

	folder_path=$1

	safeMkdir $folder_path
	safeMkdir $folder_path/dist
	safeMkdir $folder_path/node_modules
	safeMkdir $folder_path/typings

	if [[ "$m_IncludeRedux" = "1" ]]; then
		safeMkdir $folder_path/src/models
	fi
}

# =======
# PACKAGE
# =======
create_package() {
	step_title "creating package file"

	folder=$1
	is_lib=$2
	is_example=$3

	name_to_use=$m_Name
	if [[ "$is_example" = "1" ]]; then name_to_use="$m_Name-example"; fi

	package_path="$folder/package.json"

	# ==> verify that we can create this file
	canCreateFile "$package_path"
	local can_create=$?
	if [[ "$can_create" = "0" ]]; then return; fi

	# ==> create the package file
	touch $package_path

	# ==> get the appropriate template
	template_file="package.json.template"
	if [[ "$is_lib" = "1" ]]; then
		template_file="lib.package.json.template"
	fi

	# ==> replace placeholders in the file with the appropriate vars
	sed \
		-e "s/\${name}/$name_to_use/" \
		-e "s/\${description}/$m_Description/" \
		-e "s/\${fname}/$m_Filename/" \
		$DIR/$m_SubDirectory/$template_file \
		> $package_path

}



# =======================
# CREATING THE INDEX FILE
# =======================
create_index_ts() {
	folder=$1

	file_name="index.tsx"
	if [[ "$m_Mode" = "toolkip" ]]; then
		file_name="index.ts"
	fi

	# generate the appropriate index file
	template_file="$file_name.template"
	if [[ "$folder" = "$LIB_DIRECTORY" ]]; then
		template_file="lib.$template_file"
	fi

	# TODO: don't include redux if not necessary
	echo "\n > creating $file_name"
	safeCp "$DIR/$m_SubDirectory/$template_file" "$folder/src/$file_name"
}

create_react_templates() {
	folder=$1
	is_lib=$2
	is_example=$3

	# add the app.tsx file
	echo "\n > creating app.tsx"
	safeCp "$DIR/$m_SubDirectory/app.tsx.template" "$folder/src/App.tsx"

	# add the models/index file
	# TODO: allow for different files based on redux
	echo "\n > creating models folder"
	safeMkdir $folder/src/models
	safeCp "$DIR/$m_SubDirectory/thunk.store.ts.template" "$folder/src/models/index.ts"
}

create_code_templates() {
	step_title "basic templating"

	folder=$1
	is_lib=$2
	is_example=$3

	create_index_ts "$folder"

	# toolkip doesn't need anything beyond this initial file 
	if [[ "$m_Mode" = "toolkip" ]]; then return; fi

	create_react_templates "$@"
}

# ==============
# WEBPACK CONFIG
# ==============
create_webpack_config() {
	step_title "webpack config"

	folder=$1
	is_lib=$2

	if [[ "$is_lib" = "1" ]]; then return; fi

	canCreateFile "$folder/webpack.config.js"
	if [ "$?" = "0" ]; then return; fi

	# set up vars needed by the library file
	local library_repl=""
	local template_file="webpack.config.js.template"
	if [ "$is_lib" = "1" ]; then
		libraryRepl=$"library:'$m_Name',\
			libraryTarget:'umd'"
		template_file="lib.$template_file"
	fi

	# copy the file with replacements
	touch $folder/webpack.config.js
	sed \
		-e "s/\${fname}/$m_Filename/" \
		-e "s/\${library}/$libraryRepl/" \
		$DIR/$m_SubDirectory/$template_file \
		> $folder/webpack.config.js

	return
}

create_babel_config() {
	step_title "babel config"

	if [[ "$m_Mode" != "react" ]]; then return; fi

	folder=$1
	safeCp "$DIR/$m_SubDirectory/.babelrc.template" "$folder/.babelrc"
}

# =========
# TS CONFIG
# =========
create_ts_config() {
	step_title "creating ts config"

	folder=$1
	is_lib=$2

	touch "$folder/tsconfig.json"

	emit_type="noEmit"
	if [[ "$is_lib" = "1" ]]; then
		emit_type="emitDeclarationOnly"
	fi

	sed \
		-e "s/\${emitType}/$emit_type/" \
		"$DIR/$m_SubDirectory/tsconfig.json.template" \
		> "$folder/tsconfig.json"
}

# ===========
# JEST CONFIG
# ===========
create_jest_config() {
	step_title "creating jest config"

	folder=$1
	current_pwd=`pwd`

	cd $folder

	canCreateFile "jest.config.js"
	if [[ "$?" = "1" ]]; then
		npx ts-jest config:init
	fi

	cd $current_pwd
}

# ==========
# INDEX.HTML
# ==========
create_index_html() {
	step_title "creating index.html"

	folder=$1
	is_lib=$2

	if [[ "$is_lib" = "1" ]]; then return; fi

	canCreateFile "$folder/index.html"
	if [ "$?" = "0" ]; then return; fi

	touch $folder/index.html
	sed \
		-e "s/\${name}/$m_Name/" \
		-e "s/\${fname}/$m_Filename/" \
		$DIR/$m_SubDirectory/index.html.template \
		> $folder/index.html
}

# =======
# SYMLINK
# =======

symlink_node_modules() {
	step_title "symlinking various things"

	folder=$1
	is_lib=$2
	is_example=$3

	default_name="$m_Name"
	if [[ "$is_lib" = "1" ]]; then default_name="$default_name/lib"; fi
	if [[ "$is_example" = "1" ]]; then default_name="$default_name/docs"; fi

	echo " > symlinking node_modules from $folder"

	prompt "Would you like to change the folder name? (default: $default_name) "
	home_folder_name=`readInput`
	if [[ "$home_folder_name" = "" ]]; then
		home_folder_name=$default_name
	fi

	# use a helper file for this
	cur_pwd=`pwd`
	cd $folder
	sh $DIR/migrate_folder.sh "$home_folder_name"
	cd $cur_pwd
}

link_library() {
	echo " > linking library"

	if [[ "$m_IsLibrary" != "1" ]]; then
		echo "   (nothing to link)"
		return
	fi
	
	rm -rf $PWD/docs/node_modules/$m_Name
	safeMkdir $PWD/docs/node_modules/$m_Name
	
	ln -sF $PWD/lib/dist $PWD/docs/node_modules/$m_Name/dist
	ln -sF $PWD/lib/typings $PWD/docs/node_modules/$m_Name/typings
	ln -sF $PWD/lib/package.json $PWD/docs/node_modules/$m_Name/package.json
}

# ============
# DEPENDENCIES
# ============
install_dependencies() {
	step_title "installing dependencies"

	folder=$1
	is_lib=$2
	is_example=$3

	current_pwd=`pwd`

	node_modules_path="$folder/node_modules"

	# ==> verify it's worthwhile to reinstall
	local shouldInstall
	if [ -d "$node_modules_path" ]; then
		yn "Reinstall dependencies?"; shouldInstall=$?
	fi
	if [ "$shouldInstall" = "0" ]; then return; fi

	cd $folder

	# ==> delete the existing folders
	rm -rf node_modules

	# ==> add all of the relevant dependencies
	add_dev_dependencies_for_mode $is_lib
	add_dependencies_for_mode $is_lib
	add_style_dev_dependencies $is_lib
	add_style_dependencies $is_lib
	add_state_dev_dependencies $is_lib
	add_state_dependencies $is_lib

	if [[ "$is_example" = "1" ]]; then
		yarn add file:./../lib
	fi

	cd $current_pwd
}

# ===============================
# FUTURE: SUPPORT MULTIPLE PARAMS
# ===============================
get_params() {
	while test $# -gt 0; do
        case "$1" in
            -h|--help)
                print_help
                mode="h"
                shift
                ;;

            *) 
				m_Libraries+=( $1 )
                shift
                ;;
        esac
    done
}

setup_folder() {	
	m_CurrentStep=0
	generate_folders "$@"
	create_package "$@"
	create_code_templates "$@"
	create_webpack_config "$@"
	create_babel_config "$@"
	create_ts_config "$@"
	create_index_html "$@"
	symlink_node_modules "$@"
	install_dependencies "$@"
	create_jest_config "$@"
}

main() {

	# ==> determine if we're running in toolkip or react mode
	if [[ ! -z $1 ]]; then
		m_Mode=$1
	fi

	# set up the directories
	m_SubDirectory=`get_directory_for_mode`
	get_directory
	collect_info

	if [[ "$m_IsLibrary" = "1" ]]; then
		setup_folder $LIB_DIRECTORY 1 0
		setup_folder $EXAMPLE_DIRECTORY 0 1
	else 
		setup_folder "." 0 0
	fi

	link_library

	echo "\n>> Done!"
}

main "$@"