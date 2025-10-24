#!/bin/bash

extract_os_data() {
  echo -e "\"HOSTNAME\",\"OS\",\"RELEASE\",\"KERNEL\",\"HPVS\"" # Header
  for d in */ ; do
    nf="${d}dsinfo.txt"
    if test -f "$nf"; then
      HOSTNAME="${d%/}"
      OS=$(sed -n '/^NAME=/ { s/^.*NAME="\(.*\)".*$/\1/p; q }' "$nf")
      RELEASE=$(sed -n '/^\s*VERSION=/ { s/^.*VERSION="\(.*\)".*$/\1/p; q }' "$nf")
      KERNEL=$(sed -n '/^\s*Kernel Version:/ { s/^.*Kernel Version:\s*\(.*\)$/\1/p; q }' "$nf")
      HPVS=$(sed -n '/^\s*Hypervisor vendor:/ { s/^.*Hypervisor vendor:\s*\(.*\)$/\1/p; q }' "$nf")

      echo -e "\"$HOSTNAME\",\"$OS\",\"$RELEASE\",\"$KERNEL\",\"${HPVS:=-}\""
    fi
  done
}

BASE=$(echo -e "\"HOSTNAME\",\"ID\",\"ROLE\",\"MEMBER\",\"STATE\",\"IP\",\"MCR\",\"MKE\",\"COLLECT\",\"ORCHEST\",\"CREATED\",\"UPDATED\",\"STATUS\""
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
    ] | @csv
    ' "ucp-nodes.txt");

OS=$(extract_os_data)

join -t, <(echo "$BASE") <(echo "$OS")

