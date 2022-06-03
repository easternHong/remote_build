
#!/bin/bash
project_top_level_dir=`git rev-parse --show-toplevel`
remote_build_work_dir=".idea/.remote_build_work_dir"
work_dir=$project_top_level_dir/$remote_build_work_dir
export work_dir

create_patch_fun () {
    git_project_name=`sh -c "git remote get-url origin | xargs basename -s .git"`
    echo "create_patch_fun_start:$git_project_name"
    commit_id=`git rev-parse HEAD`
    branch=`git rev-parse --abbrev-ref HEAD`
    patch_file=$work_dir/$git_project_name.patch
    rm -f $work_dir/$git_project_name.config
    rm -f $patch_file
    echo "commit_id=$commit_id">>$work_dir/$git_project_name.config
    echo "branch=$branch">>$work_dir/$git_project_name.config
    git diff HEAD --binary  >> $patch_file
    echo "create_patch_fun_end:$git_project_name"
    #check patch file valid 
    if [ -s $patch_file ]
    then
        echo "patch file:$patch_file"
    else
        #rm -f $work_dir/$git_project_name.config
        rm -f $patch_file
    fi
}

export -f create_patch_fun

create_patch_fun
git submodule foreach 'create_patch_fun'
