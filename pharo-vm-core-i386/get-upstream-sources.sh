#!/bin/bash

set -e

if [ $# -eq 0 ]
then
    echo "usage: $0 <vm-version>"
    exit 1	
fi

source build.conf

VM_SOURCES_VERSION=$1
VM_SOURCES_URL="http://files.pharo.org/vm/src/vm-unix-sources/blessed/$VM_SOURCES_PREFIX-$VM_SOURCES_VERSION.tar.bz2"
VM_SOURCES_DIR="$VM_SOURCES_PREFIX-$VM_SOURCES_VERSION"

function download_sources() {
    echo "Download sources from $VM_SOURCES_URL"
    rm -f sources.tar.bz2
    wget "${VM_SOURCES_URL}" -O sources.tar.bz2
}

function extract_sources() {
    echo "Extract sources.tar.bz2 to $VM_SOURCES_DIR"
    tar xfj sources.tar.bz2
}

function wrong_vm_version_format() {
    # check that vm_Version is of the form YYYY.MM.DD
    echo ${VM_VERSION} | grep '^[[:digit:]]\{4\}\.[[:digit:]]\{2\}\.[[:digit:]]\{2\}$' > /dev/null
    grep_succeeded=$?
    [ ! $grep_succeeded -eq 0 ]
    return $?
}

function source_package_already_present() {
    echo "Checking if source package is already there"
    test -f ${PACKAGE_NAME}_${VM_VERSION}.orig.tar.bz2
    return $?
}

function clean_sources() {
    echo "Clean the directory to remove unneeded stuff"
    cd $VM_SOURCES_DIR
    find . '(' -name '*.image' -or -name '*.changes' ')' -exec rm -f '{}' ';'
    find . '(' -name 'config.log' -or -name 'config.status' ')' -exec rm -f '{}' ';'

    rm -rf platforms/win32
    rm -rf platforms/"Mac OS"
    rm -rf platforms/iOS
    rm -rf processors/ARM
    cd ..
}

function create_source_package() {
    echo "Create upstream tarball"
    rm -rf ${PACKAGE_NAME}-${VM_VERSION}
    mv $VM_SOURCES_DIR "${PACKAGE_NAME}-${VM_VERSION}"
    tar cfj ${PACKAGE_NAME}_${VM_VERSION}.orig.tar.bz2 ${PACKAGE_NAME}-${VM_VERSION}
}

download_sources
extract_sources
VM_VERSION=$(cat $VM_SOURCES_DIR/build/vmVersionInfo.h | ./extract-vm-version.sh)
if wrong_vm_version_format "$VM_VERSION"; then
    echo "Can't extract the VM version from vmVersionInfo.h"
    exit 1
elif source_package_already_present "$VM_VERSION"; then
    echo "Source package already present"
    exit 1
else
    echo "Source package is not present, creating it now"
    clean_sources
    create_source_package 
    # Don't change this line, it is used in other scripts to extract
    # the vm_version:
    echo "New version is: $VM_VERSION"
    exit 0
fi
