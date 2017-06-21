#@IgnoreInspection BashAddShebang

service_stop() {
    # Parameters
    local SERVICE_NAME=$1
    local NUMBER_OF_INSTALLATIONS=$2

    # If the package has not been installed yet, there is no need to attempt stopping the service.
    if [ $NUMBER_OF_INSTALLATIONS -gt 0 ]; then
        echo -n "Attempting to stop service..."
        service $SERVICE_NAME stop  2> /dev/null 1> /dev/null
        if [ $? -ne 0 ]; then
            systemctl stop $SERVICE_NAME 2> /dev/null 1> /dev/null
        fi
    fi
    echo "OK"
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

        if [ $? -ne 0 ]; then
            echo "FAILED"
            echo "Unable to create user $MODULE_OWNER."
            exit 1
        fi

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

    if [ -d $INITD_SCRIPTS_DIR ]; then
        echo -n "Installing initd service script..."
        cp $SCRIPT $INITD_SCRIPTS_DIR/$MODULE_NAME

        if [ $? -ne 0 ]; then
            echo "FAILED"
            echo "Unable to copy initd service script."
            exit 1
        fi

        chmod o+x $INITD_SCRIPTS_DIR/$MODULE_NAME

        if [ $? -ne 0 ]; then
            echo "FAILED"
            echo "Unable to make service script executable for owner"
            exit 1
        fi

        echo "OK"
    fi
}

service_remove_initd_service_script() {
    # Parameters
    local MODULE_NAME=$1

    # Constants
    local INITD_SCRIPTS_DIR="/etc/init.d"

    if [ -f $INITD_SCRIPTS_DIR/$MODULE_NAME ]; then
        echo -n "Removing initd service script..."
        rm $INITD_SCRIPTS_DIR/$MODULE_NAME

        if [ $? -ne 0 ]; then
            echo "WARNING: initd service script could not be removed: $INITD_SCRIPTS_DIR/$MODULE_NAME."
        fi

        echo "OK"
    fi
}

service_install_systemd_unit() {
    # Parameters
    local UNIT_FILE=$1

    # Constants
    local SYSTEMD_SCRIPTS_DIR="/usr/lib/systemd/system"

    if [ -d $SYSTEMD_SCRIPTS_DIR ]; then
        echo -n "Installing systemd unit file..."
        cp $UNIT_FILE $SYSTEMD_SCRIPTS_DIR/

        if [ $? -ne 0 ]; then
            echo "FAILED"
            echo "Could not copy systemd unit file."
            exit 1
        fi

        echo "OK"
    fi
}

service_remove_systemd_unit() {
    # Parameters
    local MODULE_NAME=$1

    # Constants
    local SYSTEMD_SCRIPTS_DIR="/usr/lib/systemd/system"

    if [ -f $SYSTEMD_SCRIPTS_DIR/${MODULE_NAME}.service ]; then
        echo -n "Removing systemd unit file..."
        rm $SYSTEMD_SCRIPTS_DIR/${MODULE_NAME}.service

        if [ $? -ne 0 ]; then
            echo "WARNING: systemd unit file could not be removed: $SYSTEMD_SCRIPTS_DIR/${MODULE_NAME}.service"
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

    echo -n "Creating directory for logging..."
    mkdir -p $LOG_DIR

    if [ $? -ne 0 ]; then
        echo "FAILED"
        echo "Could not create directory for logging at $LOG_DIR"
        exit 1
    fi

    chown $MODULE_NAME $LOG_DIR

    if [ $? -ne 0 ]; then
        echo "FAILED"
        echo "Could not change ownership of $LOG_DIR to $MODULE_NAME."
        exit 1
    fi

    echo "OK"
}