#!/bin/bash

# File containing the JSON data
f="ucp-nodes.txt"

# Extract all rows using jq and print tab-separated values
extract_data() {
    jq -r '
        sort_by(.Description.Hostname) |
        .[] | [
            (.Description.Hostname // "N/A"),
            (.ID // "N/A"),
            (.Spec.Role // "N/A"),
            (.Description.Platform.OS // "N/A"),
            (.Description.Platform.Release // "-"),
            (.Spec.Labels.hpvs // "N/A"),
            (.Spec.Availability // "N/A"),
            (.Status.State // "N/A"),
            (.Status.Addr // "N/A"),
            (.Description.Engine.EngineVersion // "-"),
            (.Spec.Labels."com.docker.ucp.node-state-augmented.reconciler-ucp-version" // "-"),
            (.Spec.Labels."msr.version" // "-"),
            (.Spec.Labels."collectors.version" // "-"),
            (.Spec.Labels."orchestration" // "-"),
            (.CreatedAt // "N/A"),
            (.UpdatedAt // "N/A"),
            (.Status.Message // "N/A")
        ] | @tsv
    ' "$f"
}

# Calculate the max width for each column (including the headers)
calculate_column_widths() {
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

# Print the table with the calculated column widths
print_table() {
    local -a widths=("$@")
    local data="$2"

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
    printf "$header_format" "${headers[@]}"

    # Print a separator line
    local separator=""
    for w in "${widths[@]}"; do
        separator+=$(printf "%-${w}s  " | tr ' ' '─')
    done
    echo "$separator"

    # Print each row
    while IFS=$'\t' read -r -a row; do
        printf "$row_format" "${row[@]}"
    done <<< "$data"  # Use pre-collected data
}

# Main execution

# Define headers for the table
headers=("HOSTNAME" "ID" "ROLE" "OS" "RELEASE" "HPVS" "MEMBER" "STATE" "IP" "MCR" "MKE" "MSR" "COLLECT" "ORCHEST" "CREATED" "UPDATED" "STATUS")

# Extract the data once and store it in a variable
data=$(extract_data)

# Get column widths (including headers and rows)
column_widths=($(calculate_column_widths "$data"))

# Print the table
print_table "${column_widths[@]}" "$data"

