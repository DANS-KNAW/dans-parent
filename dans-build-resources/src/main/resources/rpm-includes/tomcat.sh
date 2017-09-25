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

tomcat_start() {
    sudo service start tomcat
    exit_if_failed "Tomcat could not be started"
}

tomcat_create_log_directory() {
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
    chown -R tomcat:tomcat $LOG_DIR
    exit_if_failed "Could not change ownership of $LOG_DIR to tomcat."
    echo "OK"
}
