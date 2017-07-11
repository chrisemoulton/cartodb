#!/bin/bash

if [ $# -ne 1 ]; then
    echo "usage: bulk_delete_users.sh <usernames_file>"
    exit 3
fi

USERNAMES_FILE=$1
USERNAMES=($(cat $USERNAMES_FILE | tr "\n" " "))

for USERNAME in ${USERNAMES[@]}
do
    FORCE_DELETION_WOUT_PROMPT="true"
    bundle exec rake user:deletion:by_username["$USERNAME","$FORCE_DELETION_WOUT_PROMPT"]
    RC=$?
    if [ $RC -ne 0 ]; then
        echo "WARNING: bundle exec rake user:deletion:by_username['$USERNAME'] failed with RC=$RC"
    fi
done


