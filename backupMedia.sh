#!/bin/sh
MY_NAME=$(basename $0)
PROGRAMSRCFILE=/tenhoopen/src/backup/${MY_NAME}.sh
MYVERSION=9

ARJANPC=arjanpc.thuis.net
THIS_HOST=$(hostname)

PIC360=360  
BIEB=bibliotheek  
CALIBRE=Calibre  
FOTO=foto  
VIDEO=video
AUDIO=audio
SLASH=/
SRC=/Media
SRC2=/Media2
#DEST=/MediaBackup
#DEST2=/MediaBackup2
DEST=/MediaNAS
DEST2=/MediaNAS
EXTFS=volumio:/Media
EXTFS2=volumio:/Media2
EXTFSTYPE=nfs
MOUNTEXTFS=/MediaNAS
MOUNTEXTFS2=/MediaNAS
TARGET=""

SHOWPROGRESS=false
DRYRUN="-n"
RSYNCEXCLUDE=" --exclude .Trash\* "
RSYNCOPTIONS=""
RSYNCPROGRESSOPTIONS="--stats --human-readable "
SYSLOG="logger -t $MY_NAME --"		# log to /var/log/messages
 
#
# Help informatie
#
show_help ()
{
   echo "Dit tool zorgt ervoor dat de slave ${DEST} gelijk wordt aan de master ${SRC}"
   echo "Bij een verschil wordt ${DEST} aangepast"
   echo "Dit script kan alleen vanaf ${ARJANPC} uitgevoerd worden!!!"
   echo "-------------------------------------------------------------"
   echo "	-x --execute      Uitvoeren ipv dry-run"
   echo "	-D --DELETE       Delete op target ${DEST}"
   echo "	-p --progress     Show progress indicatori maar is alleen echt zinnig bij grote bestanden"
   echo "	-h --help -?      Dit bericht "
   echo "	-v --version      Versie nummber "
   echo "	-r --reverse      Reverse; from backup to my Disk"
   echo "	--360             Backup ${PIC360} "
   echo "	--bibliotheek     Backup ${BIEB} "
   echo "	--calibre         Backup ${CALIBRE} "
   echo "	--foto            Backup ${FOTO} "
   echo "	--audio           Backup ${AUDIO} "
   echo "	--video           Backup ${VIDEO} "
   echo "	--alles           Backup all media ${PIC360} ${BIEB} ${CALIBRE} ${FOTO} ${AUDIO} ${VIDEO}"
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
    LATESTVERSION=$(grep ^MYVERSION= ${PROGRAMSRCFILE}|cut -f2 -d =)
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
# Dit script is er om Media veilig te stellen vanaf de PC van arjan, controleer hier op
#
if [ "${THIS_HOST}" = "${ARJANPC}" ] ; then
{
	echo "We zitten op ${ARJANPC} .. aan de slag..." 
}
else
{
	echo "We zitten NIET op ${ARJANPC} ..... sorry .... doej" 
	exit 3
}
fi

#
# Het afhandelen van alle opties op de commando regel
#
# opties met argument is bv a: ipv a en heeft shift 2 ipv shift
#
PARSED_ARGUMENTS=$(getopt -n backupMedia -o vhDxpr --longoptions DELETE,progress,execute,reverse,help,version,360,bibliotheek,calibre,foto,lp,audio,video,alles -- "$@")
VALID_ARGUMENTS=$?
if [ "$VALID_ARGUMENTS" != "0" ]; then
  show_error
fi
#echo "PARSED_ARGUMENTS is $PARSED_ARGUMENTS"
eval set -- "$PARSED_ARGUMENTS"
while :
do
    case "$1" in
    -r | --reverse)    SRC=/MediaBackup;
                       DEST=/Media;
                       shift;
                       ;;
    -p | --progress)   SHOWPROGRESS=true;
                       shift;
                       ;;
    -v | --version)    version_check;
                       exit 0
                       ;;
    -h | -\? | --help) show_help;
                       exit 0
                       ;;
    -D | --DELETE)     RSYNCOPTIONS="--delete "
                       shift;
                       ;;
    -x | --execute)    DRYRUN=""
                       shift;
                       ;;
    --360)             TARGET="${TARGET} ${PIC360}"
                       shift;
                       ;;
    --bibliotheek)     TARGET="${TARGET} ${BIEB}"
                       shift;
                       ;;
    --calibre)         TARGET="${TARGET} ${CALIBRE}"
                       shift;
                       ;;
    --foto)            TARGET="${TARGET} ${FOTO}"
                       shift;
                       ;;
    --audio)           TARGET="${TARGET} ${AUDIO}" 
                       shift;
                       ;;
    --video)           TARGET="${TARGET} ${VIDEO}" 
                       shift;
                       ;;
    --alles)           TARGET="${PIC360} ${BIEB} ${CALIBRE} ${FOTO} ${AUDIO} ${VIDEO}" 
                       shift;
                       ;;
    --)                shift;
                       break ;;
    *)                 echo "Vreemde optie: $1 geen idee wat ik er mee aan moet."
                       show_error;
                       exit 3
                       ;;
    esac
done

#
# is er wat te doen
#
if [ "${TARGET}" = "" ] ;  then
{
	echo Foutje! Geen doel opgegeven, wat wil je backupen..... moet je wel zeggen
	show_help
	exit 2
}
fi

#
# Voeg standaarde rsync opties toe
# 
RSYNCOPTIONS="${DRYRUN} ${RSYNCOPTIONS}  -v -a -E -A -U"

#
# Laatste meldingen
#
if [ "${DRYRUN}" = "" ] ; then
{
  echo "Geen DRY-RUN ${DEST} wordt bijgewerkt"
}
else
{
  echo "DRY-RUN, er worden geen aanpassingen gemaakt"
}
fi

#
# Bestaan de slave en de master
#
for D in "${SRC}" "${DEST}"
do
  if [ ! -d "${D}" ] ;  then
  {
	echo Foutje! ${D} bestaat niet
	exit 3
  }
  fi
done

#
# Aan de slag alles moet naar /MediaBackup
# Uitzondering: video
#
for CURRENTTARGET in ${TARGET}
do
  case ${CURRENTTARGET} in
    "video" ) echo Naar /MediaBackup2 ;
              TSRC=${SRC2}/${CURRENTTARGET}${SLASH};
              TDEST=${DEST2}/${CURRENTTARGET};
	      ;;
    *       ) echo Naar /MediaBackup;
              TSRC=${SRC}/${CURRENTTARGET}${SLASH};
              TDEST=${DEST}/${CURRENTTARGET};
	      ;;
  esac

  echo "Backup van ${TSRC}"
  echo "Naar       ${TDEST}"
  echo


  #
  # Bij de progress indicator moeten we eerst weten hoeveel er overgebracht moet worden
  #
  if  ${SHOWPROGRESS}  ; then
  {
	  # alleen de bestanden
	  #TCOUNT=$(rsync -n ${RSYNCPROGRESSOPTIONS} ${RSYNCOPTIONS} ${RSYNCEXCLUDE} "${TSRC}" "${TDEST}" | grep -v "/$" | wc -l)
	  # bestanden en mappen
	  TCOUNT=$(rsync -n ${RSYNCPROGRESSOPTIONS} ${RSYNCOPTIONS} ${RSYNCEXCLUDE} "${TSRC}" "${TDEST}" | wc -l)
	  TOTALCOUNT=$((TCOUNT-18 ))
	  echo Files to transfer is ${TOTALCOUNT}
	  if [ ${TOTALCOUNT} -ne 0 ] ; then
	  {
	    if [ "${DRYRUN}" = "" ] ; then
	    {
              echo Uitvoeren van: rsync ${RSYNCPROGRESSOPTIONS} ${RSYNCOPTIONS} ${RSYNCEXCLUDE} "${TSRC}" "${TDEST}" \| pv -lep -s ${TOTALCOUNT}
              rsync                     ${RSYNCPROGRESSOPTIONS} ${RSYNCOPTIONS} ${RSYNCEXCLUDE} "${TSRC}" "${TDEST}" | pv -lep -s ${TOTALCOUNT}
              #echo Uitvoeren van: rsync ${RSYNCPROGRESSOPTIONS} ${RSYNCOPTIONS} ${RSYNCEXCLUDE} "${TSRC}" "${TDEST}" \| pv -lep -s ${TOTALCOUNT} gereed
	    }
            else
	    {
              echo Uitvoeren van: rsync ${RSYNCPROGRESSOPTIONS} ${RSYNCOPTIONS} ${RSYNCEXCLUDE} "${TSRC}" "${TDEST}"
              rsync                     ${RSYNCPROGRESSOPTIONS} ${RSYNCOPTIONS} ${RSYNCEXCLUDE} "${TSRC}" "${TDEST}"
              #echo Uitvoeren van: rsync ${RSYNCPROGRESSOPTIONS} ${RSYNCOPTIONS} ${RSYNCEXCLUDE} "${TSRC}" "${TDEST}" gereed
	    }
	    fi
          }
          else
	  {
	    echo Er is niets te doen
	  }
	  fi
  }
  else
  {
    echo Uitvoeren van: rsync ${RSYNCOPTIONS} ${RSYNCEXCLUDE} "${TSRC}" "${TDEST}"
    rsync                     ${RSYNCOPTIONS} ${RSYNCEXCLUDE} "${TSRC}" "${TDEST}"
    #echo Uitvoeren van: rsync ${RSYNCOPTIONS} ${RSYNCEXCLUDE} "${TSRC}" "${TDEST}" gereed
    echo
  }
  fi
done

#
# Was de nieuwste versie in gebruik?
#
version_check

#
# Laatste melding voordat we bey bey zeggen ...
#
echo
if [ "${DRYRUN}" = "" ] ; then
{
  echo "Geen DRY-RUN ${DEST} is bijgewerkt"
}
else
{
  echo "DRY-RUN, er zijn geen aanpassingen gemaakt"
}
fi

exit $?
