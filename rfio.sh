#!/bin/bash

nodes=""
nodesPwds="
    127.0.0.1,rootroot
"
issues="
    fioT-seqW-1M
    fioT-randW-4k
    fioT-randR-4k
    fioT-seqR-1M
"

monScript="./monitor.sh"
nodeinfos=""
nodeinfoFile='./nodeinfo.log'

SSHPSCP="sshpass -p \$(gotNodePwd \$node) scp"
SSHPSSH="sshpass -p \$(gotNodePwd \$node) ssh"

function doInit() {
    yum install sshpass	    #need epel

    for np in $nodesPwds;do
	n=${np%,*}
	nodes="$nodes $n"
    done

    node=$n
    #echo "--------$SSHPSCP"
}

function gotNodePwd(){
    node=$1
    [ -n $node ] || return
    npMatched=""
    for np in $nodesPwds;do
	if [ $node == `echo $np | awk 'BEGIN {FS=","} {print $1}'` ];then
	    #echo "match node:$node"
	    npMatched=$np
	    break
	fi
    done

    if [ -n $npMatched ];then
	pwd=`echo $npMatched | awk 'BEGIN {FS=","} {print $2}'`
    else
	return
    fi
    echo "$pwd"
}


function saveNodeinfo() {
    node=$1
    info=$2
    echo "do saveNodeinfo for node:$node,info:$info"
    for nodeinfo in $nodeinfos;do
	if [ $node == `echo $nodeinfo | awk 'BEGIN {FS=","} {print $1}'` ];then
	    #echo "match node:$node"
	    infoMatched=$nodeinfo
	    break
	fi
    done

    if [ -n "$infoMatched" ];then
	nodeinfos=`echo $nodeinfos | sed "s#$infoMatched##"`
	info="$infoMatched,$info"
    fi

    nodeinfos="$nodeinfos $info"
    #echo "updated nodeinfos:$nodeinfos---"

    echo "$nodeinfos" > $nodeinfoFile
}

function gotNodeinfos() {
    if [ -z "$nodeinfos" ];then
	if ! [ -s "$nodeinfoFile" ];then
	    exit
	fi
	nodeinfos=`cat $nodeinfoFile`
	#rm -f $nodeinfoFile
    fi
    echo "$nodeinfos"
}

function gotWorkDir(){
    node=$1
    [ -n $node ] || return
    infos=`gotNodeinfos`
    for info in $infos ;do
	if [ $node == `echo $info | awk 'BEGIN {FS=","} {print $1}'` ];then
	    break
	fi
    done

    workDir=`echo $info | awk 'BEGIN {FS=","} {print $2}'`
    echo $workDir
}

function gotIdentify(){
    node=$1
    [ -n $node ] || return
    for info in `gotNodeinfos`;do
	if [ $node == `echo $info | awk 'BEGIN {FS=","} {print $1}'` ];then
	    break
	fi
    done

    identify=${info##*,}
    echo $identify
}

function preMon(){
    for node in $nodes;do
	echo "do preMon for node:$node"
	workDir=`sshpass -p $(gotNodePwd $node) ssh $node mktemp -d`
	#nName=`sshpass -p $(gotNodePwd $node) ssh $node hostname`
	if [ -z $dryRun ];then
	    sshpass -p $(gotNodePwd $node) scp $monScript root@$node:$workDir
	    sshpass -p $(gotNodePwd $node) ssh $node "cd $workDir&&chmod +x ./$monScript"
	    if [ $node != '127.0.0.1' ];then
		sshpass -p $(gotNodePwd $node) ssh $node "echo 1 > /proc/sys/vm/drop_caches"
	    fi
	fi
	info="$node,$workDir"
	saveNodeinfo $node "$info"
    done

    if [ -z $dryRun ];then
	resDir="res-`date +%Y%m%d-%H%M%S`"
	if [ -d $resDir ];then
	    rm -rf $resDir
	fi
	mkdir $resDir
    fi

    echo
}

function startMon(){
    idtSuffix=$1
    [ -n $idtSuffix ] || idtSuffix="myRead"
    for node in $nodes;do
	echo "do startMon for node:$node"
	nName=`sshpass -p $(gotNodePwd $node) ssh $node hostname`
	identify="$nName-$idtSuffix"
	workDir=`gotWorkDir $node`
	if [ -z $dryRun ];then
	    sshpass -p $(gotNodePwd $node) ssh $node "cd $workDir && ./$monScript -ui $identify"
	fi
	saveNodeinfo $node $identify
    done
    echo
}

function stopMonGetRet(){
    for node in $nodes;do
	echo "do stopMonGetRet for node:$node"
	workDir=`gotWorkDir $node`
	identify=`gotIdentify $node`
	#echo "wkdir:$workDir"
	#echo "idt:$identify"

	if [ -z "$workDir" ];then
	    echo '---warning--- workDir'
	    exit
	fi

	if [ -z $dryRun ];then
	    sshpass -p $(gotNodePwd $node) ssh $node "cd $workDir && ./$monScript"
	    sshpass -p $(gotNodePwd $node) scp -r root@$node:$workDir/$identify ./$resDir
	fi
	echo
    done
    echo
}

function postMon() {
    for node in $nodes;do
	echo "do postMon for node:$node"
	workDir=`gotWorkDir $node`
	#echo $workDir

	if [ -z "$workDir" ];then
	    echo '---warning--- workDir'
	    exit
	fi

	if [ -z $dryRun ];then
	    sshpass -p $(gotNodePwd $node) ssh $node "rm -rf $workDir"
	fi
    done
    echo
}

function doClean() {
    for node in $nodes;do
	echo "do doClean for node:$node"
	workDir=`gotWorkDir $node`
	identify=`gotIdentify $node`
	echo "wkdir:$workDir"
	echo "idt:$identify"

	if [ -z "$workDir" ];then
	    echo '---warning--- workDir'
	    exit
	fi

	if [ -z $dryRun ];then
	    sshpass -p $(gotNodePwd $node) ssh $node "cd $workDir && ./$monScript"
	    if [ $? ];then
		sshpass -p $(gotNodePwd $node) ssh $node "rm -rf $workDir"
	    fi
	fi
	echo
    done
    echo
}

function dofio() {
    preMon
    if [ X$optIssue != X ];then
	issues=$optIssue
    fi
    echo "finally issues:$issues"
    for issue in $issues ;do
	if ! [ -s $issue ];then
	    echo "issue file $issue not exist break"
	    break
	fi

	echo "do dofio for issues $issue"
	idtSuffix=${issue#fioT-}
	#echo $idtSuffix
	startMon $idtSuffix
	if [ -z $dryRun ];then
	    res="$resDir/fioL-$idtSuffix"
	    fio $issue --output $res
	    echo
	    cat $res
	    echo "resfile: $res"
	    echo
	fi
	stopMonGetRet
	sleep 1
    done
    postMon
}

dryRun=""
cleanRun=""
optIssue=""
function usage(){
    echo "usage $0 [-t] optIssue/ -c/ -d/ $0"
    echo "-d: dryRun"
    echo "-c: doClean"
    echo "-t: optIssue"
}

function main(){
    while [ $# -gt 0 ]; do
	case "$1" in
	  -h)
	    usage
	    exit
	    ;;
	  -d)
	    dryRun="True"
	    ;;
	  -c)
	    cleanRun="True"
	    ;;
	  -t)
	    optIssue="$2"
	    shift
	    ;;
	  fioT-*)
	    optIssue="$1"
	    ;;
	esac
	shift
    done

    doInit

    if [ -n "$cleanRun" ];then
	doClean
    else
	dofio
    fi
}

main $@
