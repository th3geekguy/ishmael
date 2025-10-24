#!/bin/bash

VERBOSE=false
HARDWARE=false
BASE_FILE="ucp-nodes.txt"

while true; do
	case "$1" in
		-v | --verbose ) VERBOSE=true; shift ;;
		-w | --hardware ) HARDWARE=true; shift ;;
		-c | --clusterid ) CLUSTER_ID=true; shift ;;
		* ) break ;;
	esac
done

extract_base_data() {
	jq -r '
	  sort_by(.Description.Hostname) |
			.[] | [
					(.Description.Hostname // "N/A"),
					(.ID // "N/A"),
					(if .ManagerStatus.Leader == "true" then
						"leader"
					else
						.Spec.Role // "N/A"
					end),
					(.Spec.Availability // "N/A"),
					(.Status.State // "N/A"),
					(if .Status.Addr == "127.0.0.1" or .Status.Addr == "0.0.0.0" then
						(.ManagerStatus.Addr | gsub(":.*"; ""))
					else
						.Status.Addr // "N/A"
					end),
					(.Description.Engine.EngineVersion // "-"),
					(.Spec.Labels."com.docker.ucp.node-state-augmented.reconciler-ucp-version" // "-"),
					(.Spec.Labels."com.docker.ucp.access.label" // "-"),
					(if .Spec.Labels."com.docker.ucp.orchestrator.swarm" == "true" and
						 .Spec.Labels."com.docker.ucp.orchestrator.kubernetes" == "true" then
							"swarm/kube"
					elif .Spec.Labels."com.docker.ucp.orchestrator.swarm" == "true" then
							"swarm"
					elif .Spec.Labels."com.docker.ucp.orchestrator.kubernetes" == "true" then
							"kube"
					else
							"-/-"
					end),
					(.CreatedAt | sub("T.*"; "") // "N/A"),
					(.UpdatedAt | sub("T.*"; "") // "N/A"),
					(.Status.Message // "N/A")
			] | @tsv
			' "$BASE_FILE"
}

calc_col_widths() {
	local -a widths=()

	# Headers for the table
	headers=("HOSTNAME" "ID" "ROLE" "OS" "RELEASE" "HPVS" "MEMBER" "STATE" "IP" "MCR" "MKE" "MSR" "COLLECT" "ORCHEST" "CREATED" "UPDATED" "STATUS")

	# Initialize the widths with the size of the headers
	for i in "${!headers[@]}"; do
		widths[$i]=${#headers[$i]}
	done

	# Go through each row to find the maximum width of each column
	while IFS=$'\t' read -r -a row; do
		for i in "${!row[@]}"; do
			# Update column width if the current row's value is wider than the current max width
			if [[ ${#row[$i]} -gt ${widths[$i]} ]]; then
				widths[$i]=${#row[$i]}
			fi
		done
	done <<< "$1"  # Pass the data as input

	# Output the column widths (for debugging or further use)
	echo "${widths[@]}"
}

print_table() {
	local -a widths=("$@")
	local -a data=("$3")

	# Prepare format string for the header and rows
	local header_format=""
	local row_format=""
	for w in "${widths[@]}"; do
		header_format+="%-${w}s  "
		row_format+="%-${w}s  "
	done
	header_format+="\n"
	row_format+="\n"

	# Print the header
	printf "$header_format" "$2"

	# Print a separator line
	local separator=""
	for w in "${widths[@]}"; do
		separator+=$(printf "%-${w}s  " | tr ' ' '=')
	done
	echo "$separator"

	# Print each row
	for row in "${data[@]}"; do
		printf "$row_format" "${row[@]}"
	done
}

fast_extract_os_data() {
	for d in */ ; do
		nf="${d}dsinfo.txt"
		if test -f "$nf"; then
			HOSTNAME="${d%/}"
			OS=$(sed -n '/^NAME=/ { s/^.*NAME="\(.*\)".*$/\1/p; q }' "$nf")
			RELEASE=$(sed -n '/^\s*VERSION=/ { s/^.*VERSION="\(.*\)".*$/\1/p; q }' "$nf")
			KERNEL=$(sed -n '/^\s*Kernel Version:/ { s/^.*Kernel Version:\s*\(.*\)$/\1/p; q }' "$nf")
			HPVS=$(sed -n '/^\s*Hypervisor vendor:/ { s/^.*Hypervisor vendor:\s*\(.*\)$/\1/p; q }' "$nf")

			echo -e "$HOSTNAME\t$OS\t$RELEASE\t$KERNEL\t${HPVS:=-}"
		fi
	done
}

extract_os_data() {
	#echo -e "HOSTNAME\tOS\tHPVS\tKERNEL"
	readarray -t data <<< "$@"
	for node in "${data[@]}"; do
		HOSTNAME=$(awk '{print $1}' <<< "$node")
		#HOSTNAME=$(jq -r '.Description.Hostname // "N/A"' <<< "$node")

		node_file=$(find . -path "*$HOSTNAME*" -name "dsinfo.txt" -print -quit)
		if [[ -z $node_file ]]; then
			OS=""
			#OS=$(jq -r '.Description.Platform.OS // "N/A"' <<< "$node")
			RELEASE="-"
		else
			while IFS= read -r line; do
				case $line in
					"Operating System"*)
						RELEASE=$(echo "$line" | cut -d':' -f2 | xargs)
						RELEASE=${RELEASE/Red Hat Enterprise Linux/RHEL}
						RELEASE=${RELEASE%%(*}  # RHEL 7.9 (Maipo) -> RHEL 7.9
						;;
					"NAME="*)
						os_type=$(cut -d'=' -f2 <<< "$line" | xargs)
						[[ "$os_type" == Red* ]] && os_type="RHEL"
						;;
					"VERSION="*)
						os_version=$(cut -d'=' -f2 <<< "$line" | xargs)
						os_version=${os_version%%(*}
						;;
					"Kernel Version:"*)
						KERNEL=$(cut -d':' -f2 <<< "$line" | xargs)
						;;
					"Hypervisor vendor:"*)
						HPVS=$(cut -d':' -f2 <<< "$line" | xargs)
						break
						;;
					"mount"*)
						break
						;;
				esac
			done < "$node_file"
			OS="$os_type-$os_version"
		fi
		echo -e "$HOSTNAME\t$OS\t$RELEASE\t$HPVS\t$KERNEL"
	done
}

extract_msr_data() {
	#echo -e "HOSTNAME\tMSR"
	local -a data=("$@");
	for node in "${data[@]}"; do
		HOSTNAME=$(jq -r '.Description.Hostname // "N/A"' <<< "$node")

		node_file=$(find . -path "*$HOSTNAME*" -name "dtr-registry-*.txt" -print -quit)
		if [[ -z $node_file ]]; then
			MSR="-"
		else
			keyword="DTR_VERSION"
			MSR=$(jq -r --arg k "$keyword" '.[] | .Config.Env[] | select(. | test($k))' "$node_file" | cut -d'=' -f2)
		fi
		echo -e "$HOSTNAME\t$MSR"
	done
}

fast_extract_msr_data() {
	find . -name "dtr-registry-*.txt" -print0 | while read -d $'\0' nf
	do
		if test -f "$nf"; then
			HOSTNAME=$(echo "$nf" | cut -d'/' -f2)
			MSR=$(grep -oP 'DTR_VERSION=\K.*?(?=",)' "$nf")
		else
			MSR='-'
		fi
		echo -e "$HOSTNAME\t$MSR"
	done
}

# print header and body
#echo -e "$OUT" | column -t | sed "2 i $LINE" | sed "s/_/ /g";

# print line break
#echo -e "$LINE";

# count nodes
#NODES=$(echo -e "$BODY" | wc -l);
#echo "Nodes: $NODES";

# print cluster id
#grep --color=auto --color=auto -m1 "ucp-instance-id" dsinfo.json |\
#sed 's/.*=\(.*\)".*/Cluster ID: \1/';


# main execution
#>>base_headers=("HOSTNAME" "ID" "ROLE" "OS" "RELEASE" "HPVS" "MEMBER" "STATE" "IP" "MCR" "MKE" "MSR" "COLLECT" "ORCHEST" "CREATED" "UPDATED" "STATUS")

# extract data from dsinfo
time base_data=$(extract_base_data)

# create hostname list
time hostnames=($(awk '{print $1}' <<< "$base_data"))

# extract os data by node
#extract_os_data "$base_data"
time os_data=$(fast_extract_os_data "$base_data")

# extract data by node # msr version
time msr_data=$(fast_extract_msr_data "$base_data")

# join data
#>>echo "${base_headers[@]}"
#>>echo "$base_data"
#BODY=$(join <("$base_data") <("$os_data") -a1 -e'-/-' -o'1.1 1.2 1.3 2.2 2.3 2.4 1.4 1.5 1.6 1.7 1.8 1.9 1.10 1.11 1.12 1.13');
#BODY=$(join <("$BODY") <("$msr_data") -a1 -e'_' -o'1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 1.10 1.11 2.1 1.12 1.13 1.14 1.15 1.16' |\
	#sed 's/worker MSR/worker\/MSR/g; s/ _ /  /g')

#LEN=`awk '{ print length }' <(column -t <<< "$BODY") | sort -n | tail -1`

# create column widths
#>>column_widths=($(calc_col_widths "$headers" "$BODY"))

# finally print
#>>print_table "${column_widths[@]}" "$headers" "$BODY"
