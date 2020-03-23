branch_name=""
current_upstream=""
url=""
upstream=""
should_open=0

prompt() { printf "\n$1 "; }
readInput() { read -e in; echo $in; }

# get the current branch name
get_branch_name() {
    branch_name=$(git symbolic-ref HEAD | cut -d/ -f3-)
}

# find out if there is already an upstream
get_current_upstream() {
    str=$(git status -sb)

    IFS='..' # .. is set as delimiter
    read -ra ADDR <<< "$str" # str is read into an array as tokens separated by IFS
    declare -a pieces=()

    for i in "${ADDR[@]}"; do # access each element of array
        pieces+=( $i )
    done

    IFS=' ' # reset to spaces
    current_upstream=${pieces[1]}
}

do_push() {
    upstream=$current_upstream

    # run the appropriate push command
    if [[ ! -z $current_upstream ]]; then
        git push
        url="https://github.com/codecademy-engineering/Codecademy/pull/$branch_name"

    else
        git push --set-upstream origin $branch_name
        upstream="origin/$branch_name"
        url="https://github.com/codecademy-engineering/Codecademy/pull/new/$branch_name"

    fi
}

show_message() {
    BOLD_ON="\033[1m"
    BOLD_OFF="\033[0m"

    echo ""
    printf "Pushed to ${BOLD_ON}$upstream${BOLD_OFF}\n  --> $url\n\n"
}

parse_flag() {
    while test $# -gt 0; do
        case "$1" in
            -o|--open) 
                should_open=1
                shift
                ;;
        esac
    done
}

open_if_applicable() {
    if [[ $should_open -eq 1 ]]; then
        open $url
    fi
}

main() {
    parse_flag "$@"
    get_branch_name
    get_current_upstream
    do_push
    show_message
    open_if_applicable
}

main "$@"