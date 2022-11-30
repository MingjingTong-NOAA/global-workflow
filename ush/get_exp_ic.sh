#!/bin/bash

#----------------------------------------------------------------------
# Retrieve gfs v16 data.  v16 was officially implemented on 12 UTC
# March 22, 2021.  However, the way the switch over was done,
# the 'prod' v16 tarballs started March 21, 2021 06Z.
#----------------------------------------------------------------------

bundle=$1

set -x

cd $EXTRACT_DIR

date10_m6=`$NDATE -6 $yy$mm$dd$hh`

echo $date10_m6
yy_m6=$(echo $date10_m6 | cut -c1-4)
mm_m6=$(echo $date10_m6 | cut -c5-6)
dd_m6=$(echo $date10_m6 | cut -c7-8)
hh_m6=$(echo $date10_m6 | cut -c9-10)
ICSDIR=${ICSDIR:-$OUTDIR}
EXECgfs=${EXECgfs:-/scratch2/GFDL/gfdlscr/Mingjing.Tong/global_workflow/shield_dev}
#----------------------------------------------------------------------
# Get the atm and sfc 'anl' netcdf files from the gfs or gdas
# tarball.
#----------------------------------------------------------------------

  if [ "$bundle" = "gdas" ] ; then
    directory=${HPSSEXPDIR}/${gfs_ver:4}/${yy}${mm}${dd}${hh}
    file=gdas.tar
  else
    directory=${HPSSEXPDIR}/${gfs_ver:4}/${yy}${mm}${dd}${hh}
    file=gfs_nca.tar
  fi

  atmanl=${ICSDIR}/${bundle}.${yy}${mm}${dd}/${hh}/atmos/${bundle}.t${hh}z.atmanl.nc
  sfcanl=${ICSDIR}/${bundle}.${yy}${mm}${dd}/${hh}/atmos/${bundle}.t${hh}z.sfcanl.nc
  if [[ ! -s $atmanl || ! -s $sfcanl ]]; then
    rm -f ./list.hires*
    touch ./list.hires3
    htar -tvf  $directory/$file > ./list.hires1
    grep "anl.nc" ./list.hires1 > ./list.hires2
    while read -r line
    do 
      echo ${line##*' '} >> ./list.hires3
    done < "./list.hires2"
  
    htar -xvf $directory/$file -L ./list.hires3
    rc=$?
    [ $rc != 0 ] && exit $rc

    rm -f ./list.hires*
  fi

#----------------------------------------------------------------------
# Get the 'abias' and radstat files when processing 'gdas'.
#----------------------------------------------------------------------

  if [ "$bundle" = "gdas" ] ; then

    directory=${HPSSEXPDIR}/${gfs_ver:4}/${yy}${mm}${dd}${hh}
    file=gdas_restarta.tar

    if [ "${MODE:-"cycled"}" = "cycled" ] || [ "${DO_OmF:-"NO"}" = "YES" ]; then
      htar -xvf $directory/$file ./gdas.${yy}${mm}${dd}/${hh}/atmos/gdas.t${hh}z.abias
      rc=$?
      [ $rc != 0 ] && exit $rc
      htar -xvf $directory/$file ./gdas.${yy}${mm}${dd}/${hh}/atmos/gdas.t${hh}z.abias_air
      rc=$?
      [ $rc != 0 ] && exit $rc
      htar -xvf $directory/$file ./gdas.${yy}${mm}${dd}/${hh}/atmos/gdas.t${hh}z.abias_int
      rc=$?
      [ $rc != 0 ] && exit $rc
      htar -xvf $directory/$file ./gdas.${yy}${mm}${dd}/${hh}/atmos/gdas.t${hh}z.abias_pc
      rc=$?
      [ $rc != 0 ] && exit $rc
      htar -xvf $directory/$file ./gdas.${yy}${mm}${dd}/${hh}/atmos/gdas.t${hh}z.radstat
      rc=$?
      [ $rc != 0 ] && exit $rc
  
      cd ./gdas.${yy}${mm}${dd}/${hh}/atmos
      ln -s gdas.t${hh}z.abias abias
      ln -s gdas.t${hh}z.abias_air abias_air
  
      $EXECgfs/zero_biascoeff.x
      [ $rc != 0 ] && exit $rc
      mv abias.zeroed gdas.t${hh}z.abias
      mv abias_pc.zeroed gdas.t${hh}z.abias_pc
      mv abias_air.zeroed gdas.t${hh}z.abias_air
      rm -f abias abias_air
    fi

  fi

set +x
echo DATA PULL FOR $bundle DONE

exit 0
