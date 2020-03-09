#!/bin/sh

# TODO: describe parameters 


BASE_URL="${1}:${2}"
PASSWORD=$3
USERNAME=$4
GLOBAL_ZONE=${4}.CSI
ZONE=$5
ZOSMF_SYSTEM=$6
TMP=${7}/export
PSI_NAME=$8
NEW_DSN=${9}.PSI.EXPORT
NEW_PDS_VOLUME=${10}
# TODO: JOBSTATEMENT=?

# JSONs      
ADD_SWI_JSON='{"name":"'${PSI_NAME}'","system":"'${ZOSMF_SYSTEM}'","description":"Zowe Portable Software Instance",
      "globalzone":"'${GLOBAL_ZONE}'","targetzones":["'${ZONE}'"]}'
  
EXPORT_JCL_JSON='{“packagedir”:“'${TMP}'”,“jcldataset”:“'${NEW_DSN}'”,“jobstatement”:[“ZWEPSI01 JOB”],)'

NEW_PDS_JSON='{"volser":"'${NEW_PDS_VOLUME}'","unit":"3390","dsorg":"PS","alcunit":"TRK","primary":10,"secondary":5,
      "avgblk":500,"recfm":"FB","blksize":400,"lrecl":80}'

# URLs     
ADD_SWI_URL="${BASE_URL}/zosmf/swmgmt/swi"
LOAD_PRODUCTS_URL="${BASE_URL}/zosmf/swmgmt/swi/${ZOSMF_SYSTEM}/${PSI_NAME}/products"
EXPORT_JCL_URL="${BASE_URL}/zosmf/swmgmt/swi/${ZOSMF_SYSTEM}/${PSI_NAME}/export"
NEW_PDS_URL="${BASE_URL}/zosmf/restfiles/ds/${NEW_DSN}"
SUBMIT_JOB_URL="${BASE_URL}/zosmf/restjobs/jobs"

# TODO: check if SWI already exists

# Adding Software Instance
curl -s $ADD_SWI_URL -k -X "POST" -v -d "$ADD_SWI_JSON" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $USERNAME:$PASSWORD -f
if [ $? -gt 0 ]
then
  echo "Adding Software Instance failed."
  exit -1
fi

# Load the products, features, and FMIDs for a software instance
# The response is in format "statusurl":"https:\/\/:host:post\/restofurl"
# On statusurl can be checked actual status of loading the products, features, and FMIDs
LOAD_STATUS_URL=`curl -s $LOAD_PRODUCTS_URL -k -X "PUT" -v -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $USERNAME:$PASSWORD -f | grep -o '"statusurl":".*"' | cut -f4 -d\" | tr -d '\'`

# URL is empty if any of the commands failed
if [ "$LOAD_STATUS_URL" == "" ]
then
  echo "Load Products call failed."
  exit -1
fi

STATUS=""

# Checking the actual status of loading the products until the status is not "complete"
until [ "$STATUS" == "complete" ]
do
STATUS=`curl -s $LOAD_STATUS_URL -k -X "GET" -v -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $USERNAME:$PASSWORD -f | grep -o '"status":".*"' | cut -f4 -d\"`
if [ "$STATUS" == "" ]
then
  echo "Status of loading products failed."
  exit -1
fi
sleep 10    
done

# TODO: Check if dataset already exists, if yes modify name
# Creating Data Set that will contain Export JCL
curl -s $NEW_PDS_URL -k -X "POST" -d "$NEW_PDS_JSON"-v -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $USERNAME:$PASSWORD -f
if [ $? -gt 0 ]
then
  echo "Creation of temporary dataset failed."
  exit -1
fi

# Creating JCL that will export Portable Software Instance
# The response is in format "statusurl":"https:\/\/:host:post\/restofurl"
EXPORT_STATUS_URL=`curl -s $EXPORT_JCL_URL -k -X "POST" -d "$EXPORT_JCL_JSON" -v -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $USERNAME:$PASSWORD -f | grep -o '"statusurl":".*"' | cut -f4 -d\" | tr -d '\'`
if [ "$EXPORT_STATUS_URL" == "" ]
then
  echo "Generation of Export JCL failed."
  exit -1
fi
