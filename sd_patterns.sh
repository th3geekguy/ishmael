#!/bin/bash
# bash script for searching patterns that could indicate problems and errors in the extracted Support Dump of a MKE cluster
# Developed by gdoumas@mirantis.com during 2021
# Prerequisites : A linux laptop with bash-5 installed, or a windows laptop with Windows Subsystem for Linux , wsl , that provides an Ubuntu inside windows
# TO DO : put more patterns, and maybe remove some if the information they give (matched lines) can be gathered by another pattern
# This script is called by sd_handle.sh(sd_handle.py) , so they must be in the same folder

search_sd() {
	PATTERN_PRINT=false
	for file in $( rgrep -l "$PATTERN" . ) 
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
	'left gossip cluster'
	"healthscore:[2-9] (connectivity issues)"
	'with result "error:context canceled" took too long '
	'unsynchronized systime with swarm'
	'the clock difference against peer .* is too high '
	'has prevented the request from succeeding (get secrets)'
	'level.*error.* Cannot connect to the Docker daemon at tcp:'
	'Error from leadership election follower'
	'Cluster leadership lost'
	"heartbeat to manager .* failed"
	'dispatcher is stopped'
	'cni config uninitialized'
	'level=error msg="periodic bulk sync failure for network '
	": rejected connection from .* tcp "
	"memberlist: Failed fallback ping: read tcp .* read: connection reset by peer"
	"memberlist: Marking .* as failed, suspect timeout reached"
	'but other probes failed, network may be misconfigured'
	' Some RethinkDB data on this server has been placed into swap '
	'is in state down: heartbeat failure for node in'
	'is in state down: Unhealthy UCP manager: ERROR: RethinkDB Health check timed out'
	'is in state down: Awaiting healthy status in classic node inventory - current status: Unhealthy'
	'etcd cluster is unavailable or misconfigured'
	' martian source '
	'Failed to execute iptables-[rs].* segmentation fault'
	'Failed to create existing container'
	'failed to allocate network IP for task '
	'Failed to allocate address: Invalid address space'
	'Failed to delegate: Failed to allocate address: No available addresses'
	'"fatal task error" error="starting container failed: Address already in use"'
	'deleteServiceInfoFromCluster NetworkDB DeleteEntry failed for '
	'Failed to start certificate controller: error reading CA cert file'
	'Failed to load config file'
	'failed to re-resolve dtr-rethinkdb-'
	'unable to query [dD][bB]: rethinkdb'
	'unable to create event in database: rethinkdb: Cannot perform write:'
	'unable to create job: unable to insert job into db: rethinkdb: Cannot perform write:'
	'RethinkDB Health check timed out'
	'failed to complete security handshake from'
	'Err :connection error: desc = "transport: authentication handshake failed: read tcp '
	"http: TLS handshake error from * tls: client didn't provide a certificate"
	"tls: failed to verify client's certificate: x509: certificate has expired or is not yet valid"
	'level=error .* x509: certificate signed by unknown authority'
	'error.* x509: certificate has expired or is not yet valid: current time '
	': rejected connection from .* tls: .* certificate", ServerName '
	': rejected connection from .* tls: .* certificate: x509: certificate has '
	': rejected connection from .* "tls: .* does not match any of DNSNames '
	'"OOMKilled":true'
	'invoked oom-killer'
	'[Cc]onnection refused '
	'HTTP error: Unable to reach primary cluster manager '
	'nfs: server  not responding, still trying'
	':53: no such host'
	'port .* is already in use'
	'bind: address already in use'
	'No installed keys could decrypt the message'
	'[Nn]o space left on device'
	'cannot allocate memory'
	'error detaching from network .*: could not find network attachment for container .* to network '
	'FieldPath:"spec.containers{calico-node}"}, Reason:"Unhealthy", Message:"Liveness probe failed:'
	'FieldPath:"spec.containers{calico-node}"}, Reason:"Unhealthy", Message:"Readiness probe failed:'
	"Unable to route request"
	"Legacy license failure"
	'level=error msg="agent: session failed" backoff=.* error="rpc error: code = Unavailable desc = all SubConns are in TransientFailure'
	'"level":"fatal"'
	'LOG_LEVEL=debug'
	'OVERLAP on Network'
	'net.ipv4.ip_forward = 0'
)

for PATTERN in "${PATTERNS[@]}"
do
	search_sd
done
rgrep -r LOG_LEVEL=debug . ## to be sure that no containers of the cluster have been forgotten on a debug level
