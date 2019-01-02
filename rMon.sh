#!/bin/bash

nodes="10.152.11.170
10.152.11.171"
monScript="./monitor.sh"

idtSuffix="myRead"

nodeinfos=""
nodeinfoFile='./nodeinfo.log'
function startMon(){
    for node in $nodes;do
	echo $node
	tmpdir=`sshpass -p inspur123 ssh $node mktemp -d`
	nName=`sshpass -p inspur123 ssh $node hostname`
	identify="$nName-$idtSuffix"
	sshpass -p inspur123 scp $monScript root@$node:$tmpdir
	sshpass -p inspur123 ssh $node "cd $tmpdir && ./$monScript -ui $identify"

	nodeinfos="$nodeinfos $node,$tmpdir,$identify"
	echo
    done

    echo $nodeinfos > $nodeinfoFile
}

function stopMonGetRet(){
    if ! [ -s $nodeinfoFile ];then
	echo '---nodeinfo null--- exit'
	exit
    fi

    nodeinfos=`cat $nodeinfoFile`
    for node in $nodes;do
	for info in $nodeinfos;do
	    if [ $node == `echo $info | awk 'BEGIN {FS=","} {print $1}'` ];then
		break
	    fi
	done
	tmpdir=`echo $info | awk 'BEGIN {FS=","} {print $2}'`
	identify=`echo $info | awk 'BEGIN {FS=","} {print $3}'`

	#echo $tmpdir
	#echo $identify

	if [ -z "$tmpdir" ];then
	    echo '---warning--- tmpdir'
	    exit
	fi

	sshpass -p inspur123 ssh $node "cd $tmpdir && ./$monScript"
	sshpass -p inspur123 scp -r root@$node:$tmpdir/$identify .
	sshpass -p inspur123 ssh $node "rm -rf $tmpdir"
    done

    rm -f $nodeinfoFile
}

#fio xxx
echo '-----doing-------'

if [ $# -eq 1 ];then
    stopMonGetRet
else
    startMon
fi
