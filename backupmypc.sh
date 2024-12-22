#!/bin/sh
#
SKIPSYSTEMS=
MY_NAME=$(basename $0)
PROGRAMSRCFILE=/tenhoopen/src/backup/${MY_NAME}.sh
MYVERSION=28

#SYSLOG="logger -t $MY_NAME --"		# log to /var/log/messages
IAM=$(whoami)
THISPC=$(hostname)
STACKFILE=/tmp/stackfile$$
# Give diskmountpoint a default value
DISKMOUNTPOINT=/BACKUPDISK
DAY_OF_WEEK=$(date +%a)                  # is it Mon, Tue ...
LOCALHOMEDIR=/home/${IAM}/
DIRLIST=${HOME}/.config/backupmypc/dirlist.conf
MOUNTLIST=${HOME}/.config/backupmypc/mountlist.conf
FILELIST=${HOME}/.config/backupmypc/filelist.conf
EXCLLISTHOME=${HOME}/.config/backupmypc/exclude-home.conf
EXCLLISTDIR=${HOME}/.config/backupmypc/exclude-dir.conf

#
# gebruik geen --delete  als standaar optie voor rsync !!!
#
# Nadeel is dat het wel wat aanjongt LOL maar backup is een verzekering.
# Als de disk echt vol loopt kijken we wel weer ....
# 
# Default Rsync opties
# 
RSYNCOPTIONS=' -a -r'
RSYNCOPTIONSDIRLIST=' -a -r'
RSYNCOPTIONSMOUNTLIST=' -a -r -L'
#RSYNCEXCLUDEDIR="  --exclude-from ${EXCLLISTDIR}"
#RSYNCEXCLUDEHOME=" --exclude-from ${EXCLLISTHOME}"
RSYNCEXCLUDEDIR=" "
RSYNCEXCLUDEHOME=" "

MOUNTFILE=/tmp/mountfile$$
ERRORLOG=/tmp/backupmypcerror$$.log
GOTERROR=false
VERBOSE=false

#
# Help informatie
#
show_help ()
{
    echo "-----------------------------------------------------------------------------------------------"
    echo "-d TOPDIR             Topdir waar naar toe gebackuped moet worden, default is ${DISKMOUNTPOINT}"
    echo "-s hostname           Skip this host"
    echo "-h                    Dit bericht "
    echo "-V                    Verbose rsync"
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
while getopts vVhd:s: OPT
do
    case ${OPT} in
    h)    show_help;
          exit 0
	  ;;
    v)    version_check;
          exit 0
	  ;;
    V)    RSYNCOPTIONS=" -vv ${RSYNCOPTIONS} " 
	  VERBOSE=true
	  ;;
    d)    DISKMOUNTPOINT=${OPTARG}
	  ;;
    s)    SKIPSYSTEMS="${SKIPSYSTEMS} ${OPTARG}"
	  ;;
    \?)   show_error;
          exit 2
	  ;;
    esac
done

#
# Moet er nog wat gemount worden
# 
case ${DISKMOUNTPOINT} in
  "/BACKUPDISK"                )
  				echo "Using /BACKUPDISK as mountpoint"
				 ;;
  		
  *			     )
  				echo "ERROR: Unknown mountpoint ${DISKMOUNTPOINT}, need to quit..."
				exit 5
				 ;;
esac

DISKMOUNTPOINTLOGFILE=${DISKMOUNTPOINT}/log.txt

RUNDATEFILEDAY=${DISKMOUNTPOINT}/${THISPC}/${DAY_OF_WEEK}/last-run.txt
RUNDATEFILE=${DISKMOUNTPOINT}/last-run.txt


#
# LETOP de / achteraan LOCALHOMEDIR is verplicht!!!!! (zie man page van rsync)
#
BACKUPHOMEDIR=${DISKMOUNTPOINT}/${THISPC}/${DAY_OF_WEEK}/home/${IAM}
BACKUPMYSQLDIR=${DISKMOUNTPOINT}/${THISPC}/${DAY_OF_WEEK}/mysql/${IAM}
BACKUPDIRLISTDIR=${DISKMOUNTPOINT}/${THISPC}/${DAY_OF_WEEK}/dirlist/${IAM}
BACKUPMOUNTLISTDIR=${DISKMOUNTPOINT}/${THISPC}/${DAY_OF_WEEK}/mountlist/${IAM}
BACKUPFILELISTDIR=${DISKMOUNTPOINT}/${THISPC}/${DAY_OF_WEEK}/filelist/${IAM}

umask 022 

#
# systemen om over te slaan
#
if [ "${SKIPSYSTEMS}" != "" ] ; then
{
  echo "Skipping systems: ${SKIPSYSTEMS}"
}
fi


#
# Is alles wat we nodig hebben aanwezig?
#
echo "${MY_NAME} on host ${THISPC}"
echo "        LOCALHOMEDIR		${LOCALHOMEDIR}"
echo "        BACKUPHOMEDIR		${BACKUPHOMEDIR}"
echo "        BACKUPMYSQLDIR		${BACKUPMYSQLDIR}"
echo "        BACKUPDIRLISTDIR	${BACKUPDIRLISTDIR}"
echo "        BACKUPFILELISTDIR	${BACKUPFILELISTDIR}"
echo " "

#
# Both homedirs must be different
#
if [ "${LOCALHOMEDIR}" = "${BACKUPHOMEDIR}" ] ; then
{
  echo "ERROR: LOCALHOMEDIR ${LOCALHOMEDIR} is gelijk aan BACKUPHOMEDIR ${BACKUPHOMEDIR}, roep Arjan!"
  echo -n "Toets op Enter: "
  read KEY

  exit 3
}
fi

#
# do the dirs exist
#
if [ ! -d "${LOCALHOMEDIR}" ] ; then
{
  echo "ERROR: ${LOCALHOMEDIR} bestaat niet. Hier zouden je bestanden moeten staan. Roep Arjan!"
  echo -n "Toets op Enter: "
  read KEY

  exit 4
}
fi

if [ ! -d "${BACKUPHOMEDIR}" ] ; then
{
  mkdir -p "${BACKUPHOMEDIR}" 2>/dev/null 1>/dev/null
  if [ ! -d "${BACKUPHOMEDIR}" ] ; then
  {
    echo "ERROR: Kan ${BACKUPHOMEDIR} niet maken. Hier moeten je bestanden naar toe veilig gesteld worden. Roep Arjan!"
    exit 5
  }
  fi
}
fi

if [ ! -d "${BACKUPMYSQLDIR}" ] ; then
{
  mkdir -p "${BACKUPMYSQLDIR}" 2>/dev/null 1>/dev/null
  if [ ! -d "${BACKUPMYSQLDIR}" ] ; then
  {
    echo "ERROR: Kan ${BACKUPMYSQLDIR} niet maken. Hier moeten je bestanden naar toe veilig gesteld worden. Roep Arjan!"
    echo -n "Toets op Enter: "
    read KEY

    exit 5
  }
  fi
}
fi

#
# extra mappen die meegenomen moeten worden staan in DIRLIST,is er wat?
#
if [ ! -f "${DIRLIST}" ] ; then
{
  echo Geen extra lokale mappen te backupen want ${DIRLIST} bestaat niet
}
fi

#
# extra mappen die meegenomen moeten worden staan in DIRLIST,is er wat?
#
if [ ! -f "${MOUNTLIST}" ] ; then
{
  echo Geen extra gemounte mappen te backupen want ${MOUNTLIST} bestaat niet
}
fi

#
# extra bestanden die meegenomen moeten worden staan in FILELIST,is er wat?
#
if [ ! -f "${FILELIST}" ] ; then
{
  echo Geen extra bestanden te backupen want ${FILELIST} bestaat niet
}
fi

#
# exclude bestanden die meegenomen moeten worden
#
if [ ! -f "${EXCLLISTHOME}" ] ; then
{
  echo Geen exclude bestand voor /home  want ${EXCLLISTHOME} bestaat niet
}
else
{
	RSYNCEXCLUDEHOME="  --exclude-from ${EXCLLISTHOME}"
}
fi
if [ ! -f "${EXCLLISTDIR}" ] ; then
{
  echo Geen exclude bestanden voor directories want ${EXCLLISTDIR} bestaat niet
}
else
{
	RSYNCEXCLUDEDIR="  --exclude-from ${EXCLLISTDIR}"
}
fi

#
# mount alles wat we nodig hebben
#
# In /etc/fstab staan all filesystmen incl NFS, echter een aantal worden niet automatisch
# gemount (noauto), zoals bv alle pi homedirs op pi's
#
# De ${MOUNTFILE} wordt ook weer gebruikt bij het unmounten aan het einde van het script
#
# Hier worden ze geselecteerd door op ,noauto te greppen
#
STOP=0
#grep -e "^#" /etc/fstab |grep -v "^##" |grep ":" |sed -e "s/[ ]\+/ /g"  >  ${MOUNTFILE}
#grep ",noauto" /etc/fstab |sed -e "s/[ ]\+/ /g"  >  ${MOUNTFILE}
grep "nfs [ ]* noauto [ ]*0" /etc/fstab |sed -e "s/[ ]\+/ /g"  >  ${MOUNTFILE}

FSMOUNTCOUNT=$(cat ${MOUNTFILE} | wc -l)

if [ ${FSMOUNTCOUNT} -eq 0 ] ; then
{
	echo "### Er is niets te mounten ....."
}
else
{
	echo "### Mounting filesystems ....."
}

fi

while read L
do
  FSTYPE=`echo "${L}" | cut -f3 -d " "`
  MOUNTPOINT=`echo "${L}" | cut -f2 -d " "`
  FS=`echo "${L}" | cut -f1 -d " " | sed -e "s/^#//"`
  REMOTEHOST=$(echo ${FS} | cut -f1 -d:)


  #echo -n "System: ${REMOTEHOST}:	Fileystem ${FS}	on ${MOUNTPOINT}"
  if ${VERBOSE} ; then
    echo -n "Mounting ${FS}	on ${MOUNTPOINT}"
  fi
  if [[ "${SKIPSYSTEMS}" =~ "${REMOTEHOST}" ]]; then
  {
    echo
    echo "  Skipping host ${REMOTEHOST}"
  }
  else
  {
    TARGETALREADYMOUNTED=$(mount | grep ${MOUNTPOINT} | wc -l)
    if [ ${TARGETALREADYMOUNTED} -ne 1 ] ; then
    {
      #echo -n "  Mounting ${FS} type ${FSTYPE} on ${MOUNTPOINT}"
      sudo mount -t ${FSTYPE} ${FS} ${MOUNTPOINT}
      RC=$?
      if [ ${RC} -eq 0 ] ; then
      {
        if ${VERBOSE} ; then
	  echo "		Mounted"
	fi
      }
      else
      {
        echo "ERROR Cannot mount ${FS}"
        STOP=1
      }
      fi
    }
    else
    {
      #echo "  Filesystem ${FS} type ${FSTYPE} from ${REMOTEHOST} is already mounted on ${MOUNTPOINT}"
      if ${VERBOSE} ; then
        echo "		Is already Mounted"
      fi
    }
    fi
  }
  fi
done < ${MOUNTFILE}

if [ ${STOP} -ne 0 ] ; then
{
  echo "Mount problemen, werk aan de winkel .. doejjj"
  echo -n "Toets op Enter: "
  read KEY

  exit 3
}
fi

echo " "

#
# Ready to rock and roll
#
echo -n "Started: " > ${RUNDATEFILE}
date >> ${RUNDATEFILE}
# and for this day
echo -n "Started: " > ${RUNDATEFILEDAY}
date >> ${RUNDATEFILEDAY}

#
# Backup van de home directory van de huidige gebruiker
#
cd ${LOCALHOMEDIR}
echo "### Backup maken van de home directory van gebruiker ${IAM} op ${THISPC}"
if ${VERBOSE} ; then
  echo Uitvoeren: rsync ${RSYNCOPTIONS} ${RSYNCEXCLUDEHOME} "${LOCALHOMEDIR}" "${BACKUPHOMEDIR}"
fi
rsync                 ${RSYNCOPTIONS} ${RSYNCEXCLUDEHOME} "${LOCALHOMEDIR}" "${BACKUPHOMEDIR}"
RC=$?
if [ ${RC} -ne 0 ] ; then
{
  echo "###     ERROR rsync ${RSYNCOPTIONS} ${RSYNCEXCLUDEHOME} ${LOCALHOMEDIR} ${BACKUPHOMEDIR}"
  echo "Er is wat fout gegaan bij rsync ${RSYNCOPTIONS} ${RSYNCEXCLUDEHOME} ${LOCALHOMEDIR} ${BACKUPHOMEDIR}" >> ${ERRORLOG}
  echo '###### ERROR END #############################################################'
  GOTERROR=true
}
fi
echo " "

#
# De lokale mappen die meegenomen moeten worden
#
if [ -f "${DIRLIST}" ] ; then
{
  echo "### Backup van de directory list in ${DIRLIST}"
  while read MAP
  do
    if [ ! -d "${MAP}" ] ; then
    {
      echo "FOUT in ${DIRLIST} want ${MAP} bestaat niet"
    }
    else
    {
	echo "###   Map is ${MAP} "
	if ${VERBOSE} ; then 
	  echo "  Uitvoeren: rsync ${RSYNCOPTIONSDIRLIST} ${RSYNCEXCLUDEDIR} ${MAP}/ ${BACKUPDIRLISTDIR}${MAP}"
	fi
	mkdir -p "${BACKUPDIRLISTDIR}""${MAP}"
	sudo            rsync ${RSYNCOPTIONSDIRLIST} ${RSYNCEXCLUDEDIR} "${MAP}/" "${BACKUPDIRLISTDIR}""${MAP}"
	RC=$?
	if [ ${RC} -ne 0 ] ; then
	{
          echo "###     ERROR sudo rsync ${RSYNCOPTIONSDIRLIST} ${RSYNCEXCLUDEDIR} ${MAP}/ ${BACKUPDIRLISTDIR}${MAP}"
          echo "Er is wat fout gegaan bij sudo rsync ${RSYNCOPTIONSDIRLIST} ${RSYNCEXCLUDEDIR} ${MAP}/ ${BACKUPDIRLISTDIR}${MAP}"  >> ${ERRORLOG}
          GOTERROR=true
	}
        fi
    }
    fi
  done < "${DIRLIST}"
}
fi
echo " "

#
# De gemounte mappen die meegenomen moeten worden
#
if [ -f "${MOUNTLIST}" ] ; then
{
  echo "### Backup maken van mounted list in ${MOUNTLIST}"
  while read MAP
  do
    if [ ! -d "${MAP}" ] ; then
    {
      echo "FOUT in ${MOUNTLIST} want ${MAP} bestaat niet"
    }
    else
    {
	echo "###   Map is ${MAP} "
	if ${VERBOSE} ; then 
	  echo "  Uitvoeren: rsync ${RSYNCOPTIONSMOUNTLIST} ${RSYNCEXCLUDEDIR} ${MAP}/ ${BACKUPMOUNTLISTDIR}${MAP}"
	fi
	mkdir -p "${BACKUPMOUNTLISTDIR}""${MAP}"
	sudo            rsync ${RSYNCOPTIONSMOUNTLIST} ${RSYNCEXCLUDEDIR} "${MAP}/" "${BACKUPMOUNTLISTDIR}""${MAP}"
	RC=$?
	if [ ${RC} -ne 0 ] ; then
	{
          echo "###     ERROR sudo rsync ${RSYNCOPTIONSMOUNTLIST} ${RSYNCEXCLUDEDIR} ${MAP}/ ${BACKUPMOUNTLISTDIR}${MAP}"
          echo "Er is wat fout gegaan bij sudo rsync ${RSYNCOPTIONSMOUNTLIST} ${RSYNCEXCLUDEDIR} ${MAP}/ ${BACKUPMOUNTLISTDIR}${MAP}"  >> ${ERRORLOG}
          GOTERROR=true
	}
        fi
    }
    fi
  done < "${MOUNTLIST}"
}
fi
echo " "

#
# De bestanden die meegenomen moeten worden
#
if [ -f "${FILELIST}" ] ; then
{
  echo "### Backup maken van file list in ${FILELIST}"
  while read BESTAND
  do
    echo "###   Bestand is ${BESTAND}"
    if [ ! -f "${BESTAND}" ] ; then
    {
      echo "  FOUT in ${FILELIST} want ${BESTAND} bestaat niet"
    }
    else
    {
	DNAME=`dirname "${BACKUPFILELISTDIR}""${BESTAND}"`
	sudo                 mkdir -p "${DNAME}"
	sudo                 cp ${BESTAND} "${BACKUPFILELISTDIR}""${BESTAND}"
	RC=$?
	if [ ${RC} -ne 0 ] ; then
	{
          echo "###     ERROR sudo cp ${BESTAND} ${BACKUPFILELISTDIR}${BESTAND}"
          echo "Er is wat fout gegaan bij sudo cp ${BESTAND} ${BACKUPFILELISTDIR}${BESTAND}"  >> ${ERRORLOG}
          GOTERROR=true
	}
        fi
    }
    fi
  done < "${FILELIST}"
}
fi
echo " "

#
# Backup alle MySQL databases
#
sudo systemctl status mqsql 1>/dev/null 2>/dev/null
RC=$?

if [ $RC -eq 0 ] ; then
{
  USERNAME=root
  PASSWORD=geheim
  DBHOST=localhost
  PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/mysql/bin 

  #
  # OPT string for use with mysqldump ( see man mysqldump )
  #
  #ATH got error "mysqldump: Got error: 1044: Access denied for user 'root'@'localhost' to database 'information_schema' when using LOCK TABLES "
  #ATH seems that option --single-transaction solves this problem
  OPT="--user=$USERNAME --password=$PASSWORD --host=$DBHOST --quote-names --opt --databases --single-transaction"  


  #
  # Find all databases and repalce a space in a the name of a db into %
  #
  which mysql 2>/dev/null 1>/dev/null
  RC=$?
  if [ $RC -eq 0 ] ; then
  {
    DBNAMES="`sudo mysql --user=$USERNAME --password=$PASSWORD --host=$DBHOST --batch --skip-column-names -e "show databases"| sed 's/ /%/g'`"
  }
  else
  {
    DBNAMES=""
  }
  fi
    
  echo "### Database Backup op ${THISPC}"
  for MDB in $DBNAMES
  do
    # Prepare $DB for using
    MDB="`echo $MDB | sed 's/%/ /g'`"
    RC=0
  
    # Real backup!!!
    case "${MDB}" in
    "information_schema" ) 
                            echo "###   Database ${MDB} wordt overgeslagen"
                            ;;
    "performance_schema" )
                            echo "###   Database ${MDB} wordt overgeslagen"
                            ;;
    * )
                            echo "###   Backup maken van ${MDB}"
                            sudo mysqldump ${OPT} ${MDB} > ${BACKUPMYSQLDIR}/${MDB}.sql
                            RC=$?
                            ;;
    esac
  
    if [ ${RC} -ne 0 ] ; then
    {
      echo "###     ERROR: database ${MDB}, mysqldump gaf terug ${RC}"
      echo ERROR: Er is wat fout gegaan bij de backup van database ${MDB}, mysqldump gaf terug ${RC}  >> ${ERRORLOG}
      GOTERROR=true
      STATUS=3
    }
    fi
  done
  echo " "
}
else
{
  echo "Mysql is not runing, nothing to do"
}
fi

#
# unmount alles wat we nodig hebben
#
if [ ${FSMOUNTCOUNT} -eq 0 ] ; then
{
	echo "### Er is niets te unmounten ....."
}
else
{
	echo "### Unmounten filesystemen ....."
}
fi
while read L
do
  MOUNTPOINT=`echo "${L}" | cut -f2 -d " "`
  if ${VERBOSE} ; then
	  echo -n "Unmounting ${MOUNTPOINT} ... "
  fi
  sudo umount ${MOUNTPOINT}
  RC=$?
  if [ ${RC} -ne 0 ] ; then
  {
    echo "Cannot unmount ${MOUNTPOINT}"
  }
  fi
done < ${MOUNTFILE}
echo " "

case ${DISKMOUNTPOINT} in
  *                          )
                                echo "### No specials to umount"
                                 ;;
esac
echo " "

#
# Gebruik ik de nieuwste versie?
#
version_check;


if ${GOTERROR} ; then
{
    echo -n 'Backup gemaakt op: ' >> ${DISKMOUNTPOINTLOGFILE}
    date >> ${DISKMOUNTPOINTLOGFILE}
    echo '########################################################################'
    echo '###### ERROR ###########################################################' >> ${DISKMOUNTPOINTLOGFILE}
    echo '###### ERROR ###########################################################' 
    echo '########################################################################'
    cat ${ERRORLOG} >> ${DISKMOUNTPOINTLOGFILE}
    cat ${ERRORLOG}
    echo '########################################################################' >> ${DISKMOUNTPOINTLOGFILE}

    echo -n "Ended: " >> ${RUNDATEFILE}
    date >> ${RUNDATEFILE}
    echo "Ended with Errors, see ${DISKMOUNTPOINTLOGFILE}" >> ${RUNDATEFILE}

    echo -n "Ended: " >> ${RUNDATEFILEDAY}
    date >> ${RUNDATEFILEDAY}
    echo "Ended with Errors, see ${DISKMOUNTPOINTLOGFILE}" >> ${RUNDATEFILEDAY}
}
else
{
    echo -n 'Backup gemaakt op: ' >> ${DISKMOUNTPOINTLOGFILE}
    date >> ${DISKMOUNTPOINTLOGFILE}

    echo -n "Ended: " >> ${RUNDATEFILE}
    date >> ${RUNDATEFILE}
    echo "Ended without Errors" >> ${RUNDATEFILE}

    echo -n "Ended: " >> ${RUNDATEFILEDAY}
    date >> ${RUNDATEFILEDAY}
    echo "Ended without Errors" >> ${RUNDATEFILEDAY}
}
fi

rm -f ${MOUNTFILE}

tail -100 ${DISKMOUNTPOINTLOGFILE} > ${STACKFILE}
rm -f ${DISKMOUNTPOINTLOGFILE}
mv ${STACKFILE} ${DISKMOUNTPOINTLOGFILE}

echo -n "Toets op Enter: "
read KEY

rm -f ${MOUNTFILE} ${ERRORLOG}

exit 0

