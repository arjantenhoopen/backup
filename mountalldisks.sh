#!/bin/sh
MY_NAME=`basename $0`
PROGRAMSRCFILE=/tenhoopen/src/backup/${MY_NAME}.sh
MYVERSION=1

SYSLOG="logger -t $MY_NAME --"		# log to /var/log/messages
IAM=`whoami`
THISPC=`hostname`
MOUNTFILE=/tmp/mountfile$$

#
# Help informatie
#
show_help ()
{
    echo "-----------------------------------------------------------------------------------------------"
    echo "-h                    Dit bericht "
    echo "-v                    Versie en versie controle "
} 
#
# Error informatie
#
show_error ()
{
    echo "Onbekende optie of onvolledige commando regel.";
    echo "Gebruik -h om uitleg te verkrijgen.";
}

#
# Versie controle
#
version_check ()
{
  if [ ! -f ${PROGRAMSRCFILE} ] ; then
  {
    echo Waarschuwing: kan niet bepalen of dit de laatste versie is
  }
  else
  {
    LATESTVERSION=`grep ^MYVERSION= ${PROGRAMSRCFILE}|cut -f2 -d =`
    if [ ${MYVERSION} -ne ${LATESTVERSION} ] ; then
    {
      echo ER IS EEN NIEUWER VERSIE
      echo Nieuwste versie is ${LATESTVERSION} mijn versie is ${MYVERSION}
    }
    else
    {
      echo Mijn versie is ${MYVERSION} en is up to date
    }
    fi
  }
  fi
}


#
# Het afhandelen van alle opties op de commando regel
#
while getopts vh OPT
do
    case ${OPT} in
    h)    show_help;
          exit 0
	  ;;
    v)    version_check;
          exit 0
	  ;;
    \?)   show_error;
          exit 2
	  ;;
    esac
done

umask 022 

#
# is dit de nieuwste versie?
#
version_check

#
# mount alles wat we nodig hebben
#
STOP=0
grep -e "^#" /etc/fstab |grep ":" |sed -e "s/[ ]\+/ /g" >  ${MOUNTFILE}
while read L
do
  FSTYPE=`echo "${L}" | cut -f3 -d " "`
  MOUNTPOINT=`echo "${L}" | cut -f2 -d " "`
  FS=`echo "${L}" | cut -f1 -d " " | sed -e "s/^#//"`
  echo Mounting ${FS} type ${FSTYPE} on ${MOUNTPOINT}
  sudo mount -t ${FSTYPE} ${FS} ${MOUNTPOINT}
  RC=$?
  if [ ${RC} -eq 0 ] ; then
  {
    echo Mounted ${MOUNTPOINT}
  }
  else
  {
    echo "Kan ${MOUNTPOINT} niet mounten"
    STOP=1
  }
  fi
done < ${MOUNTFILE}

rm -f ${MOUNTFILE}

if [ ${STOP} -ne 0 ] ; then
{
  echo "Mount problemen, werk aan de winkel .. doejjj"
  exit 3
}
fi

exit 0

