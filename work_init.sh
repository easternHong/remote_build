. work.config
if [[ $1 = "-init" ]]; then
    cd $local_workspace
    project_git_url=`git config --get remote.origin.url`
    ssh $remote_ip "cd $remote_workspace_dir;mkdir -p $remote_workspace_dir;git clone $project_git_url $remote_workspace_dir"
    ssh $remote_ip "cd $remote_workspace_dir;git submodule init;git submodule update"
fi
