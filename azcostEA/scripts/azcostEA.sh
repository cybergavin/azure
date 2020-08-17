#!/bin/bash
########################################################################################################################################
# Author            : Cybergavin
# Created On        : 16th August 2020
# Last Modified On  : N/A
# Release           : azcostEA (refer README.md)
# Description       : This script obtains usage costs for an Azure Enterprise Agreement Agreement account (https://ea.azure.com)
#                     The usage costs are grouped and then sent to a remote graphite server for visualization in grafana.
#
#########################################################################################################################################
#
# Determine Script Location and define variables
#
if [ -n "`dirname $0 | grep '^/'`" ]; then
    script_location=`dirname $0`
elif [ -n "`dirname $0 | grep '^..'`" ]; then
    cd `dirname $0`
    script_location=$PWD
    cd - > /dev/null
else
    script_location=`echo ${PWD}/\`dirname $0\` | sed 's#\/\.$##g'`
fi
script_name=`basename $0`
if [ $1 ]; then
    ydate="$1"
else
    ydate=$(date '+%Y-%m-%d' --date=yesterday)
fi
install_root=${script_location}/..
script_dir=${install_root}/scripts
data_dir=${install_root}/data
raw_dir=${data_dir}/raw
rawjson=${raw_dir}/azure_usagecost_${ydate}.json
rawcsv=${raw_dir}/azure_usagecost_${ydate}.csv
processed_dir=${data_dir}/processed
subscription_file=${processed_dir}/azure_usagecost_${ydate}_subscription.csv
serviceprovider_file=${processed_dir}/azure_usagecost_${ydate}_serviceprovider.csv
service_file=${processed_dir}/azure_usagecost_${ydate}_service.csv
resourcegroup_file=${processed_dir}/azure_usagecost_${ydate}_resourcegroup.csv
conf_dir=${install_root}/conf
token_file=${conf_dir}/ea.token
cfg_file=${conf_dir}/${script_name%%.*}.cfg
log_dir=${install_root}/logs
logfile=${log_dir}/${script_name%%.*}.log
logfile_old=${log_dir}/${script_name%%.*}.log.old
reportserver="grafana.cybergav.in"
#########################################################################################################################################
#
# Functions
#
#########################################################################################################################################
#
# Logging
#
logMessage()
{
    green="\033[0;32m"
    red="\033[0;31m"
    nc="\033[0m" # no color
    logtime=`date '+%d-%b-%Y : %H:%M:%S'`
    if [ "$1" = "INFO" ]; then
        printf "$logtime : $HOSTNAME : ${green}$1${nc} : $2\n"
    elif [ "$1" = "ERROR" ]; then
        printf "$logtime : $HOSTNAME : ${red}$1${nc} : $2\n"
    fi
    if [ -s $logfile ]; then
        printf "$logtime : $HOSTNAME : $1 : $2\n" >> $logfile
    else
        printf "$logtime : $HOSTNAME : $1 : $2\n" > $logfile
    fi
}
#
# Clean up old stuff
#
houseKeep()
{
    if [ `wc -l $logfile | awk '{print $1}'` -ge 5000 ]; then
        mv $logfile $logfile_old
        if [ $? -eq 0 ]; then
            logMessage "INFO" "Rotated logfile (>= 5000 lines) to $logfile_old"
        else
            logMessage "ERROR" "Failed to rotate logfile (>= 5000 lines) to $logfile_old"
        fi
    fi
}
#
# Check exit code
#
checkStatus()
{
    if [ $? -eq 0 ]; then
        logMessage "INFO" "$1"
    else
        logMessage "ERROR" "$2"
        if [ "$3" ]; then
           eval "$3"
        fi
    fi
}
#########################################################################################################################################
#
# MAIN
#
#########################################################################################################################################
logMessage "INFO" "STARTING execution of $script_name"
#
# Validation
#
for mydir in $data_dir $raw_dir $processed_dir $log_dir
do
    if [ ! -d $mydir ]; then
        logMessage "INFO" "$mydir does not exist."
        mkdir $mydir
        checkStatus "Created directory $mydir" "Failed to create directory $mydir" "exit 911"
    fi
done
if [ ! -f $token_file ]; then
    logMessage "ERROR" "Missing token file $token_file . Cannot authenticate against EA account. Exiting!"
    exit 100
else
    token=$(cat $token_file)
    if [ -z "$token" ]; then
        logMessage "ERROR" "Cannot read token from token file $token_file . Cannot authenticate against EA account. Exiting!"
        exit 200
    fi
fi
if [ ! -f $cfg_file ]; then
    logMessage "ERROR" "Missing config file $cfg_file . Exiting!"
    exit 300
else
    source $cfg_file
fi
if [ -z "$enrollment_number" ]; then
        logMessage "ERROR" "Could not determine enrollment number from config file $conf_file . Exiting!"
        exit 400
fi
#
# Obtain usage data for EA account
#
http GET "https://consumption.azure.com/v3/enrollments/${enrollment_number}/usagedetailsbycustomdate?startTime=${ydate}&endTime=${ydate}" "Authorization: Bearer $token" > $rawjson
checkStatus "Obtained usage details for Cybergavin' EA account for $ydate" "Failed to obtain usage details for Cybergavin' EA account for $ydate" "exit 911"
#
# Convert json to csv
#
cat $rawjson | jq -jr '[.data[]]' | jq -jr '.[] |.subscriptionName,",",.consumedService,",",.serviceName,",",.product,",",.resourceGroup,",",.cost,"\n"' > $rawcsv
checkStatus "Parsed JSON and generated CSV" "Failed to parse JSON and generate CSV" "exit 911"
#
# Generate subscription data and send to graphite
#
awk 'BEGIN{ FS=OFS="," }{a[$1]+=$6 }END{for(i in a)print i","sprintf("%.2f",a[i]);}' $rawcsv > $subscription_file
checkStatus "Generated subscription data" "Failed to generate subscription data"
sed "s/ /_/g;s/^/azure\.subscription\./g;s/$/,`date "+%s" -d \"$ydate 23:59:59\"`/g;s/,/ /g" $subscription_file | nc $reportserver 2003
checkStatus "Sent subscription data to graphite server" "Failed to send subscription data to graphite server"
#
# Generate service provider data and send to graphite
#
awk 'BEGIN{ FS=OFS="," }{a[$2]+=$6 }END{for(i in a)print i","sprintf("%.2f",a[i]);}' $rawcsv > $serviceprovider_file
checkStatus "Generated service provider data" "Failed to generate service provider data"
sed "s/ /_/g;s/^/azure\.serviceprovider\./g;s/$/,`date "+%s" -d \"$ydate 23:59:59\"`/g;s/,/ /g" $serviceprovider_file | nc $reportserver 2003
checkStatus "Sent service provider data to graphite server" "Failed to send service provider data to graphite server"
#
# Generate resource group data and send to graphite
#
awk 'BEGIN{ FS=OFS="," }{a[$5]+=$6 }END{for(i in a)print i","sprintf("%.2f",a[i]);}' $rawcsv > $resourcegroup_file
checkStatus "Generated resource group data" "Failed to generate resource group data"
sed "s/ /_/g;s/^/azure\.resourcegroup\./g;s/$/,`date "+%s" -d \"$ydate 23:59:59\"`/g;s/,/ /g" $resourcegroup_file | nc $reportserver 2003
checkStatus "Sent resource group data to graphite server" "Failed to send resource group data to graphite server"
#
# Calculate total cost and send to graphite
#
totalcost=$(awk 'BEGIN{ FS=OFS="," }{tc=tc+$6}END{printf("%.2f",tc)}' $rawcsv)
echo "azure.totalcost $totalcost `date "+%s" -d \"$ydate 23:59:59\"`" | nc $reportserver 2003
checkStatus "Sent total cost $totalcost for $ydate to graphite server" "Failed to send total cost to graphite server"
#
# HouseKeep
#
houseKeep
logMessage "INFO" "COMPLETED execution of $script_name"