#! /usr/bin/env bash

source "$HOMEgfs/ush/preamble.sh"

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

set -x

###############################################################
# Source relevant configs
configs="base getic init prep"
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
export EXTRACT_DIR=${EXTRACT_DIR:-$DATA}
export PRODHPSSDIR=${PRODHPSSDIR:-/NCEPPROD/hpssprod/runhistory}
export COMPONENT="atmos"
export gfs_ver=${gfs_ver:-"v16"}
export OPS_RES=${OPS_RES:-"C768"}
export GETICSH=${GETICSH:-${GDASINIT_DIR}/get_v16.data.sh}
export DOGCYCLE=${DOGCYCLE:-"YES"}
export replay_4DIAU=${replay_4DIAU:-"NO"}

if [ $CDATE -ge 2022062700 ]; then
  version="v16.2"
else
  version="prod"
fi

# Create ROTDIR/EXTRACT_DIR
if [ ! -d $ROTDIR ]; then mkdir -p $ROTDIR ; fi
if [ ! -d $EXTRACT_DIR ]; then mkdir -p $EXTRACT_DIR ; fi
if [ ! -d ${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT} ]; then
  mkdir -p ${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}
fi

if [[ $MODE = "forecast-only" && $EXP_WARM_START = ".true." ]]; then
   cd $ROTDIR 
else
   cd $EXTRACT_DIR
fi

# Check version, cold/warm start, and resolution
if [[ $MODE = "cycled" && $EXP_WARM_START = ".true." && "$CDATE" = "$SDATE" ]]; then # Pull warm start ICs - no chgres
  # Pull RESTART files off HPSS
  cd $ROTDIR
  RESTARTEXP=${RESTARTEXP:-${PSLOT}}
  if [[ $ANAL_START == ".true." ]]; then
     htar -xvf ${HPSSEXPDIR}/$RESTARTEXP/$GDATE/gdas_restartb.tar
     status=$?
     [[ $status -ne 0 ]] && exit $status
     htar -xvf ${HPSSEXPDIR}/$RESTARTEXP/$GDATE/gdas.tar
     status=$?
     [[ $status -ne 0 ]] && exit $status
     # VarBC coefficient
     echo "./gdas.${gyy}${gmm}${gdd}/${ghh}/${COMPONENT}/gdas.t${ghh}z.abias "      >list.txt
     echo "./gdas.${gyy}${gmm}${gdd}/${ghh}/${COMPONENT}/gdas.t${ghh}z.abias_air " >>list.txt
     echo "./gdas.${gyy}${gmm}${gdd}/${ghh}/${COMPONENT}/gdas.t${ghh}z.abias_int " >>list.txt
     echo "./gdas.${gyy}${gmm}${gdd}/${ghh}/${COMPONENT}/gdas.t${ghh}z.abias_pc  " >>list.txt
     htar -xvf ${HPSSEXPDIR}/$RESTARTEXP/$GDATE/gdas_restarta.tar -L ./list.txt
     status=$?
     [[ $status -ne 0 ]] && exit $status
  else
     htar -xvf ${HPSSEXPDIR}/$RESTARTEXP/$GDATE/gdas_restartb.tar
     status=$?
     [[ $status -ne 0 ]] && exit $status
     htar -xvf ${HPSSEXPDIR}/$RESTARTEXP/$CDATE/gdas_restarta.tar
     status=$?
     [[ $status -ne 0 ]] && exit $status
     htar -xvf ${HPSSEXPDIR}/$RESTARTEXP/$CDATE/gdas.tar
     status=$?
     [[ $status -ne 0 ]] && exit $status
  fi 
elif [ $MODE != "cycled" ]; then # Pull chgres cube inputs for cold start IC generation
  pullanldata="NO"
  if [[ $MODE == "forecast-only" ]]; then
     if [[ $EXP_WARM_START == ".true." ]]; then
        # pull warm start files
        hpssdir="/NCEPDEV/$HPSS_PROJECT/1year/$USER/$machine/scratch/$RESTARTEXP"
        gdasb=$hpssdir/$GDATE/gdas_restartb.tar
        htar -xvf $gdasb
        gdasa=$hpssdir/$CDATE/gdas_restarta.tar
        htar -tvf $gdasa > ${ROTDIR}/logs/${CDATE}/list1
        >${ROTDIR}/logs/${CDATE}/list2
        grep abias ${ROTDIR}/logs/${CDATE}/list1 | awk '{ print $7 }' >> ${ROTDIR}/logs/${CDATE}/list2
        grep sfcanl ${ROTDIR}/logs/${CDATE}/list1 | awk '{ print $7 }' >> ${ROTDIR}/logs/${CDATE}/list2
        grep atmi ${ROTDIR}/logs/${CDATE}/list1 | awk '{ print $7 }' >> ${ROTDIR}/logs/${CDATE}/list2
        htar -xvf $gdasa -L ${ROTDIR}/logs/${CDATE}/list2
     else
        # Run UFS_UTILS GETICSH
        atmanl=${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.atmanl.nc
        sfcanl=${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.sfcanl.nc
        if [[ ! -s $atmanl || ! -s $sfcanl ]]; then
          sh ${GETICSH} ${ICDUMP}
          status=$?
          [[ $status -ne 0 ]] && exit $status
          pullanldata="YES"
        else
          echo "IC atmanl exists, skip pulling data"
          pullanldata="NO"
        fi
     fi
     #if [[ $DO_OmF == "YES" ]]; then
     #   hpssdir="/NCEPDEV/$HPSS_PROJECT/1year/$USER/$machine/scratch/$RESTARTEXP"
     #   tarball=$hpssdir/$GDATE/enkfgdas.tar
     #   htar -xvf ${tarball} ./enkfgdas.${gyy}${gmm}${gdd}/${ghh}/atmos/gdas.t${ghh}z.sfcf006.ensmean.nc
     #fi
  else 
     # replay mode: cold or warm start first cycle or 3D replay
     if [[ $EXP_WARM_START == ".true." && "$CDATE" == "$SDATE" ]]; then
        # pull warm start files
        hpssdir="/NCEPDEV/$HPSS_PROJECT/1year/$USER/$machine/scratch/$RESTARTEXP"
        gdasb=$hpssdir/$GDATE/gdas_restartb.tar
        gdasa=$hpssdir/$CDATE/gdas_restarta.tar
        if [ ! -d ${ROTDIR}/gdas.${gyy}${gmm}${gdd}/${ghh}/atmos/RESTART ]; then
           htar -xvf $gdasb
        else
           echo "restart files exist, skip pulling restart files"
        fi
        if [[ $DOGCYCLE != "YES" ]]; then
           htar -xvf $gdasa 
        else
           echo "will rerun surface analysis, skip pulling sfcanl data"
        fi
     fi 
     if [[ $replay_4DIAU != "YES" || ($EXP_WARM_START != ".true." && "$CDATE" == "$SDATE") ]]; then 
        # Run UFS_UTILS GETICSH
        atmanl=${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.atmanl.nc
        sfcanl=${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.sfcanl.nc
        if [[ ! -s $atmanl || ! -s $sfcanl ]]; then
          sh ${GETICSH} ${ICDUMP}
          status=$?
          [[ $status -ne 0 ]] && exit $status
          if [[ "${EXTRACT_DIR}" != "${ICSDIR}" ]]; then
            mv ${EXTRACT_DIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/*abias* ${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/
            mv ${EXTRACT_DIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/*radstat ${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/
          fi
          pullanldata="YES" 
        else
          echo "IC atmanl exists, skip pulling data"
          pullanldata="NO"
        fi
     fi
     if [[ $replay_4DIAU == "YES" && ( $EXP_WARM_START == ".true." || "$CDATE" != "$SDATE" ) ]]; then
        cd $EXTRACT_DIR
        if [[ ($ics_from == "opsgfs" || $ics_from == "pargfs") && ${fullresanl:-"NO"} != "YES" ]]; then
           
           # replay to operational GFS
           if [[ ${RETRO:-"NO"} == "YES" && "$CDATE" -lt "2021032500" ]]; then
              directory=${HPSSDIR}/${yy}${mm}${dd}${hh}
              tarball="${ICDUMP}.tar"
              tarball2="${ICDUMP}_restarta.tar"
           else
              directory=${PRODHPSSDIR}/rh${yy}/${yy}${mm}/${yy}${mm}${dd}
              tarball="com_gfs_${version}_${ICDUMP}.${yy}${mm}${dd}_${hh}.${ICDUMP}_nc.tar"
              tarball2="com_gfs_${version}_${ICDUMP}.${yy}${mm}${dd}_${hh}.${ICDUMP}_restart.tar"
           fi
           if [ ! -s ${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.atmanl.ensres.nc ]; then
              echo "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.atma003.ensres.nc " >list.txt
              echo "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.atma009.ensres.nc " >>list.txt
              echo "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.atmanl.ensres.nc " >>list.txt
              htar -xvf ${directory}/${tarball} -L ./list.txt
              status=$?
              [[ $status -ne 0 ]] && exit $status
              if [[ "${EXTRACT_DIR}" != "${ICSDIR}" ]]; then
                mv ${EXTRACT_DIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/*ensres.nc ${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/
              fi
           else
              echo "atmanl.ensres for 4DIAU replay exist, skip pulling data"
           fi
        else
           # replay to full resolution experimental GFS or SHiELD (need to recompute full resolution analysis from analysis increment)
           directory=${HPSSEXPDIR}/${ics_from}/${CDATE}
           tarball2="${ICDUMP}_restarta.tar"
           # first pull first guess
           if [[ ! -s ${ICSDIR}/${ICDUMP}.${gyy}${gmm}${gdd}/${ghh}/${COMPONENT}/${ICDUMP}.t${ghh}z.atmf006.nc ]]; then
             echo "./${ICDUMP}.${gyy}${gmm}${gdd}/${ghh}/${COMPONENT}/${ICDUMP}.t${ghh}z.atmf003.nc " >list.txt
             echo "./${ICDUMP}.${gyy}${gmm}${gdd}/${ghh}/${COMPONENT}/${ICDUMP}.t${ghh}z.atmf006.nc " >>list.txt
             echo "./${ICDUMP}.${gyy}${gmm}${gdd}/${ghh}/${COMPONENT}/${ICDUMP}.t${ghh}z.atmf009.nc " >>list.txt
             tarball="${ICDUMP}.tar"
             htar -xvf ${HPSSEXPDIR}/${ics_from}/${GDATE}/${tarball} -L ./list.txt
             status=$?
             [[ $status -ne 0 ]] && exit $status
             if [ ! -d ${ICSDIR}/${ICDUMP}.${gyy}${gmm}${gdd}/${ghh}/${COMPONENT} ]; then
                mkdir -p ${ICSDIR}/${ICDUMP}.${gyy}${gmm}${gdd}/${ghh}/${COMPONENT}
             fi
             if [[ "${EXTRACT_DIR}" != "${ICSDIR}" ]]; then
               mv $EXTRACT_DIR/${ICDUMP}.${gyy}${gmm}${gdd}/${ghh}/${COMPONENT}/${ICDUMP}.t${ghh}z.atmf*.nc ${ICSDIR}/${ICDUMP}.${gyy}${gmm}${gdd}/${ghh}/${COMPONENT}/
             fi
           fi
           # pull increment
           if [[ ! -s ${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.atminc.nc ]]; then
             echo "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.atmi003.nc " >list.txt
             echo "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.atminc.nc "  >>list.txt
             echo "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.atmi009.nc " >>list.txt
             tarball="${ICDUMP}_restarta.tar"
             htar -xvf ${HPSSEXPDIR}/${ics_from}/${CDATE}/${tarball} -L ./list.txt
             status=$?
             [[ $status -ne 0 ]] && exit $status
             if [[ "${EXTRACT_DIR}" != "${ICSDIR}" ]]; then
               mv $EXTRACT_DIR/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.atmi*.nc ${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/
             fi
           fi
        fi
     fi
  fi
  if [[ $DO_OmF == "YES" && "$CDATE" != "$SDATE" ]]; then
     if [[ "$ics_from" == "opsgfs" ]]; then
        directory=/NCEPPROD/hpssprod/runhistory/rh${gyy}/${gyy}${gmm}/${gyy}${gmm}${gdd}
        tarball=com_gfs_${gfssubver}_gdas.${gyy}${gmm}${gdd}_${ghh}.gdas_restart.tar
     else
        directory=${HPSSEXPDIR}/${ics_from}/${GDATE}
        tarball="${ICDUMP}.tar"
     fi
     abias=${ICSDIR}/${ICDUMP}.${gyy}${gmm}${gdd}/${ghh}/${COMPONENT}/${ICDUMP}.t${ghh}z.abias_air
     if [[ ! -s $abias ]]; then
        echo "./${ICDUMP}.${gyy}${gmm}${gdd}/${ghh}/${COMPONENT}/${ICDUMP}.t${ghh}z.abias "      >list.txt
        echo "./${ICDUMP}.${gyy}${gmm}${gdd}/${ghh}/${COMPONENT}/${ICDUMP}.t${ghh}z.abias_air " >>list.txt
        echo "./${ICDUMP}.${gyy}${gmm}${gdd}/${ghh}/${COMPONENT}/${ICDUMP}.t${ghh}z.abias_int " >>list.txt
        echo "./${ICDUMP}.${gyy}${gmm}${gdd}/${ghh}/${COMPONENT}/${ICDUMP}.t${ghh}z.abias_pc  " >>list.txt
        htar -xvf ${directory}/${tarball} -L ./list.txt
        status=$?
        [[ $status -ne 0 ]] && exit $status
        if [[ "${EXTRACT_DIR}" != "${ICSDIR}" ]]; then
          mv $EXTRACT_DIR/${ICDUMP}.${gyy}${gmm}${gdd}/${ghh}/${COMPONENT}/*abias* ${ICSDIR}/${ICDUMP}.${gyy}${gmm}${gdd}/${ghh}/${COMPONENT}/
        fi
     fi
  fi
fi

cd $EXTRACT_DIR
# Move extracted data to ICSDIR
if [[ $MODE != "cycled" && $pullanldata == "YES" && "${EXTRACT_DIR}" != "${ICSDIR}" ]]; then
  if [ -d ${EXTRACT_DIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT} ]; then
     mv ${EXTRACT_DIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/* ${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/
  elif [ "$(ls -A ${EXTRACT_DIR}/${ICDUMP}.${yy}${mm}${dd}/${hh})" ]; then
     mv ${EXTRACT_DIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/* ${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/
  else
     echo "Data not in right directory"
  fi
fi

# Pull dtfanl for GFS replay
dtfanl=${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.dtfanl.nc
if [[ $MODE = "replay" && $DOGCYCLE = "YES" && $DONST = "YES" && ! -s $dtfanl ]]; then
   if [[ ${RETRO:-"NO"} = "YES" && "$CDATE" -lt "2021032500" ]]; then
      export tarball="${ICDUMP}_restarta.tar"
      htar -xvf ${HPSSDIR}/${yy}${mm}${dd}${hh}/${tarball} ./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.dtfanl.nc  
   else
      export tarball="com_gfs_${version}_${ICDUMP}.${yy}${mm}${dd}_${hh}.${ICDUMP}_restart.tar"
      htar -xvf ${PRODHPSSDIR}/rh${yy}/${yy}${mm}/${yy}${mm}${dd}/${tarball} ./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.dtfanl.nc
   fi
   if [[ "${EXTRACT_DIR}" != "${ICSDIR}" ]]; then
     mv ${EXTRACT_DIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.dtfanl.nc ${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/
   fi
   rc=$?
   [ $rc != 0 ] && exit $rc
fi

# Pull sfcanl restart file to get SST for replay and DA cycle
cd ${ICSDIR}
# need to check the condition below, always use operational surface analysis for now
#if [[ $gfs_ver == "v16" ]]; then
  getsfcanl="NO"
  if [[  $MODE != "forecast-only" && ($DO_TSFC_TILE == "YES" || $DOGCYCLE != "YES" ) && ("$CDATE" != "$SDATE" || $EXP_WARM_START == ".true.") ]]; then
     getsfcanl="YES" 
  fi
  runchgres="NO" 
  if [[ ! -d ${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART_${CASE} && $MODE != "forecast-only" ]]; then
     runchgres="YES"
  fi
  if [[ ! -d ${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART_${CASE_ENKF} && $MODE == "cycled" ]]; then
     runchgres="YES"
  fi
  if [[ $getsfcanl == "YES" && ($runchgres == "YES" || $OPS_RES == $CASE) ]]; then
     if [[ -d ${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART_GFS ]]; then
       getdata="NO"
       getdata2="NO"
       >list.txt
       for n in $(seq 1 6); do
          file=${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART_GFS/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile${n}.nc
          file2=${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART_GFS/${yy}${mm}${dd}.${hh}0000.sfcanl_data.tile${n}.nc
          if [ -s $file ]; then
            fsize=`wc -c $file | awk '{print $1}'`
            if [ $n -eq 1 ]; then
               fsize1=$fsize
            else
               if [ $fsize -lt $fsize1 ]; then
                  getdata="YES"
                  echo "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile${n}.nc" >>list.txt
               elif [ $fsize -gt $fsize1 ]; then
                  getdata="YES"
                  m = $((n - 1))
                  echo "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile${m}.nc" >>list.txt
                  fsize1=$fsize
               fi
            fi
          else
            getdata="YES"
            echo "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile${n}.nc" >>list.txt
          fi
          if [ -s $file2 ]; then
            fsize=`wc -c $file2 | awk '{print $1}'`
            if [ $n -eq 1 ]; then
               fsize1=$fsize
            else
               if [ $fsize -lt $fsize1 ]; then
                  getdata2="YES"
                  echo "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART/${yy}${mm}${dd}.${hh}0000.sfcanl_data.tile${n}.nc" >>list.txt
               elif [ $fsize -gt $fsize1 ]; then
                  getdata="YES" 
                  m = $((n - 1))
                  echo "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART/${yy}${mm}${dd}.${hh}0000.sfcanl_data.tile${m}.nc" >>list.txt
                  fsize1=$fsize
               fi
            fi
          else
            getdata2="YES"
            echo "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART/${yy}${mm}${dd}.${hh}0000.sfcanl_data.tile${n}.nc" >>list.txt
          fi
       done 
     else
       getdata="YES"
       echo  "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile1.nc  " >>list.txt
       echo  "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile2.nc  " >>list.txt
       echo  "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile3.nc  " >>list.txt
       echo  "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile4.nc  " >>list.txt
       echo  "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile5.nc  " >>list.txt
       echo  "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile6.nc  " >>list.txt
       getdata2="YES"
       echo  "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART/${yy}${mm}${dd}.${hh}0000.sfcanl_data.tile1.nc  " >>list.txt
       echo  "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART/${yy}${mm}${dd}.${hh}0000.sfcanl_data.tile2.nc  " >>list.txt
       echo  "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART/${yy}${mm}${dd}.${hh}0000.sfcanl_data.tile3.nc  " >>list.txt
       echo  "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART/${yy}${mm}${dd}.${hh}0000.sfcanl_data.tile4.nc  " >>list.txt
       echo  "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART/${yy}${mm}${dd}.${hh}0000.sfcanl_data.tile5.nc  " >>list.txt
       echo  "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART/${yy}${mm}${dd}.${hh}0000.sfcanl_data.tile6.nc  " >>list.txt
     fi    
     if [[ $getdata = "YES" || $getdata2 = "YES" ]]; then
       if [[ (${RETRO:-"NO"} = "YES" && "$CDATE" -lt "2021032500") || ${REDUCEDRES:-"NO"} = "YES" ]]; then
          export tarball="${ICDUMP}_restarta.tar"
          htar -xvf ${HPSSDIR}/${yy}${mm}${dd}${hh}/${tarball} -L ./list.txt 
          status=$?
          [[ $status -ne 0 ]] && exit $status
       else   
          export tarball="com_gfs_${version}_${ICDUMP}.${yy}${mm}${dd}_${hh}.${ICDUMP}_restart.tar"
          htar -xvf ${PRODHPSSDIR}/rh${yy}/${yy}${mm}/${yy}${mm}${dd}/${tarball} -L ./list.txt
          status=$?
          [[ $status -ne 0 ]] && exit $status
       fi     
       if [ -d ${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART_GFS ]; then
         mv -f ${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART/* ${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART_GFS/
         rm -rf ${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART
       else
         mv ${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART ${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART_GFS
       fi
     else
       echo "sfcanl exist, skip pulling data"
     fi
     rm -f list.txt
  else
     echo "sfcanl exist, skip pulling data"
  fi
#fi

# Pull pgbanl file for verification/archival - v14+
# disable it for now
if [ "YES" = "NO" ]; then
if [[ $MODE != "cycled" && $DO_METP == "YES" && $ICSTYP == "gfs" && $ICDUMP == "gdas" ]]; then
  if [ $gfs_ver = v14 -o $gfs_ver = v15 -o $gfs_ver = v16 ]; then
    if [ ! -s ${ARCDIR}/../${ICDUMP}/pgbanl.${ICDUMP}.${CDATE}.grib2 ]; then
      cd $EXTRACT_DIR
      #for grid in 0p25 0p50 1p00
      for grid in 1p00
      do
        if [ $gfs_ver = v14 ]; then # v14 production source
          file="${ICDUMP}.t${hh}z.pgrb2.${grid}.anl"
          export tarball="gpfs_hps_nco_ops_com_gfs_prod_gfs.${yy}${mm}${dd}${hh}.pgrb2_${grid}.tar"
          htar -xvf ${PRODHPSSDIR}/rh${yy}/${yy}${mm}/${yy}${mm}${dd}/${tarball} ./${file}
    
        elif [ $gfs_ver = v15 ]; then # v15 production source
          file="${ICDUMP}.${yy}${mm}${dd}/${hh}/${file}" 
          export tarball="com_gfs_prod_${ICDUMP}.${yy}${mm}${dd}_${hh}.${ICDUMP}_pgrb2.tar"
          htar -xvf ${PRODHPSSDIR}/rh${yy}/${yy}${mm}/${yy}${mm}${dd}/${tarball} ./${file}
    
        elif [ $gfs_ver = v16 ]; then # v16 - determine RETRO or production source next
    
          if [[ $RETRO = "YES" && "$CDATE" -lt "2021032500" ]]; then # Retrospective parallel source
    
            if [ $ICDUMP = "gdas" ]; then
              export tarball="gdas.tar"
            elif [ $grid = "0p25" ]; then # anl file spread across multiple tarballs
              export tarball="gfsa.tar"
            elif [ $grid = "0p50" -o $grid = "1p00" ]; then
              export tarball="gfsb.tar"
            fi
            file="${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${file}"
            htar -xvf ${HPSSDIR}/${yy}${mm}${dd}${hh}/${tarball} ./${file}
    
          else # Production source
            file="${ICDUMP}.${yy}${mm}${dd}/${hh}/atmos/${file}"
            export tarball="com_${version}_prod_${ICDUMP}.${yy}${mm}${dd}_${hh}.${ICDUMP}_pgrb2.tar"
            htar -xvf ${PRODHPSSDIR}/rh${yy}/${yy}${mm}/${yy}${mm}${dd}/${tarball} ./${file}
    
          fi # RETRO vs production
  
        fi # Version check
        mv ${EXTRACT_DIR}/${file} $ARCDIR/../${ICDUMP}/pgbanl.${ICDUMP}.${CDATE}.grib2
      done # grid loop
    else
      echo "${ICDUMP}.t${hh}z.pgrb2.1p00.anl exist, skip pulling data"
    fi
  fi # v14-v16 pgrb anl file pull
fi
fi

if [[ $MODE == "forecast-only" && $EXP_WARM_START == ".true." && $DO_OmF == "YES" ]]; then
   mkdir -p $ROTDIR/dump
   cd $ROTDIR/dump
   tarball=${CDUMP}_restarta.tar
   rm -f ${ROTDIR}/logs/${CDATE}/list*
   htar -tvf ${PTARDIR}/${tarball} > ${ROTDIR}/logs/${CDATE}/list1
   if [ ! -s ${ROTDIR}/${CDUMP}.${PDY}/${cyc}/atmos/gdas.t${cyc}z.prepbufr ]; then
      >${ROTDIR}/logs/${CDATE}/list2
      grep prepbufr ${ROTDIR}/logs/${CDATE}/list1 | awk '{ print $7 }' >> ${ROTDIR}/logs/${CDATE}/list2
      htar -xvf ${PTARDIR}/${tarball} -L ${ROTDIR}/logs/${CDATE}/list2
   fi
fi

##########################################
# Remove the Temporary working directory
##########################################
[[ $KEEPDATA = "NO" ]] && rm -rf $DATA

###############################################################
# Exit out cleanly


exit 0
