# Git Tools
shell scripts that make it a little easier to work with git

## ibranch
interactive view of `git branch -l`, along with tooling to generate a new branch off of the most recent version of master

## branchPush 
if a branch has an existing upstream, this pulls from that stream and then executes the push
if there is no upstream set, this automatically adds `set-upstream origin branchName` to the push command