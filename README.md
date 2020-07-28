# Shell Helpers
Collection of useful shell scripts. Written for Mac OSX; might work on other OS

## gitTools
Various tools to make git easier to work with Git branches.

### ibranch
An interactive view of the branches that are currently available locally. Run as `sh ./ibranch.sh --help` to see a full list of options within the interactive view.

### new_branch_push
A shortcut to ```git push --set-upstream [upstream branch]``` (or just ```git push``` if there is already an upstream). Pass in the `-o` flag to also open a web browser window to a pull request from the newly pushed branch.

### pull_and_rebase
A shortcut command for performing the following commands:
```
git co [rebase_branch_name]
git pull
git co [local_branch_name]
git rebase [rebase_branch_name]
```

Run as `sh ./pull_and_rebase.sh [-i|--interactive] [-p|--push] [-h|--help] [release_branch_name]`


## initTsProject
Setup script for module-based TS project with jest tests. Supports presets `toolkip` and `react`. This is a very barebones implementation of each project, containing libraries that allow for writing code within the libraries, testing the code, and packing the code.


To setup a new Typescript React-Redux project:
```
sh ./initTsProject.sh react
```

To setup a new Typescript toolkip.ts project:
```
sh ./initTsProject.sh toolkip
```

If a preset is not specified, defaults to `toolkip`
