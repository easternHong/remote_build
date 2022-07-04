#!/bin/bash
#apply_patch.sh
project_top_level_dir=`git rev-parse --show-toplevel`
remote_build_work_dir=".idea/.android"
work_dir=$project_top_level_dir/$remote_build_work_dir
export work_dir
Build_Red='\033[0;31m'          # Red
Build_Green='\033[0;32m'        # Green
Build_NC='\033[0m' # No Color
export Build_Green
export Build_NC
export Build_Red
printf "${Build_Green}:$1 ${Build_NC}\n"

reset_fun=' 
    git_project_name=`sh -c "git remote get-url origin | xargs basename -s .git"`
    echo ""
    printf "${Build_Green}reset_project_start:$git_project_name ${Build_NC}\n"
    # if $git_project_name.config file exist
    if test -f "$work_dir/$git_project_name.config"; then
        . $work_dir/$git_project_name.config
        echo "branch:$branch"
        git checkout -f $branch
        git clean -d -f
        git pull -X theirs
        git reset --hard $commit_id
        git status
    else 
        printf "${Build_Red}failed:$git_project_name ${Build_NC}\n"
    fi
    printf "${Build_Green}reset_project_end:$git_project_name ${Build_NC}\n"
    echo ""
    '
apply_fun='
    git_project_name=`sh -c "git remote get-url origin | xargs basename -s .git"`
    echo ""
    printf "${Build_Green}apply_patch_fun_start:$git_project_name ${Build_NC}\n"
    patch_file="$work_dir/$git_project_name.patch"
    if test -f $patch_file ; then
        # apply patch
        echo "$patch_file exist" 
        git apply $patch_file
        git status
    else 
        printf "${Build_Red}nothing changed ${Build_NC}\n"
    fi
    printf "${Build_Green}apply_patch_fun_end:$git_project_name ${Build_NC}\n"
    echo ""
'

#reset
sh -c "$reset_fun"
git submodule init
git submodule update
git submodule foreach "$reset_fun"

#apply patch
git submodule foreach "$apply_fun"
sh -c "$apply_fun"