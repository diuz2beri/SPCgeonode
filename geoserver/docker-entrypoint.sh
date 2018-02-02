#!/bin/sh

# Exit script in case of error
set -e

printf '\n--- START Geoserver Docker Entrypoint ---\n'

# TODO : see if we can have startup.sh exit on error
# (eg. when starting before django migrations, the user tables are missing)

# Run migrations
printf '\nInitializing data dir\n'
if test "$(ls -A "/spcgeonode-geodatadir/")"; then
    printf 'Geodatadir not empty, skipping initialization...\n'
else
    printf 'Geodatadir empty, we run initialization...\n'

    # We launch once geoserver to generate initial data (such as root password and default setup)
    # We give it 180 seconds to launch (note : it is usually OK after 100-120 s on my slow and old machine)
    printf '\n\nWe launch Geoserver for the first time... it has 180 seconds to initialize all important files...\n'
    set +e # for some reason, timeout exits with error 143
    timeout -t 180 -s SIGTERM bin/startup.sh
    set -e

    printf '\n\n\n\n\n\nWe killed Geoserver. Now we check if important files exist...\n'
    if [ ! -f /spcgeonode-geodatadir/security/masterpw/default/passwd ]; then
        printf '\n\nMissing important files ! Initialization failed. We remove everything to start over...\n'
        rm -rf /spcgeonode-geodatadir/*
        exit 1
    fi

    printf '\n\nWe remove the plain text password\n'
    rm -rf /spcgeonode-geodatadir/security/masterpw.info

    printf '\n\nWe replace folders from our config\n'
    rm -rf /spcgeonode-geodatadir/security/auth
    rm -rf /spcgeonode-geodatadir/security/filter
    rm -rf /spcgeonode-geodatadir/security/role
    rm -rf /spcgeonode-geodatadir/security/usergroup
    rm -rf /spcgeonode-geodatadir/security/config.xml
    rm -rf /spcgeonode-geodatadir/workspaces/

    cp -Rf /geodatadir-overrides/. /spcgeonode-geodatadir/

    # WE DON'T USE THIS. THIS WOULD BE NEEDED TO UPDATE THE ROOT PASSWORD IF WE PROVIDE AN EXISTING DATA DIR
    # BUT IT DOESN'T WORK COMPLETELY (CAN'T LOGIN ANYMORE). I THINK IT'S BECAUSE EACH PASSWORD IN THE KEYSTORE
    # MUST BE REENCRYPTED INDIVIDUALLY

    # # Update the keystore main password
    # keytool -storepasswd -new '123456' -keystore /spcgeonode-geodatadir/security/geoserver.jceks -storetype JCEKS -storepass 'sKLgISITTbzDLyLboJO6'

    # # Update the digest
    # (printf "digest1:" && /usr/lib/jvm/java-1.8-openjdk/jre/bin/java -classpath /geoserver-2.12.1/webapps/geoserver/WEB-INF/lib/jasypt-1.8.jar org.jasypt.intf.cli.JasyptStringDigestCLI digest.sh algorithm=SHA-256 saltSizeBytes=16 iterations=100000 input='123456' verbose=0) | tr -d '\n' > /spcgeonode-geodatadir/security/masterpw.digest_test

    # # Save the encrypted password
    # The key ( 5lp6`U#!rxUuH%nILQqnr3XQPnJd5X$lUFT)cXUU ) is generated by this strange code here, which is hardcoded.:  https://github.com/geoserver/geoserver/blob/e4817074ef05fe96f446e8f3ca7449c6c4f95b65/src/main/src/main/java/org/geoserver/security/password/URLMasterPasswordProvider.java
    # /usr/lib/jvm/java-1.8-openjdk/jre/bin/java -classpath /geoserver-2.12.1/webapps/geoserver/WEB-INF/lib/jasypt-1.8.jar org.jasypt.intf.cli.JasyptPBEStringEncryptionCLI input="123456" password='5lp6`U#!rxUuH%nILQqnr3XQPnJd5X$lUFT)cXUU' verbose=0 | tr -d '\n' > /spcgeonode-geodatadir/security/masterpw/default/passwd_test    

fi
 
printf '\n--- END Geoserver Docker Entrypoint ---\n\n'

# Run the CMD 
exec "$@"
