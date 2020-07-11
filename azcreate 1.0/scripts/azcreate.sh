#!/bin/bash
########################################################################################################################################
# Author            : cybergavin
# Created On        : 8th July 2020
# Last Modified On  : N/A
# Release           : azcreate 1.0 (refer README.txt)
# Description       : This script parses data files containing details about Azure Resources and creates them.
#                     This script accepts a single INPUT PARAMETER - the identifier of the Azure resource to be created
#                     The identifier of the Azure resource to be created must be specified in the azcreate.cfg file and 
#                     a corresponding data file (<azure_resource_identifier>.dat) must exist.
#
#########################################################################################################################################
#
# USAGE
#
if [ $# -ne 1 ]; then
    echo -e "\nERROR: Missing Parameter.\nUSAGE: azcreate.sh <AzureResource Identifier>\n"
    exit 100
fi
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
install_root=${script_location}/..
script_dir=${install_root}/scripts
data_dir=${install_root}/data
conf_dir=${install_root}/conf
temp_dir=${install_root}/temp
log_dir=${install_root}/logs
auditfile=${log_dir}/${script_name%%.*}_audit_`date '+%b%Y'`.log
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
# Create command-line switches with parameters for AZ CLI commands based on data files
#
azparams()
{
  my_azresource=$1
  my_datafile=${data_dir}/${my_azresource}.dat
  my_paramfile=${temp_dir}/${my_azresource}.params.$$
  cat /dev/null > $my_paramfile
  if [ ! -f ${my_datafile} ]; then
    logMessage "ERROR" "Missing data file ${my_datafile}."
  elif [ -z "`grep -v '^#' ${my_datafile} | awk -F, 'NR>1'`" ]; then # Exclude comments and the first record (header)
       logMessage "ERROR" "Empty data file ${my_datafile}."
  else
       azheaders=(`grep -v '^#' ${my_datafile} | head -1 | sed 's/,/ /g'`)
       dflc=0
       for line in `grep -v '^#' ${my_datafile} | awk -F, 'NR>1'` # Loop through resource datafile
         do
            dflc=$(( dflc + 1 ))
            my_azparams=""
            IFS=, read -ra fields <<< $line
            numfields=${#fields[*]}
            if [ $numfields -ne ${#azheaders[*]} ]; then
                logMessage "ERROR" "Number of fields in line $(( dflc + 1 )) do not match number of headers in $my_datafile"
                continue
            fi
            for (( p=0; p<$numfields; p++ ))
              do
                if [ -n "${fields[$p]}" ]; then
                    if [ -n "`echo ${fields[$p]} | grep '#'`" ]; then
                        my_azparams+="--${azheaders[$p]} `echo ${fields[$p]}|awk -F# '{for(i=1;i<=NF;i++)print $i}'` "
                    else
                        my_azparams+="--${azheaders[$p]} ${fields[$p]} "
                    fi
                fi
              done
              echo $my_azparams >> $my_paramfile
         done    
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
    if [ -d $log_dir ]; then
        find $log_dir -type f -name "*audit*.log" -mtime +365 | xargs -i rm -f {}
    fi
    if [ -d  $temp_dir ]; then
       rm -f ${temp_dir}/*.$$
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
    fi
    if [ -n "$3" ]; then
       exit $3
    fi 
}
#########################################################################################################################################
#
# MAIN
#
#########################################################################################################################################
#
# Validation
#
az_resource=$1
if [ ! -f ${conf_dir}/${script_name%%.*}.cfg ]; then
   logMessage "ERROR" "Missing configuration file ${conf_dir}/${script_name%%.*}.cfg . Exiting!"
   exit 100
fi
if [ -z "`grep -v \"^#\" ${conf_dir}/${script_name%%.*}.cfg | awk -v g=$az_resource -F, '$1 == g'`" ]; then
   logMessage "ERROR" "Missing resource $az_resource in configuration file ${conf_dir}/${script_name%%.*}.cfg . Exiting!"
   exit 200
fi
if [ ! -f ${data_dir}/${az_resource}.dat ]; then
   logMessage "ERROR" "Missing data file (${data_dir}/${az_resource}.dat) for Azure resource ${az_resource}. Exiting!"
   exit 300
fi
#
# Authenticate with Azure
#
echo -en "\nEnter your Azure account username  : "
read username
echo -en "\nEnter your Azure account password  : "
read -s userpass
az login -u $username -p "$userpass" > /dev/null
echo -en "\n\n"
checkStatus "Azure authentication successful for $username" "Azure authentication FAILED for $username"
#
# Create Azure Resource
#
azparams $az_resource # Call function to generate az cli switches
while IFS= read -r cmdparams
do
    azcommand=`grep -v "^#" ${conf_dir}/${script_name%%.*}.cfg | awk -v g=$az_resource -F, '$1 == g {print $NF}'`
    azresdesc=`grep -v "^#" ${conf_dir}/${script_name%%.*}.cfg | awk -v g=$az_resource -F, '$1 == g {print $2}'`
    azcommand+=" create $cmdparams"
    $azcommand
    if [ $? -eq 0 ]; then
        az_created_resource=`echo $cmdparams | awk '{for(i=1; i<=NF; i++) if($i=="--name") print $(i+1)}'`
        logMessage "INFO" "Successfully created Azure resource $az_created_resource"
        echo "`date` : AUDIT : USER=$username : COMMAND=$azcommand" >> $auditfile
    else
        logMessage "ERROR" "FAILED to create Azure resource $az_created_resource"
    fi
done < $my_paramfile
#
# HouseKeep
#
houseKeep
#
# Logout
#
az logout
checkStatus "$username has been logged out of Azure" "$username has FAILED to logout from Azure"