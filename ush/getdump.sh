#!/bin/ksh
set -x

export COMPONENT=${COMPONENT:-atmos}

CDATE=${1:-""}
SDUMP=${2:-""}
SOURCE_DIR=${3:-$DMPDIR/${SDUMP}${DUMP_SUFFIX}.${PDY}/${cyc}}
TARGET_DIR=${4:-$ROTDIR/${CDUMP}.${PDY}/$cyc/$COMPONENT}

DUMP_SUFFIX=${DUMP_SUFFIX:-""}

# Exit if SORUCE_DIR does not exist
if [ ! -s $SOURCE_DIR ]; then 
   echo "***ERROR*** DUMP SOURCE_DIR=$SOURCE_DIR does not exist"
   exit 99
fi
   

# Create TARGET_DIR if is does not exist
if [ ! -s $TARGET_DIR ]; then mkdir -p $TARGET_DIR ;fi


# Set file prefix
cyc=$(echo $CDATE |cut -c 9-10)
prefix="$SDUMP.t${cyc}z."


# Link dump files from SOURCE_DIR to TARGET_DIR
cd $SOURCE_DIR
if [ -s ${prefix}updated.status.tm00.bufr_d ]; then
    for file in $(ls ${prefix}*); do
        if [ $MODE == "cycled" ]; then
	  ln -fs $SOURCE_DIR/$file $TARGET_DIR/$CDUMP.t${cyc}z.${file#${prefix}}
        else
          ln -fs $SOURCE_DIR/$file $TARGET_DIR/$ICDUMP.t${cyc}z.${file#${prefix}}
        fi
    done
else
    echo "***ERROR*** ${prefix}updated.status.tm00.bufr_d NOT FOUND in $SOURCE_DIR"
    exit 99
fi

exit 0



