#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2020
################################################################################

################################################################################
# This script will run component `validate` and `configure` step if they are defined.
#
# This script take these parameters
# - c:    INSTANCE_DIR
# - t:    a list of component IDs separated by comma
#
# For example:
# $ bin/internal/prepare-workspace.sh \
#        -c "/path/to/my/zowe/instance" \
#        -t "discovery,explorer-jes,jobs"
################################################################################

# if the user passes INSTANCE_DIR from command line parameter "-c"
while getopts "c:t:" opt; do
  case $opt in
    c) INSTANCE_DIR=$OPTARG;;
    t) LAUNCH_COMPONENTS=$OPTARG;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

########################################################
# prepare environment variables
export ROOT_DIR=$(cd $(dirname $0)/../../;pwd)
. ${ROOT_DIR}/bin/internal/prepare-environment.sh -c "${INSTANCE_DIR}"

########################################################
# Validate component properties if script exists
ERRORS_FOUND=0
for component_id in $(echo $LAUNCH_COMPONENTS | sed "s/,/ /g")
do
  component_dir=$(find_component_directory "${component_id}")
  # FIXME: change here to read manifest `commands.validate` entry
  VALIDATE_SCRIPT=${component_dir}/bin/validate.sh
  if [ ! -z "${component_dir}" -a -x "${VALIDATE_SCRIPT}" ]; then
    . ${VALIDATE_SCRIPT}
    retval=$?
    let "ERRORS_FOUND=$ERRORS_FOUND+$retval"
  fi
done
# exit if there are errors found
checkForErrorsFound

########################################################
# Prepare workspace directory
mkdir -p ${WORKSPACE_DIR}
# Make accessible to group so owning user can edit?
chmod -R 771 ${WORKSPACE_DIR}

# Copy manifest into WORKSPACE_DIR so we know the version for support enquiries/migration
cp ${ROOT_DIR}/manifest.json ${WORKSPACE_DIR}

# Keep config dir for zss within permissions it accepts
# FIXME: this should be moved to zlux/bin/configure.sh
if [ -d ${WORKSPACE_DIR}/app-server/serverConfig ]
then
  chmod 750 ${WORKSPACE_DIR}/app-server/serverConfig
  chmod -R 740 ${WORKSPACE_DIR}/app-server/serverConfig/*
fi

########################################################
# Prepare workspace directory - manage active_configuration.cfg
mkdir -p ${WORKSPACE_DIR}/backups

#Backup previous directory if it exists
if [[ -f ${WORKSPACE_DIR}"/active_configuration.cfg" ]]
then
  PREVIOUS_DATE=$(cat ${WORKSPACE_DIR}/active_configuration.cfg | grep CREATION_DATE | cut -d'=' -f2)
  mv ${WORKSPACE_DIR}/active_configuration.cfg ${WORKSPACE_DIR}/backups/backup_configuration.${PREVIOUS_DATE}.cfg
fi

# Create a new active_configuration.cfg properties file with all the parsed parmlib properties stored in it,
NOW=$(date +"%y.%m.%d.%H.%M.%S")
ZOWE_VERSION=$(cat $ROOT_DIR/manifest.json | grep version | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d '[[:space:]]')
cp ${INSTANCE_DIR}/instance.env ${WORKSPACE_DIR}/active_configuration.cfg
echo <<EOF >> ${WORKSPACE_DIR}/active_configuration.cfg

# === zowe-certificates.env
EOF
cat ${KEYSTORE_DIRECTORY}/zowe-certificates.env >> ${WORKSPACE_DIR}/active_configuration.cfg
cat <<EOF >> ${WORKSPACE_DIR}/active_configuration.cfg

# === extra information
VERSION=${ZOWE_VERSION}
CREATION_DATE=${NOW}
ROOT_DIR=${ROOT_DIR}
STATIC_DEF_CONFIG_DIR=${STATIC_DEF_CONFIG_DIR}
LAUNCH_COMPONENTS=${LAUNCH_COMPONENTS}
EOF

########################################################
# Run setup/configure on components if script exists
for component_id in $(echo $LAUNCH_COMPONENTS | sed "s/,/ /g")
do
  component_dir=$(find_component_directory "${component_id}")
  # FIXME: change here to read manifest `commands.configure` entry
  CONFIGURE_SCRIPT=${component_dir}/bin/configure.sh
  if [ ! -z "${component_dir}" -a -x "${CONFIGURE_SCRIPT}" ]; then
    . ${CONFIGURE_SCRIPT}
  fi
done