#!/bin/bash

f="ucp-nodes.txt"

calc_col_widths() {


# Read the jq output into an array, splitting only on newlines
readarray -t sd < <(jq -c 'sort_by(.Description.Hostname) | .[]' "$f")

formatted_rows=()

sd_print() {
	# Extract keys and rows
	keys=($(jq -r '.[0] | keys_unsorted[]' <<< "$sd"))
	rows=($(jq -c '.[]' <<< "$sd"))
	for i in "${!keys[@]}"; do maxw[i]=${#keys[i]}; done

	# Calculate max widths
	for row in "${rows[@]}"; do
			for i in "${!keys[@]}"; do
					val=$(jq -r ".${keys[i]}" <<< "$row")
					(( ${#val} > maxw[i] )) && maxw[i]=${#val}
			done
	done

	# Print row
	print_row() { for i in "${!keys[@]}"; do printf "%-${maxw[i]}s  " "$(jq -r ".${keys[i]}" <<< "$1")"; done; echo; }

	# Sum up column widths to calculate the total width of the table
	total_width=0
	for width in "${maxw[@]}"; do
			(( total_width += width ))
	done

	# Print headers
	for i in "${!keys[@]}"; do printf "%-${maxw[i]}s  " "${keys[i]}"; done; echo
	printf '%*s\n' $((total_width + ${#keys[@]} * 2))

	# Print rows
	for row in "${rows[@]}"; do print_row "$row"; done

	echo "Nodes: ${#rows[@]}"
}

# Loop through each JSON object and extract values, then print them in the formatted table
for element in "${sd[@]}"; do
    # Extract values using jq from each JSON object
    HOSTNAME=$(jq -r '.Description.Hostname // "N/A"' <<< "$element")
		ID=$(jq -r '.ID // "N/A"' <<< "$element")
		ROLE=$(jq -r '.Spec.Role // "N/A"' <<< "$element")

		# Specific OS Version
    RELEASE=$(echo "$element" | jq -r '.Description.Platform.Release // "-"')

		r=$(find . -path "*$HOSTNAME*" -name "dsinfo.txt" -print -quit)
		#RELEASE=""
		if [[ -z $r ]]; then
			OS=$(jq -r '.Description.Platform.OS // "N/A"' <<< "$element")
			RELEASE="-"
		else
			while IFS= read -r line; do
				case $line in
					"Operating System"*)
						echo "meow"
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
						kernel=$(cut -d':' -f2 <<< "$line" | xargs)
						;;
					"Hypervisor vendor:"*)
						HPVS=$(cut -d':' -f2 <<< "$line" | xargs)
						#break
						;;
					"mount"*)
						#break
						;;
				esac
			done < "$r"
			OS="$os_type-$os_version"
		fi

    #HPVS=$(echo "$element" | jq -r '.Spec.Labels.hpvs // "N/A"')
		MEMBER=$(jq -r '.Spec.Availability // "N/A"' <<< "$element")
		STATE=$(jq -r '.Status.State // "N/A"' <<< "$element")
		IP=$(jq -r '.Status.Addr // "N/A"' <<< "$element")
		MCR=$(jq -r '.Description.Engine.EngineVersion // "-"' <<< "$element")
		MKE=$(jq -r '.Spec.Labels."com.docker.ucp.node-state-augmented.reconciler-ucp-version" // "-"' <<< "$element")

		# MSR VERSION
		r=$(find . -path "*$HOSTNAME*" -name "dtr-registry-*.txt" -print -quit)
		if [[ -z $r ]]; then
			MSR="-"
		else
			k="DTR_VERSION"
			MSR=$(jq -r --arg k "$k" '.[] | .Config.Env[] | select(. | test($k))' "$r" | cut -d'=' -f2)
		fi

		COLLECT=$(jq -r '.Spec.Labels."com.docker.ucp.access.label" // "-"' <<< "$element")
    ORCHEST=$(jq -r '
			if .Spec.Labels."com.docker.ucp.orchestrator.swarm" == "true" and
				.Spec.Labels."com.docker.ucp.orchestrator.kubernetes" == "true" then
				"swarm/kube"
			elif .Spec.Labels."com.docker.ucp.orchestrator.swarm" == "true" and
				(.Spec.Labels."com.docker.ucp.orchestrator.kubernetes" != "true" or
			  .Spec.Labels."com.docker.ucp.orchestrator.kubernetes" == null) then
				"swarm/-"
			elif .Spec.Labels."com.docker.ucp.orchestrator.kubernetes" == "true" and
				(.Spec.Labels."com.docker.ucp.orchestrator.swarm" != "true" or
				.Spec.Labels."com.docker.ucp.orchestrator.swarm" == null) then
				"-/kube"
			else
				"-/-"
			end' <<< "$element")
		CREATED=$(jq -r '.CreatedAt | sub("T.*"; "") // "N/A"' <<< "$element")
		UPDATED=$(jq -r '.UpdatedAt | sub("T.*"; "") // "N/A"' <<< "$element")
		STATUS=$(jq -r '.Status.Message // "N/A"' <<< "$element")

    # Print the extracted values in the same format as the Python output
    #printf "%-10s %-12s %-12s %-10s %-12s %-8s %-8s %-8s %-15s %-8s %-8s %-8s %-8s %-12s %-12s %-20s %-15s\n" \
    #"$HOSTNAME" "$ID" "$ROLE" "$OS" "$RELEASE" "$HPVS" "$MEMBER" "$STATE" "$IP" "$MCR" "$MKE" "$MSR" "$COLLECT" "$ORCHEST" "$CREATED" "$UPDATED" "$STATUS"

		row_data=""
		for i in "${!keys[@]}"; do
			row_data+=$(printf "%-${maxw[i]}s  " "$(jq -r ".${keys[i]}" <<< "$1")")
    done
    formatted_rows+=("$row_data")
done

sd_print


# Print a closing separator line
#printf '%s\n' "──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────"

