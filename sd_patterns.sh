#!/bin/bash
# bash script for searching patterns that could indicate problems and errors in the extracted Support Dump of a MKE cluster
# Developed by gdoumas@mirantis.com Feb 2021
# Prerequisites : A linux laptop with bash installed, or a windows laptop with Windows Subsystem for Linux , wsl , that provides an Ubuntu inside windows
# TO DO : put more patterns, and maybe remove some if the information they give (matched lines) can be gathered by another pattern
# This script is called by sd_handle.sh(sd_handle.py) , so they must be in the same folder

search_sd() {
	PATTERN_PRINT=false
  for file in $( grep -r -l "$PATTERN" . ) 
  do
		if [ "$PATTERN_PRINT" = false ]; then
			echo -e "\nThe pattern \x1b[31m'$PATTERN'\x1b[0m appears "
			PATTERN_PRINT=true
		fi
    NODE=${file%%/*}
    NUMBER_OF_OCCURENCES=$(grep "$PATTERN" $file | wc -l )
    if [ $NUMBER_OF_OCCURENCES -gt 0 ]; then
			echo -e "\n    \x1b[34m$NUMBER_OF_OCCURENCES times in file\x1b[0m: \x1b[32m$file\x1b[0m and last line:\n"
      LAST_LINE=$(grep  "$PATTERN" $file | tail -1)
      echo -e "        $LAST_LINE"
    fi
  done
	if $PATTERN_PRINT; then
		printf "%`tput cols`s"|sed "s/ /─/g"
	fi
}

#### 'containers with unready status'  ## this produces very long lines, and I am not sure if it is helpful to search for, so I took it out for now
PATTERNS=(
'"level":"fatal"'
'left gossip cluster'
"healthscore:[2-9] (connectivity issues)"
'with result "error:context canceled" took too long '
'has prevented the request from succeeding (get secrets)'
'is in state down: Unhealthy UCP manager: ERROR: RethinkDB Health check timed out'
'is in state down: Awaiting healthy status in classic node inventory - current status: Unhealthy'
'is in state down: heartbeat failure for node in'
'Error from leadership election follower'
'Cluster leadership lost'
"heartbeat to manager .* failed"
'etcd cluster is unavailable or misconfigured'
'Failed to create existing container'
'Failed to load config file'
'Failed to allocate address: Invalid address space'
' error="failed to allocate network IP for task '
'Failed to delegate: Failed to allocate address: No available addresses'
'Failed to start certificate controller: error reading CA cert file'
'unable to query [dD][bB]: rethinkdb'
'unable to create event in database: rethinkdb: Cannot perform write:'
'unable to create job: unable to insert job into db: rethinkdb: Cannot perform write:'
'RethinkDB Health check timed out'
'handshake failed'
"TLS handshake error from [1][^72]"
'failed to complete security handshake from'
'certificate has expired or is not yet valid'
'"OOMKilled":true'
'invoked oom-killer'
'[Cc]onnection refused '
'rejected connection from'
':53: no such host'
'restartCount":"[^01]"'
'dispatcher is stopped'
'No installed keys could decrypt the message'
'unsynchronized systime with swarm'
'OVERLAP on Network'
'no space left on device'
'cannot allocate memory'
'Some RethinkDB data on this server has been placed into swap memory'
)

for PATTERN in "${PATTERNS[@]}"
do
  search_sd
done
grep -r LOG_LEVEL=debug . ## to be sure that no containers of the cluster have been forgotten on a debug level
