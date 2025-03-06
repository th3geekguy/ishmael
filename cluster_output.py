#!/usr/bin/env python3

import json, os, subprocess

clusterid = ""
managers = []
operatingsystems = {}
kernelversions = {}
license = {}

class Versions:
    def __init__(self, mcr, mke, msr):
        self.mcr = mcr
        self.mke = mke
        self.msr = msr

class System:
    def __init__(self, os, release, collector, hpvs, kernel):
        self.os = os
        self.release = release
        self.collector = collector
        self.hpvs = hpvs
        self.kernel = kernel

class Timestamps:
    def __init__(self, created, updated):
        self.created = created
        self.updated = updated

class Node:
    def __init__(self, role, id, membership, orchestration, ip, versions, system, timestamps, health):
        self.role = role
        self.id = id
        self.membership = membership
        self.orchestration = orchestration
        self.ip = ip
        self.versions = Versions(*versions)
        self.system = System(*system)
        self.timestamps = Timestamps(*timestamps)
        self.health = health
        self.status = health

def gather_data():
    global clusterid, managers, operatingsystem, kernelversions

    # Get clusterid
    with open("dsinfo.json", "r") as dsinfo_file:
        clusterid = next(line.split("=")[1].split("\"")[0].strip(',\\"')
                for line in dsinfo_file if "ucp-instance-id" in line and "=" in line)

    # Get managers
    with open("ucp-nodes.txt", "r") as ucp_nodes_file:
        managers = sorted(set(
            node["Description"]["Hostname"] for node in json.load(ucp_nodes_file)
            if node["Spec"]["Role"] == "manager"
        ))

        # Get unique nodes
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

            with open(nodeinfo, "r") as nodeinfo_file:
                node_os = next(
                    line.strip().split(':')[1] for line in nodeinfo_file
                    if "Operating System" in line
                )
                operatingsystems[nodepath] = node_os

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
    sortoperatingsys = sorted(operatingsystems.keys())
    sortkernel = sorted(kernelversions.keys())

    print(f'Cluster ID: {clusterid}')
    print('Managers:', *managers, sep='\n')
    print('Operating Systems:')
    for node in sortoperatingsys:
        print(f'\t{node}\t{sortoperatingsys[node]}')
    print('Kernel Versions:')
    for node in sortkernel:
        print(f'\t{node}\t{kernelversions[node]}')
    print(f'License: {license}')

def build_json():
    global clusterid, managers, operatingsystem, kernelversions, license

    #kernel_json = json.dumps({"Kernel Versions": kernelversions}, indent=2)
    cluster_json = json.dumps({
        "Cluster ID": clusterid,
        "Managers": managers,
        "Operating System": operatingsystems,
        "Kernel Versions": kernelversions,
        "License Info": license
    }, indent=2)

    print(cluster_json)

gather_data()
build_json()

