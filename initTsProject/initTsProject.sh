#!/bin/sh
STEP_COUNT=7

# HELPER FUNCTIONS
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
	if [ "$canCreate" -eq "0" ]; then
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


# MAIN FUNCTIONS
createPackage() {
	echo "\n>> create package file [1/$STEP_COUNT]"
	canCreateFile "package.json"
	local canCreate=$?
	if [ "$canCreate" -eq "0" ]; then
		return
	fi

	# GET DETAILS FOR PACKAGE
	prompt "Package name : "; name=`readInput`
	prompt "Description : "; description=`readInput`
	prompt "Output Filename : "; fname=`readInput`
	yn "Is this a library? "; isLibrary=$? 

	if [ "$isLibrary" -eq "1" ]; then
		nameToUse="@kipprice\/$name"
	else
		nameToUse=$name
	fi

	# WRITE PACKAGE CONFIG
	touch package.json
	sed \
		-e "s/\${name}/$nameToUse/" \
		-e "s/\${description}/$description/" \
		-e "s/\${fname}/$fname/" \
		$DIR/package.json.template \
		> package.json
}

installDependencies() { 
	echo "\n>> installing dependencies [2/$STEP_COUNT]"

	local shouldInstall
	if [ -d "node_modules" ]; then
		yn "Reinstall dependencies?"
		shouldInstall=$?
	fi
	
	if [ "$shouldInstall" -eq "0" ]; then
		return
	fi

	rm -rf node_modules

	npm i --save-dev \
	\
	typescript \
	\
	webpack \
	webpack-cli \
	ts-loader \
	terser-webpack-plugin \
	\
	jest \
	jest-cli \
	ts-jest \
	@types/jest
}

createFolders() {
	echo "\n>> creating directories [3/$STEP_COUNT]"
	safeMkdir src
	safeMkdir compiled_js
}

createIndex() {
	echo "\n>> creating entry point [4/$STEP_COUNT]"

	canCreateFile src/index.ts
	local canCreate=$?
	if [ "$canCreate" -eq "0" ]; then
		return
	fi

	echo "\twriting index.ts"
	touch src/index.ts
}

createWebpackConfig() {
	echo "\n>> writing the webpack config [5/$STEP_COUNT]"

	canCreateFile "webpack.config.js"
	local canCreate=$?
	if [ "$canCreate" -eq "0" ]; then
		return
	fi

	local libraryRepl=""
	if [ "$isLibrary" -eq 1 ]; then
		libraryRepl=$"library:'',\
			libraryTarget:'commonjs'"
	fi

	echo "\twriting webpack.config.js"
	touch webpack.config.js
	sed \
		-e "s/\${fname}/$fname/" \
		-e "s/\${library}/$libraryRepl/" \
		$DIR/webpack.config.js.template \
		> webpack.config.js

	return
}

createTsConfig() {
	echo "\n>> writing the typescript config $fname [6/$STEP_COUNT]"
	
	canCreateFile "tsconfig.json"
	local canCreate=$?

	if [ "$canCreate" -eq "0" ]; then
		return
	fi

	echo "\twriting tsconfig.json"
	touch tsconfig.json
	cp $DIR/tsconfig.json.template ./tsconfig.json
	return
}

createJestConfig() {
	echo "\n >> writing the jest config file [7/$STEP_COUNT]"
	npx ts-jest config:init
}

symlinkNodeModules() {
	echo "\n >> symlinking the node modules folder [8/$STEP_COUNT]"

	prompt "Would you like to change the folder name? (default: $name) "
	folderName=`readInput`
	if [ "$folderName" = "" ]; then
		folderName=$name
	fi

	mkdir ~/npm/$folderName
	mv ./node_modules ~/npm/$folderName/node_modules
	ln -s ~/npm/$folderName/node_modules $PWD
}

main() {
	getDirectory
	createPackage
	installDependencies
	createFolders
	createIndex
	createWebpackConfig
	createTsConfig
	createJestConfig
	symlinkNodeModules

	echo "\n>> Done!"
}

main