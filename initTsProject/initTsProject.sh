#!/bin/sh

declare m_Mode="toolkip"
declare m_Name=""
declare m_Description=""
declare m_Filename=""
declare m_IsLibrary=0
declare m_SubDirectory=""

declare -r STEP_COUNT=7
declare -r REACT_DIRECTORY="react_templates"
declare -r TOOLKIP_DIRECTORY="toolkip_templates"

declare -r SHARED_DEV_DEPENDENCIES="typescript webpack webpack-cli webpack-dev-server ts-loader jest jest-cli ts-jest @types/jest"
declare -r TOOLKIP_DEV_DEPENDENCIES="terser-webpack-plugin"
declare -r REACT_DEV_DEPENDENCIES="@babel/core @babel/plugin-proposal-class-properties @babel/plugin-proposal-object-rest-spread @babel/plugin-transform-runtime @babel/preset-env @babel/preset-react @babel/preset-typescript @babel/runtime babel-loader css-loader style-loader sass sass-loader @types/react @types/react-dom tslint tslint-immutable @types/redux"
declare -r REACT_DEPENDENCIES="react react-dom react-redux redux redux-thunk"

getDirectory() {
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
		mkdir $foldername
	else
		echo "\t($foldername already created)"
	fi
}

# MODE SPECIFIC FUNCTIONALITY
get_directory_for_mode() {
	if [[ "$m_Mode" = "toolkip" ]]; then
		echo $TOOLKIP_DIRECTORY
	else
		echo $REACT_DIRECTORY
	fi
}

get_dev_dependencies_for_mode() {
	if [[ "$m_Mode" = "toolkip" ]]; then
		echo "$SHARED_DEV_DEPENDENCIES $TOOLKIP_DEV_DEPENDENCIES"
	else
		echo "$SHARED_DEV_DEPENDENCIES $REACT_DEV_DEPENDENCIES"
	fi
}

get_dependencies_for_mode() {
	if [[ "$m_Mode" = "toolkip" ]]; then
		echo ""
	else
		echo "$REACT_DEPENDENCIES"
	fi
}

# MAIN FUNCTIONS
createPackage() {

	echo "\n>> create package file [1/$STEP_COUNT]"
	canCreateFile "package.json"
	local canCreate=$?
	if [ "$canCreate" = "0" ]; then
		return
	fi

	# GET DETAILS FOR PACKAGE
	prompt "Package name : "; m_Name=`readInput`
	prompt "Description : "; m_Description=`readInput`
	prompt "Output Filename : "; m_Filename=`readInput`
	yn "Is this a library? "; m_IsLibrary=$? 

	if [ "$m_IsLibrary" = "1" ]; then
		prompt "Library Name (no @) : "; libName=`readInput`
		nameToUse="@$libName\/$m_Name"
	else
		nameToUse=$m_Name
	fi

	touch package.json
	sed \
		-e "s/\${name}/$nameToUse/" \
		-e "s/\${description}/$m_Description/" \
		-e "s/\${fname}/$m_Filename/" \
		$DIR/$m_SubDirectory/package.json.template \
		> package.json
}

installDependencies() { 
	echo "\n>> installing dependencies [2/$STEP_COUNT]"

	local shouldInstall
	if [ -d "node_modules" ]; then
		yn "Reinstall dependencies?"
		shouldInstall=$?
	fi
	
	if [ "$shouldInstall" = "0" ]; then
		return
	fi

	rm -rf node_modules

	# ==> add the development dependencies for the mode
	yarn add --dev `get_dev_dependencies_for_mode`

	# ==> if therere are regular dependencies, install those too
	dependencies="`get_dependencies_for_mode`"
	if [[ ! -z $dependencies ]]; then
		yarn add $dependencies
	fi
}

createFolders() {
	echo "\n>> creating directories [3/$STEP_COUNT]"
	safeMkdir src
	if [[ "$m_Mode" = "react" ]]; then
		safeMkdir src/models
	fi
	safeMkdir dist
}

createIndex() {
	echo "\n>> creating entry point [4/$STEP_COUNT]"

	if [[ "$m_Mode" = "toolkip" ]]; then
		createToolkipIndex
	else
		createReactIndex
	fi
}

createToolkipIndex() {
	canCreateFile src/index.ts
	local canCreate=$?
	if [ "$canCreate" = "0" ]; then
		return
	fi

	echo "\twriting index.ts"
	cp $DIR/$m_SubDirectory/index.ts.template src/index.ts
}

createReactIndex() {

	# index.tsx
	canCreateFile src/index.tsx
	local canCreate=$?
	if [ "$canCreate" = "0" ]; then
		return
	fi

	echo "\twriting index.tsx"
	cp $DIR/$m_SubDirectory/index.tsx.template src/index.tsx

	# App.tsx
	canCreateFile src/App.tsx
	canCreate=$?
	if [ "$canCreate" = "0" ]; then
		return
	fi

	echo "\twriting app.tsx"
	cp $DIR/$m_SubDirectory/app.tsx.template src/App.tsx

	# models/index.ts
	canCreateFile src/models/index.ts
	canCreate=$?
	if [ "$canCreate" = "0" ]; then
		return
	fi

	echo "\twriting models/index.ts"
	cp $DIR/$m_SubDirectory/store.ts.template src/models/index.ts
}

createWebpackConfig() {
	echo "\n>> writing the webpack config [5/$STEP_COUNT]"

	canCreateFile "webpack.config.js"
	local canCreate=$?
	if [ "$canCreate" = "0" ]; then
		return
	fi

	local libraryRepl=""
	if [ "$m_IsLibrary" -eq 1 ]; then
		libraryRepl=$"library:'',\
			libraryTarget:'commonjs'"
	fi

	echo "\twriting webpack.config.js"
	touch webpack.config.js
	sed \
		-e "s/\${fname}/$m_Filename/" \
		-e "s/\${library}/$libraryRepl/" \
		$DIR/$m_SubDirectory/webpack.config.js.template \
		> webpack.config.js

	if [[ "$m_Mode" = "react" ]]; then
		createBabelConfig
	fi

	return
}

createTsConfig() {
	echo "\n>> writing the typescript config $m_Filename [6/$STEP_COUNT]"
	
	canCreateFile "tsconfig.json"
	local canCreate=$?

	if [ "$canCreate" = "0" ]; then
		return
	fi

	echo "\twriting tsconfig.json"
	touch tsconfig.json
	cp $DIR/$m_SubDirectory/tsconfig.json.template ./tsconfig.json
	return
}

createJestConfig() {
	echo "\n >> writing the jest config file [7/$STEP_COUNT]"
	npx ts-jest config:init
}

createBabelConfig() {
	echo "\n >> writing .babelrc"
	cp $DIR/$m_SubDirectory/.babelrc.template ./.babelrc
}

createIndexHtml() {
	echo "\n >> writing index.html"
	canCreateFile "index.html"
	local canCreate=$?

	if [ "$canCreate" = "0" ]; then
		return
	fi

	touch index.html
	sed \
		-e "s/\${name}/$m_Name/" \
		-e "s/\${fname}/$m_Filename/" \
		$DIR/shared_templates/index.html.template \
		> index.html
}

symlinkNodeModules() {
	echo "\n >> symlinking the node modules folder [8/$STEP_COUNT]"

	prompt "Would you like to change the folder name? (default: $m_Name) "
	folderName=`readInput`
	if [ "$folderName" = "" ]; then
		folderName=$m_Name
	fi

	mkdir ~/npm/$folderName
	mv ./node_modules ~/npm/$folderName/node_modules
	ln -s ~/npm/$folderName/node_modules $PWD
}

main() {

	# ==> determine if we're running in toolkip or react mode
	if [[ ! -z $1 ]]; then
		m_Mode=$1
	fi
	m_SubDirectory=`get_directory_for_mode`

	getDirectory
	createPackage
	installDependencies
	createFolders
	createIndex
	createWebpackConfig
	createTsConfig
	createJestConfig
	createIndexHtml
	symlinkNodeModules

	echo "\n>> Done!"
}

main "$@"