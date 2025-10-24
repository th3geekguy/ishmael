#!/bin/bash

# Parse arguments
clusterid=false
json_output=false
verbose=false
hardware=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--clusterid)
            clusterid=true
            shift
            ;;
        -j|--json)
            json_output=true
            shift
            ;;
        -v|--verbose)
            verbose=true
            shift
            ;;
        -w|--hardware)
            hardware=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Helper functions
findfile() {
    local topdir=$1
    local f_glob=$2
    find "$topdir" -name "$f_glob" -print -quit
}

getddcver() {
    local nodename=$1
    local f_glob=$2
    local k=$3
    local f=$(findfile "$nodename" "$f_glob")
    if [[ -z $f ]]; then
        echo "-"
    else
        local version=$(jq -r --arg k "$k" '.[] | .Config.Env[] | select(. | test($k))' "$f" | cut -d'=' -f2)
        echo "$version"
    fi
}

full_os_details_sep() {
    local hostname=$1
    local node_dsinfo_filename="${hostname}/dsinfo.txt"
    local os_ext="-"
    local dsi_os="-"
    local hpv="-"
    local kernel="-"

    if [[ -f "$node_dsinfo_filename" ]]; then
        while IFS= read -r line; do
            case "$line" in
                "Operating System:"*)
                    dsi_os=$(echo "$line" | cut -d':' -f2 | xargs)
                    dsi_os=${dsi_os/Red Hat Enterprise Linux/RHEL}
                    dsi_os=${dsi_os%%(*}  # RHEL 7.9 (Maipo) -> RHEL 7.9
                    ;;
                "NAME="*)
                    os_type=$(echo "$line" | cut -d'=' -f2 | xargs)
                    [[ "$os_type" == Red* ]] && os_type="RHEL"
                    ;;
                "VERSION="*)
                    os_version=$(echo "$line" | cut -d'=' -f2 | xargs)
                    os_version=${os_version%%(*}
                    ;;
                "Kernel Version:"*)
                    kernel=$(echo "$line" | cut -d':' -f2 | xargs)
                    ;;
                "Hypervisor vendor:"*)
                    hpv=$(echo "$line" | cut -d':' -f2 | xargs)
                    break
                    ;;
                "mount"*)
                    break
                    ;;
            esac
        done < "$node_dsinfo_filename"
        os_ext="$os_type-$os_version"
    fi
    echo "$os_ext" "$dsi_os" "$hpv" "$kernel"
}

get_cluster_id() {
    local hostname=$1
    local node_dsinfo_filename="${hostname}/dsinfo.json"
    if [[ -f "$node_dsinfo_filename" ]]; then
        local cluster_id=$(jq -r '.docker_info.Swarm.Cluster.ID // empty' "$node_dsinfo_filename")
        echo "$cluster_id"
    else
        echo ""
    fi
}

# Print table output
sd_print() {
    local nodes=("$@")
    for node in "${nodes[@]}"; do
        echo "$node"
    done
}

# Main function
display_nodes() {
    local f="ucp-nodes.txt"
    
    # Check if file exists and is not empty
    if [[ ! -s "$f" ]]; then
        echo "Error: File $f is either missing or empty."
        exit 1
    fi
    
    # Check if file is valid JSON
    if ! jq empty "$f" 2>/dev/null; then
        echo "Error: $f is not valid JSON."
        exit 1
    fi

    # Load the nodes
    readarray -t sd < <(jq -c '.[]' "$f")
    
    if [[ ${#sd[@]} -eq 0 ]]; then
        echo "No nodes found in $f."
        exit 1
    fi
    
    local nodes=()
    local hw=()
    local cluster=()

    for node in "${sd[@]}"; do
        local desc=$(echo "$node" | jq -r '.Description')
        local hostname=$(echo "$desc" | jq -r '.Hostname')
        local os=$(echo "$desc" | jq -r '.Platform.OS')
        local os_version release hypervisor kernel

        if [[ "$os" == "linux" ]]; then
            read -r os_version release hypervisor kernel <<< "$(full_os_details_sep "$hostname")"
        else
            os_version="N/A"
            release="-"
            hypervisor="N/A"
            kernel="-"
        fi

        local engver=$(echo "$desc" | jq -r '.Engine.EngineVersion // "N/A"')

        # Append node info
        nodes+=("Hostname: $hostname, OS Version: $os_version, Engine Version: $engver")

        if [[ "$hardware" == true ]]; then
            # Gather hardware-specific details
            local cpus=$(echo "$desc" | jq -r '.Resources.NanoCPUs // 0')
            local memory=$(echo "$desc" | jq -r '.Resources.MemoryBytes // 0')
            memory=$(echo "$memory / 1024^3" | bc)
            hw+=("Hostname: $hostname, CPUs: $cpus, Memory: ${memory}GiB")
        fi

        if [[ "$clusterid" == true ]]; then
            local cid=$(get_cluster_id "$hostname")
            [[ -n "$cid" ]] && cluster+=("$cid")
        fi
    done

    if [[ "$json_output" == true ]]; then
        # Print in JSON format
        echo "${nodes[@]}" | jq -c '.'
    else
        # Print table
        sd_print "${nodes[@]}"
        [[ "$verbose" == true ]] && echo "" && sd_print "${hw[@]}"
    fi

    if [[ "$clusterid" == true ]]; then
        echo "Cluster ID: ${cluster[@]}"
    fi
}

# Run the main function
display_nodes

