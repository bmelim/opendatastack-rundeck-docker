#!/bin/bash

if [ "$1" = 'rundeck' ]
then

    mkdir -p /data/etc/ssl /data/ssh /data/projects /var/lib/rundeck/.ssh
    chown rundeck:rundeck /data/etc /data/ssh /data/projects /var/lib/rundeck/.ssh

    # Rundeck configuration initial files if not present in the volume
    for FILE in `find /root/rundeck-config/ -type f | xargs -I TMP echo "TMP" | cut -d'/' -f4- -`
    do
      # If is not in the volume we copied the initial and linked to etc
      if [ ! -f /data/etc/$FILE ]
      then
        cp -rv /root/rundeck-config/$FILE /data/etc/$FILE
        chown -v rundeck:rundeck /data/etc/$FILE
      fi
      if [ -f /etc/rundeck/$FILE ]
      then
        rm -v /etc/rundeck/$FILE
      fi
      ln -sv /data/etc/$FILE /etc/rundeck/$FILE
    done

    # Special case initial realm.properties
    if [ ! -f /data/etc/realm.properties ]
    then
      envtpl -o /data/etc/realm.properties --allow-missing --keep-template /root/rundeck-config-templates/realm.properties
      chown -v rundeck:rundeck /data/etc/realm.properties
    fi
    rm -v /etc/rundeck/realm.properties
    ln -sv /data/etc/realm.properties /etc/rundeck/realm.properties

    # Configure rundeck via envtpl
    rm -v /etc/rundeck/rundeck-config.properties
    envtpl -o /etc/rundeck/rundeck-config.groovy --allow-missing --keep-template /root/rundeck-config-templates/rundeck-config.groovy
    chown -v rundeck:rundeck /etc/rundeck/rundeck-config.groovy

    # Configure profile
    cp -v /root/rundeck-config-templates/profile /etc/rundeck/profile
    chown -v rundeck:rundeck /etc/rundeck/profile

    # Configure ssh
    cp -v /root/rundeck-config-templates/config_ssh /var/lib/rundeck/.ssh/config
    chown -v rundeck:rundeck /var/lib/rundeck/.ssh/config
    ln -s /data/ssh/id_rsa /var/lib/rundeck/.ssh/id_rsa

    echo "starting rundeck service..."
    service rundeckd start

    touch /var/log/rundeck/rundeck.log
    chown -v rundeck:adm /var/log/rundeck/rundeck.log

    sleep 60

    echo "Import Rundeck Jobs from /root/jobs/."

    export RD_URL='http://127.0.0.1:4440'
    export RD_USER="admin"
    export RD_PASSWORD=$RUNDECK_INITIAL_ADMIN_PASSWORD

    rd projects list --outformat "%name" | \grep -c $RUNDECK_DEFAULT_PROJECT > /dev/null 2>&1 \
        || rd projects create --project $RUNDECK_DEFAULT_PROJECT

    for JOB_FILE in `ls /root/jobs`
    do
        rd jobs load \
        --project $RUNDECK_DEFAULT_PROJECT \
        --file /root/jobs/$JOB_FILE \
        --format 'yaml' \
        --duplicate "update"
    done

    tail -f /var/log/rundeck/rundeck.log

    # stop service and clean up here
    echo "stopping rundeck service..."
    service rundeckd stop
    echo "exited $0"
else
    exec "$@"
fi

