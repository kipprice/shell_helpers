branch_name=""
current_upstream=""

get_branch_name() {
    branch_name=$(git symbolic-ref HEAD | cut -d/ -f3-)
}

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
    echo $current_upstream
}

# get the current branch name
main() {
    get_branch_name
    get_current_upstream

    # run the appropriate push command
    if [[ ! -z current_upstream ]]; then
        git pull
        git push
    else
        git push --set-upstream=$branch_name
    fi
}

main