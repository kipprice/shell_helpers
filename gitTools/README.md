# Git Tools
shell scripts that make it a little easier to work with git

## ibranch
interactive view of `git branch -l`, along with tooling to generate a new branch off of the most recent version of master

## new_branch_push 
if there is no upstream set, this automatically adds `set-upstream origin branchName` to the push command; otherwise it executes a regular push