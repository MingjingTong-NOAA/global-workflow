#!/bin/ksh -x

###############################################################
## Abstract:
## Get GFS intitial conditions
## RUN_ENVIR : runtime environment (emc | nco)
## HOMEgfs   : /full/path/to/workflow
## EXPDIR : /full/path/to/config/files
## CDATE  : current date (YYYYMMDDHH)
## CDUMP  : cycle name (gdas / gfs)
## PDY    : current date (YYYYMMDD)
## cyc    : current cycle (HH)
###############################################################

###############################################################
# Source FV3GFS workflow modules
. $HOMEgfs/ush/load_fv3gfs_modules.sh
status=$?
[[ $status -ne 0 ]] && exit $status

###############################################################
# Source relevant configs
configs="base getic init"
for config in $configs; do
    . $EXPDIR/config.${config}
    status=$?
    [[ $status -ne 0 ]] && exit $status
done

###############################################################
# Source machine runtime environment
. $BASE_ENV/${machine}.env getic
status=$?
[[ $status -ne 0 ]] && exit $status

###############################################################
# Set script and dependency variables

export yy=$(echo $CDATE | cut -c1-4)
export mm=$(echo $CDATE | cut -c5-6)
export dd=$(echo $CDATE | cut -c7-8)
export hh=${cyc:-$(echo $CDATE | cut -c9-10)}
export GDATE=$($NDATE -${assim_freq:-"06"} $CDATE)
export gyy=$(echo $GDATE | cut -c1-4)
export gmm=$(echo $GDATE | cut -c5-6)
export gdd=$(echo $GDATE | cut -c7-8)
export ghh=$(echo $GDATE | cut -c9-10)
export IAUSDATE=$($NDATE -3 $CDATE)
export iyy=$(echo $IAUSDATE | cut -c1-4)
export imm=$(echo $IAUSDATE | cut -c5-6)
export idd=$(echo $IAUSDATE | cut -c7-8)
export ihh=$(echo $IAUSDATE | cut -c9-10)

export DATA=${DATA:-${DATAROOT}/getic}
export EXTRACT_DIR=${DATA:-$EXTRACT_DIR}
export PRODHPSSDIR=${PRODHPSSDIR:-/NCEPPROD/hpssprod/runhistory}
export COMPONENT="atmos"
export gfs_ver=${gfs_ver:-"v16"}
export OPS_RES=${OPS_RES:-"C768"}
export GETICSH=${GETICSH:-${GDASINIT_DIR}/get_v16.data.sh}
export rungcycle=${rungcycle:-"YES"}
export replay_4DIAU=${replay_4DIAU:-"NO"}

# Create ROTDIR/EXTRACT_DIR
if [ ! -d $ROTDIR ]; then mkdir -p $ROTDIR ; fi
if [ ! -d $EXTRACT_DIR ]; then mkdir -p $EXTRACT_DIR ; fi
cd $EXTRACT_DIR

# Check version, cold/warm start, and resolution
if [[ $gfs_ver = "v16" && $EXP_WARM_START = ".true." && $CASE = $OPS_RES ]]; then # Pull warm start ICs - no chgres

  # Pull RESTART files off HPSS
  if [ ${RETRO:-"NO"} = "YES" ]; then # Retrospective parallel input

    # Pull prior cycle restart files
    htar -xvf ${HPSSDIR}/${GDATE}/gdas_restartb.tar
    status=$?
    [[ $status -ne 0 ]] && exit $status

    # Pull current cycle restart files
    htar -xvf ${HPSSDIR}/${CDATE}/gfs_restarta.tar
    status=$?
    [[ $status -ne 0 ]] && exit $status

    # Pull IAU increment files
    htar -xvf ${HPSSDIR}/${CDATE}/gfs_netcdfa.tar
    status=$?
    [[ $status -ne 0 ]] && exit $status

  else # Opertional input - warm starts

    cd $ROTDIR
    # Pull CDATE gfs restart tarball
    htar -xvf ${PRODHPSSDIR}/rh${yy}/${yy}${mm}/${yy}${mm}${dd}/com_gfs_prod_gfs.${yy}${mm}${dd}_${hh}.gfs_restart.tar
    # Pull GDATE gdas restart tarball
    htar -xvf ${PRODHPSSDIR}/rh${gyy}/${gyy}${gmm}/${gyy}${gmm}${gdd}/com_gfs_prod_gdas.${gyy}${gmm}${gdd}_${ghh}.gdas_restart.tar
  fi

else # Pull chgres cube inputs for cold start IC generation

  # Run UFS_UTILS GETICSH
  sh ${GETICSH} ${ICDUMP}
  status=$?
  [[ $status -ne 0 ]] && exit $status

fi

# Move extracted data to ROTDIR
if [ ! -d ${ROTDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT} ]; then mkdir -p ${ROTDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT} ; fi
if [ $gfs_ver = "v16" ]; then
  if [ -d ${EXTRACT_DIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT} ]; then
    mv ${EXTRACT_DIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/* ${ROTDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/
  else
    mv ${EXTRACT_DIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/* ${ROTDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/
  fi
else
  mv ${EXTRACT_DIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/* ${ROTDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/
fi

# Pull sfcanl restart file for replay
if [ $gfs_ver = v16 ]; then
  if [[ $MODE = "replay" && $rungcycle = "NO" ]]; then
     cd $EXTRACT_DIR

     echo  "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile1.nc  " >list.txt
     echo  "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile2.nc  " >>list.txt
     echo  "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile3.nc  " >>list.txt
     echo  "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile4.nc  " >>list.txt
     echo  "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile5.nc  " >>list.txt
     echo  "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile6.nc  " >>list.txt
  
     if [[ ${RETRO:-"NO"} = "YES" && "$CDATE" -lt "2021032500" ]]; then
        export tarball="${ICDUMP}_restarta.tar"
        htar -xvf ${HPSSDIR}/${yy}${mm}${dd}${hh}/${tarball} -L ./list.txt 
     else   
        export tarball="com_gfs_prod_${ICDUMP}.${yy}${mm}${dd}_${hh}.${ICDUMP}_restart.tar"
        htar -xvf ${PRODHPSSDIR}/rh${yy}/${yy}${mm}/${yy}${mm}${dd}/${tarball} -L ./list.txt
     fi     
     mv ${EXTRACT_DIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART ${ROTDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/
  fi

  if [[ $replay_4DIAU = "YES" ]]; then
     cd $EXTRACT_DIR
     echo "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.atma003.ensres.nc " >list.txt
     echo "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.atma009.ensres.nc " >>list.txt
     echo "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.atmanl.ensres.nc " >>list.txt

     if [[ ${RETRO:-"NO"} = "YES" && "$CDATE" -lt "2021032500" ]]; then
        export tarball="${ICDUMP}.tar"
        htar -xvf ${HPSSDIR}/${yy}${mm}${dd}${hh}/${tarball} -L ./list.txt
     else
        export tarball="com_gfs_prod_${ICDUMP}.${yy}${mm}${dd}_${hh}.${ICDUMP}_nc.tar"
        htar -xvf ${PRODHPSSDIR}/rh${yy}/${yy}${mm}/${yy}${mm}${dd}/${tarball} -L ./list.txt
     fi
     mv ${EXTRACT_DIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/*ensres.nc ${ROTDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/
  fi
fi

# Pull pgbanl file for verification/archival - v14+
if [ $DO_METP = "YES" ]; then
if [ $gfs_ver = v14 -o $gfs_ver = v15 -o $gfs_ver = v16 ]; then
  for grid in 0p25 0p50 1p00
  do
    file=${ICDUMP}.t${hh}z.pgrb2.${grid}.anl

    if [ $gfs_ver = v14 ]; then # v14 production source

      cd $ROTDIR/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}
      export tarball="gpfs_hps_nco_ops_com_gfs_prod_gfs.${yy}${mm}${dd}${hh}.pgrb2_${grid}.tar"
      htar -xvf ${PRODHPSSDIR}/rh${yy}/${yy}${mm}/${yy}${mm}${dd}/${tarball} ./${file}

    elif [ $gfs_ver = v15 ]; then # v15 production source

      cd $EXTRACT_DIR
      export tarball="com_gfs_prod_${ICDUMP}.${yy}${mm}${dd}_${hh}.${ICDUMP}_pgrb2.tar"
      htar -xvf ${PRODHPSSDIR}/rh${yy}/${yy}${mm}/${yy}${mm}${dd}/${tarball} ./${ICDUMP}.${yy}${mm}${dd}/${hh}/${file}
      mv ${EXTRACT_DIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${file} ${ROTDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${file}

    elif [ $gfs_ver = v16 ]; then # v16 - determine RETRO or production source next

      if [[ $RETRO = "YES" && "$CDATE" -lt "2021032500" ]]; then # Retrospective parallel source

        cd $EXTRACT_DIR
        if [ $ICDUMP = "gdas" ]; then
          export tarball="gdas.tar"
        elif [ $grid = "0p25" ]; then # anl file spread across multiple tarballs
          export tarball="gfsa.tar"
        elif [ $grid = "0p50" -o $grid = "1p00" ]; then
          export tarball="gfsb.tar"
        fi
        htar -xvf ${HPSSDIR}/${yy}${mm}${dd}${hh}/${tarball} ./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${file}
        mv ${EXTRACT_DIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${file} ${ROTDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${file}

      else # Production source

        cd $ROTDIR
        export tarball="com_gfs_prod_${ICDUMP}.${yy}${mm}${dd}_${hh}.${ICDUMP}_pgrb2.tar"
        htar -xvf ${PRODHPSSDIR}/rh${yy}/${yy}${mm}/${yy}${mm}${dd}/${tarball} ./${ICDUMP}.${yy}${mm}${dd}/${hh}/atmos/${file}

      fi # RETRO vs production

    fi # Version check
     
    if [[ $MODE = "free" && $grid = "1p00" ]]; then
       $NCP $ROTDIR/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${file} $ARCDIR/pgbanl.${ICDUMP}.${CDATE}.grib2
    fi
  done # grid loop
fi # v14-v16 pgrb anl file pull
fi

##########################################
# Remove the Temporary working directory
##########################################
cd $DATAROOT
[[ $KEEPDATA = "NO" ]] && rm -rf $DATA

###############################################################
# Exit out cleanly
exit 0
