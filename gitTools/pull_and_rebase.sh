#!/bin/bash

use_interactive=0
rebase_branch_name=""
cur_branch_name=""
should_show_help=0

get_branch_name() {
    cur_branch_name=$(git symbolic-ref HEAD | cut -d/ -f3-)
}

parse_flags() {
    while test $# -gt 0; do
        case "$1" in
            -h|--help) 
                should_show_help=1
                shift
                ;;
            -i|--interactive)
                use_interactive=1
                shift
                ;;
            *)
                rebase_branch_name=$1
                break
                ;;
                
        esac
    done
}

show_help() {
    BOLD_ON="\033[1m"
    BOLD_OFF="\033[0m"

    clear
    echo "${BOLD_ON}Pull & Rebase${BOLD_OFF}"
    echo
    echo "This runs a pull on the branch you want to rebase off of before"
    echo "actually executing the rebase."
    echo
    echo "Run this as 'sh ./pull_and_rebase.sh branch-name' where 'branch-name'"
    echo "is the name of the branch you are rebasing from."
    echo
    echo "'branch-name' defaults to master if not provided"
    echo
    echo
    echo "The different flags that are supported are:"
    echo "  ${BOLD_ON}-i, --interactive${BOLD_OFF}: runs the rebase in interactive mode"
    echo "  ${BOLD_ON}-h, --help${BOLD_OFF}: show this help text"
    echo
    echo "Flags must be specified before the branch name."
    echo
}

check_rebase_branch() {
    if [ -z "$rebase_branch_name" ]; then
        rebase_branch_name="master"
    fi
}

update_rebase_branch() {
    
    git checkout $rebase_branch_name
    if [ $? -ne 0 ]; then
        return $?
    fi
    git pull
    return 0
}

rebase_cur_branch() {
    git checkout $cur_branch_name
    if [ $use_interactive -eq 1 ]; then
        git rebase -i $rebase_branch_name
    else
        git rebase $rebase_branch_name
    fi
}

run_rebase_with_pull() {
    BOLD_ON="\033[1m"
    BOLD_OFF="\033[0m"

    check_rebase_branch
    get_branch_name

    # Status message for the user
    echo "  > rebasing $cur_branch_name from most updated state of $rebase_branch_name"

    # verify that we're not on the same branch that's doing the rebasing
    if [ "$cur_branch_name" = "$rebase_branch_name" ]; then
        echo "  ${BOLD_ON}ERR:${BOLD_OFF} can't rebase from same branch"
        return 1
    fi

    # checkout the other branch and pull down the latest version
    update_rebase_branch
    if [ $? -ne 0 ]; then
        return $?
    fi

    # re-checkout the original branch
    rebase_cur_branch
}


main() {
    parse_flags "$@"

    if [ $should_show_help -eq 1 ]; then
        show_help
    else 
        run_rebase_with_pull
    fi
}

main "$@"