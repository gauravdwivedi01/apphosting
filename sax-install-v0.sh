#!/bin/bash
# Script to Install StreamAnalytix @ HDInsight EdgeNode !!!
application_name=StreamAnalytix
CLUSTER_NAME=$1
HDI_ADMIN=$2
HDI_PWD=$3
isDownloadDone=false
SAX_DOWNLOAD_CHECKSUM="0f6ce145d4094eab62d1ea76e6eb5a30"
SAX_DOWNLOAD_LINK="https://arrival.streamanalytix.com/nextcloud/index.php/s/E9oFxj5e92dFAYA/download"
SAX_DEPENDENCY_DOWNLOAD_LINK="https://raw.githubusercontent.com/gauravdwivedi01/apphosting/master/sax-dependencies-install-v0.sh"
SAX_CONF_DOWNLOAD_LINK="https://raw.githubusercontent.com/gauravdwivedi01/apphosting/master/sax-yaml-configure-v01.sh"
SAX_ENV_CONF_DOWNLOAD_LINK="https://raw.githubusercontent.com/gauravdwivedi01/apphosting/master/env-config.yaml"
#JQ_DOWNLOAD_LINK="https://github.com/gauravdwivedi01/AppHostingShell/blob/master/jq.zip"
SAX_HOME="/saxHdInsightApp/"
SAX_DOWNLOAD_JAR_NAME="StreamAnalytix-3.1.5-SNAPSHOT.tar.gz"
SAX_DEPENDENCY_SHELL_NAME="sax-dependencies-install-v0.sh"
SAX_CONF_SHELL_NAME="sax-yaml-configure-v01.sh"
#JQ_ZIP_NAME="jq.zip"
SAX_DOWNLOAD_BUNDLE_PATH="$SAX_HOME$SAX_DOWNLOAD_JAR_NAME"
SAX_DEPENDENCY_SHELL_PATH="$SAX_HOME$SAX_DEPENDENCY_SHELL_NAME"
SAX_INSTALLATION_DIR="$SAX_HOME$application_name"
EMBEDDED_MODE="-deployment.mode=embedded"
#java_home=$JAVA_HOME
java_home=$(awk -F"=" '$1 ~ /^export JAVA_HOME$/{print$2}' ~/.bashrc)
echo "--------------------------------------------------------------------------------"
echo "JAVA_HOME is - $java_home"
echo "Installing StreamAnalytix HDInsight Cluster's EdgeNode with user : $(whoami) "
echo "Today :  $(date)"
echo "EdgeNode hostname : $(hostname) & ip is $(hostname -i)"
echo "HDInsight Cluster Name : $CLUSTER_NAME" 
echo "HDInsight Cluster Admin Name : $HDI_ADMIN" 
echo "HDInsight Cluster Admin Password  : $HDI_PWD" 
echo "--------------------------------------------------------------------------------"

## retry function ##
# Retries a command on failure.
# $1 - the max number of attempts
# $2... - the command to run
retry() {
    local -r -i max_attempts="$1"; shift
    local -r cmd="$@"
    local -i attempt_num=1

    until $cmd
    do
        if (( attempt_num == max_attempts ))
        then
            echo "Attempt $attempt_num failed and there are no more attempts left!"
            return 1
        else
            echo "Attempt $attempt_num failed! Trying again in $attempt_num seconds..."
            sleep $(( attempt_num++ ))
        fi
    done
}

#create SAX_HOME directory if needed
if [ -d "$SAX_HOME" ]; then
  echo "SAX_HOME $SAX_HOME already exists, removing directory !!"
  rm -rf "$SAX_DOWNLOAD_BUNDLE_PATH"
  mkdir -p "$SAX_HOME"
    
  	if [ -d "$SAX_HOME" ]; then
  		echo " SAX_HOME $SAX_HOME directory created successfully.."
  	fi
  else	
	echo " SAX_HOME $SAX_HOME does not exists, creating directory.."
	mkdir -p "$SAX_HOME"   
        
fi

# downloading StreamAnalytix bundle
if ! $isDownloadDone ; then
	echo " downloading StreamAnalytix bundle at $SAX_HOME !!"
	retry 3 wget -O "$SAX_DOWNLOAD_BUNDLE_PATH" "$SAX_DOWNLOAD_LINK"
	downloadedFieChksum=$(md5sum "$SAX_DOWNLOAD_BUNDLE_PATH" | cut -d ' ' -f 1)
	echo downloadedFieChksum value is "$downloadedFieChksum" And linuxChecksum value is "$SAX_DOWNLOAD_CHECKSUM  !!"
	if [ $downloadedFieChksum = $SAX_DOWNLOAD_CHECKSUM ] ; then
		echo "StreamAnalytix Downloaded bundle checksum is correct , download success !!"
	else
		echo "StreamAnalytix Download bundle checksum is incorrect, please connect to app publisher !!"
	fi
	
fi

# untar StreamAnalytix bundle
echo "SAX_DOWNLOAD_BUNDLE_PATH is $SAX_DOWNLOAD_BUNDLE_PATH !!"
if [ -f "$SAX_DOWNLOAD_BUNDLE_PATH" ]
	then
	echo "$SAX_DOWNLOAD_BUNDLE_PATH exists at edge node $SAX_HOME !!"
	cd "$SAX_HOME"
	echo "Untar StreamAnalytix bundle !!"
	#jar xf "$SAX_DOWNLOAD_JAR_NAME"
	tar -xzf "$SAX_DOWNLOAD_JAR_NAME"
	echo "Untar StreamAnalytix bundle completed !!"
	
	echo "Untar tomcat !!"
	cd "$SAX_INSTALLATION_DIR/server"
	tar -xzf tomcat.tar.gz
	echo "Untar tomcat completed !!"

	echo "Moving StreamAnalytix.war jar to server/tomcat/webapps !!"
	mv $SAX_INSTALLATION_DIR/lib/StreamAnalytix.war $SAX_INSTALLATION_DIR/server/tomcat/webapps/
	echo "Successfully moved StreamAnalytix.war jar to server/tomcat/webapps !!"
	
	#templates/azure-template/cloud-conf-template.yaml
	cd /saxHdInsightApp/StreamAnalytix/conf/yaml
	mkdir -p /templates/azure-template/
	wget -O cloud-conf-template.yaml $SAX_ENV_CONF_DOWNLOAD_LINK
        else
		echo "$SAX_DOWNLOAD_JAR_NAME not found in $SAX_HOME !!"
fi

## Install & Configure StreamAnalytix dependencies 
echo "Installing StreamAnalytix dependencies with user : $(whoami)  & $SAX_HOME !!"
cd "$SAX_HOME"
retry 3 wget -O "$SAX_DEPENDENCY_SHELL_NAME" "$SAX_DEPENDENCY_DOWNLOAD_LINK"
chmod 755 $SAX_DEPENDENCY_SHELL_NAME
"./sax-dependencies-install-v0.sh"
echo "Installing StreamAnalytix dependencies completed !! "


## Configure env-conf.yaml & config.properties file of StreamAnalytix 
echo "Configuring StreamAnalytix env-conf.yaml & config.properties with user : $(whoami) !!"
cd "$SAX_HOME"
retry 3 wget -O "$SAX_CONF_SHELL_NAME" "$SAX_CONF_DOWNLOAD_LINK"
chmod 755 $SAX_CONF_SHELL_NAME
./sax-yaml-configure-v0.sh $CLUSTER_NAME $HDI_ADMIN $HDI_PWD
echo "Installing StreamAnalytix dependencies completed !! "

# Starting StreamAnalytix WebApp
echo "+ Starting StreamAnalytix WebApp with user : $(whoami)  !!"
#permission required to start embedded services of streamanalytix else we run into permission issues.
chown -R root:root "$SAX_INSTALLATION_DIR"
cd "$SAX_INSTALLATION_DIR/bin"
echo "Current StreamAnalytix directory : $PWD  !!"
#updating JAVA_HOME @ startServicesServer.sh 
sed -i "s|HEAP_DUMP_DIR=heapDump|HEAP_DUMP_DIR=heapDump;JAVA_HOME=$java_home|g" startServicesServer.sh
echo "Updated JAVA_HOME at serverStart script !!"

#starting tomcat server 
echo "Starting SAx server !!"
./startServicesServer.sh

echo "StreamAnalytix Installation completed successfully at HDInsight cluster's edgeNode !!"

echo "----------------------------------------------------------------------"






