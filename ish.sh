#!/bin/bash

VERBOSE=false
HARDWARE=false

while true; do
	case "$1" in
		-v | --verbose ) VERBOSE=true; shift ;;
		-w | --hardware ) HARDWARE=true; shift ;;
		-c | --clusterid ) CLUSTER_ID=true; shift ;;
		* ) break ;;
	esac
done

JQ=$(jq -C '.[] |
			[(.Description.Hostname // "none"),
				.ID[0:10],
				(if .ManagerStatus.Leader == true then
					"leader"
				else
					.Spec.Role
				end),
				.Spec.Availability,
				.Status.State,
				(if .Status.Addr == "127.0.0.1" or .Status.Addr == "0.0.0.0" then
					(.ManagerStatus.Addr | gsub(":.*"; ""))
				else
					.Status.Addr
				end),
				.Description.Engine.EngineVersion,
				.Spec.Labels."com.docker.ucp.access.label",
				(if .Spec.Labels."com.docker.ucp.orchestrator.swarm" == "true" and
					.Spec.Labels."com.docker.ucp.orchestrator.kubernetes" == "true" then
					"swarm/kube"
				elif .Spec.Labels."com.docker.ucp.orchestrator.swarm" == "true" then
					"swarm"
				elif .Spec.Labels."com.docker.ucp.orchestrator.kubernetes" == "true" then
					"kube"
				else
					"-"
				end),
				(.CreatedAt | (.[0:19] | strptime("%Y-%m-%dT%H:%M:%S") | strftime("%Y-%m-%d"))) + "/" +
				(.UpdatedAt | (.[0:19] | strptime("%Y-%m-%dT%H:%M:%S") | strftime("%Y-%m-%d"))),
				(.Status.Message | gsub(" "; "_"))]
			|@tsv' -r ucp-nodes.txt | sort);

# get OS versions
OS=""
HPVS_OUT=""
for file in $(find . -iname "dsinfo.txt");
do
  DSI=$(grep -m1 "Operating System: " $file |\
    cut -d':' -f2 |\
		xargs |\
		cut -d'(' -f1 |\
		xargs);

  TYPE=$(grep -m1 "^NAME=" $file |\
    cut -d'=' -f2 |\
    xargs |\
		sed 's/Red.*/RHEL/');

  VERSION=$(grep -m1 "^VERSION=" $file |\
    cut -d'=' -f2 |\
    xargs |\
    cut -d'(' -f1 |\
    xargs);

  HOSTNAME=$(echo $file |\
    cut -d'/' -f2);

	HPVS=$(grep -m1 "Hypervisor vendor: " $file |\
		cut -d':' -f2 |\
		xargs);

  OS=$(echo -e "$OS\n$HOSTNAME\t$TYPE-${VERSION}/$DSI" |\
		sed 's/Red Hat Enterprise Linux/RHEL/g; s/ /_/g' | sort);
  HPVS_OUT=$(echo -e "$HPVS_OUT\n$HOSTNAME\t$HPVS" | sort | awk NF);
done

# build output with jq output and OS info
INTERIM=$(join <(echo "$JQ") <(echo "$OS") -a1 -e"-----/NoInfo" -o'1.1 1.2 1.3 2.2 1.4 1.5 1.6 1.7 1.8 1.9 1.10 1.11');

# add HPVS
INTERIM=$(join <(echo "$INTERIM") <(echo "$HPVS_OUT") -a1 -e"None" -o'1.1 1.2 1.3 1.4 2.2 1.5 1.6 1.7 1.8 1.9 1.10 1.11 1.12');

# get MKE versions
MKE_OUT="";
for file in $(find . -iname "ucp-proxy.txt");
do
  MKE=$(jq -r '.[].Config.Env[] | select(startswith("IMAGE_VERSION"))' $file |\
    cut -d'=' -f2);

  HOSTNAME=$(echo $file |\
    cut -d'/' -f2);

	MKE_OUT=$(echo -e "$MKE_OUT\n$HOSTNAME\t$MKE" | sort | awk NF);
done

# get MSR versions
MSR_OUT="";
for file in $(find . -iname "dtr-registry-*.txt");
do
  MSR=$(jq -r '.[].Config.Env[] | select(startswith("DTR_VERSION"))' $file |\
    cut -d'=' -f2);

  HOSTNAME=$(echo $file |\
    cut -d'/' -f2);

	MSR_OUT=$(echo -e "$MSR_OUT\n$HOSTNAME\t$MSR\tMSR" | sort | awk NF);
done

# build MKE/MSR text string
DDC=$(join <(echo -e "$MKE_OUT") <(echo -e "$MSR_OUT") -a1 -e'-' -o'1.1 1.2 2.2' | awk '{ print $1"\t"$2"/"$3 }');

# build output with jq, OS, and DDC
BODY=$(join <(echo -e "$INTERIM") <(echo -e "$DDC") -a1 -e'-/-' -o'1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.2 1.10 1.11 1.12 1.13');

BODY=$(join <(echo -e "$BODY") <(echo -e "$MSR_OUT") -a1 -e'_' -o'1.1 1.2 1.3 2.3 1.4 1.5 1.6 1.7 1.8 1.9 1.10 1.11 1.12 1.13 1.14' | sed 's/worker MSR/worker\/MSR/g; s/ _ /  /g');

LEN=`awk '{ print length }' <(echo -e "$BODY" | column -t) | sort -n | tail -1`;

LINE=$(printf '─%.0s' $(seq 1 $LEN));

HEADER="hostname|id|role|os_version|hpvs|avail|state|ip|mcr|mke/msr|collect|orch|created/updated|status_message";
HEADER=$(echo ${HEADER^^} | sed 's/|/ /g');

OUT="$HEADER\n$BODY\n";

# print header and body
echo -e "$OUT" | column -t | sed "2 i $LINE" | sed "s/_/ /g";

# print line break
echo -e "$LINE";

# count nodes
NODES=$(echo -e "$BODY" | wc -l);
echo "Nodes: $NODES";

# print cluster id
grep --color=auto --color=auto -m1 "ucp-instance-id" dsinfo.json |\
	sed 's/.*=\(.*\)".*/Cluster ID: \1/';
