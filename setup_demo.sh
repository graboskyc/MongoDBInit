#!/bin/bash

ulimit -n 4096
#
# setup demo environment:
# (1) download all required software, this will ensure that vagrant servers
#     don't need to do this
# (2) startup instances
#
# NOTE: Only support for centos
#
# arguments:
# -a - One of 4 supported authentication mechanisms
#      (1) scram:     enable scram authentication (DEFAULT)
#      (2) kerberose: enable kerberos authentication (NOT IMPLEMENTED YET)
#      (3) ldap:      enable LDAP authentication (NOT IMPLEMENTED YET)
#      (4) x509:      enable x509 authentication support (NOT IMPLEMENTED YET)
#
# -s - enable ssl
# -c - create a 3-node sharded cluster
#
# TODO: fix arguments
#

#=============================================================================#
# VARIABLES
#=============================================================================#
MDB_URL="http://downloads.10gen.com/linux"
MDB_VERS=`cat ./conf/om_variables.json | grep MDB_DEMO_VERSION | awk -F\" '{print $4}'`

OPS_URL="https://downloads.mongodb.com/on-prem-mms/tar"
OPS_VER=`cat ./conf/om_variables.json | grep MDB_OM_DEMO_VERSION | awk -F\" '{print $4}'`
OPS_FILE="mongodb-mms-${OPS_VER}.x86_64.tar.gz"

CACHE_DIR="./shared/cache"
KEYTABS_DIR="./shared/keytabs"
LOGS_DIR="./shared/logs"
YUM_DIR="./shared/yum"

# global variable
VALID_FILE="OK"
IS_ERR="OK"
CMD_ERR=""
AUTH="scram"
SSL="disabled"
CLUSTER="rs"
#=============================================================================#
# FUNCTIONS
#=============================================================================#

#
# log_exit()
# log message and exit
#
function log_exit(){
    echo "log_exit(): ${1}"
    exit 1
}

#
# f_mkdir()
# function wrapping mkdir - just for troubleshooting if needed
#
function f_mkdir() {
    echo "f_mkdir(): attempting to make directory - ${1}"
    ret=`mkdir -p ${1}; echo $?`
    [[ ${ret} -eq 0 ]] && echo "f_mkdir(): success(ret:${ret})" || echo "f_mkdir(): failed(ret:${ret})"
}

#
# validate_dirs()
# validate that core directories exist, if not mkdir
#
function validate_dirs() {
    echo "validate_dirs(): attempting to validate/create required directories"
    [[ ! -d ${CACHE_DIR} ]] && f_mkdir ${CACHE_DIR}     # ./shared/cache - binaries and checksums
    [[ ! -d ${KEYTABS_DIR} ]] && f_mkdir ${KEYTABS_DIR} # ./shared/keytabs - kerberos keytab files
    [[ ! -d ${LOGS_DIR} ]] && f_mkdir ${LOGS_DIR}       # ./shared/logs - log data for troubleshooting
    [[ ! -d ${YUM_DIR} ]] && f_mkdir ${YUM_DIR}         # ./shared/yum - cached yum packages (time reducer)
}

#
# download_and_create_cksum()
# download file and create checksum to validate later when rebuilding
#
# NOTE:
# the use of echo in a bash function will alsox act as a return and all
# data will be passed back to the caller, because of this no echos
# in this function
#
function download_and_create_cksum() {
    url=${1}
    tar_file=${2}
    cksum_file=${3}
    curl ${url}/${tar_file} -s -o ${CACHE_DIR}/${tar_file}
    if [[ `tar tvvf ${CACHE_DIR}/${tar_file} &> /dev/null; echo $?` == 0 ]]; then
        # valid file, create hash
        shasum ${CACHE_DIR}/${tar_file} > ${CACHE_DIR}/${cksum_file}
        if [[ ${tar_file} =~ .*enterprise.* ]]; then
            tar xzf ${CACHE_DIR}/${tar_file} --directory ${CACHE_DIR}
        fi
        echo "OK"
    else
        rm -rf ${CACHE_DIR}/${tar_file}
        echo "ERR"
    fi
        
}

#
# download_mdb()
# attempt to download an individual mongo db version to the ${CACHE_DIR}
# if the file and checksum do not exist in the cache or anything is inconsistent, such as
# an invalid tar or bad checksum, download the file
#
function download_software() {
    url=${1}
    package=${2}
    cksum=${3}
    ret="OK"
    echo "download_software(): attempting to validate ${package} from ${url} using checksum ${cksum}"
    # does file and checksum exist?
    if [ -f ${CACHE_DIR}/${package} ] && [ -f ${CACHE_DIR}/${cksum} ]; then
        # did checksum fail?
        echo "download_software(): found package(${package}) and checksum(${cksum})"
        if [[ `shasum -cs ${CACHE_DIR}/${cksum}; echo $?` != 0 ]]; then
            echo "download_software(): invalid checksum, will attempt to download again"
            ret=`download_and_create_cksum ${url} ${package} ${cksum}`
        else
            echo "download_software(): cache is consistent, no download needed"
        fi
    else
        echo "downlaod_software(): did not find package(${package}) and/or checksum(${cksum}), will download file"
        ret=`download_and_create_cksum ${url} ${package} ${cksum}`        
    fi
    
    if [[ ${ret} != "OK" ]]; then
        echo "download_software(): ERROR - failed to download ${package} from ${url}"
        IS_ERR="ERR"
    else
        echo "download_software(): successfully validated ${package}"
    fi
    echo "download_software(): finished"
}

#
# download()
# start the download of the required packages
#
function download() {
    echo "download(): Attempting to get required software"
    # attempt to validate mongodb version
    for VER in ${MDB_VERS}; do
        download_software ${MDB_URL} "mongodb-linux-x86_64-enterprise-rhel70-${VER}.tgz" "checksum.${VER}" &
    done
    download_software ${OPS_URL} ${OPS_FILE} "checksum.${OPS_VER}" &
    wait
    [[ ${IS_ERR} == "ERR" ]] && log_exit "${0} cannot continue, downloads did not complete successfully"
    echo "download(): finished download attempts"
}

function ops_mgr_up() {
    # ops manager
    echo "ops_mgr_up(): Attempting to start opsmgr instance, logging to ./shared/logs/opsmgr.vagrant_up.log"
    vagrant up opsmgr &> ./shared/logs/opsmgr.vagrant_up.log &
    o_pid=`echo $!`
    job_cmd=`ps auwwwx | grep ${o_pid} | grep vagrant | grep -v grep | awk '{out=$11; for(i=12;i<=NF;i++){out=out" "$i}; print out}'`
    echo "ops_mgr_up(): setup running(job:${job_cmd}) - please wait a few minutes"
    wait ${o_pid}
    job_status=$?
    [[ ${job_status} != 0 ]] && log_exit "ops_mgr_up(): startup failed(status:${job_status}), see ./shared/logs/opsmgr.vagrant_up.log"
    echo "ops_mgr_up(): startup succeeded(job status:${job_status})"
}

function mdb_hosts_up() {
    # MDB hosts
    declare -a v_jobs
    pids=""
    for i in 1 2 3; do
        vagrant up "${mdb_host}${i}" &> ./shared/logs/${mdb_host}${i}.vagrant_up.log &
        pid=`echo $!`
        j_cmd=`ps auwwwx | grep ${pid} | grep vagrant | grep -v grep | awk '{out=$11; for(i=12;i<=NF;i++){out=out" "$i}; print out}'`
        pids="${pid} ${pids}"
        v_jobs[${pid}]=${j_cmd}
        echo "Started ${mdb_host}${i} vagrant instance (pid:${pid}), please review ./shared/logs/${mdb_host}${i}.vagrant_up.log"
        sleep 5
    done
    for pid in ${pids}; do
        v_job=`echo "${v_jobs["${pid}"]}"`
        echo "mdb setup running(job:${v_job}): please wait a few minutes"
        wait $pid
        job_status=$?
        if [[ ${job_status} != 0 ]]; then
            echo "failure: job(${v_job}) failed to execute, please troubleshoot and re-run command"
            IS_ERR="ERR"
            CMD_ERR="(${v_job}:FAILURE)${CMD_ERR}"
        fi
    done    
}

function loader_up(){
    # Loader
    vagrant up loader&> ./shared/logs/loader.vagrant_up.log &
    l_pid=`echo $!`
    job_cmd=`ps auwwwx | grep ${l_pid} | grep -v grep | awk '{out=$11; for(i=12;i<=NF;i++){out=out" "$i}; print out}'`
    echo "loader setup running(job:${job_cmd}): please wait a few minutes"
    wait ${l_pid}
    job_status=$?
    if [[ ${job_status} != 0 ]]; then
        echo "loader instance startup failed(job status: ${job_status}), please see ./shared/logs/loader.vagrant_up.log"
        IS_ERR="ERR"
    else 
        echo "loader instance startup succeeded(job status:${job_status}) finished vagrant builds"
    fi    
}

function vagrant_up() {
    echo "vagrant_up(): attempting to start systems"
    vagrant destroy -f
    sleep 5
    ops_mgr_up
    mdb_hosts_up
    loader_up
    # final validation
    if [[ ${IS_ERR} == "ERR" ]]; then
        echo "FAILED COMMANDS: ${CMD_ERR}"
        echo "provisioned demo environment with some failures - see logs might be able to salvage"
    else
        echo "Successfully provisioned demo environment"
    fi
}

#=============================================================================#
# MAIN SCRIPT
#=============================================================================#

# defaults to scram!
mdb_host="mdbscram"

# parse args
while [[ ${1} ]]; do
    case ${1} in
        -a | --auth)
            auth=${2}
            shift 2
            [[ ${auth} == "scram" ]] && mdb_host="mdbscram"
            [[ ${auth} == "ldap" ]] && mdb_host="mdbldap"
            [[ ${auth} == "kerberos" ]] && mdb_host="mdbgssapi"
            [[ ${auth} == "x509" ]] && mdb_host="mdbx509"
            ;;
#        -s | --ssl)
#            ssl="enabled"
#            ;;
#        -c | --cluster)
#            cluster="cluster"
#            ;;
        -h | --help)
#            echo "usage: ./setup_demo.sh -a [scram|ldap|kerberos|x509] [-s -c]"
            echo "usage: ./setup_demo.sh -a [scram|ldap|kerberos|x509]"
            exit 1
            ;;
        *)
#            echo "invalid option - usage: ./setup_demo.sh -a [scram|ldap|kerberos|x509] [-s -c]"
            echo "invalid option - usage: ./setup_demo.sh -a [scram|ldap|kerberos|x509]"
            exit 1
            ;;
    esac
done

validate_dirs
download

echo "continuing to build systems (copying required libraries and destroying old instances)"
cp -R ../mongo_mgr_rest ./shared/
[[ $? -ne 0 ]] && log_exit "${0} cannot continue, did not copy require ruby files (cp -R ../mongo_mgr_rest ./shared failed)"

vagrant_up

echo ""
echo "======================================================="
OM_URL=`cat ./conf/om_variables.json | grep OM_URL | awk -F\" '{print $4}'`
OM_ADMIN=`cat ./conf/om_variables.json | grep OM_ADMIN | awk -F\" '{print $4}'`
OM_PASSWORD=`cat ./conf/om_variables.json | grep OM_PASSWORD | awk -F\" '{print $4}'`
OM_API=`cat ./shared/.APIKEY`
echo "opsmgr url:    ${OM_URL}"
echo "opsmgr user:   ${OM_ADMIN}"
echo "opsmgr pwd:    ${OM_PASSWORD}"
echo "group api key: ${OM_API}"
echo "======================================================="
echo ${auth} > ./shared/.AUTH_MECH
echo ${ssl} > ./shared/.SSL
echo ${cluster} > ./shared/.CLUSTER

exit 0
