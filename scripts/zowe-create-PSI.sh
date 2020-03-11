#!/bin/sh

# TODO: describe parameters 
if [[ $# -ne 12 ]] 
then
echo; echo $SCRIPT Usage:
cat <<EndOfUsage
$SCRIPT 

   Parameter subsitutions:
 
   Parm name	  Value used	               Meaning
   ---------    ----------                 -------
 1  host	      https://zosmfhost          zOSMF host address
 2  port	      10443                      Port where zOSMF is running
 3  password	  password  
 4  username	    
 5  CSI HLQ	    ZOE.SMP   	               ZOWE CSI's HLQ
 6  targetzone  TZONE                      Name of target zone
 7  system      S0W1                       zOSMF System Nickname
 8  export_path /tmp/export/	             Directory where will be Portable Software Instance
 9  psi_name    ZOWE_Software_Instance	   Name for Software Instance
 10 psidsn	    ZOE.EXPORT                 Dataset name where will be stored JCL for PSI export
 11 volser	    B3PRD3                     Volume for psidsn
 12 sshPort     22                         SSH port
EndOfUsage
exit
fi
#TODO check default ssh port

BASE_URL="${1}:${2}"
PASSWORD=$3
USERNAME=$4
GLOBAL_ZONE=${5}.CSI
ZONE=$6
ZOSMF_SYSTEM=$7
TMP=${8}
PSI_NAME=$9
NEW_DSN=${10}.PSI.EXPORT
NEW_PDS_VOLUME=${11}
SSHPORT = ${12}
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

STATUS=""

# Checking the actual status of generating JCL until the status is not "complete"
until [ "$STATUS" == "complete" ]
do
# Status is not shown until the recentage is not 100 
PERCENTAGE=`curl -s $EXPORT_STATUS_URL -k -X "GET" -v -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $USERNAME:$PASSWORD -f | grep -o '"percentcomplete":".*"' | cut -f4 -d\"`
if [ PERCENTAGE == 100 ]
then
  RESP = `curl -s $EXPORT_STATUS_URL -k -X "GET" -v -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $USERNAME:$PASSWORD -f`
  STATUS = `echo $RESP | grep -o '"status":".*"' | cut -f4 -d\"`
  DSN = `echo $RESP | grep -o '"jcl":[".*"]' | cut -f4 -d\"`
  if [ "$STATUS" != "complete" ]
  then
    echo "Status of generation of Export JCL failed."
    exit -1
  fi
  if [ "$DSN" == "" ]
  then
    echo "There is no DSN in the response available."
    exit -1
  fi
fi
if [ "$PERCENTAGE" == "" ]
  then
  echo "Checking status of generation of Export JCL failed."
  exit -1
fi
sleep 10    
done

# Submit the Export JCL
SUBMIT_JOB_JSON='{"file": "//${DSN}"}'

JOB_STATUS_URL=`curl -s $SUBMIT_JOB_URL -k -X "PUT" -d "$SUBMIT_JOB_JSON" -v -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $USERNAME:$PASSWORD -f | grep -o '"url":".*"' | cut -f4 -d\" | tr -d '\'`
if [ "$JOB_STATUS_URL" == "" ]
  then
  echo "Submit of Export JCL failed."
  exit -1
fi

# Check status of submitted job from the previous step
STATUS = ""

until [ "STATUS" == "OUTPUT" ]
do
RESP = `curl -s $JOB_STATUS_URL -k -X "GET" -v -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $USERNAME:$PASSWORD -f`
STATUS = `echo $RESP | grep -o '"status":".*"' | cut -f4 -d\"`
if [ "$STATUS" == "" ]
  then
  echo "Couldn't get the job status."
  exit -1
fi
done

# Check return code
RC = `echo $RESP | grep -o '"retcode":".*"' | cut -f4 -d\"`

if [ "$RC" != "CC 0000" ]
then
    echo "Return code of Export job is "$RC
fi

# Pax the directory 
HOST = ${1}
#TODO Probably find something different if .ssh is not set
ssh -o StrictHostKeyChecking=no $USERNAME@$HOST "pax -wvz -o saveext -s#${TMP}## -f Zowe.pax.Z ./${TMP}*"
#TODO Download - can be over ftp or scp

#TODO Probably find something different if .ssh is not set
ssh -o StrictHostKeyChecking=no $USERNAME@$HOST "rm -r ${TMP}"
