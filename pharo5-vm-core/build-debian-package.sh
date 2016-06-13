#!/bin/bash

set -e

source build.conf

function extract_source_package() {
    upstream_version="$1"
    echo "Extract ${PACKAGE_NAME}_${upstream_version}.orig.tar.bz2"
    rm -rf ${PACKAGE_NAME}-${upstream_version}/
    tar xfj ${PACKAGE_NAME}_${upstream_version}.orig.tar.bz2
}

function build() {
    upstream_version="$1"
    package_version="$2"
    distribution="$3"
    want_to_package_sources="$4"
    want_source_package="$5"

    root_directory="${PACKAGE_NAME}-${upstream_version}"
    echo "Copy debian/ directory to $root_directory"
    cp -R debian "${root_directory}/"
    cd "${root_directory}"

    echo "Update changelog"
    dch --distribution ${distribution} --local "-${package_version}~ppa1~${distribution}" "Build for ${distribution}"

    # Use this if you want to build a binary deb package directly
    #       -sa    Forces the inclusion of the original source.
    #       -sd    Forces the exclusion of the original source and includes only the diff.
    #       -us    Do not sign the source package.
    #       -uc    Do not sign the .changes file.
    #       -b     Specifies a binary-only build, limited to architecture dependent packages.  Passed to dpkg-genchanges.
    #       -S     Specifies a source-only build, no binary packages need to be made.  Passed to dpkg-genchanges.

    if [ $want_to_package_sources -eq 0 ]; then
        upload_sources="-sa"
    else
        upload_sources="-sd"
    fi

    if [ $want_source_package -eq 0 ]; then
        echo "Create a source package to delegate the build (to PPA for example)"
        debuild -k0x$PGP_KEY_ID -S ${upload_sources} --changes-option="-DDistribution=${distribution}"
    else
        echo "Create a binary package for immediate installation"
        debuild -k0x$PGP_KEY_ID -b ${upload_sources} -uc -us
    fi

    cd ..
}

function usage() {
    echo "Usage: $0 <package name> <upstream_version> <package_version> <distribution> [OPTIONS]"
    echo "Create the *.deb files"
    echo ""
    echo -e "  --binary\t if you want to build the package locally"
    echo -e "  --upload\t if you want to upload to the PPA"
    echo -e "          \t    (incompatible with --binary)"
    echo -e "  --no-sources\t if you already uploaded the orig.tar.gz package"
}

if [[ $# -lt 3 ]]; then
    usage
    exit 1
fi

upstream_version=$1
package_version=$2
distribution=$3

shift 3

if [ -z "$PACKAGE_NAME" -o -z "$upstream_version" -o -z "$package_version" -o -z "$distribution" ]; then
    usage
    exit 1
fi

want_source_package=0
want_ppa_upload=1
want_to_package_sources=0

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --binary)
            want_source_package=1
            want_ppa_upload=1
            want_to_package_sources=1
            ;;
        --upload)
            want_ppa_upload=0
            ;;
        --no-sources)
            want_to_package_sources=1
            ;;
        *)
            echo "Unknown option: " $1
            usage
            exit 1
            ;;
    esac
    shift
done


extract_source_package $upstream_version
build $upstream_version $package_version $distribution $want_to_package_sources $want_source_package

if [ $want_ppa_upload -eq 0 ]; then
    echo "uploading ${PACKAGE_NAME}_${upstream_version}-${package_version}~ppa1~${distribution}1_source.changes"
    dput ppa:$PPA ${PACKAGE_NAME}_${upstream_version}-${package_version}~ppa1~${distribution}1_source.changes
fi
