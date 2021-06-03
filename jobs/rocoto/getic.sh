#!/bin/ksh -x

###############################################################
## Abstract:
## Get GFS intitial conditions
## RUN_ENVIR : runtime environment (emc | nco)
## HOMEgfs   : /full/path/to/workflow
## EXPDIR : /full/path/to/config/files
## CDATE  : current date (YYYYMMDDHH)
## ICDUMP  : cycle name (gdas / gfs)
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
configs="base getic"
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

yyyy=$(echo $CDATE | cut -c1-4)
mm=$(echo $CDATE | cut -c5-6)
dd=$(echo $CDATE | cut -c7-8)
cyc=${cyc:-$(echo $CDATE | cut -c9-10)}

export COMPONENT=${COMPONENT:-atmos}

###############################################################

if [ $ics_from = "opsgfs" ]; then
  if [ $yyyy$mm$dd$cyc -lt 2012052100 ]; then
    set +x
    echo FATAL ERROR: SCRIPTS DO NOT SUPPORT OLD GFS DATA
    exit 2
  elif [ $yyyy$mm$dd$cyc -lt 2016051000 ]; then
    gfs_ver=v12
  elif [ $yyyy$mm$dd$cyc -lt 2017072000 ]; then
    gfs_ver=v13
  elif [ $yyyy$mm$dd$cyc -lt 2019061200 ]; then
    gfs_ver=v14
  elif [ $yyyy$mm$dd$cyc -lt 2021032100 ]; then
    gfs_ver=v15
  else
    gfs_ver=v16
  fi
fi

if [[ $EXP_WARM_START = ".false." || $replay -gt 0 ]] ; then
   target_dir=$ICSDIR/input
else
   target_dir=$ROTDIR
fi
if [[ ! -d $target_dir ]]; then
   mkdir -p $target_dir
fi
cd $target_dir/

if [ $ics_from = "opsgfs" ]; then

    # Location of production tarballs on HPSS
    hpssdir="/NCEPPROD/hpssprod/runhistory/rh$yyyy/$yyyy$mm/$PDY"

    # Handle nemsio and pre-nemsio GFS filenames
    case $gfs_ver in
      v14)
        # Add ICDUMP.PDY/CYC to target_dir
        target_dir=$ICSDIR/$CDATE/$ICDUMP/${ICDUMP}.$yyyy$mm$dd/$cyc
        mkdir -p $target_dir
        cd $target_dir

        nfanal=4
        fanal[1]="./${ICDUMP}.t${cyc}z.atmanl.nemsio"
        fanal[2]="./${ICDUMP}.t${cyc}z.sfcanl.nemsio"
        fanal[3]="./${ICDUMP}.t${cyc}z.nstanl.nemsio"
        fanal[4]="./${ICDUMP}.t${cyc}z.pgrbanl"
        flanal="${fanal[1]} ${fanal[2]} ${fanal[3]} ${fanal[4]}"
        tarpref="gpfs_hps_nco_ops_com"
        if [ $IICDUMP = "gdas" ]; then
            tarball="$hpssdir/${tarpref}_gfs_prod_${ICDUMP}.${CDATE}.tar"
        elif [ $IICDUMP = "gfs" ]; then
            tarball="$hpssdir/${tarpref}_gfs_prod_${ICDUMP}.${CDATE}.anl.tar"
        fi
        if [[ -s $target_dir/${ICDUMP}.t${cyc}z.atmanl.nemsio && \
              -s $target_dir/${ICDUMP}.t${cyc}z.sfcanl.nemsio && \
              -s $target_dir/${ICDUMP}.t${cyc}z.nstanl.nemsio && \
              -s $target_dir/${ICDUMP}.t${cyc}z.pgrbanl ]]; then
           echo "IC data exist, exit getic"
           exit 0 
        fi
       ;;
      v15)
        nfanal=2
        fanal[1]="./${ICDUMP}.$yyyy$mm$dd/$cyc/${ICDUMP}.t${cyc}z.atmanl.nemsio"
        fanal[2]="./${ICDUMP}.$yyyy$mm$dd/$cyc/${ICDUMP}.t${cyc}z.sfcanl.nemsio"
        flanal="${fanal[1]} ${fanal[2]}"
        if [ $CDATE -ge "2020022600" ]; then 
          tarpref="com"
        else 
          tarpref="gpfs_dell1_nco_ops_com"
        fi
        if [ $ICDUMP = "gdas" ]; then
            tarball="$hpssdir/${tarpref}_gfs_prod_${ICDUMP}.${yyyy}${mm}${dd}_${cyc}.${ICDUMP}_nemsio.tar"
        elif [ $ICDUMP = "gfs" ]; then
            tarball="$hpssdir/${tarpref}_gfs_prod_${ICDUMP}.${yyyy}${mm}${dd}_${cyc}.${ICDUMP}_nemsioa.tar"
        fi
        if [[ -s $target_dir/${ICDUMP}.$yyyy$mm$dd/$cyc/${ICDUMP}.t${cyc}z.atmanl.nemsio && \
              -s $target_dir/${ICDUMP}.$yyyy$mm$dd/$cyc/${ICDUMP}.t${cyc}z.sfcanl.nemsio ]]; then
           echo "IC data exist, exit getic"
           exit 0
        fi
       ;;
      v16)
        tarpref="com"
        if [[ $EXP_WARM_START = ".false." || $replay -gt 0 ]] ; then
          nfanal=2
          fanal[1]="./${ICDUMP}.$yyyy$mm$dd/$cyc/atmos/${ICDUMP}.t${cyc}z.atmanl.nc"
          fanal[2]="./${ICDUMP}.$yyyy$mm$dd/$cyc/atmos/${ICDUMP}.t${cyc}z.sfcanl.nc"
          flanal="${fanal[1]} ${fanal[2]}"
          if [ $ICDUMP = "gdas" ]; then
            tarball="$hpssdir/${tarpref}_gfs_prod_${ICDUMP}.${yyyy}${mm}${dd}_${cyc}.${ICDUMP}_nc.tar"
          else
            tarball="$hpssdir/${tarpref}_gfs_prod_${ICDUMP}.${yyyy}${mm}${dd}_${cyc}.${ICDUMP}_nca.tar"
          fi
          if [[ -s $target_dir/${ICDUMP}.$yyyy$mm$dd/$cyc/atmos/${ICDUMP}.t${cyc}z.atmanl.nc && \
                -s $target_dir/${ICDUMP}.$yyyy$mm$dd/$cyc/atmos/${ICDUMP}.t${cyc}z.sfcanl.nc ]]; then
            echo "IC data exist, exit getic"
            exit 0
          fi
        else  
          # can only warm start from gdas
          if [ $ICDUMP = "gdas" ]; then
            tarball="$hpssdir/${tarpref}_gfs_prod_${ICDUMP}.${yyyy}${mm}${dd}_${cyc}.${ICDUMP}_restart.tar"
        
            GDATE=$($NDATE -$assim_freq $CDATE)
            gyyyy=$(echo $GDATE | cut -c1-4)
            gmm=$(echo $GDATE | cut -c5-6)
            gdd=$(echo $GDATE | cut -c7-8)
            gcyc=$(echo $GDATE | cut -c9-10)
            tarball_b="$hpssdir/${tarpref}_gfs_prod_${ICDUMP}.${gyyyy}${gmm}${gdd}_${gcyc}.${ICDUMP}_restart.tar"
       
            IAUDATE=$($NDATE +3 $GDATE)
            iyyyy=$(echo $IAUDATE | cut -c1-4)
            imm=$(echo $IAUDATE | cut -c5-6)
            idd=$(echo $IAUDATE | cut -c7-8)
            icyc=$(echo $IAUDATE | cut -c9-10)

            # surface data 
            >fname1
            for i in $(seq 1 6); do
              echo ./gdas.${yyyy}${mm}${dd}/${cyc}/atmos/RESTART/${iyyyy}${imm}${idd}.${icyc}0000.sfcanl_data.tile${i}.nc >>fname1
            done
            echo ./gdas.${yyyy}${mm}${dd}/${cyc}/atmos/gdas.t${cyc}z.atmi003.nc >>fname1
            echo ./gdas.${yyyy}${mm}${dd}/${cyc}/atmos/gdas.t${cyc}z.atmi009.nc >>fname1
            echo ./gdas.${yyyy}${mm}${dd}/${cyc}/atmos/gdas.t${cyc}z.atminc.nc >>fname1

            # atmosphere data
            >fname2
            for i in $(seq 1 6); do
              echo ./gdas.${gyyyy}${gmm}${gdd}/${gcyc}/atmos/RESTART/${iyyyy}${imm}${idd}.${icyc}0000.fv_core.res.tile1.nc >>fname2
              echo ./gdas.${gyyyy}${gmm}${gdd}/${gcyc}/atmos/RESTART/${iyyyy}${imm}${idd}.${icyc}0000.fv_srf_wnd.res.tile1.nc >>fname2
              echo ./gdas.${gyyyy}${gmm}${gdd}/${gcyc}/atmos/RESTART/${iyyyy}${imm}${idd}.${icyc}0000.fv_tracer.res.tile1.nc >>fname2
              echo ./gdas.${gyyyy}${gmm}${gdd}/${gcyc}/atmos/RESTART/${iyyyy}${imm}${idd}.${icyc}0000.phy_data.res.tile1.nc >>fname2
              echo ./gdas.${gyyyy}${gmm}${gdd}/${gcyc}/atmos/RESTART/${iyyyy}${imm}${idd}.${icyc}0000.sfc_data.res.tile1.nc >>fname2
            done
            hpsstar get $tarball $fname1
            rc=$?
            if [ $rc -ne 0 ]; then
              echo "untarring $tarball failed, ABORT!"
              exit $rc 
            fi  
            hpsstar get $tarball_b $fname2
            rc=$?
            if [ $rc -ne 0 ]; then
              echo "untarring $tarball_b failed, ABORT!"
              exit $rc
            fi
          else
            echo "can only restart from gdas"
            exit 99
          fi
        fi
       ;;
 esac

    # First check the COMROOT for files, if present copy over
    rc=0
    if [ $machine = "WCOSS_C" ]; then

        # Need COMROOT
        module load prod_envir/1.1.0 >> /dev/null 2>&1

        comdir="$COMROOT/$ICDUMP/prod/$ICDUMP.$PDY"
        for i in `seq 1 $nfanal`; do
            if [ -f $comdir/${fanal[i]} ]; then
                $NCP $comdir/${fanal[i]} ${fanal[i]}
            else
                rb=1 ; ((rc+=rb))
            fi
        done

    fi

    # Get initial conditions from HPSS
    if [[ $rc -ne 0 || $machine != "WCOSS_C" ]]; then

        # check if the tarball exists
        hsi ls -l $tarball
        rc=$?
        if [[ $rc -ne 0 ]]; then
            echo "$tarball does not exist and should, ABORT!"
            exit $rc
        fi
        # get the tarball
        htar -xvf $tarball $flanal
        rc=$?
        if [[ $rc -ne 0 ]]; then
            echo "untarring $tarball failed, ABORT!"
            exit $rc
        fi

        # Move the files to legacy EMC filenames
        if [ $CDATE -le "2019061118" ]; then #GFSv14
           for i in `seq 1 $nfanal`; do
             $NMV ${fanal[i]} ${flanal[i]}
           done
        fi

    fi

    # If found, exit out
    if [[ $rc -ne 0 ]]; then
        echo "Unable to obtain operational GFS initial conditions, ABORT!"
        exit 1
    fi

elif [ $ics_from = "pargfs" ]; then

    case $gfs_ver in
      v14)
        nfanal=4
        fanal[1]="gfnanl.${ICDUMP}.$CDATE"
        fanal[2]="sfnanl.${ICDUMP}.$CDATE"
        fanal[3]="nsnanl.${ICDUMP}.$CDATE"
        fanal[4]="pgbanl.${ICDUMP}.$CDATE"
        flanal="${fanal[1]} ${fanal[2]} ${fanal[3]} ${fanal[4]}"

        # Get initial conditions from HPSS from retrospective parallel
        tarball="$HPSS_PAR_PATH/${CDATE}${ICDUMP}.tar"
       ;;
      v15)
        nfanal=2
        fanal[1]="gfnanl.${ICDUMP}.$CDATE"
        fanal[2]="sfnanl.${ICDUMP}.$CDATE"
        flanal="${fanal[1]} ${fanal[2]}"

        # Get initial conditions from HPSS from retrospective parallel
        tarball="$HPSS_PAR_PATH/${CDATE}/${ICDUMP}.tar"
       ;;
      v16)
        if [[ $EXP_WARM_START = ".false." || $replay -gt 0 ]] ; then
          nfanal=2
          fanal[1]="./${ICDUMP}.${yyyy}${mm}${dd}/${cyc}/atmos/${ICDUMP}.t${cyc}z.atmanl.nc"
          fanal[2]="./${ICDUMP}.${yyyy}${mm}${dd}/${cyc}/atmos/${ICDUMP}.t${cyc}z.sfcanl.nc"
          fanal[3]="./${ICDUMP}.${yyyy}${mm}${dd}/${cyc}/${ICDUMP}.t${cyc}z.atmanl.nc"
          fanal[4]="./${ICDUMP}.${yyyy}${mm}${dd}/${cyc}/${ICDUMP}.t${cyc}z.sfcanl.nc"
          flanal="${fanal[1]} ${fanal[2]} ${fanal[3]} ${fanal[4]}"
  
          if [[ $ICDUMP = "gfs" ]]; then
            tarball="$HPSS_PAR_PATH/${yyyy}${mm}${dd}${cyc}/${ICDUMP}_netcdfa.tar"
          else
            tarball="$HPSS_PAR_PATH/${yyyy}${mm}${dd}${cyc}/${ICDUMP}.tar"
          fi
        else
          tarball="$HPSS_PAR_PATH/${yyyy}${mm}${dd}${cyc}/${ICDUMP}_restarta.tar"

          # check if the tarball exists
          hsi ls -l $tarball
          rc=$?
          if [ $rc -ne 0 ]; then
              echo "$tarball does not exist and should, ABORT!"
              exit $rc
          fi

          htar -xvf $tarball
          rc=$?
          if [ $rc -ne 0 ]; then
              echo "untarring $tarball failed, ABORT!"
              exit $rc
          fi

          GDATE=$($NDATE -$assim_freq $CDATE)
          gyyyy=$(echo $GDATE | cut -c1-4)
          gmm=$(echo $GDATE | cut -c5-6)
          gdd=$(echo $GDATE | cut -c7-8)
          gcyc=$(echo $GDATE | cut -c9-10)
          tarball="$HPSS_PAR_PATH/${gyyyy}${gmm}${gdd}${gcyc}/${ICDUMP}_restartb.tar"

          # check if the tarball exists
          hsi ls -l $tarball
          rc=$?
          if [ $rc -ne 0 ]; then
              echo "$tarball does not exist and should, ABORT!"
              exit $rc
          fi

          htar -xvf $tarball
          rc=$?
          if [ $rc -ne 0 ]; then
              echo "untarring $tarball failed, ABORT!"
              exit $rc
          fi
        fi
       ;;
    esac

    # get the tarball
    if [[ $EXP_WARM_START = ".false." || $replay -gt 0 ]] ; then
       # check if the tarball exists
       hsi ls -l $tarball
       rc=$?
       if [ $rc -ne 0 ]; then
           echo "$tarball does not exist and should, ABORT!"
           exit $rc
       fi
       htar -xvf $tarball $flanal
       rc=$?
       if [ $rc -ne 0 ]; then
           echo "untarring $tarball failed, ABORT!"
           exit $rc
       fi
    fi

else

    echo "ics_from = $ics_from is not supported, ABORT!"
    exit 1

fi
###############################################################

# Copy pgbanl file to COMROT for verification - GFSv14 only
if [ $CDATE -le "2019061118" ]; then #GFSv14
  COMROT=$ROTDIR/${ICDUMP}.$PDY/$cyc/$COMPONENT
  [[ ! -d $COMROT ]] && mkdir -p $COMROT
  $NCP ${fanal[4]} $COMROT/${ICDUMP}.t${cyc}z.pgrbanl
fi

###############################################################
# Exit out cleanly
exit 0
