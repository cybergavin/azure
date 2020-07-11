###################################################################################################################
#          ~~~~~~~~~  azcreate v1.0  ~~~~~~~~~ 
# Bulk creation of Azure resources using Azure CLI
# Uses az cli "create" commands to create one or more Azure resource across one or more subscriptions within a tenant
# 
####################################################################################################################

USING azcreate:
---------------

(1) Create an entry in conf/azcreate.cfg for the type of azure resource (e.g. resource group) to be created, if not already present.

(2) Create a data file data/<resource identifier>.dat, if not already present, where <resource identifier> is the same identifier present in conf/azcreate.cfg.

(3) Populate the data file with details of the resource(s) to be created. The column headings must be valid command-line switches used in the az cli command.
    For example, as per https://docs.microsoft.com/en-us/cli/azure/group?view=azure-cli-latest#az-group-create , for the azure resource group,
    valid column headings are location, name, managed-by, subscription and tags (at the current time). You may define column headings
    only for the command parameters that you wish to use.

    ****NOTE:**** 
        * Every data file must have a subscription column.
        * The number of fields in every record must match the number of column headings. If you don't wish to populate some fields
          for some resources,use consecutive commas to omit them. 
          Example: column headings => subscription,name,location,tags
                         no tags   => testsub,test,canadacentral,,
(4) Execute scripts/azcreate.sh <resource identifier> to create the relevant azure resources.

######################################################################################################################
