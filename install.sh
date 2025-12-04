#!/bin/bash
# Copyright 2022 Proyectos y Sistemas de Mantenimiento SL (eProsima).
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Exit on command failure
set -e
shopt -s globstar

SCRIPT_DIR=`cd -- \`dirname -- $0\`; pwd`

: ${CC:=cc} ${CXX:=c++}
export CC CXX
export CFLAGS='-O0 -g0 -Os '$CFLAGS    CXXFLAGS='-Wno-deprecated-literal-operator -O0 -g0 -Os '$CXXFLAGS

export SHYNUR_CMAKE_VARS='-DSECURITY=OFF -DNO_TLS=ON '
SHYNUR_CMAKE_VARS+=' -DSHM_TRANSPORT_DEFAULT=OFF '  # 默认不使用共享内存通信.
SHYNUR_CMAKE_VARS+=' -DFASTDDS_STATISTICS=OFF -DSTRICT_REALTIME=OFF -DSQLITE3_SUPPORT=OFF '
SHYNUR_CMAKE_VARS+=' -DLOG_NO_INFO=OFF -DFASTDDS_ENFORCE_LOG_INFO=ON -DLOG_NO_WARNING=OFF '
SHYNUR_CMAKE_VARS+=' -DLOG_NO_ERROR=OFF '
SHYNUR_CMAKE_VARS+=" -DINTERNAL_DEBUG=${FASTDDS_INTERNAL_DEBUG:=ON} "
SHYNUR_CMAKE_VARS+=' -DCOMPILE_EXAMPLES=OFF -DINSTALL_EXAMPLES=OFF -DBUILD_DOCUMENTATION=OFF '
SHYNUR_CMAKE_VARS+=' -DCHECK_DOCUMENTATION=OFF '
SHYNUR_CMAKE_VARS+=" -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE:=Debug} -DCMAKE_C_FLAGS='$CFLAGS' -DCMAKE_CXX_FLAGS='$CXXFLAGS' "

#if [ -f /etc/apt/sources.list ]; then
#    sed -i 's/\(archive\|security\)\.ubuntu\.com/mirrors.cloud.aliyuncs.com/g' /etc/apt/sources.list
#fi
apt update
DEBIAN_FRONTEND=noninteractive apt install -y tzdata
ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
dpkg-reconfigure --frontend noninteractive tzdata

apt install -y wget make openjdk-11-jre-headless git python3 emacs-nox cpp

git config --global --add safe.directory \*

if ! type cmake || [ 3.31 = `cmake --version | head -n 1 | awk '{print $3"\n3.31"}' | sort -V -r | head -n 1` ]; then
    $SCRIPT_DIR/cmake-3.31.9-linux-$HOSTTYPE.sh --prefix=/usr/local --exclude-subdir
fi

if [ 18.04 = `cat /etc/os-release | grep VERSION_ID | awk -F'"' '{print \$2}'` ]; then
  if [ -f /usr/local/include/asio.hpp ] &&
    [ `$CXX -dM -E /usr/local/include/asio/version.hpp | egrep ASIO_VERSION'[[:space:]]' | awk '{print $3}'` -ge 101202 ]; then
      :
  else
    (
       cd /tmp
       rm -rf asio*
       wget https://github.com/chriskohlhoff/asio/archive/refs/tags/asio-1-12-2.tar.gz
       tar zxf asio*.tar.gz
       cd asio*/asio/include
       rm -rf /usr/local/include/asio{.hpp,/}
       mv asio.hpp asio/ /usr/local/include
    )
  fi
fi

print_usage()
{
    echo "-----------------------------------------------------"
    echo "Bootstrap script for building and installing Fast DDS"
    echo "-----------------------------------------------------"
    echo "GENERAL FLAGS:"
    echo "   -h | --help                 Print help"
    echo "   --no-install-dependencies   Do not install apt dependencies"
    echo "   --no-shared-libs            Do not compile shared libraries"
    echo "   --no-static-libs            Do not compile static libraries. This option is"
    echo "                               incompatible with '--no-shared-libs'"
    echo "   --build-cores               Number of cores used to build. Passed to CMake with -j"
    echo "                               [Defaults: 1]"
    echo
    exit ${1}
}

parse_options()
{
    INSTALL_DEPENDENCIES="TRUE"
    COMPILE_SHARED_LIBS="TRUE"
    COMPILE_STATIC_LIBS="TRUE"
    SECURITY="ON"
    INSTALL_PREFIX=${INSTALL_PREFIX:=/usr/local}
    INSTALL_EXAMPLES="OFF"
    BUILD_CORES="1"

    # Validate options
    if ! options=$(getopt \
        --name 'install.sh' \
        --options h \
        --longoption \
            help,no-install-dependencies,no-shared-libs,no-static-libs,build-cores: \
        -- "$@")
    then
        print_usage 1
    fi

    eval set -- "${options}"

    while true
    do
        case "${1}" in
            # General flags
            -h | --help                     ) print_usage 0;;
            --no-install-dependencies       ) INSTALL_DEPENDENCIES="FALSE"; shift;;
            --no-shared-libs                ) COMPILE_SHARED_LIBS="FALSE"; shift;;
            --no-static-libs                ) COMPILE_STATIC_LIBS="FALSE"; shift;;
            --build-cores                   ) BUILD_CORES="${2}"; shift 2;;
            # End mark
            -- ) shift; break ;;
            # Wrong args
            * ) echo "Unknown option: '${1}'" >&2; print_usage 1;;
        esac
    done

    if [ ${COMPILE_SHARED_LIBS} == "FALSE" ] && [ ${COMPILE_STATIC_LIBS} == "FALSE" ]
    then
        echo "Cannot use both '--no-shared-libs' and '--no-static-libs'"
        print_usage 1
    fi

    SHARED_LIBS_OPTIONS=""
    if [[ ${COMPILE_SHARED_LIBS} == "TRUE" ]]
    then
        SHARED_LIBS_OPTIONS="ON"
    fi

    if [[ ${COMPILE_STATIC_LIBS} == "TRUE" ]]
    then
        SHARED_LIBS_OPTIONS="${SHARED_LIBS_OPTIONS} OFF"
    fi

    if ! test "${BUILD_CORES}" -gt 0 2> /dev/null
    then
        echo "Value '${BUILD_CORES}' passed with --build-cores is not a possitive integer"
        print_usage 1
    fi

    if [[ ! -d ${INSTALL_PREFIX} ]]
    then
        mkdir -p ${INSTALL_PREFIX}
    fi
}

main()
{
    parse_options ${@}

    # Determine if apt-get is available
    if [[ ${INSTALL_DEPENDENCIES} == "TRUE" ]]
    then
        # Install dependencies
        apt install --yes --no-install-recommends \
            libssl-dev \
	    `[ 18.04 != \`cat /etc/os-release | grep VERSION_ID | awk -F'"' '{print \$2}'\` ] && echo libasio-dev` \
            libtinyxml2-dev
    fi

    # Build and install foonthan memory
    mkdir -p ${SCRIPT_DIR}/build/foonathan_memory_vendor
    cd ${SCRIPT_DIR}/build/foonathan_memory_vendor
    bash -c "cmake -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX} $SHYNUR_CMAKE_VARS ${SCRIPT_DIR}/src/foonathan_memory_vendor"
    cmake --build . --target install -j ${BUILD_CORES}
    cd -

    for SHARED_LIBS_OPTION in ${SHARED_LIBS_OPTIONS}
    do
        # Build and install Fast CDR
        mkdir -p ${SCRIPT_DIR}/build/fastcdr
        cd ${SCRIPT_DIR}/build/fastcdr
        bash -c "cmake -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX} -DBUILD_SHARED_LIBS=${SHARED_LIBS_OPTION} $SHYNUR_CMAKE_VARS ${SCRIPT_DIR}/src/fastcdr"
        cmake --build . --target install -j ${BUILD_CORES}
        cd -

        # Build and install Fast DDS
        mkdir -p ${SCRIPT_DIR}/build/fastdds
        cd ${SCRIPT_DIR}/build/fastdds
        bash -c "cmake -DCMAKE_PREFIX_PATH=${INSTALL_PREFIX} -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX} -DBUILD_SHARED_LIBS=${SHARED_LIBS_OPTION} -DSECURITY=${SECURITY} -DCOMPILE_EXAMPLES=${INSTALL_EXAMPLES} -DINSTALL_EXAMPLES=${INSTALL_EXAMPLES} $SHYNUR_CMAKE_VARS ${SCRIPT_DIR}/src/fastdds"
        cmake --build . --target install -j ${BUILD_CORES}
        cd -

        # Remove build directories
        rm -rf ${SCRIPT_DIR}/build
    done

    # Install Fast DDS-Gen
    mkdir -p ${INSTALL_PREFIX}/share/fastddsgen/java
    _SHYNUR_FASTDDSGEN_REPO_PARENT=/tmp/shynur/fastddsgen-$RANDOM/
    (
	mkdir -p $_SHYNUR_FASTDDSGEN_REPO_PARENT
	cd $_SHYNUR_FASTDDSGEN_REPO_PARENT
	git clone https://git.shynur.fun/eProsima/Fast-DDS-Gen
	cd Fast-DDS-Gen
	git checkout 8ab13bea6d6edaa7c16d2d275053b94c0d524da4
	./gradlew assemble
    )
    cp $_SHYNUR_FASTDDSGEN_REPO_PARENT/Fast-DDS-Gen/share/fastddsgen/java/fastddsgen.jar ${INSTALL_PREFIX}/share/fastddsgen/java
    cp $_SHYNUR_FASTDDSGEN_REPO_PARENT/Fast-DDS-Gen/scripts/fastddsgen ${INSTALL_PREFIX}/bin/
}

main ${@}
