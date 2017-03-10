#!/usr/bin/python

# Script written by Graham Gilbert
# https://gist.github.com/grahamgilbert/8ccba318d3ecadee02b1

import os
import sys, getopt
import subprocess
import urllib
import urllib2
import tempfile
import json
import shutil
from time import localtime
import stat

# No trailing slash on this one
# SAL_URL = "http://192.168.192.105:8001"
# PUBLIC_KEY = "l1x7c5kmmgdxm5z4nvbef4ck"
# PRIVATE_KEY = "8z2xspiv9jq8s9dxj462h4ysxh15ywnzydm99ajzbn6vlw3zucr8dq987c3kktew"
# PKG_IDENTIFIER = "com.salopensource.sal_enroll"
# python sal_package_generator.py --sal_url=http://192.168.192.105:8001 --public_key=l1x7c5kmmgdxm5z4nvbef4ck --private_key=8z2xspiv9jq8s9dxj462h4ysxh15ywnzydm99ajzbn6vlw3zucr8dq987c3kktew --pkg_id=com.salopensource.sal_enroll

# STOP EDITING HERE

# Pkg sources
SAL_PKG = "https://github.com/salopensource/sal/releases/download/v0.4.0/sal_scripts.pkg"
FACTER_PKG = "https://downloads.puppetlabs.com/mac/facter-latest.dmg"

def get_arguments(argv):
    SAL_URL = ''
    PUBLIC_KEY = ''
    PRIVATE_KEY = ''
    PKG_IDENTIFIER = ''
    try:
        opts, args = getopt.getopt(argv,"hu:p:k:i:",["sal_url=","public_key=","private_key=","pkg_id="])
    except getopt.GetoptError:
        print 'python sal_package_generator.py --sal_url=<SAL_URL> --public_key=<PUBLIC_KEY> --private_key=<PRIVATE_KEY> --pkg_id=<PKG_IDENTIFIER>'
        sys.exit(2)
    for opt, arg in opts:
        if opt == '-h':
            print 'python sal_package_generator.py --sal_url=<SAL_URL> --public_key=<PUBLIC_KEY> --private_key=<PRIVATE_KEY> --pkg_id=<PKG_IDENTIFIER>'
            print 'To obtain the public and private keys, log into Sal as a user with Global Admin privelages and choose the "person" menu at the top right and then choose Settings. From the sidebar, choose API keys and then choose to make a new one. Give it a name so you can recognise it - e.g. "PKG Generator". You will then be given a public key and a private key. Enter them in the command as above.'
            print 'See https://grahamgilbert.com/blog/2015/07/10/using-the-sal-api/ for more details.'
            sys.exit()
        elif opt in ("-p", "--public_key"):
            PUBLIC_KEY = arg
        elif opt in ("-k", "--private_key"):
            PRIVATE_KEY = arg
        elif opt in ("-u", "--sal_url"):
            SAL_URL = arg
        elif opt in ("-i", "--pkg_id"):
            PKG_IDENTIFIER = arg
    return SAL_URL, PUBLIC_KEY, PRIVATE_KEY, PKG_IDENTIFIER

def download_package(temp_dir, pkg_url):
    file_name = pkg_url.split('/')[-1]
    output_path = os.path.join(temp_dir, file_name)
    u = urllib2.urlopen(pkg_url)
    f = open(output_path, 'wb')
    meta = u.info()
    file_size = int(meta.getheaders("Content-Length")[0])
    print "Downloading: %s Bytes: %s" % (file_name, file_size)

    file_size_dl = 0
    block_sz = 8192
    while True:
        buffer = u.read(block_sz)
        if not buffer:
            break

        file_size_dl += len(buffer)
        f.write(buffer)
        status = r"%10d  [%3.2f%%]" % (file_size_dl, file_size_dl * 100. / file_size)
        status = status + chr(8)*(len(status)+1)
        print status,

    f.close()
    return output_path

def mount_dmg(dmg):
    # Mount the dmg
    temp_mount = tempfile.mkdtemp()
    cmd = ['/usr/bin/hdiutil', 'attach', dmg, '-mountpoint', temp_mount]
    subprocess.call(cmd)
    return temp_mount

def unmount_dmg(path):
    cmd = ['/usr/bin/hdiutil', 'eject', path]
    subprocess.call(cmd)

def copy_packages(sourcePath, destPath):
    """
    Finds all packages in a specified directory and copies them to a specified directory
    """
    pkg_list = []
    for package in os.listdir(sourcePath):
        if package.endswith('.pkg') or package.endswith('.mpkg'):
            pkg = os.path.join(sourcePath, package)
            dest_file = os.path.join(destPath, os.path.basename(pkg))
            if os.path.isfile(pkg):
                shutil.copy(pkg, dest_file)
            else:
                shutil.copytree(pkg, dest_file)
            pkg_list.append(dest_file)
    return pkg_list

def main():
    # Make our tempdir
    temp_dir = tempfile.mkdtemp()
    pkg_root = os.path.join(temp_dir, 'package_root')
    if not os.path.exists(pkg_root):
        os.makedirs(pkg_root)

    # Download Sal package
    package = download_package(temp_dir, SAL_PKG)

    # Move it to the pkg root
    shutil.move(package, os.path.join(pkg_root,os.path.basename(package)))

    #Download FACTER_PKG
    facter = download_package(temp_dir, FACTER_PKG)

    # Mount Facter dmg
    facter_mount = mount_dmg(facter)

    # And copy out the .pkg
    facter_packages = copy_packages(facter_mount, pkg_root)

    # Unmount the dmg
    unmount_dmg(facter_mount)

    # Get all of the machine Groups
    machine_groups = get_machine_groups()

    script_dir = os.path.join(temp_dir, 'Scripts')
    now = localtime()
    version = "%04d.%02d.%02d" % (now.tm_year, now.tm_mon, now.tm_mday)
    # For Each machine group
    for group in machine_groups:
        pkg_name = 'sal-enroll-%s.pkg' % (group['name'])
        script = """#!/bin/bash
/usr/bin/defaults write $3/Library/Preferences/com.github.salopensource.sal ServerURL %s
/usr/bin/defaults write $3/Library/Preferences/com.github.salopensource.sal key %s
/usr/sbin/installer -pkg "/private/tmp/%s" -target $3
""" % (SAL_URL, group['key'], os.path.basename(package))
        # There is potentially going to be more than one package in here, loop over them all
        for facter_package in facter_packages:
            extra_script = """
/usr/sbin/installer -pkg "/private/tmp/%s" -target $3
""" % os.path.basename(facter_package)
            script = script + extra_script

        if not os.path.exists(script_dir):
            os.makedirs(script_dir)
        script_path = os.path.join(script_dir, 'postinstall')
        with open(script_path, "w") as fd:
            fd.write(script)
        os.chmod(script_path, 0755)

        pkg_output_path = os.path.join(os.getcwd(), pkg_name)
        cmd = ['/usr/bin/pkgbuild',
               "--root", pkg_root,
               "--identifier", PKG_IDENTIFIER,
               "--version", version,
               "--scripts", script_dir,
               "--install-location", "/private/tmp",
               pkg_output_path]
        subprocess.call(cmd)

        shutil.rmtree(script_dir)

def get_machine_groups():
    api_url = "%s/api/machine_groups/" % SAL_URL
    req = urllib2.Request(api_url)
    req.add_header('privatekey', PRIVATE_KEY)
    req.add_header('publickey', PUBLIC_KEY)
    response = urllib2.urlopen(req)
    output = response.read()
    return json.loads(output)


if __name__ == '__main__':
    # get the arguments from the command line
    SAL_URL, PUBLIC_KEY, PRIVATE_KEY, PKG_IDENTIFIER = get_arguments(sys.argv[1:])

    main()
