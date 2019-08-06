#
# utils/mdb.sh
# utility script used by config_os.sh for configuring mongodb deployments
#
#

#
# create_mongod-usr()
# all systems will have the mongod users setup
#
function create_mongod_usr(){
    log "create_mongod_usr(): attempting to create mongod user"
    RET=`useradd mongod -m -d /home/mongod -U; echo $?`
    check_for_cmd_err ${RET} "useradd (utils/mdb.sh:create_mongod_usr())"
}

#
# create_data_dirs()
# create required data directories
#
function create_data_dirs(){
    install_target=$1
    log "create_data_dirs(): attempting to create data dirs for target(${INSTALL_TARGET})"
    RET=`mkdir /data; echo $?`
    check_for_cmd_err ${RET} "mkdir /data (utils/mdb.sh:create_data_dirs())"
    RET=`chown mongod:mongod /data; echo $?`
    check_for_cmd_err ${RET} "chown /data (utils/mdb.sh:create_data_dirs())"
    if [[ ${install_target} == "OM" ]]; then
        log "create_data_dirs(): attempting to create require data directories for ops manager"
        RET=`mkdir /head; echo $?`
        check_for_cmd_err ${RET} "mkdir /head (utils/mdb.sh:create_data_dirs())"
        RET=`chown mongod:mongod /head; echo $?`
        check_for_cmd_err ${RET} "chown /head (utils/mdb.sh:create_data_dirs())"
        RET=`mkdir /fsbackup; echo $?`
        check_for_cmd_err ${RET} "mkdir /fsbackup (utils/mdb.sh:create_data_dirs())"
        RET=`chown mongod:mongod /fsbackup; echo $?`
        check_for_cmd_err ${RET} "chown /fsbackup (utils/mdb.sh:create_data_dirs())"
    fi
    log "create_data_dirs(): successfully created data dirs for target(${INSTALL_TARGET})"
}

#
# enable_automation_agent()
# deploy automation agent to target system
#
function enable_automation_agent() {
    log "enable_automation_agent(): preparing automation agent for host"    
    AUTO_AGENT=`cat /shared/.AUTOMATION`
    check_for_cmd_err $? "read /shared/.AUTOMATION (utils/mdb.sh:enable_automation_agent())"
    APIKEY=`cat /shared/.K_API`
    check_for_cmd_err $? "read /shared/.K_API (utils/mdb.sh:enable_automation_agent())"
    GROUPID=`cat /shared/.GROUPID`
    check_for_cmd_err $? "read /shared/.GROUPID (utils/mdb.sh:enable_automation_agent())"
    OM_URL=`cat /shared/.OM_URL`
    check_for_cmd_err $? "read /shared/.OM_URL (utils/mdb.sh:enable_automation_agent())"
    curl -s -L -O ${AUTO_AGENT} > /dev/null
    check_for_cmd_err $? "download agent - curl (utils/mdb.sh:enable_automation_agent())"
    rpm -U `echo ${AUTO_AGENT} | sed -e 's/.*\/\(.*rpm$\)/\1/'`
    check_for_cmd_err $? "install agent - rpm (utils/mdb.sh:enable_automation_agent())"
    mkdir -p /data
    chown mongod:mongod /data
    sed -e "s/^mmsApiKey=/mmsApiKey=$APIKEY/" -i /etc/mongodb-mms/automation-agent.config
    sed -e "s/^mmsGroupId=/mmsGroupId=$GROUPID/" -i /etc/mongodb-mms/automation-agent.config
    sed -e "s#^mmsBaseUrl=#mmsBaseUrl=$OM_URL#" -i /etc/mongodb-mms/automation-agent.config

    service mongodb-mms-automation-agent start
    check_for_cmd_err $? "starting agent - service (utils/mdb.sh:enable_automation_agent())"

    log "enable_automation_agent(): automation agent installed"
}
