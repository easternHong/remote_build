#!/bin/bash

Build_Red='\033[0;31m'          # Red
Build_Green='\033[0;32m'        # Green
Build_NC='\033[0m' # No Color

#time
now=$(date +"%T")
time_start=$(date +%s)
time_cost() {
    time_end=$(date +%s)
    log_i "time elapse: $(($time_end-$time_start))s"
}

log_i() {
    printf "${Build_Green}$now:$1${Build_NC}\n"
}

log_e() {
    printf "${Build_Red}$now:$1${Build_NC}\n"
}

print_help(){
    echo ""
    printf "${Green}********build_remote.sh**************************${NC}\n"
    printf "${Green}* Usage:                                        *${NC}\n"
    printf "${Green}* -install|-i: install local apk                *${NC}\n"
    printf "${Green}* -help|-h: print help                          *${NC}\n"
    printf "${Green}* -stop: ./gradlew --stop                       *${NC}\n"
    printf "${Green}* -clean: clean build                           *${NC}\n"
    printf "${Green}* -init: initialize server workspace            *${NC}\n"
    printf "${Green}* -download: download server apk                *${NC}\n"
    printf "${Green}* -q: just do it                                *${NC}\n"
    printf "${Green}* -conf xxx(target config)                      *${NC}\n"
    printf "${Green}********build_remote.sh**************************${NC}\n"
    echo ""
}

rm_file(){
    if test -f "$1"; then
        log_i "remove file $1"
        rm  $1
    else 
        log_e "file not found:"$1    
    fi
}

wait_for_key(){
    if [[ quiet -eq 1 ]]; then
        return 
    fi
    log_e "'q'键退出，其他键继续"
    while : ; do
    read -n 1 k <&1
    if [[ $k = q ]] ; then
        exit -1
    else
        break
    fi
    done
}
remote_build_work_dir='.idea/.android'
work_config_file="work.config"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -t|-target)   target="$2"; shift ;;
        -conf)        work_config_file="$2";. "$2"; shift ;;
        -i|-install)  install=1 ;;
        -h|-help)     print_help; exit 1 ;;
        -stop)        stop=1; ssh $remote_ip "cd $remote_workspace_dir; ./gradlew --stop";;
        -download)    download=1 ;;
        -clean)       clean=1; ssh $remote_ip "cd $remote_workspace_dir; ./gradlew clean";;
        -init)        sh -c "./work_init.sh -init"; exit 1 ;;
        -q)           quiet=1 ;;
        *) echo "Unknown parameter passed: $1";print_help; exit 1 ;;
    esac
    shift
done

if [[ stop -eq 1 ]] || [[ clean -eq 1 ]];then
  exit 1
fi

if test -f "$work_config_file"; then
    #source init_.sh file 
    . $work_config_file
else 
    log_e "work_config_file not found:"
    exit 1
fi

log_i $work_config_file
log_i $local_workspace

if [ -z "$remote_ip" ] || [ -z "$local_workspace" ] || [ -z "$remote_gradle_task" ] || [ -z "$remote_workspace_dir" ]
then
      log_e "$work_config_file file  is empty"
      log_e "remote_ip:$remote_ip"
      log_e "local_workspace:$local_workspace"
      log_e "remote_gradle_task:$remote_gradle_task"
      log_e "remote_workspace_dir:$remote_workspace_dir"
      echo ""
      echo "eg:$work_config_file"
      log_i "remote_ip='172.xx.x.x'"
      log_i "local_workspace='/home/xxx/workspace/project'"
      log_i "remote_gradle_task='installXXXDebug'"
      log_i "remote_workspace_dir='/home/yyy/workspace/project''"
      exit -1 
fi

devices=`adb devices|grep -v devices |awk -F " " '{print $1}'`
if [ -z "$devices" ];then
    log_i "adb not found"
else 
    log_i "target devices:$devices"    
fi

abi=`adb shell am get-config|grep abi|awk -F "abi: " '{print $2}'|awk -F "," '{print $1}'`
if [ -z "$abi" ];then
    abi="armeabi-v7a"
else 
    log_i "abi:$abi"    
fi
take="app/build/outputs/apk/$flavor_name/debug/app-$flavor_name-$abi-debug.apk"
remote_apk_path=$remote_workspace_dir/$take

tmp_apk='tmp.apk'

launch_app(){
    launch_activity=`aapt dump badging $local_workspace/$remote_build_work_dir/$tmp_apk |egrep "launchable-activity|package: name="|awk -F "name='" '{print $2}'|awk -F "'" '{print $1}'`
    echo $launch_activity
    package_name=`echo $launch_activity|awk -F " " '{print $1}'`
    activity_name=`echo $launch_activity|awk -F " " '{print $2}'`
    echo $package_name
    echo $activity_name
    adb shell am start -n "$package_name/$activity_name" -a android.intent.action.MAIN -c android.intent.category.LAUNCHER
}

install_apk(){
    adb install -r $local_workspace/$remote_build_work_dir/$tmp_apk
    launch_app
    time_cost
}
download_apk(){
    cd $local_workspace
    rm_file "$remote_build_work_dir/$tmp_apk"
    scp $remote_ip:$remote_apk_path $remote_build_work_dir/$tmp_apk
}
if [[ install -eq 1 ]]; then
    install_apk
    exit -1
fi
if [[ download -eq 1 ]]; then
    download_apk
    install_apk
    exit -1
fi

#
log_i "local_workspace:$local_workspace/$remote_build_work_dir"
mkdir -p $local_workspace/$remote_build_work_dir
cp apply_patch.sh $local_workspace/$remote_build_work_dir/
cp create_patch.sh $local_workspace/$remote_build_work_dir/
cd $local_workspace


sh -c $remote_build_work_dir/create_patch.sh

local_work_file="local_work_file.tar"
tar cfv $local_work_file --exclude="*.apk" --exclude="*/tmp" $remote_build_work_dir
scp $local_work_file $remote_ip:$remote_workspace_dir
ssh $remote_ip "cd $remote_workspace_dir;rm -rf $remote_build_work_dir;mkdir -p $remote_build_work_dir; tar xvf $local_work_file;rm $local_work_file;chmod +x $remote_build_work_dir/apply_patch.sh;$remote_build_work_dir/apply_patch.sh "
rm_file $local_work_file

#wait for user to conform
contains_patch=`ls $remote_build_work_dir|grep "\.patch"`
if [ -z "$contains_patch" ];then 
    log_i "       "
    log_i "       nothing change!!!"
    log_i "       nothing change!!!"
    log_i "       nothing change!!!"
    log_i "       "
fi

wait_for_key $1

#execute server build/install
#./gradlew $remote_gradle_task;
ssh $remote_ip "cd $remote_workspace_dir;./gradlew $remote_gradle_task"
if [ $? -eq 0 ]; then
    time_cost 
    log_i "server build OK"
else
    log_e "*******BUILD FAIL*******"
    time_cost
    exit -1
fi
ssh $remote_ip "cd $remote_workspace_dir;rm -f out_apk_hash;shasum $remote_apk_path>>out_apk_hash;"


#download apk from server 
if test -f "$remote_build_work_dir/$tmp_apk"; then
    scp  $remote_ip:$remote_workspace_dir/out_apk_hash ./out_apk_hash
    remote_apk_hash=`cat out_apk_hash|awk -F " " '{print $1}'`
    local_apk_hash=`shasum $remote_build_work_dir/$tmp_apk|awk -F " " '{print $1}'`
    if [ $remote_apk_hash = $local_apk_hash ]; then
        log_i "this build has no changes,use local apk"
    else
        log_i remote_apk_hash:$remote_apk_hash
        log_i local_apk_hash :$local_apk_hash
        log_i "download apk from server"
        download_apk
    fi
else
    log_i "local apk not exists, download apk from server"
    download_apk
fi
rm -f out_apk_hash

install_apk
time_cost

#ssh $remote_ip "cd $remote_workspace_dir;./gradlew -q --stop;./gradlew"