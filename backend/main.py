#!/usr/bin/env python3

import bottle
import cpuinfo
import gpustat
import psutil
import time
import os


CACHE_TIME = 5
HOST_ROOT = '/host_root'

cpu_info_data = None
gpu_info_data = None
gpu_info_expires = 0
disk_info_data = None
disk_info_expires = 0


def cpu_info():
    global cpu_info_data
    if cpu_info_data is None:
        cpu_info_data = cpuinfo.get_cpu_info()
    try:
        freq_obj = psutil.cpu_freq()
        freq = dict(freq_obj._asdict()) if freq_obj else {}
    except Exception:
        freq = {}
    return {'info': cpu_info_data,
            'count': psutil.cpu_count(),
            'usage': psutil.cpu_percent(),
            'percent': psutil.cpu_percent(percpu=True),
            'stats': dict(psutil.cpu_stats()._asdict()),
            'freq': freq,
            'times': dict(psutil.cpu_times()._asdict()),
            'times_percent': dict(psutil.cpu_times_percent()._asdict())}


def gpu_info():
    global gpu_info_data, gpu_info_expires, CACHE_TIME
    try:
        if gpu_info_expires < time.time():
            gpu_info_data = None
        if gpu_info_data is None:
            query_result = gpustat.new_query()
            gpu_info_data = [dict(gpu) for gpu in query_result]
            gpu_info_expires = time.time() + CACHE_TIME
    except Exception:
        gpu_info_data = []
    return gpu_info_data


def disk_info():
    global disk_info_data, disk_info_expires, CACHE_TIME
    if disk_info_expires < time.time():
        disk_info_data = None
    if disk_info_data is None:
        disks = []
        # In Docker, the host filesystem is bind-mounted at /host_root.
        # Use it directly so disk usage reflects the real machine.
        if os.path.ismount(HOST_ROOT):
            root_dev = None
            try:
                root_dev = os.stat(HOST_ROOT).st_dev
                usage = psutil.disk_usage(HOST_ROOT)
                disks.append({
                    'device': 'host:/',
                    'mountpoint': '/',
                    'fstype': 'host',
                    'opts': 'ro',
                    'usage': dict(usage._asdict()),
                })
            except OSError:
                pass
            # Additional bind-mounted host paths. Skip when the source did
            # not exist on the host and resolved to the root filesystem.
            for container_path, host_label in (('/host_data', '/data'),):
                if not os.path.ismount(container_path):
                    continue
                try:
                    if root_dev is not None and os.stat(container_path).st_dev == root_dev:
                        continue
                    usage = psutil.disk_usage(container_path)
                    disks.append({
                        'device': f'host:{host_label}',
                        'mountpoint': host_label,
                        'fstype': 'host',
                        'opts': 'ro',
                        'usage': dict(usage._asdict()),
                    })
                except OSError:
                    pass
        else:
            # Bare-metal: scan real partitions, skipping loop devices and /boot.
            for part in psutil.disk_partitions():
                if part.device.startswith('/dev/loop'):
                    continue
                if part.mountpoint.startswith('/boot'):
                    continue
                try:
                    usage = psutil.disk_usage(part.mountpoint)
                except (PermissionError, OSError):
                    continue
                p = dict(part._asdict())
                p['usage'] = dict(usage._asdict())
                disks.append(p)
        disk_info_data = disks
        disk_info_expires = time.time() + CACHE_TIME
    return disk_info_data


def host_name():
    # Inside a container, os.uname()[1] returns the container hostname.
    # docker-compose passes the real host name via HOST_HOSTNAME.
    return os.environ.get('HOST_HOSTNAME') or os.uname()[1]


app = bottle.Bottle()

@app.get('/stat')
def stat():
    bottle.response.set_header('Access-Control-Allow-Origin', '*')
    return {'host': host_name(),
            'time': time.time(),
            'cpu': cpu_info(),
            'mem': dict(psutil.virtual_memory()._asdict()),
            'swap': dict(psutil.swap_memory()._asdict()),
            'gpu': gpu_info(),
            'disk': disk_info()}



if __name__ == '__main__':
    import argparse, sys

    parser = argparse.ArgumentParser(sys.argv[0])
    parser.add_argument('--server', default='gunicorn')
    parser.add_argument('--host', default='0.0.0.0')
    parser.add_argument('--port', default=9989)
    parser.add_argument('--workers', default=1)
    args = parser.parse_args()

    sys.argv = [sys.argv[0]]
    app.run(server=args.server, host=args.host, port=args.port, workers=args.workers)
    