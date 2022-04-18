#!/usr/bin/env python3

import os, json, fnmatch, numpy

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
        # print env
        imgverstr = [s for s in env if k in s]
        # print imgverstr[0]
        imgver = imgverstr[0].split('=')[1]
        return imgver

def full_os_details(hostname):
    node_dsinfo_filename = os.path.join(hostname, "dsinfo.txt")
    os_type = "-"
    os_version = "---"
    dsi_os = "NoInfo "   ## docker system info result
    full_os_text = os_type + '-' + os_version + '/' + dsi_os
    hpv = "None"
    try:      ## after setting some default values, we see what the dsinfo.txt file has
        with open(node_dsinfo_filename, 'r') as inf:
            for line in inf:
                line = line.lstrip()
                if line.startswith("Operating System: "):
                    dsi_os = line.split(': ')[1].strip()
                    dsi_os = dsi_os.replace('Red Hat Enterprise Linux', 'RHEL')
                    '''
                    dsi_os = dsi_os.replace('Red ', 'R').replace('Hat ', 'H').replace('Enterprise ', 'E')
                    '''
                    dsi_os = dsi_os.split('(')[0]  # RHEL 7.9 (Maipo) will become RHEL 7.9
                if line.startswith("NAME="):
                    os_type = line.split('=')[1].strip().strip('"')
                    ## Just to make the output a little shorter
                    if os_type.startswith("Red"):
                        os_type = "RHEL"
                if line.startswith("VERSION="):
                    os_version = line.split('=')[1].strip().strip('"')
                    os_version = os_version.split('(')[0].strip()   ## 20.04.1 LTS (Focal Fossa)  --> 20.04.1 LTS
                full_os_text = os_type + '-' + os_version + '/' + dsi_os

                if line.startswith("Hypervisor vendor: "):
                    hpv = line.split(': ')[1].strip()
                    break
                if line.startswith("mount"):   # reached this point? you will not find any line about Hypervisor, stop reading the rest of the file
                    break
            full_os_text = (os_type + '-' + os_version + '/' + dsi_os).strip()
            return full_os_text, hpv  #in case that the dsinfo.txt file has no line starting with Hypervisor vendor:  at least return - as hpv
    except FileNotFoundError:        # for nodes that the SD did not gather info, at least return the default values
        return full_os_text.strip(), hpv

def sd_print(sd):
    body_widths = [max(map(len, col)) for col in zip(*(node.values() for node in sd))]
    head_widths = [max(map(len, col)) for col in zip(*(node.keys() for node in sd))]
    col_widths = numpy.maximum(head_widths, body_widths)
    node_count = 0

    print("  ".join((key.upper().ljust(width) for key, width in zip(sd[0].keys(), col_widths))))
    print("─" * (sum(col_widths) + len(col_widths) * 2))
    for node in sd:
        node_count += 1
        print("  ".join((value.ljust(width) for value, width in zip(node.values(), col_widths))))
        '''print(" ▏".join((value.ljust(width) for value, width in zip(node.values(), col_widths))))'''
    print("─" * (sum(col_widths) + len(col_widths) * 2))
    print("Nodes:", node_count)

def load(f):
    with open(f, 'r') as r:
        sd = json.load(r)

    nodes = []

    for node in sd:
        host = node['Description']['Host'] if 'Host' in node['Description'] else 'n/a'

        '''Description'''
        desc = node['Description']
        hostname = desc['Hostname'] if 'Hostname' in desc else 'N/A'
        arch = desc['Platform']['Architecture'] if 'Architecture' in desc['Platform'] else 'N/A'
        os = desc['Platform']['OS'] if 'OS' in desc['Platform'] else 'N/A'
        os_string, hypervisor = full_os_details(hostname) if os == 'linux' else ('N/A', '-')
        os = os.replace('linux', '🐧 ')
        os = os.replace('windows', '📂 ')
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
        ucpdtrver = '/'.join([ucpver,dtrver])

        c_at = node['CreatedAt'].split('T')[0]
        u_at = node['UpdatedAt'].split('T')[0]
        t_stamps = '/'.join([c_at,u_at])

        nodes.append({'hostname': hostname, \
                      'id': cid, \
                      'role': role, \
                      'os_version': os_string, \
                      'hpvs': hypervisor, \
                      'avail': avail, \
                      'state': state, \
                      'ip': addr, \
                      'mcr': engver, \
                      'mke/msr': ucpdtrver, \
                      'collect': collect, \
                      'orch': orch, \
                      'created/updated': t_stamps, \
                      'status_message': stsmsg, \
                      'os ': os})

    s = sorted(nodes, key=lambda k: k['hostname'])
    sd_print(s)

if __name__ == "__main__":
    load("ucp-nodes.txt")
