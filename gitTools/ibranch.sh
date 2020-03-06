#!/bin/sh

clear

# declare the globals used by this script
currentBranch=""
currentIdx=-1
rootName=""
declare -a options=()

# helpers to show & read info from the user
prompt() { printf "\n$1 "; }
readInput() { read -e in; echo $in; }
createNewPrompt() { echo "+new from $rootName"; }

# shamelessly stolen from Alexander K in this SO post:
# https://unix.stackexchange.com/questions/146570/arrow-key-enter-menu
# 
# Renders a text based list of options that can be selected by the
# user using up, down and enter keys and returns the chosen option.
#
#   Arguments   : list of options, maximum of 256
#                 "opt1" "opt2" ...
#   Return value: selected index (0 for opt1, 1 for opt2 ...)

select_option() {

    # load in the known parameters before using the rest as an implicit list
    local selected=$1
    local branchName=$2
    shift
    shift
    
    # little helpers for terminal print control and key input
    ESC=$( printf "\033")
    cursor_blink_on()  { printf "$ESC[?25h"; }
    cursor_blink_off() { printf "$ESC[?25l"; }
    cursor_to()        { printf "$ESC[$1;${2:-1}H"; }
    print_option()     { printf "   $1 "; }
    print_selected()   { printf "  $ESC[7m $1 $ESC[27m"; }
    get_cursor_row()   { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
    key_input()        { read -s -n3 key 2>/dev/null >&2
                         if [[ $key = $ESC[A ]]; then echo up;    fi
                         if [[ $key = $ESC[B ]]; then echo down;  fi
                         if [[ $key = ""     ]]; then echo enter; fi; }

    # initially print empty new lines (scroll down if at bottom of screen)
    for opt
    do 
        printf "\n"
    done

    # determine current screen position for overwriting the options
    local lastrow=`get_cursor_row`
    local startrow=$(($lastrow - $#))

    # ensure cursor and input echoing back on upon a ctrl+c during read -s
    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    
    while true; do
        # print options by overwriting the last lines
        local idx=0
        for opt; do
            cursor_to $(($startrow + $idx))

            # kip: add green highlighting to current branch
            if [ "$opt" = "$branchName" ]; then
                opt="\e[32m$opt\e[0m"

            # kip: add teal highlighting to new option
            elif [ "$opt" = "$(createNewPrompt)" ]; then
                opt="\e[36m$opt\e[0m"
            fi

            # hilite if this is the selected line, regular formatting otherwise
            if [ $idx -eq $selected ]; then
                print_selected "$opt"
            else
                print_option "$opt"
            fi
            ((idx++))
        done

        # user key control
        case `key_input` in
            enter) break;;
            up)    ((selected--));
                   if [ $selected -lt 0 ]; then selected=$(($# - 1)); fi;;
            down)  ((selected++));
                   if [ $selected -ge $# ]; then selected=0; fi;;
        esac
    done

    # cursor position back to normal
    cursor_to $lastrow
    printf "\n"
    cursor_blink_on

    return $selected
}

# list all of the branches available in this directory and parse them
# into the array expected by the menu display code
get_branches() {

    # build the list of branches
    git branch -l --no-color > $PWD/branches.txt

    # track the most common root branches so we can add a new option
    local hasMaster=0
    local hasDevelop=0

    # loop through each branch to build the array
    # this is written with the weird stdin + stdout because
    # read actually spins up its own 
    local cnt=0
    while read line; do

        # if this is the selected branch, format & save the idx + branch name
        if [[ ${line:0:1} == "*" ]]; then
            line="${line:2}"
            currentBranch=$line
            currentIdx=$cnt
            options+=( $line )
        
        # otherwise save the line as is
        else
            options+=( $line )
        fi

        # track what the root node is for branch creation
        if [ $line = "master" ]; then 
            hasMaster=1
        elif [ $line = "develop" ]; then
            hasDevelop=1
        fi

        #gross
        ((cnt=cnt+1))
    done < $PWD/branches.txt


    # additionally add a "new branch" option from the appropriate
    # master development branch (usually master or develop)
    if [ $hasDevelop -eq 1 ]; then
        rootName="develop"
        options+=( "$(createNewPrompt)" )
    elif [  $hasMaster -eq 1 ]; then
        rootName="master"
        options+=( "$(createNewPrompt)" )
    fi

    rm $PWD/branches.txt
}

# show the menu to the user of all of the checked out branches
render_menu() {
    echo "Select the branch you want to switch to:"
    echo

    select_option $currentIdx $currentBranch "${options[@]}"
    choice=$?
    return $choice
}



# actually check out the selected branch or show an error if its
# already checked out
checkout() {
    choice=$1
    value=${options[$choice]}

    clear

    # don't switch to the current branch
    if [ "$value" = "$currentBranch" ]; then
        echo "already on branch $currentBranch"

    # allow creating a new branch with the most up to date version of master
    elif [ "$value" = "$(createNewPrompt)" ]; then
        prompt "Branch name : "; bname=`readInput`
        git co $rootName
        git pull
        clear
        git co -b $bname

    else
        git co $value
    fi
}

# run the program
function main {
    get_branches
    render_menu
    checkout $?
}

main