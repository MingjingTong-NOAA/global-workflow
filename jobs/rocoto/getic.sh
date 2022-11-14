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
export DOGCYCLE=${DOGCYCLE:-"YES"}
export replay_4DIAU=${replay_4DIAU:-"NO"}

# Create ROTDIR/EXTRACT_DIR
if [ ! -d $ROTDIR ]; then mkdir -p $ROTDIR ; fi
if [ ! -d $EXTRACT_DIR ]; then mkdir -p $EXTRACT_DIR ; fi
if [[ $MODE = "forecast-only" && $EXP_WARM_START = ".true." ]]; then
   cd $ROTDIR 
else
   cd $EXTRACT_DIR
fi

# Check version, cold/warm start, and resolution
if [[ $MODE = "cycled" && $EXP_WARM_START = ".true." && "$CDATE" = "$SDATE" ]]; then # Pull warm start ICs - no chgres

  # there is problem pulling all warm start data at once, so pull data before running DA cycle 
  if [ -d $ROTDIR/gdas.${PDY} ]; then 
     echo "IC exists, skip pulling data"
     exit 0
  else
     echo "Prepare IC before running warm-start DA cycling"
     exit 99
  fi
 
  # Pull RESTART files off HPSS
  cd $ROTDIR
  RESTARTEXP=${RESTARTEXP:-${PSLOT}}
  htar -xvf ${HPSSEXPDIR}/$RESTARTEXP/$GDATE/gdas_restartb.tar
  status=$?
  [[ $status -ne 0 ]] && exit $status
  htar -xvf ${HPSSEXPDIR}/$RESTARTEXP/$CDATE/gdas_restarta.tar
  status=$?
  [[ $status -ne 0 ]] && exit $status

  if [ $DOHYBVAR = "YES" ]; then
    for igp in $(seq 1 8); do
       gpn=$(printf %02i $igp)
       htar -xvf ${HPSSEXPDIR}/${RESTARTEXP}/${GDATE}/enkfgdas_restartb_grp${gpn}.tar
       status=$?
       [[ $status -ne 0 ]] && exit $status
       htar -xvf ${HPSSEXPDIR}/${RESTARTEXP}/${CDATE}/enkfgdas_restarta_grp${gpn}.tar
       status=$?
       [[ $status -ne 0 ]] && exit $status
    done
  fi

elif [ $MODE != "cycled" ]; then # Pull chgres cube inputs for cold start IC generation

  if [[ $MODE == "forecast-only" && $EXP_WARM_START = ".true." ]]; then
     # pull warm start files
     hpssdir="/NCEPDEV/$HPSS_PROJECT/1year/$USER/$machine/scratch/$RESTARTEXP"
     gdasb=$hpssdir/$GDATE/gdas_restartb.tar
     gdasa=$hpssdir/$CDATE/gdas_restarta.tar
     htar -xvf $gdasb
     htar -xvf $gdasa 
     exit 0
  else
     # Run UFS_UTILS GETICSH
     atmanl=${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.atmanl.nc
     sfcanl=${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.sfcanl.nc
     abias=${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.abias
     if [[ ! -s $atmanl || ! -s $sfcanl || ! -s $abias ]]; then
          sh ${GETICSH} ${ICDUMP}
       status=$?
       [[ $status -ne 0 ]] && exit $status
   
     else
       echo "IC atmanl exists, skip pulling data"
     fi
  fi


fi

cd $EXTRACT_DIR
# Move extracted data to ICSDIR
if [ ! -d ${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT} ]; then
  mkdir -p ${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}
fi
if [[ -d ${EXTRACT_DIR}/${ICDUMP}.${yy}${mm}${dd}/${hh} && $MODE != "cycled" ]]; then
  if [ -d ${EXTRACT_DIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT} ]; then
     mv ${EXTRACT_DIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/* ${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/
  else
     mv ${EXTRACT_DIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/* ${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/
  fi
fi

# Pull dtfanl for GFS replay
dtfanl=${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.dtfanl.nc
if [[ $MODE = "replay" && $DOGCYCLE = "YES" && $DONST = "YES" && ! -s $dtfanl ]]; then
   if [[ ${RETRO:-"NO"} = "YES" && "$CDATE" -lt "2021032500" ]]; then
      export tarball="${ICDUMP}_restarta.tar"
      htar -xvf ${HPSSDIR}/${yy}${mm}${dd}${hh}/${tarball} ./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.dtfanl.nc  
   else
      export tarball="com_gfs_prod_${ICDUMP}.${yy}${mm}${dd}_${hh}.${ICDUMP}_restart.tar"
      htar -xvf ${PRODHPSSDIR}/rh${yy}/${yy}${mm}/${yy}${mm}${dd}/${tarball} ./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.dtfanl.nc
   fi
   mv ${EXTRACT_DIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.dtfanl.nc ${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/
   rc=$?
   [ $rc != 0 ] && exit $rc
fi

# Pull sfcanl restart file to get tref for replay and DA cycle
cd ${ICSDIR}
if [[ $gfs_ver = "v16" ]]; then
  if [[  $MODE != "forecast-only" && ($DO_TREF_TILE = ".true." || $DOGCYCLE != "YES" ) && ("$CDATE" != "$SDATE" || $EXP_WARM_START = ".true.") ]]; then
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
          if [ "$CDATE" -ge 2022062700 ]; then 
             export tarball="com_gfs_v16.2_${ICDUMP}.${yy}${mm}${dd}_${hh}.${ICDUMP}_restart.tar"
          else
             export tarball="com_gfs_prod_${ICDUMP}.${yy}${mm}${dd}_${hh}.${ICDUMP}_restart.tar"
          fi
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
  fi

  if [[ $MODE = "replay" && $replay_4DIAU = "YES" && ( $EXP_WARM_START = ".true." || "$CDATE" != "$SDATE" ) ]]; then
     if [ ! -s ${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.atmanl.ensres.nc ]; then
       cd $EXTRACT_DIR
       echo "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.atma003.ensres.nc " >list.txt
       echo "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.atma009.ensres.nc " >>list.txt
       echo "./${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${ICDUMP}.t${hh}z.atmanl.ensres.nc " >>list.txt
  
       if [[ ${RETRO:-"NO"} = "YES" && "$CDATE" -lt "2021032500" ]]; then
          export tarball="${ICDUMP}.tar"
          htar -xvf ${HPSSDIR}/${yy}${mm}${dd}${hh}/${tarball} -L ./list.txt
          status=$?
          [[ $status -ne 0 ]] && exit $status
       else
          export tarball="com_gfs_prod_${ICDUMP}.${yy}${mm}${dd}_${hh}.${ICDUMP}_nc.tar"
          htar -xvf ${PRODHPSSDIR}/rh${yy}/${yy}${mm}/${yy}${mm}${dd}/${tarball} -L ./list.txt
          status=$?
          [[ $status -ne 0 ]] && exit $status
       fi
       status=$?
       [[ $status -ne 0 ]] && exit $status
       mv ${EXTRACT_DIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/*ensres.nc ${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/
     else
       echo "atmanl.ensres for 4DIAU replay exist, skip pulling data"
     fi
  fi
fi

# Pull surface analysis file for warm-start run
if [[ $MODE = "replay" && $EXP_WARM_START = ".true." ]]; then
  if [[ ( $CDUMP = "gfs" && $gfsanl = "NO" ) || "$CDATE" = "$SDATE" ]]; then
    if [[ ! -d $ROTDIR/gdas.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART && $DOGCYCLE = "YES" ]]; then
      cd $ROTDIR
      echo  "./gdas.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile1.nc  " >list.txt
      echo  "./gdas.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile2.nc  " >>list.txt
      echo  "./gdas.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile3.nc  " >>list.txt
      echo  "./gdas.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile4.nc  " >>list.txt
      echo  "./gdas.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile5.nc  " >>list.txt
      echo  "./gdas.${yy}${mm}${dd}/${hh}/${COMPONENT}/RESTART/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile6.nc  " >>list.txt
      # old run
      #tarball="gdas_restartb.tar"
      # new run
      tarball="gdas_restarta.tar"
      htar -xvf ${HPSSEXPDIR}/${RESTARTEXP}/${CDATE}/${tarball} -L ./list.txt
      status=$?
      [[ $status -ne 0 ]] && exit $status
    fi
    if [ ! -d $ROTDIR/gdas.${gyy}${gmm}${gdd}/${ghh}/${COMPONENT}/RESTART ]; then
      cd $ROTDIR
      tarball="gdas_restartb.tar"
      htar -xvf ${HPSSEXPDIR}/${RESTARTEXP}/${GDATE}/${tarball}
      status=$?
      [[ $status -ne 0 ]] && exit $status
    fi
  fi
  if [[ $MODE = "replay" && $replay_4DIAU = "YES" ]]; then
     cd $ROTDIR
     echo "./gdas.${yy}${mm}${dd}/${hh}/${COMPONENT}/gdas.t${hh}z.atmi003.nc " >list.txt
     echo "./gdas.${yy}${mm}${dd}/${hh}/${COMPONENT}/gdas.t${hh}z.atminc.nc "  >>list.txt
     echo "./gdas.${yy}${mm}${dd}/${hh}/${COMPONENT}/gdas.t${hh}z.atmi009.nc " >>list.txt
     tarball="gdas.tar"
     htar -xvf ${HPSSEXPDIR}/${RESTARTEXP}/${CDATE}/${tarball} -L ./list.txt
     status=$?
     [[ $status -ne 0 ]] && exit $status
  fi
fi          

# Pull pgbanl file for verification/archival - v14+
# disable it for now
if [ "YES" = "NO" ]; then
if [[ $MODE != "cycled" && $DO_METP = "YES" && $ICSTYP = "gfs" && $ICDUMP = "gdas" ]]; then
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
            if [ "$CDATE" -ge 2022062700 ]; then
               export tarball="com_v16.2_prod_${ICDUMP}.${yy}${mm}${dd}_${hh}.${ICDUMP}_pgrb2.tar"
            else
               export tarball="com_gfs_prod_${ICDUMP}.${yy}${mm}${dd}_${hh}.${ICDUMP}_pgrb2.tar"
            fi
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

##########################################
# Remove the Temporary working directory
##########################################
cd $DATAROOT
[[ $KEEPDATA = "NO" ]] && rm -rf $DATA

###############################################################
# Exit out cleanly


exit 0
