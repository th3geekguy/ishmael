#!/usr/bin/env python3

import argparse, os, json, fnmatch, numpy

def parse_arguments():
    parser = argparse.ArgumentParser(description='Display cluster/node information found in support dump')
    parser.add_argument('-c', '--clusterid', action='store_true', help='Gather cluster id from dsinfo.json')
    parser.add_argument('-j', '--json', action='store_true', help='Render output as json')
    parser.add_argument('-v', '--verbose', action='store_true', help='Verbose mode')
    parser.add_argument('-w', '--hardware', action='store_true', help='Display hardware specific details')
    arguments = parser.parse_args()
    return arguments

def findfile(topdir, f_glob):
    for d_name, sd_name, f_list in os.walk(topdir):
        for f_name in f_list:
            if fnmatch.fnmatch(f_name, f_glob):
                return os.path.join(d_name, f_name)

def getddcver(nodename,f_glob,k):
    f = findfile(nodename,f_glob)
    if f == None:
        return '-'
    else:
        with open(f, 'r') as r:
            j = json.load(r)

        env = j[0]['Config']['Env']
        imgverstr = [s for s in env if k in s]
        imgver = imgverstr[0].split('=')[1]
        return imgver

def full_os_details(hostname):
    node_dsinfo_filename = os.path.join(hostname, "dsinfo.txt")
    os_type = "-"
    os_version = "---"
    dsi_os = "NoInfo "   ## docker system info result
    full_os_text = os_type + '-' + os_version + '/' + dsi_os
    hpv = "None"
    kernel = "-"
    try:      ## after setting some default values, we see what the dsinfo.txt file has
        with open(node_dsinfo_filename, 'r') as inf:
            for line in inf:
                line = line.lstrip()
                if line.startswith("Operating System: "):
                    dsi_os = line.split(': ')[1].strip()
                    dsi_os = dsi_os.replace('Red Hat Enterprise Linux', 'RHEL')
                    dsi_os = dsi_os.split('(')[0]  # RHEL 7.9 (Maipo) will become RHEL 7.9
                elif line.startswith("NAME="):
                    os_type = line.split('=')[1].strip().strip('"')
                    ## Just to make the output a little shorter
                    if os_type.startswith("Red"):
                        os_type = "RHEL"
                elif line.startswith("VERSION="):
                    os_version = line.split('=')[1].strip().strip('"')
                    os_version = os_version.split('(')[0].strip()   ## 20.04.1 LTS (Focal Fossa)  --> 20.04.1 LTS
                full_os_text = os_type + '-' + os_version + '/' + dsi_os

                if line.startswith("Kernel Version:"):
                    kernel = line.split(':')[1].strip()

                if line.startswith("Hypervisor vendor: "):
                    hpv = line.split(': ')[1].strip()
                    break
                if line.startswith("mount"):   # reached this point? you will not find any line about Hypervisor, stop reading the rest of the file
                    break
            full_os_text = (os_type + '-' + os_version + '/' + dsi_os).strip()
            return full_os_text, hpv, kernel  # in case that the dsinfo.txt file has no line starting with Hypervisor vendor:  at least return - as hpv
    except FileNotFoundError:                 # for nodes that the SD did not gather info, at least return the default values
        return full_os_text.strip(), hpv, kernel

def full_os_details_sep(hostname):
    node_dsinfo_filename = os.path.join(hostname, "dsinfo.txt")
    os_ext = os_type = os_version = dsi_os = "- "   ## docker system info result
    full_os_text = os_type + '-' + os_version + '/' + dsi_os
    hpv = kernel = "-"
    try:      ## after setting some default values, we see what the dsinfo.txt file has
        with open(node_dsinfo_filename, 'r') as inf:
            for line in inf:
                line = line.lstrip()
                if line.startswith("Operating System: "):
                    dsi_os = line.split(': ')[1].strip()
                    dsi_os = dsi_os.replace('Red Hat Enterprise Linux', 'RHEL')
                    dsi_os = dsi_os.split('(')[0]  # RHEL 7.9 (Maipo) will become RHEL 7.9
                elif line.startswith("NAME="):
                    os_type = line.split('=')[1].strip().strip('"')
                    ## Just to make the output a little shorter
                    if os_type.startswith("Red"):
                        os_type = "RHEL"
                elif line.startswith("VERSION="):
                    os_version = line.split('=')[1].strip().strip('"')
                    os_version = os_version.split('(')[0].strip()   ## 20.04.1 LTS (Focal Fossa)  --> 20.04.1 LTS
                full_os_text = os_type + '-' + os_version + '/' + dsi_os

                if line.startswith("Kernel Version:"):
                    kernel = line.split(':')[1].strip()

                if line.startswith("Hypervisor vendor: "):
                    hpv = line.split(': ')[1].strip()
                    break
                if line.startswith("mount"):   # reached this point? you will not find any line about Hypervisor, stop reading the rest of the file
                    break
            #full_os_text = (os_type + '-' + os_version + '/' + dsi_os).strip()
                os_ext = '-'.join([os_type, os_version]).strip()
            return os_ext, dsi_os, hpv, kernel  # in case that the dsinfo.txt file has no line starting with Hypervisor vendor:  at least return - as hpv
    except FileNotFoundError:                 # for nodes that the SD did not gather info, at least return the default values
        return os_ext, dsi_os, hpv, kernel

def get_cluster_id(hostname):
    node_dsinfo_filename = os.path.join(hostname, "dsinfo.json")
    try:
        with open(node_dsinfo_filename, 'r') as inf:
            specs = json.load(inf)
        swarm = specs['docker_info']['Swarm'] if 'docker_info' in specs else ''
        return swarm['Cluster']['ID'] if 'Cluster' in swarm else None
    except FileNotFoundError:
        return None


def sd_print(sd, show_nc=True):
    body_widths = [max(map(len, col)) for col in zip(*(node.values() for node in sd))]
    head_widths = [max(map(len, col)) for col in zip(*(node.keys() for node in sd))]
    col_widths = numpy.maximum(head_widths, body_widths)
    node_count = 0

    print("  ".join((key.upper().ljust(width) for key, width in zip(sd[0].keys(), col_widths))))
    print("─" * (sum(col_widths) + len(col_widths) * 2))
    for node in sd:
        node_count += 1
        print("  ".join((value.ljust(width) for value, width in zip(node.values(), col_widths))))
        #print(" ▏".join((value.ljust(width) for value, width in zip(node.values(), col_widths)))) # join cols with | instead
    print("─" * (sum(col_widths) + len(col_widths) * 2))
    if show_nc:
        print("Nodes:", node_count)

def json_print(sd):
    print(json.dumps(sd))

def display_nodes(args, f):
    with open(f, 'r') as r:
        sd = json.load(r)

    nodes = []
    hw = []
    cluster = []

    for node in sd:
        host = node['Description']['Host'] if 'Host' in node['Description'] else 'n/a'

        '''Description'''
        desc = node['Description']
        hostname = desc['Hostname'] if 'Hostname' in desc else 'N/A'
        arch = desc['Platform']['Architecture'] if 'Architecture' in desc['Platform'] else 'N/A'
        os = desc['Platform']['OS'] if 'OS' in desc['Platform'] else 'N/A'
        os_version, release, hypervisor, kernel = full_os_details_sep(hostname) if os == 'linux' else ('N/A', '-', 'N/A', '-')
        os = os.replace('linux', '🐧')
        os = os.replace('windows', '🗑️')
        engver = desc['Engine']['EngineVersion'] if 'EngineVersion' in desc['Engine'] else 'N/A'

        '''Status'''
        status = node['Status']
        state = status['State']
        addr = status['Addr'] if 'Addr' in status else 'N/A'
        stsmsg = status['Message'] if 'Message' in status else 'N/A'
        stsmsg = stsmsg.replace('UCP', 'MKE').strip()

        '''Spec'''
        spec = node['Spec']
        role = spec['Role']
        avail = spec['Availability']
        collect = spec['Labels']['com.docker.ucp.access.label']
        o_swarm = o_kube = '-'
        if 'com.docker.ucp.orchestrator.swarm' in node['Spec']['Labels'] and \
                node['Spec']['Labels']['com.docker.ucp.orchestrator.swarm'] == 'true':
            o_swarm = 'swarm'
        if 'com.docker.ucp.orchestrator.kubernetes' in node['Spec']['Labels'] and \
                node['Spec']['Labels']['com.docker.ucp.orchestrator.kubernetes'] == 'true':
            o_kube = 'kube'
        orch = '/'.join([o_swarm, o_kube])

        '''ManagerStatus'''
        m_stat = node['ManagerStatus'] if 'ManagerStatus' in node else ""
        addr = m_stat['Addr'] if addr == '127.0.0.1' or addr == '0.0.0.0' else addr
        addr = addr.replace(':2377', '').strip()
        role = 'leader' if role == 'manager' and 'Leader' in m_stat and m_stat['Leader'] == True else role

        '''Other'''
        cid = node['ID'][:10]
        ucpver = getddcver(hostname,'ucp-proxy.txt','IMAGE_VERSION')
        dtrver = getddcver(hostname,'dtr-registry-*.txt','DTR_VERSION')

        if dtrver != '-':
            role += '/MSR'
        #ucpdtrver = '/'.join([ucpver,dtrver])

        c_at = node['CreatedAt'].split('T')[0]
        u_at = node['UpdatedAt'].split('T')[0]
        #t_stamps = '/'.join([c_at,u_at])

        nodes.append({'hostname': hostname, \
                      'id': cid, \
                      'role': role, \
                      #'os_version': os_string, \
                      'os': os_version, \
                      'release': release, \
                      'hpvs': hypervisor, \
                      'member': avail, \
                      'state': state, \
                      'ip': addr, \
                      'mcr': engver, \
                      #'mke/msr': ucpdtrver, \
                      'mke': ucpver, \
                      'msr': dtrver, \
                      'collect': collect, \
                      'orchest': orch, \
                      #'created/updated': t_stamps, \
                      'created': c_at, \
                      'updated': u_at, \
                      'status': stsmsg, \
                      'os ': os})

        if args.hardware or args.verbose:
            '''Hardware Specific'''
            cpus = f"{desc['Resources']['NanoCPUs'] // 1000000000}"
            mem = f"{round(desc['Resources']['MemoryBytes'] / 1024**3, 2)}GiB"

            hw.append({'hostname': hostname, \
                       'id': cid, \
                       'role': role, \
                       'mcr': engver, \
                       #'mke/msr': ucpdtrver, \
                       'mke': ucpver, \
                       'msr': dtrver, \
                       'kernel': kernel, \
                       #'os_version': os_string, \
                       'os': os_version, \
                       'release': release, \
                       'cpus': cpus, \
                       'memory': mem})

        if args.clusterid:
            cluster.append(get_cluster_id(hostname))

    if not args.json:
        if args.verbose or not args.hardware:
            s = sorted(nodes, key=lambda k: k['hostname'])
            sd_print(s, not args.verbose)
        if args.verbose:
            print("")
        if args.verbose or args.hardware:
            s = sorted(hw, key=lambda k: k['hostname'])
            sd_print(s)
    else:
        v = [e | next((f for f in hw if f["hostname"] == e["hostname"]), None) for e in nodes]
        vv = sorted(v, key=lambda k: k['hostname'])
        json_print(vv)

    if args.clusterid:
        print('Cluster ID:', ' '.join(set([i for i in cluster if i is not None])) or '(failed to fetch)')

if __name__ == "__main__":
    args = parse_arguments()
    display_nodes(args, "ucp-nodes.txt")
