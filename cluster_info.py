#!/usr/bin/env python3

import json
import os
import subprocess

clusterid = ""
managers = []
operatingsystem = ""
kernelversions = {}
license = {}

def gather_data():
    global clusterid, managers, operatingsystem, kernelversions

    # Get clusterid
    with open("dsinfo.json", "r") as dsinfo_file:
        clusterid = next(line.split("=")[1].split("\"")[0].strip(',\\"') for line in dsinfo_file if "ucp-instance-id" in line)

    # Get managers
    with open("ucp-nodes.txt", "r") as ucp_nodes_file:
        managers = sorted(set(
            node["Description"]["Hostname"] for node in json.load(ucp_nodes_file)
            if node["Spec"]["Role"] == "manager"
        ))

    # Get operating system
    operatingsystem = subprocess.check_output(
        'grep --color=auto --color=auto --include \\*dsinfo.txt -hir -m 1 -B 6 -e "version_id" |'
        ' sed -e "/--/d" -e "/ID/d" -e "/^VAR/d" | sed \'s/.*="\\(.*\\)".*/\\1/\' | awk \'!x[$0]++\' | paste -sd \' \'',
        shell=True, text=True).strip()

    # Get unique nodes
    with open("ucp-nodes.txt", "r") as ucp_nodes_file:
        nodes = sorted(set(
            node["Description"]["Hostname"] for node in json.load(ucp_nodes_file)
        ))

    for node in nodes:
        error_file_path = f"{node}.error"
        if not os.path.exists(error_file_path):
            nodepath = f"{node}/dsinfo.json"
            nodeinfo = f"{node}/dsinfo.txt"
            with open(nodeinfo, "r") as nodeinfo_file:
                nodekernel = next(
                    line.strip().split()[2] for line in nodeinfo_file
                    if "Linux version" in line
                )
                kernelversions[nodepath] = nodekernel

    mirantis_lic_path = "mirantis.lic"
    if os.path.exists(mirantis_lic_path):
        # Get license information if mirantis.lic exists
        with open(mirantis_lic_path, "r") as mirantis_lic_file:
            mirantis_lic_data = json.load(mirantis_lic_file)
            license["Max Engines"] = mirantis_lic_data["details"]["maxEngines"]
            license["Expiration"] = mirantis_lic_data["details"]["expiration"]
            license["Tier"] = mirantis_lic_data["details"]["tier"]
            license["License Type"] = mirantis_lic_data["details"]["licenseType"]
            license["Scanning Enabled"] = mirantis_lic_data["details"]["scanningEnabled"]

def debug_print():
    sortkernel = sorted(kernelversions.keys())

    print(f'Cluster ID: {clusterid}')
    print('Managers:', *managers, sep='\n')
    print(f'Operating System: {operatingsystem}')
    print('Kernel Versions:')
    for kernel in sortkernel:
        print(f'\t{kernel}\t{kernelversions[kernel]}')
    print(f'License: {license}')

def build_json():
    global clusterid, managers, operatingsystem, kernelversions, license

    kernel_json = json.dumps({"Kernel Versions": kernelversions}, indent=2)
    cluster_json = json.dumps({
        "Cluster ID": clusterid,
        "Managers": managers,
        "Operating System": operatingsystem,
        "Kernel Versions": kernelversions,
        "License Info": license
    }, indent=2)

    print(cluster_json)

gather_data()
build_json()

