#!/bin/sh

# constants for reference
NEW_FEATURE="+ New Feature"

# global vars to be used in the checkin portion of the program
message=""
root_branch=""
feature_branch=""
declare -a options=()


# helpers to show & read info from the user
prompt() { printf "\n$1 "; }
read_input() { read -e in; echo $in; }
bold_on() { echo "\033[1m"; }
bold_off() { echo "\033[0m"; }

# get the current branch name
get_root_branch() {
    root_branch=$(git symbolic-ref HEAD | cut -d/ -f3-)
}

# render a menu to allow selecting additional branches
render_menu() {
    
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
    
    selected=0

    while true; do
        # print options by overwriting the last lines
        local idx=0
        for opt; do
            cursor_to $(($startrow + $idx))

            # hilite the new option differently
            if [ "$opt" = "$NEW_FEATURE" ]; then
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

# @deprecated - now we load branches baesd off of branch name
generate_options_from_file() {
    config=$(cat $PWD/$CONFIG_FILE)
    if [ -z config ]; then
        echo ""
        return 1
    fi

    # get the list of all of the feature branches we have
    fname="$PWD/bgroupbranches.tmp"
    jq --raw-output '.featureBranches' > $fname

    # loop through each branch to build the array
    # this is written with the weird stdin + stdout because
    # read actually spins up its own context
    while read line; do
        options+=( $line )
    done < $fname

    # also add an option for a new branch
    options+=( "$NEW_FEATURE" )

    rm $fname
}

generate_feature_options() {

    # build the list of branches starting with this branch name
    git branch -la --no-color "$root_branch-*" > $PWD/branches.txt

    # loop through each branch to build the array
    # this is written with the weird stdin + stdout because
    # read actually spins up its own 
    local cnt=0
    while read line; do

        # if this is the selected branch, format & save the idx + branch name
        if [[ ${line:0:1} == "*" ]]; then
            line="${line:2}"
            options+=( $line )
        
        # otherwise save the line as is
        else
            options+=( $line )
        fi

    done < $PWD/branches.txt
    rm $PWD/branches.txt

    options+=( "$NEW_FEATURE" )
}

interactive_branch() {
    get_root_branch
    generate_feature_options

    clear
    echo "Which feature branch should this be committed to?"
    render_menu "${options[@]}"
    choice=$?
    value=${options[$choice]}
    if [ "$value" = "$NEW_FEATURE" ]; then
        new_branch
    else
        feature_branch=$value
    fi
}

get_first_commit_in_root() {
    git log --format=%H master -n 1
    # git log master..$root_branch --format=%H | tail -1
}

# generate a new branch for use
new_branch() {

    # get the name if not provided
    bname=$1
    if [ -z $bname ]; then
        printf "\nwhat should the name of the new branch be? $root_branch-"; bname=`read_input`
    fi

    # setup the feature branch name
    feature_branch="$root_branch-$bname"

    # checkout from the first node in the integration branch
    git branch $feature_branch $(get_first_commit_in_root)
}

## BEGIN BROKEN STATE ##
export_broken_state() {
    echo "GRIT_FEATURE_BNAME=$feature_branch \
            GRIT_ROOT_BNAME=$root_branch \
            GRIT_FAILED_AT=$1 \
            GRIT_FAILED_COMMAND=$command \
            GRIT_IS_BROKEN=1" > $PWD/.git/.grit_state
}

get_broken_state() {
    while read x; do
        echo $x
    done < $PWD/.grit_state
}

reset_broken_state() {
    rm $PWD/.grit_state
}
## END BROKEN STATE ##

process_checkin_args() {
    while test $# -gt 0; do

        case "$1" in
            -i) interactive_branch ;;
            -b) new_branch "$2"; shift ;;
            -m) message="$2"; shift ;;
            *)  interactive_branch; break;;
        esac
        shift
    done
}

get_message() {
    if [ -z $message ]; then
        prompt "What message should be associated with the commit?"
        message=$(read_input)
    fi
}

check_feature_branch() {
    if [ -z $feature_branch ]; then
        interactive_branch
    fi

    if [ -z $feature_branch ]; then
        echo "no feature branch"
        return 1
    fi

    return 0
}

prep_checkin() {

    process_checkin_args "$@"

    # ensure we have the other data that we need
    check_feature_branch
    if [ $? -eq 1 ]; then return 1; fi

    get_message
    return 0
}

apply_stash_to_branch() {
    bname=$1
    msg="$2"

    git co $bname
    git stash apply
    if [ $? -ne 0 ]; then return 1; fi

    git add -A
    git ci -m "$msg"
}

checkin() {

    # ensure we've performed the prep we need
    prep_checkin "$@"
    if [ $? -eq 1 ]; then return 1; fi

    echo "==> stashing changes"
    yarn precommit
    # double stash the current set of changes; this will allow
    # us to track the staged vs unstaged changes separately
    git stash -k -u
    git stash
    #read -e pause

    # check in changes to feature branch and root branch
    clear
    echo "\n==> applying changes to $feature_branch"
    apply_stash_to_branch $feature_branch "$message"
    if [ $? -eq 1 ]; then 
        export_broken_state "feature"
        return 1; 
    fi
    #read -e pause

    clear
    echo "\n==> applying changes to $root_branch"
    apply_stash_to_branch $root_branch "$message ($feature_branch)"
    if [ $? -eq 1 ]; then 
        export_broken_state "root"
        return 1; 
    fi
    #read -e pause

    # now apply the other unstaged changes
    clear
    echo "\n==> removing stashed changes"
    git stash drop
    git stash pop
    #read -e pause

    # success
    return 0
}

breakup() {

    # get the name of the root branch to merge off of
    rname=$1
    if [ -z $rname ]; then
        rname=master
    fi

    # clone the current integration branch to not lose data on the real branch
    # get_root_branch
    # git co -b $root_branch---tmp  

    # run the appropriate reset commands
    git reset --soft $rname
    git reset

    return 0
}

breakup_done() {
    return 1
}

# TODO: make this
# given a list of branch names, generate the shared branch for them
# (ideally calculating what that shared branch name is and additionally
#  executing the group init file)
combine() {
    return 1
}

# Rebase is the trickiest of all of the operations. Generally we can tackle
# this in two ways: rebase the integration branch and incorporate those changes 
# into the feature branches, or rebranch the feature branches and then recreate
# the merged integration branch. Each have their share of difficulty if there
# are files adjusted by multiple branches (whether those are internal or external
# branches). 
#
# Some things to watch out for:
#   - handling merge issues between feature branches
#   - handling merge issues between trunk and branches
#   - tracking ordering of commits
#   - tracking which commits correspond between branches
rebase() {
    # check out each feature branch & rebase it to whatever root
    
    # address any merge issues (needs some thoughtful error handling)

    # 
    return 1
}

rebase_feature() {
    return 1
}

main() {
    command=$1
    shift

    case $command in
        # init) init "$1" ;;
        commit|ci) checkin "$@"; break ;;
        breakup|bk) breakup "$@" ;;
        # rebase|rb) rebase "$@"; break ;;
        continue|cont) continue "$@"; break ;;

        # default is to run the git equivalent command
        *) git $command "$@"; break ;;
    esac

}

main "$@"