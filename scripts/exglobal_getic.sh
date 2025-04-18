#! /usr/bin/env bash

###############################################################
####  UNIX Script Documentation Block
# 
# Script name:    exglobal_getic.sh 
# Script description:  Get GFS/SHiELD intitial conditions
#
# Author: Mingjing Tong  Org: GFDL    Date: 2025-02-04
#
# $Id$
#
# Attributes:
#   Language: POSIX shell
#
###############################################################

source "${USHgfs}/preamble.sh"

# Directories.
pwd=$(pwd)

set -x

###############################################################
# Set script and dependency variables

export yy=$(echo $CDATE | cut -c1-4)
export mm=$(echo $CDATE | cut -c5-6)
export dd=$(echo $CDATE | cut -c7-8)
export hh=${cyc:-$(echo $CDATE | cut -c9-10)}
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
export EXTRACT_DIR=${EXTRACT_DIR:-$ICSROOT}
export PRODHPSSDIR=${PRODHPSSDIR:-/NCEPPROD/hpssprod/runhistory}
export COMPONENT="atmos"
export gfs_ver=${gfs_ver:-"v16"}
export OPS_RES=${OPS_RES:-"C768"}
export GETICSH=${GETICSH:-${GDASINIT_DIR}/get_v16.data.sh}
export DOGCYCLE=${DOGCYCLE:-"YES"}
export REPLAY_4DIAU=${REPLAY_4DIAU:-"NO"}

if [ $CDATE -ge 2022062700 ]; then
  version="v16.2"
else
  version="prod"
fi

[[ ! -d $EXTRACT_DIR ]] && mkdir -p $EXTRACT_DIR
[[ ! -d ${EXTRACT_DIR}/logs ]] && mkdir -p ${EXTRACT_DIR}/logs
[[ ! -d ${COMOUT_ATMOS_ANALYSIS} ]] && mkdir -p ${COMOUT_ATMOS_ANALYSIS}

# Check version, cold/warm start, and resolution
if [[ $MODE = "cycled" && $EXP_WARM_START = ".true." && "$CDATE" = "$SDATE" ]]; then # Pull warm start ICs - no chgres
  # Pull RESTART files off HPSS
  cd $EXTRACT_DIR
  RESTARTEXP=${RESTARTEXP:-${PSLOT}}
  if [[ $ANAL_START == ".true." ]]; then
     htar -xvf ${HPSSEXPDIR}/${RESTARTEXP}/${GDATE}/gdas_restartb.tar
     status=$?
     [[ $status -ne 0 ]] && exit $status
     htar -xvf ${HPSSEXPDIR}/${RESTARTEXP}/${GDATE}/gdas.tar
     status=$?
     [[ $status -ne 0 ]] && exit $status
     # VarBC coefficient
     htar -tvf ${HPSSEXPDIR}/${RESTARTEXP}/${GDATE}/gdas_restarta.tar > ${ROTDIR}/logs/${CDATE}/list1 
     >>${ROTDIR}/logs/${CDATE}/list2
     grep abias ${ROTDIR}/logs/${CDATE}/list1 | awk '{ print $7 }' >> ${ROTDIR}/logs/${CDATE}/list2
     htar -xvf ${HPSSEXPDIR}/${RESTARTEXP}/${GDATE}/gdas_restarta.tar -L ${ROTDIR}/logs/${CDATE}/list2
     status=$?
     [[ $status -ne 0 ]] && exit $status
  else
     htar -xvf ${HPSSEXPDIR}/${RESTARTEXP}/${GDATE}/gdas_restartb.tar
     status=$?
     [[ $status -ne 0 ]] && exit $status
     htar -xvf ${HPSSEXPDIR}/${RESTARTEXP}/${CDATE}/gdas_restarta.tar
     status=$?
     [[ $status -ne 0 ]] && exit $status
     htar -xvf ${HPSSEXPDIR}/${RESTARTEXP}/${CDATE}/gdas.tar
     status=$?
     [[ $status -ne 0 ]] && exit $status
  fi 
elif [ $MODE != "cycled" ]; then # Pull chgres cube inputs for cold start IC generation
  pullanldata="NO"
  if [[ $MODE == "forecast-only" ]]; then
     if [[ $EXP_WARM_START == ".true." ]]; then
        # warm start from experiment
        gdasb=${HPSSEXPDIR}/${RESTARTEXP}/${GDATE}/gdas_restartb.tar
        htar -xvf $gdasb
        gdasa=${HPSSEXPDIR}/${RESTARTEXP}/${CDATE}/gdas_restarta.tar
        htar -tvf $gdasa > ${ROTDIR}/logs/${CDATE}/list1
        >${ROTDIR}/logs/${CDATE}/list2
        grep abias ${ROTDIR}/logs/${CDATE}/list1 | awk '{ print $7 }' >> ${ROTDIR}/logs/${CDATE}/list2
        grep sfcanl ${ROTDIR}/logs/${CDATE}/list1 | awk '{ print $7 }' >> ${ROTDIR}/logs/${CDATE}/list2
        grep atmi ${ROTDIR}/logs/${CDATE}/list1 | awk '{ print $7 }' >> ${ROTDIR}/logs/${CDATE}/list2
        htar -xvf $gdasa -L ${ROTDIR}/logs/${CDATE}/list2
     else
        # cold start from GFS analysis
        # Run UFS_UTILS GETICSH v16 and earlier 
        atmanl=${COMOUT_ATMOS_ANALYSIS}/${ICDUMP}.t${hh}z.atmanl.nc
        sfcanl=${COMOUT_ATMOS_ANALYSIS}/${ICDUMP}.t${hh}z.sfcanl.nc
        if [[ ! -s $atmanl || ! -s $sfcanl ]]; then
          sh ${GETICSH} ${ICDUMP}
          status=$?
          [[ $status -ne 0 ]] && exit $status
          pullanldata="YES"
        else
          echo "IC atmanl exists, skip pulling data"
          pullanldata="NO"
        fi
        # New version
        
     fi
  else 
     # replay mode: cold or warm start first cycle or 3D replay
     if [[ $EXP_WARM_START == ".true." && "$CDATE" == "$SDATE" ]]; then
        # pull warm start files
        gdasb=${HPSSEXPDIR}/${RESTARTEXP}/${GDATE}/gdas_restartb.tar
        gdasa=${HPSSEXPDIR}/${RESTARTEXP}/${CDATE}/gdas_restarta.tar
        if [ ! -d ${COMIN_ATMOS_RESTART} ]; then
           htar -xvf $gdasb
           [[ ! -d ${COMOUT_ATMOS_RESTART} ]] && mkdir -p ${COMOUT_ATMOS_RESTART}
           if [[ ${COMOUT_ATMOS_RESTART} != ${COMIN_ATMOS_RESTART} ]]; then
             $NLN ${COMIN_ATMOS_RESTART}/* ${COMOUT_ATMOS_RESTART}/
           fi
        else
           echo "restart files exist, skip pulling restart files"
        fi
        if [[ ${DO_SFCANL} != "YES" ]]; then
           htar -xvf $gdasa 
        else
           echo "will rerun surface analysis, skip pulling sfcanl data"
        fi
     fi 
     if [[ $REPLAY_4DIAU != "YES" || ($EXP_WARM_START != ".true." && "$CDATE" == "$SDATE") ]]; then 
        # Run UFS_UTILS GETICSH
        atmanl=${COMIN_ATMOS_ANALYSIS}/${ICDUMP}.t${hh}z.atmanl.nc
        sfcanl=${COMIN_ATMOS_ANALYSIS}/${ICDUMP}.t${hh}z.sfcanl.nc
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
     if [[ $REPLAY_4DIAU == "YES" && ( $EXP_WARM_START == ".true." || "$CDATE" != "$SDATE" ) ]]; then
        cd $EXTRACT_DIR
        if [[ $ICFROM == "gfs" ]]; then
           # replay to operational GFS
           directory=${PRODHPSSDIR}/rh${yy}/${yy}${mm}/${yy}${mm}${dd}
           tarball="com_gfs_${gfssubver}_${ICDUMP}.${yy}${mm}${dd}_${hh}.${ICDUMP}_nc.tar"
        else
           # replay to SHiELD or GFS retro analysis
           directory=${HPSSEXPDIR}/${ICFROM}/${CDATE}
           tarball="${ICDUMP}.tar"
        fi
        if [ ! -s ${COMIN_ATMOS_ANALYSIS}/${ICDUMP}.t${hh}z.atmanl.ensres.nc ]; then
           if [ -d ${ROTDIR}/logs/${CDATE} ]; then
              echo ${ROTDIR}/logs/${CDATE}
           else
              echo 'not exist'
           fi
           echo ".${ATMOS_ANALYSIS}/${ICDUMP}.t${hh}z.atma003.ensres.nc " >${ROTDIR}/logs/${CDATE}/list.txt
           echo ".${ATMOS_ANALYSIS}/${ICDUMP}.t${hh}z.atma009.ensres.nc " >>${ROTDIR}/logs/${CDATE}/list.txt
           echo ".${ATMOS_ANALYSIS}/${ICDUMP}.t${hh}z.atmanl.ensres.nc " >>${ROTDIR}/logs/${CDATE}/list.txt
           htar -xvf ${directory}/${tarball} -L ${ROTDIR}/logs/${CDATE}/list.txt
           status=$?
           [[ $status -ne 0 ]] && exit $status
           pullanldata="YES" 
        else
           echo "atmanl.ensres for 4DIAU replay exist, skip pulling data"
        fi
     fi
  fi
  if [[ $DO_OMF == "YES" && "$CDATE" != "$SDATE" ]]; then
     if [[ "$ICFROM" == "gfs" ]]; then
        directory=/NCEPPROD/hpssprod/runhistory/rh${gyy}/${gyy}${gmm}/${gyy}${gmm}${gdd}
        tarball=com_gfs_${gfssubver}_gdas.${gyy}${gmm}${gdd}_${ghh}.gdas_restart.tar
     else
        directory=${HPSSEXPDIR}/${ICFROM}/${GDATE}
        tarball="${ICDUMP}.tar"
     fi
     if [[ ! -s ${COMOUT_ATMOS_ANALYSIS_PREV}/${ICDUMP}.t${ghh}z.abias_air ]]; then
        if [[ ! -s ${COMIN_ATMOS_ANALYSIS_PREV}/${ICDUMP}.t${ghh}z.abias_air ]]; then 
          htar -tvf ${directory}/${tarball} > ${ROTDIR}/logs/${CDATE}/list1
          >${ROTDIR}/logs/${CDATE}/list2
          grep abias ${ROTDIR}/logs/${CDATE}/list1 | awk '{ print $7 }' >> ${ROTDIR}/logs/${CDATE}/list2
          htar -xvf ${directory}/${tarball} -L ${ROTDIR}/logs/${CDATE}/list2
          status=$?
          [[ $status -ne 0 ]] && exit $status
        fi
        $NLN ${COMIN_ATMOS_ANALYSIS_PREV}/*abias* ${COMOUT_ATMOS_ANALYSIS_PREV}/
     else
        echo "skip pulling previous cycle *abias* "
     fi
  fi
fi

[[ ! -d ${COMOUT_ATMOS_ANALYSIS} ]] && mkdir -p ${COMOUT_ATMOS_ANALYSIS}
# Move extracted data to ICSROOT
#if [[ $MODE != "cycled" && $pullanldata == "YES" && ${COMIN_ATMOS_ANALYSIS} != ${COMOUT_ATMOS_ANALYSIS} ]]; then
if [[ $MODE != "cycled" && ${COMIN_ATMOS_ANALYSIS} != ${COMOUT_ATMOS_ANALYSIS} ]]; then
  $NLN ${COMIN_ATMOS_ANALYSIS}/* ${COMOUT_ATMOS_ANALYSIS}/
fi

# Pull dtfanl for GFS replay
dtfanl=${COMIN_ATMOS_ANALYSIS}/${ICDUMP}.t${hh}z.dtfanl.nc
if [[ $MODE = "replay" && $DO_SFCANL = "YES" && $DONST = "YES" && ! -s $dtfanl ]]; then
   if [[ ${RETRO:-"NO"} = "YES" && "$CDATE" -lt "2021032500" ]]; then
      export tarball="${ICDUMP}_restarta.tar"
      htar -xvf ${HPSSEXPDIR}/${CDATE}/${tarball} ./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.dtfanl.nc  
   else
      export tarball="com_gfs_${gfssubver}_${ICDUMP}.${yy}${mm}${dd}_${hh}.${ICDUMP}_restart.tar"
      htar -xvf ${PRODHPSSDIR}/rh${yy}/${yy}${mm}/${yy}${mm}${dd}/${tarball} ./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.dtfanl.nc
   fi
   if [[ "${COMOUT_ATMOS_ANALYSIS}" != "${COMIN_ATMOS_ANALYSIS}" ]]; then
     $NLN $dtfanl ${COMOUT_ATMOS_ANALYSIS}/${ICDUMP}.t${hh}z.dtfanl.nc
   fi
   rc=$?
   [ $rc != 0 ] && exit $rc
fi

# Pull sfcanl restart file to get SST for replay and DA cycle
cd ${ICSROOT}
# need to check the condition below, always use operational surface analysis for now
#if [[ $gfs_ver == "v16" ]]; then
  getsfcanl="NO"
  if [[  $MODE != "forecast-only" && ($DO_TSFC_TILE == "YES" || $DOGCYCLE != "YES" ) && ("$CDATE" != "$SDATE" || $EXP_WARM_START == ".true.") ]]; then
     getsfcanl="YES" 
  fi
  runchgres="NO" 
  if [[ ! -d ${COMIN_ATMOS_ANALYSIS_RESTART} && ("${MODE}" == "cycled" || "${MODE}" == "replay") ]]; then
     runchgres="YES"
  fi
  if [[ $getsfcanl == "YES" && ($runchgres == "YES" || $OPS_RES == $CASE) ]]; then
     if [[ -d ${COMIN_ATMOS_ANALYSIS_RESTART} ]]; then
       getdata="NO"
       getdata2="NO"
       >${ROTDIR}/logs/${CDATE}/list.txt
       for n in $(seq 1 6); do
          file=${COMIN_ATMOS_ANALYSIS_RESTART}/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile${n}.nc
          file2=${COMIN_ATMOS_ANALYSIS_RESTART}/${yy}${mm}${dd}.${hh}0000.sfcanl_data.tile${n}.nc
          if [ -s $file ]; then
            fsize=`wc -c $file | awk '{print $1}'`
            if [ $n -eq 1 ]; then
               fsize1=$fsize
            else
               if [ $fsize -lt $fsize1 ]; then
                  getdata="YES"
                  echo ".${ATMOS_ANALYSIS_RESTART}/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile${n}.nc" >>${ROTDIR}/logs/${CDATE}/list.txt
               elif [ $fsize -gt $fsize1 ]; then
                  getdata="YES"
                  m = $((n - 1))
                  echo ".${ATMOS_ANALYSIS_RESTART}/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile${m}.nc" >>${ROTDIR}/logs/${CDATE}/list.txt
                  fsize1=$fsize
               fi
            fi
          else
            getdata="YES"
            echo ".${ATMOS_ANALYSIS_RESTART}/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile${n}.nc" >>${ROTDIR}/logs/${CDATE}/list.txt
          fi
          if [ -s $file2 ]; then
            fsize=`wc -c $file2 | awk '{print $1}'`
            if [ $n -eq 1 ]; then
               fsize1=$fsize
            else
               if [ $fsize -lt $fsize1 ]; then
                  getdata2="YES"
                  echo ".${ATMOS_ANALYSIS_RESTART}/${yy}${mm}${dd}.${hh}0000.sfcanl_data.tile${n}.nc" >>${ROTDIR}/logs/${CDATE}/list.txt
               elif [ $fsize -gt $fsize1 ]; then
                  getdata="YES" 
                  m = $((n - 1))
                  echo ".${ATMOS_ANALYSIS_RESTART}/${yy}${mm}${dd}.${hh}0000.sfcanl_data.tile${m}.nc" >>${ROTDIR}/logs/${CDATE}/list.txt
                  fsize1=$fsize
               fi
            fi
          else
            getdata2="YES"
            echo ".${ATMOS_ANALYSIS_RESTART}/${yy}${mm}${dd}.${hh}0000.sfcanl_data.tile${n}.nc" >>${ROTDIR}/logs/${CDATE}/list.txt
          fi
       done 
     else
       getdata="YES"
       echo  ".${ATMOS_ANALYSIS_RESTART}/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile1.nc  " >>${ROTDIR}/logs/${CDATE}/list.txt
       echo  ".${ATMOS_ANALYSIS_RESTART}/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile2.nc  " >>${ROTDIR}/logs/${CDATE}/list.txt
       echo  ".${ATMOS_ANALYSIS_RESTART}/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile3.nc  " >>${ROTDIR}/logs/${CDATE}/list.txt
       echo  ".${ATMOS_ANALYSIS_RESTART}/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile4.nc  " >>${ROTDIR}/logs/${CDATE}/list.txt
       echo  ".${ATMOS_ANALYSIS_RESTART}/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile5.nc  " >>${ROTDIR}/logs/${CDATE}/list.txt
       echo  ".${ATMOS_ANALYSIS_RESTART}/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile6.nc  " >>${ROTDIR}/logs/${CDATE}/list.txt
       getdata2="YES"
       echo  ".${ATMOS_ANALYSIS_RESTART}/${yy}${mm}${dd}.${hh}0000.sfcanl_data.tile1.nc  " >>${ROTDIR}/logs/${CDATE}/list.txt
       echo  ".${ATMOS_ANALYSIS_RESTART}/${yy}${mm}${dd}.${hh}0000.sfcanl_data.tile2.nc  " >>${ROTDIR}/logs/${CDATE}/list.txt
       echo  ".${ATMOS_ANALYSIS_RESTART}/${yy}${mm}${dd}.${hh}0000.sfcanl_data.tile3.nc  " >>${ROTDIR}/logs/${CDATE}/list.txt
       echo  ".${ATMOS_ANALYSIS_RESTART}/${yy}${mm}${dd}.${hh}0000.sfcanl_data.tile4.nc  " >>${ROTDIR}/logs/${CDATE}/list.txt
       echo  ".${ATMOS_ANALYSIS_RESTART}/${yy}${mm}${dd}.${hh}0000.sfcanl_data.tile5.nc  " >>${ROTDIR}/logs/${CDATE}/list.txt
       echo  ".${ATMOS_ANALYSIS_RESTART}/${yy}${mm}${dd}.${hh}0000.sfcanl_data.tile6.nc  " >>${ROTDIR}/logs/${CDATE}/list.txt
     fi    
     if [[ $getdata = "YES" || $getdata2 = "YES" ]]; then
       echo '$RETRO ' $RETRO
       if [[ (${RETRO:-"NO"} = "YES" && "$CDATE" -lt "2021032500") || ${REDUCEDRES:-"NO"} = "YES" ]]; then
          export tarball="${ICDUMP}_restarta.tar"
          htar -xvf ${HPSSEXPDIR}/${yy}${mm}${dd}${hh}/${tarball} -L ${ROTDIR}/logs/${CDATE}/list.txt 
          status=$?
          [[ $status -ne 0 ]] && exit $status
       else   
          export tarball="com_gfs_${gfssubver}_${ICDUMP}.${yy}${mm}${dd}_${hh}.${ICDUMP}_restart.tar"
          htar -xvf ${PRODHPSSDIR}/rh${yy}/${yy}${mm}/${yy}${mm}${dd}/${tarball} -L ${ROTDIR}/logs/${CDATE}/list.txt
          status=$?
          [[ $status -ne 0 ]] && exit $status
       fi     
     else
       echo "sfcanl exist, skip pulling data"
     fi
     if [ ! -d ${COMOUT_ATMOS_ANALYSIS_RESTART} ]; then
        mkdir -p ${COMOUT_ATMOS_ANALYSIS_RESTART}
        $NLN ${COMIN_ATMOS_ANALYSIS_RESTART}/* ${COMOUT_ATMOS_ANALYSIS_RESTART}/  
     fi
  else
     echo "sfcanl exist, skip pulling data"
  fi
#fi

rm -f ${ROTDIR}/logs/${CDATE}/list*

exit 0
