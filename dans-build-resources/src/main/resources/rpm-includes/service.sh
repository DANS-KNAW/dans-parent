#@IgnoreInspection BashAddShebang

exit_if_failed() {
    local MESSAGE=$1
    local EXIT_STATUS=${2:-1}

    if [ $? -ne 0 ]; then
       echo "FAILED: $MESSAGE."
       exit $EXIT_STATUS
    fi
}

warn_if_failed() {
    local MESSAGE=$1

    if [ $? -ne 0 ]; then
        echo "WARNING: $MESSAGE."
    fi
}

service_is_systemd_controlled() {
   pidof systemd > /dev/null && echo -n 1 || echo -n 0
}

service_is_initd_controlled() {
    # According to this post https://unix.stackexchange.com/questions/121654/convenient-way-to-check-if-system-is-using-systemd-or-sysvinit-in-bash
    # it should be possible to establish that initd is controlling the system by checking that /sbin/init has pid 1. However it
    # seems that when running as root /sbin/init has pid 1 even though systemd is running. Possibly it is just an alias of systemd in that case.
    # We therefore use the absence of systemd as the criterion for initd being in charge.
    pidof systemd > /dev/null && echo -n 0 || echo -n 1
}

service_save_restart_memo() {
    # Parameters
    local SERVICE_NAME=$1

    # Constants
    local RESTART_MEMO="/tmp/$SERVICE_NAME-restart-memo"

    if [ -d /tmp ]; then
        echo -n "Service is running; /tmp found; creating memo to restart service after upgrade..."
        touch $RESTART_MEMO
        echo "OK"
    fi
}

service_stop() {
    # Parameters
    local SERVICE_NAME=$1
    local NUMBER_OF_INSTALLATIONS=$2

    # If the package has not been installed yet, there is no need to attempt stopping the service.
    if [ $NUMBER_OF_INSTALLATIONS -gt 1 ]; then
        if (( $(service_is_systemd_controlled) )); then
            systemctl status $SERVICE_NAME 2> /dev/null 1> /dev/null
            local STATE=$?

            if [ $STATE -eq 0 ]; then # Service is running
               service_save_restart_memo $SERVICE_NAME
               echo -n "Attempting to stop service..."
               systemctl stop $SERVICE_NAME 2> /dev/null 1> /dev/null
               exit_if_failed "Could not stop service $SERVICE_NAME"
               echo "OK"
            fi
        else # we assume it is initd-controlled
            # Depends on the output of the status command. This should end in "is running." or "is stopped."
            local STATE=$(service $SERVICE_NAME status | sed  's/^.*is \(.*\)\.$/\1/')

            if [ "$STATE" == "running" ]; then
               service_save_restart_memo $SERVICE_NAME
               echo -n "Attempting to stop service..."
               service $SERVICE_NAME stop  2> /dev/null 1> /dev/null
               exit_if_failed "Could not stop service $SERVICE_NAME"
               echo "OK"
            fi
        fi
    fi
}

# Attempts to stop the service under all conditions. Does NOT safe a restart memo
service_stop_unconditional() {
    # Parameters
    local SERVICE_NAME=$1

    if (( $(service_is_systemd_controlled) )); then
        systemctl status $SERVICE_NAME 2> /dev/null 1> /dev/null
        local STATE=$?

        if [ $STATE -eq 0 ]; then # Service is running
           echo -n "Attempting to stop service..."
           systemctl stop $SERVICE_NAME 2> /dev/null 1> /dev/null
           exit_if_failed "Could not stop service $SERVICE_NAME"
           echo "OK"
        fi
    else # we assume it is initd-controlled
        # Depends on the output of the status command. This should end in "is running." or "is stopped."
        local STATE=$(service $SERVICE_NAME status | sed  's/^.*is \(.*\)\.$/\1/')

        if [ "$STATE" == "running" ]; then
           echo -n "Attempting to stop service..."
           service $SERVICE_NAME stop  2> /dev/null 1> /dev/null
           exit_if_failed "Could not stop service $SERVICE_NAME"
           echo "OK"
        fi
    fi
}

service_restart() {
    # Parameters
    local SERVICE_NAME=$1

    # Constants
    local RESTART_MEMO="/tmp/$SERVICE_NAME-restart-memo"

    if [ -f $RESTART_MEMO ]; then
        echo -n "Found restart memo; attempting to start service..."
        rm $RESTART_MEMO

        if (( $(service_is_systemd_controlled) )); then
            systemctl daemon-reload
            systemctl start $SERVICE_NAME 2> /dev/null 1> /dev/null
            warn_if_failed "Could not restart service $SERVICE_NAME after upgrade"
            echo "OK"
        else
            service $SERVICE_NAME start 2> /dev/null 1> /dev/null
            warn_if_failed "Could not restart service $SERVICE_NAME after upgrade"
            echo "OK"
        fi
    fi
}

service_create_module_user() {
    # Parameters
    local MODULE_OWNER=$1

    # Getting the user ID of a non-existent user will result in exit status 1.
    # We do not want to see the error messages, so we redirect them to the memory hole.
    id -u $1 2> /dev/null 1> /dev/null

    if [ "$?" == "1" ]; # User not found
    then
        echo -n "Creating module user: $MODULE_OWNER..."
        useradd --system $MODULE_OWNER 2> /dev/null
        exit_if_failed "Unable to create user $MODULE_OWNER."
        echo "OK"
    else
        echo "Module user $MODULE_OWNER already exists. No action taken."
    fi
}

service_install_initd_service_script() {
    # Parameters
    local SCRIPT=$1
    local MODULE_NAME=$2

    # Constants
    local INITD_SCRIPTS_DIR="/etc/init.d"

    if (( $(service_is_initd_controlled) )); then
        echo -n "Installing initd service script..."
        cp $SCRIPT $INITD_SCRIPTS_DIR/$MODULE_NAME
        exit_if_failed "Unable to copy initd service script."
        chmod o+x $INITD_SCRIPTS_DIR/$MODULE_NAME
        exit_if_failed "Unable to make service script executable for owner"
        echo "OK"
    fi
}

service_remove_initd_service_script() {
    # Parameters
    local MODULE_NAME=$1
    local NUMBER_OF_INSTALLATIONS=$2

    # Constants
    local INITD_SCRIPTS_DIR="/etc/init.d"

    if ([ $NUMBER_OF_INSTALLATIONS -eq 0 ] && [ -f $INITD_SCRIPTS_DIR/$MODULE_NAME ]); then
        service_stop_unconditional $MODULE_NAME

        echo -n "Removing initd service script..."
        rm $INITD_SCRIPTS_DIR/$MODULE_NAME
        warn_if_failed "initd service script could not be removed: $INITD_SCRIPTS_DIR/$MODULE_NAME."
        echo "OK"
    fi
}

service_install_systemd_unit() {
    # Parameters
    local UNIT_FILE=$1
    local MODULE_NAME=$2
    local DROP_IN_FILE=$3

    # Constants
    local SYSTEMD_SCRIPTS_DIR="/usr/lib/systemd/system"
    local SYSTEMD_DROP_INS_PARENT_DIR="/etc/systemd/system"

    if (( $(service_is_systemd_controlled) )); then
        echo -n "Installing systemd unit file..."
        cp $UNIT_FILE $SYSTEMD_SCRIPTS_DIR/
        exit_if_failed "Could not copy systemd unit file."
        echo "OK"

        if [ $# -gt 2 ]; then
            echo -n "Installing drop-ins..."
            local DROP_IN_DIR="$SYSTEMD_DROP_INS_PARENT_DIR/$MODULE_NAME.service.d/"
            if [ ! -d $DROP_IN_DIR ]; then
                mkdir $DROP_IN_DIR
            fi
            cp $DROP_IN_FILE $DROP_IN_DIR
            exit_if_failed "Could not install drop-ins."
            echo "OK"
        fi
    fi
}

service_remove_systemd_unit() {
    # Parameters
    local MODULE_NAME=$1
    local NUMBER_OF_INSTALLATIONS=$2

    # Constants
    local SYSTEMD_SCRIPTS_DIR="/usr/lib/systemd/system"
    local SYSTEMD_DROP_INS_PARENT_DIR="/etc/systemd/system"

    if ([ $NUMBER_OF_INSTALLATIONS -eq 0 ] && [ -f $SYSTEMD_SCRIPTS_DIR/${MODULE_NAME}.service ]); then
        service_stop_unconditional $MODULE_NAME

        echo -n "Removing systemd unit file..."
        rm $SYSTEMD_SCRIPTS_DIR/${MODULE_NAME}.service
        warn_if_failed "systemd unit file could not be removed: $SYSTEMD_SCRIPTS_DIR/${MODULE_NAME}.service"

        local DROP_IN_DIR="$SYSTEMD_DROP_INS_PARENT_DIR/$MODULE_NAME.service.d/"
        if [ -d $DROP_IN_DIR ]; then
            rm -fr $DROP_IN_DIR
            warn_if_failed "systemd drop-in directory at $DROP_IN_DIR could not be removed."
        fi
        echo "OK"
    fi
}

service_create_log_directory() {
    # Parameters
    local MODULE_NAME=$1

    # Constants
    local LOG_BASE="/var/opt/dans.knaw.nl/log"
    local LOG_DIR="$LOG_BASE/$MODULE_NAME"

    if [ ! -d $LOG_DIR ]; then
        echo -n "Creating directory for logging..."
        mkdir -p $LOG_DIR
        exit_if_failed "Could not create directory for logging at $LOG_DIR"
        echo "OK"
    fi

    echo -n "Making sure logging directory is owned by service user..."
    chown $MODULE_NAME $LOG_DIR
    exit_if_failed "Could not change ownership of $LOG_DIR to $MODULE_NAME."
    echo "OK"
}
