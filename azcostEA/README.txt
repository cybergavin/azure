###############################################################################################################################
#                                                                                                                             #
#                                                  azcostEA.sh  - cybergavin                                                  #
#                                                                                                                             #
###############################################################################################################################
If your organization uses Microsoft's Azure Cloud platform and has an Enterprise Agreement (EA) with Microsoft, then you may 
generate an API Access Key at https://ea.azure.com and use this key along with your enrollment number to obtain usage details
for your Azure resources across all EA subscriptions.

Microsoft's Azure Enterprise REST APIs are documented at https://docs.microsoft.com/en-us/azure/cost-management-billing/manage/ea-portal-rest-apis#:~:text=Microsoft%20Enterprise%20Azure%20customers%20can,from%20the%20Azure%20EA%20portal

At the time of this writing, Microsoft provides a Power BI connector (Azure Cost Management) to obtain reports/graphs on usage
 details, but this requires a Power BI Pro license.

By using Microsoft's Azure Enterprise REST APIs along with Grafana, you may build your own Cost Reporting dashboards.

azcostEA.sh is a simple bash shell script that does the following:

    *   Uses  Microsoft's Azure Enterprise REST APIs to obtain usage costs for an Azure Enterprise Agreement account.
    *   Parses the resulting JSON and generates CSV files containing specific fields.
    *   Sends data in the required format to a remote graphite/carbon server for subsequent visualization with Grafana.

================================
azcostEA DIRECTORY STRUCTURE
================================

azcostEA
├── conf
│   ├── azcostEA.cfg        --> Config file containing enrollment number and to be used for future enhancements
│   └── ea.token            --> Contains API access key (a long string) that was generated at https://ea.azure.com
├── data
│   ├── processed           --> Shall contain processed csv files for dispatch to graphite
│   └── raw                 --> Shall contain raw json and csv files
├── logs
│   └── azcostEA.log        --> Shall contain the script's log files
├── README.md               
└── scripts
    └── azcostEA.sh         --> The main bash shell script


================================
PRE-REQUISITES: 
================================
=>  An Enterprise Agreement (EA) Enrollment number
=>  An API Access Key for the EA account
=>  The jq JSON parser (https://stedolan.github.io/jq/)
=>  The httpie client (https://httpie.org/)

###############################################################################################################################