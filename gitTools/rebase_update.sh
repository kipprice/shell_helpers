rebaseFrom=$1

branch_name=""

# get the current branch name
get_branch_name() {
    branch_name=$(git symbolic-ref HEAD | cut -d/ -f3-)
}


main() {
    get_branch_name

    # default to the own branch if not provided
    if [[ -z rebaseFrom ]]; then
        rebaseFrom="origin"
    fi
    
    # check out the most up to date version of the branch
    if [[ rebaseFrom != "origin" ]]; then
        git checkout rebaseFrom && \
        git pull && \
        git checkout branch_name
    fi

    # run the rebase
    git rebase -i $rebaseFrom
    
}

main