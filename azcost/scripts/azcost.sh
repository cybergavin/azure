#!/bin/bash
########################################################################################################################################
# Author            : cybergavin 
# Created On        : 8th July 2020
# Last Modified On  : 15th August 2021 
# Version History   : Refer Source Code Manager. 
# Description       : This script uses Azure CLI to obtain usage costs based on subscription, service, product, resource and tags for all tenants and subscriptions
#                     specified in a config file.
#                     PRE-REQUISITES: 
#                     ---------------
#                     (1) An Azure service principal with privileges associated with the "Billing Reader" role or higher, across all subscriptions
#                     within the given tenant.
#                     (2) The jq JSON parser on the host where this script is executed.
#
#########################################################################################################################################
#
# Determine Script Location and define variables
#
script_location="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
script_name=`basename $0`
ydate=$(date '+%Y-%m-%d' --date=yesterday)
install_root=${script_location}/..
script_dir=${install_root}/scripts
data_dir=${install_root}/data
raw_dir=${data_dir}/raw
processed_dir=${data_dir}/processed
conf_dir=${install_root}/conf
tenant_conf=${conf_dir}/tenant.cfg
log_dir=${install_root}/logs
logfile=${log_dir}/${script_name%%.*}.log
logfile_old=${log_dir}/${script_name%%.*}.log.old
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
        printf "$logtime : ${green}$1${nc} : $2\n\n"
    elif [ "$1" = "ERROR" ]; then
        printf "$logtime : ${red}$1${nc} : $2\n\n"
    fi
    if [ -s $logfile ]; then
        printf "$logtime : $1 : $2\n\n" >> $logfile
    else
        printf "$logtime : $1 : $2\n\n" > $logfile
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
        if [ -n "$3" ]; then
            $3
        fi 
    fi
}
#########################################################################################################################################
#
# MAIN
#
#########################################################################################################################################
#
# Directory Validation
#
for mydir in $data_dir $raw_dir $processed_dir $log_dir
do
  if [ ! -d $mydir ]; then
     mkdir $mydir
  fi
done
#
# Obtain usage data for all tenants
#
IFS=$'\n'
for line in `grep -v "^#" $tenant_conf`
do
    IFS=, read -ra fields <<< $line
    mytenant=${fields[0]}
    rawdata_file=${raw_dir}/${mytenant}_usagecost_${ydate}.csv
    cat /dev/null > $rawdata_file
    source ${conf_dir}/${mytenant}.creds
    az login --service-principal -u $client_id -p "$secret" --tenant $tenant > /dev/null
    checkStatus "Authenticated with Azure Tenant $mytenant" "Failed to authenticate with Azure Tenant $mytenant"
    for (( s=1; s< ${#fields[*]}; s++ ))
    do
       az account set -s "${fields[$s]}"
       checkStatus "Switched to subscription ${fields[$s]}" "Failed to switch to subscription ${fields[$s]}" "continue"
       az consumption usage list -s $ydate -e $ydate -o json | jq -jr '.[] |.subscriptionName,",",.consumedService,",",.product,",",.instanceName,",",.tags.CostCenter,",",.tags.Owner,",",.pretaxCost,"\n"' >> $rawdata_file
       checkStatus "Retrieved consumption usage for resources in subscription ${fields[$s]} for $ydate" "Failed to retrieve consumption usage for resources in subscription ${fields[$s]} for $ydate" 
    done
    # Process raw data
    awk 'BEGIN{ FS=OFS="," }{a[$2]+=$7 }END{for(i in a)print i","sprintf("%.2f",a[i]);}' $rawdata_file > ${processed_dir}/${mytenant}_costbyresourcetype_${ydate}.csv 
    awk 'BEGIN{ FS=OFS="," }{a[$4]+=$7 }END{for(i in a)print i","sprintf("%.2f",a[i]);}' $rawdata_file > ${processed_dir}/${mytenant}_costbyresource_${ydate}.csv 
    #
    # Logout
    #
    az logout
    checkStatus "Successfully logged out from Azure Tenant $mytenant" "FAILED to logout from Azure Tenant $mytenant"
done
#
# HouseKeep
#
houseKeep
