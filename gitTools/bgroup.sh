# constants for reference
CONFIG_FILE=.bgroupconfig
NEW_FEATURE = "+ New Feature"

# global vars to be used in the checkin portion of the program
branch_name=""
message=""
declare -a options=()


# helpers to show & read info from the user
prompt() { printf "\n$1 "; }
read_input() { read -e in; echo $in; }
bold_on() { echo "\033[1m" }
bold_off() { echo "\033[0m" }

# determine the name of the shared branch
get_shared_branch() {
    config=$(cat $PWD/$CONFIG_FILE)
    if [ -z config ]; then
        echo ""
        return 1
    fi
    jq --raw-output '.groupName' | echo $1
    return 0
}


store_shared_branch() {
    $bname=$1
    echo "{ \
            \"groupName\" : \"$bname\", \
            \"featureBranches\" : [] \
          }" > $PWD/$CONFIG_FILE
}

# create the branch grouper and ensure that it's available for later
# for now, this will be a config file within the folder
init() {

    # store the actual branch
    store_shared_branch

    # add in commands to handle general commands
    _bgroup_options='init commit ci breakup br'
    complete -W "${_bgroup_options}" 'bgroup'

    # add to gitignore
    echo $CONFIG_FILE >> ".gitignore"
}

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

generate_options() {
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
    options+=( $NEW_FEATURE )

    rm $fname
}


interactive_branch() {
    generate_options

    echo "Which feature branch should this be committed to? (type <- to exit)"

    select_option "${options[@]}"
    choice=$?
    feature_branch=${options[$choice]}
}

# generate a new branch for use
new_branch() {

    # get the name if not provided
    $bname=$1
    if [ -z $bname ]; then
        prompt "what should the name of the new branch be?"; bname=`read_input`
    fi

    # save into the array: this is where maybe this all should've been in python...
    # TODO: update this

    # setup the feature branch name
    feature_branch=$bname
}

process_checkin_args() {
    while test $# -gt 0; do
        case "$1" in
            -i) interactive_branch ;;
            -b) new_branch "$2"; shift ;;
            -m) $message="$2"; shift ;;
            *)  $feature_branch=$1; break;;
        esac
        shift
    done
}

checkin() {

    process_checkin_args

    # get the shared branch
    $shared_branch=$(get_shared_branch)
    if [ $? -eq 1 ]; then
        echo "no shared branch; run $(bold_on)bgroup init$(bold_off) first"
        return 1
    fi

    # ensure we have the other data that we need
    if [ -z $feature_branch ]; then
        echo "no feature branch"
        return 1
    fi

    if [ -z $message ]; then
        prompt "What message should be associated with the commit?"; $message=`read_input`
    fi

    # stash the current set of changes; this tracks whether
    # something has been added so we don't have to do anything special there
    git stash

    # check out the relevant feature branch and check in the changes there
    git co $feature_branch
    git stash apply
    git ci -m $message

    # check out the shared branch & check in the same changes
    git co $shared_branch
    git stash apply
    git ci -m $message ($feature_branch)

    # drop this stash so we can fall back to the later stash
    git stash drop
}

breakup() {

}

main() {
    command=$1
    shift

    case $command in
        init) init "$@" ;;
        commit|ci) checkin "$@" ;;
        breakup|br) breakup "$@" ;;

        # default is to run the git equivalent command
        *) git $command "$@" ;;
    esac

}

main "$@"