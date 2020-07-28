#!/bin/sh

# This adds an interactive version of the view rendered by the 
# git branch -l command. You can navigate to an existing branch via the
# arrow keys + return, or you can create a new branch from the latest
# version of the master or develop branch. Currently only handles 
# showing local versions

clear

# declare the globals used by this script
currentBranch=""
currentIdx=-1
rootName=""
mode="c"
escape=false
hasMaster=0
hasDevelop=0
hasMain=0

declare -a options=()

# helpers to show & read info from the user
prompt() { printf "\n$1 "; }
readInput() { read -e in; echo $in; }
createNewPrompt() { echo "+new from $rootName"; }

# Menu taken from Alexander K in this SE post:
# https://unix.stackexchange.com/questions/146570/arrow-key-enter-menu
# 
# Renders a text based list of options that can be selected by the
# user using up, down and enter keys and returns the chosen option.
#
#   Arguments   : 1) index to start selected
#                 2) name of the currently checked out branch      
#                 3) list of options, maximum of 256
#                    "opt1" "opt2" ...
#
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
                         if [[ $key = $ESC[D ]]; then echo escape; fi
                         if [[ $key = ""     ]]; then echo enter; fi;
                        }
                         

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
            escape) escape=true
                    break;;
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
        # order here doesn't matter
        if [ $line = "master" ]; then 
            hasMaster=1
        elif [ "$line" = "main" ]; then
            hasMain=1
        elif [ $line = "develop" ]; then
            hasDevelop=1
        fi

        #gross
        ((cnt=cnt+1))
    done < $PWD/branches.txt


    # additionally add a "new branch" option
    if [ "$mode" = "c" ]; then

        # get the root branch name
        if [ $hasDevelop -eq 1 ]; then
            rootName="develop"
        elif [ $hasMain -eq 1 ]; then
            rootName="main"
        elif [ $hasMaster -eq 1 ]; then
            rootName="master"
        fi

        options+=( "$(createNewPrompt)" )
    fi

    rm $PWD/branches.txt
}

# make sure we are showing the right prompt for the mode
render_prompt() {
    case "${mode}" in
        c) echo "Select the branch you want to switch to" ;;
        d) echo "Select the branch you want to delete" ;;
        n) echo "Select the branch you want to create off of" ;;
        p) echo "Select the branch you want to update" ;;
    esac
}

# show the menu to the user of all of the checked out branches
render_menu() {
    echo "`render_prompt` [Press <- to cancel]:"
    echo

    select_option $currentIdx $currentBranch "${options[@]}"
    choice=$?
    return $choice
}

# handle branching off of an existing branch
new_branch() {
    root=$1

    prompt "Branch name : "; bname=`readInput`

    git co $root --quiet
    git pull
    clear
    git co -b $bname
}

# handle checking out a particular branch
checkout() {
    value=$1
    if [ "$value" = "$currentBranch" ]; then
        echo "already on branch $currentBranch"

    # allow creating a new branch
    elif [ "$value" = "$(createNewPrompt)" ]; then
        new_branch $rootName

    else
        git co $value

    fi
}

# delete the specified branch (while allowing the user to cancel the action)
delete() {
    bname=$1

    if [ "$bname" = "$currentBranch" ]; then
        echo "you can't delete your current branch ($currentBranch)"
        return
    fi

    prompt "Are you sure you want to delete $bname? (Y/N)"; resp=`readInput`
    if [ $resp = "Y" ] || [ $resp = "y" ]; then
        git branch -d --quiet $bname
        if [ $? -ne 0 ]; then
            prompt "delete failed; try to hard delete $bname? (Y/N)"
            resp=`readInput`
            
            if [ $resp = "Y" ] || [ $resp = "y" ]; then
                git branch -D $bname
            fi
        fi
    fi
}

# pull in updates from the specified branch, then recheckout the current branch
pull() {
    bname=$1

    if [ "$bname" != "$currentBranch" ]; then
        git co $bname
    fi

    git pull

    if [ "$bname" != "$currentBranch" ]; then
        git co $currentBranch
    fi

    clear
}

# actually check out the selected branch or show an error if its
# already checked out
execute() {
    if [ $escape = true ]; then
        clear
        echo "Canceled"
        return 0
    fi

    choice=$1
    value=${options[$choice]}
    clear

    # perform the requested action
    case "${mode}" in
        c) checkout "$value" ;;
        d) delete $value ;;
        n) new_branch $value ;;
        p) pull $value ;;
    esac
}

# render the help details if the user requests it
print_help() {
    BOLD_ON="\033[1m"
    BOLD_OFF="\033[0m"

    clear
    echo "${BOLD_ON}Interactive Branch${BOLD_OFF}"
    echo
    echo "This runs an interactive version of the git branch list command. It supports"
    echo "rendering all of the current local branches and running specific commands"
    echo "against it."
    echo
    echo "Run this as sh ./ibranch.sh "
    echo
    echo "The different flags that are supported are:"
    echo
    echo "  ${BOLD_ON}-c, --checkout${BOLD_OFF}: checks out the specified branch [default]"
    echo "  ${BOLD_ON}-n, --new-branch${BOLD_OFF}: creates a new offshoot of the specified branch"
    echo "  ${BOLD_ON}-d, --delete${BOLD_OFF}: locally deletes the specified branch"
    echo "  ${BOLD_ON}-p, --pull${BOLD_OFF}: pulls the most recent version of the specified branch"
    echo
    echo "If you don't specify a flag, this will run in ${BOLD_ON}checkout${BOLD_OFF} mode."
    echo 
    echo "You can cancel this utility's action either through the standard ${BOLD_ON}ctrl+c${BOLD_OFF} or"
    echo "through the ${BOLD_ON}<-${BOLD_OFF} left arrow."
    echo
}

# parse flags to determine what mode this will run in
get_mode() {
    while test $# -gt 0; do
        case "$1" in
            -d|--delete) 
                mode="d" 
                shift
                ;;
            -p|--pull) 
                mode="p" 
                shift
                ;;
            -n|--new-branch) 
                mode="n" 
                shift
                ;;
            
            -h|--help)
                print_help
                mode="h"
                shift
                ;;
            *) 
                break
                ;;
        esac
    done
}

# run the program
main() {
    get_mode "$@"
    if [ $mode = "h" ]; then return; fi

    get_branches
    render_menu
    execute $?
}

main "$@"
