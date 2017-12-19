#!/usr/local/bin/bash

# - avoir la possibilite de remondre Y automatiquement
# - avoir ine liste zlist le moins restrictive possible

# script to list send check zfs to remote 
# from snapshot made with zfs-periodic

# Options paramétrables
local_zpool=zroot
remote_zfs=zroot/cahost
remote_host=fnas-vpn
zlist=$(zfs list -H -o name | grep -v poudr | grep -v ROOT | grep -v zroot/distfiles | grep -v zroot$ | grep -v zroot/fnas)
active_bootfs=$(zpool get bootfs zroot | awk 'END{print $3}')
zlist=$zlist' '$active_bootfs

# Autres variables à ne pas modifier
OPTIND=1         # Reset in case getopts has been used previously in the shell.
output_file=""
verbose=0
header=1
create_opt=0
back=5
remote_opt=0
local_opt=0
send_opt=0
next_opt=0
yes_opt=0
snaptype='monthly' # default time snap type check
ymsnap=''; f=''; g='';
tmp_file=/tmp/list-snap-pid.$$
tmp_remote_file=/tmp/list-remote-snap-pid.$$

function asksure {
    if [ $yes_opt -eq 0 ] 
    then
	echo -n "     Are you sure (Y/N)? "
	while read -r -n 1 -s answer; do
	    if [[ $answer = [YyNn] ]]; then
		[[ $answer = [Yy] ]] && retval=0
		[[ $answer = [Nn] ]] && retval=1
		break
	    fi
	done
	echo # just a final linefeed, optics...
    fi
    return $retval
}

# affiche le header de verbosite
function verbosity {
    if [[ ( "$remote_opt" -eq 0 ) && ( "$local_opt" -eq 0 ) ]]
    then echo '... Just the list of snap to check'
    else echo '... look for snap: '$ymsnap; fi
    if [ "$remote_opt" -eq 1 ]; then echo '... remotly'; fi
    if [ "$local_opt" -eq 1 ];  then echo '... localy' ; fi
}

# verifie que l'on ne check qu'un type de snapshot a la fois
function snaptypechck {
    next=0
    if [[ ( "$1" != 'hourly' ) && \
	( "$1" != 'daily' ) && \
	( "$1" != 'weekly' ) && \
	( "$1" != 'monthly' ) ]]
    then	 	
	echo 'type must be : [hourly, daily, weekly or monthly]'
	exit 1
    fi
    if [ "$1" == 'monthly' ] 
    then
	if [ "$2" == 'next' ]
	then 
	    tmpback=$(($back - 1))
	    ymsnap=$(date -v-"$tmpback"m "+"$snaptype"-%Y-%m")
	else
	    ymsnap=$(date -v-"$back"m "+"$snaptype"-%Y-%m")
	fi
    else
	echo 'monthly only support for the moment !'
	echo 'other type not suported yet !'
	exit 1
    fi    
}

function havelocalsnap {
    if [ "$local_opt" -eq 1 ]; then
	    if [ "$2" == 'next' ]; then
		snaptypechck 'monthly' 'next'
	    fi
	    local=$(grep $z@$ymsnap $tmp_file)
	    if [ ! -z $local ]; then 
		echo $local
	    fi
	fi
}

function haveremotesnap {        
    if [ "$remote_opt" -eq 1 ]; then	    
	tmp_z=$(echo $z | cut -d'/' -f2-)
	tmp_z='/'$tmp_z
	if [ "$tmp_z" = '/'$local_zpool ]; then 
	    tmp_z=''; 
	fi
	if [ "$2" == 'next' ]; then
	    snaptypechck 'monthly' 'next'
	fi
	remote=$(grep $remote_zfs$tmp_z@$ymsnap $tmp_remote_file)
	if [ ! -z $remote ]; then
	    echo ' remote snapshot: '$remote
	fi
    fi
}

function nextsnap {
    if [ "$local_opt" -eq 1 ]; then
	l=$(havelocalsnap 'monthly' 'next') 
	if [ -n "$l" ]; then echo -n 'x'; else  echo -n '.'; fi		
	if [ "$header" -eq 1 ]; then echo -n '          '; fi
	echo -n ' '
    fi
    r=''
    if [ "$remote_opt" -eq 1 ]; then
	r=$(haveremotesnap 'monthly' 'next')
	if [[ ( -z "$r" ) && ( "$remote_opt" -eq 1 ) ]]
	then
	    echo -n '.'
	    if [ "$header" -eq 1 ]; then echo -n '           '; fi
	    if [ "$send_opt" -eq 1 ] 
	    then
		sendsnap $r $l
	    fi
	else
	    echo -n 'x'
	    if [ "$header" -eq 1 ]; then echo -n '           '; fi
	    if [ "$send_opt" -eq 1 ] ; then echo ' '$z; fi	    
	fi
	echo -n ' '
    fi
}

function sendsnap {
    one=$(havelocalsnap)
    if [ "$create_opt" -eq 1 ] 
    then
	echo '     /!\ send recurse remote zfs : '$z
	cmd='zfs send -i '$one' | ssh root@fnas zfs receive -dvu '$remote_zfs
	echo '     '$cmd
	if asksure; then
	    echo "     Okay, performing transfert ...."
	    zfs send $one | ssh root@fnas zfs receive -dvu $remote_zfs
	else
	    echo "     No transfert for the moment..."
	fi 
    else
	two=$(havelocalsnap 'monthly' 'next')
	echo '     /!\ send recurse remote zfs : '$z
	cmd='zfs send -i '$one' '$two' | ssh root@fnas zfs receive -dvu '$remote_zfs
	echo '     '$cmd	
	if asksure; then
	    echo "     Okay, performing transfert ...."
	    zfs send -i $one $two | ssh root@fnas zfs receive -dvu $remote_zfs
	else
	    echo "     No transfert for the moment..."
	fi 
    fi
}

function showheader {
    if [ "$local_opt" -eq 1 ]; then echo -n ' Local '; fi
    if [ "$remote_opt" -eq 1 ]; then echo -n ' Remote '; fi
    if [[ ( "$next_opt" -eq 1 ) && ( "$local_opt" -eq 1 ) ]]; then 
	echo -n ' Next Local '; fi
    if [[ ( "$next_opt" -eq 1 ) && ( "$remote_opt" -eq 1 ) ]]; then 
	echo -n ' Next Remote '; fi
    echo -n ' ZFS ';echo -n '. check '$ymsnap
    echo
}

# verification de la presence des option -rl pour utilisation de -s
function optchk {
    if [[ ( ( "$remote_opt" -eq 0 ) || \
	( "$local_opt" -eq 0 ) ) && \
	( "$send_opt" -eq 1 ) ]] 
    then
	echo 'to send snap you must use remote and local option : -rl'
	exit 1
    fi
    if [[ ( "$create_opt" -eq 1 ) && ( "$next_opt" -eq 1 ) ]]; then
	echo "can't use create and next option at the same time"
	exit 1
    fi
    if [ "$back" -lt 0 ]; then echo 'back must be >=0 '; exit 1; fi
    if [[ ( "$back" -eq 0 ) && ( "$next_opt" -eq 1 ) ]]; then 
	echo "can't check next mount from current mount -b 0."; exit 1; fi
}

function help {
    echo 'Usage : '$0' [OPTION...]'
    echo '
    -v verbose
    -h header
    -r remote
    -l local
    -b back
    -s send
    -n next
    -H header
    -c create
    -y yes'
    exit 0
}

while getopts "Hh?vb:lrsncy" opt; do
    case "$opt" in
    h|\?)
        help
        ;;
    v)  verbose=1
        ;;
    r)  remote_opt=1
        ;;
    l)  local_opt=1
        ;;
    b)  back=$OPTARG
        ;;
    s)  send_opt=1
        ;;
    n)  next_opt=1
        ;;
    H)  header=0
        ;;
    c)  create_opt=1
	;;
    y)  yes_opt=1
        ;;
    esac
done

optchk
if [ "$verbose" -eq 1 ]; then verbosity; fi

# list les snapshots locaux
if [ "$local_opt" -eq 1 ]; then
    zfs list -o name -t snapshot > $tmp_file
fi

# list les snapshots distants
if [ "$remote_opt" -eq 1 ]; then
    ssh root@$remote_host zfs list -o name -t snapshot | grep $remote_zfs > $tmp_remote_file
fi

snaptypechck "$snaptype"
if [[ ( "$header" -eq 1 ) && ( "$send_opt" -eq 0 ) ]]; then showheader; fi

# pour tout ce que l'on veut vérifier
for z in $zlist
do 
    if [[ ( "$header" -eq 1 ) && ( "$send_opt" -eq 1 ) ]]; then showheader; fi
    f=''; g='';
    echo -n ' ' # premier espace d'affichage
    f=$(havelocalsnap)
    if [[ ( -z "$f" ) && ( "$local_opt" -eq 1 ) ]]
    then echo -n '.'
    if [ "$header" -eq 1 ]; then echo -n '     '; fi
    echo -n ' '
    elif [ "$local_opt" -eq 1 ] 
    then echo -n 'x'
    if [ "$header" -eq 1 ]; then echo -n '     '; fi
    echo -n ' '; fi	
    g=$(haveremotesnap 'monthly' 'current')
    if [[ ( -z "$g" ) && ( "$remote_opt" -eq 1 ) ]]
    then echo -n '.'
	if [ "$header" -eq 1 ]; then echo -n '      '; fi
	echo -n ' '
	# si l'option est la creons les nouveaux snap distants
	if [[ ( "$create_opt" -eq 1 ) ]]; then sendsnap; fi
    elif [ "$remote_opt" -eq 1 ]
    then echo -n 'x'
	if [ "$header" -eq 1 ]; then echo -n '      '; fi
	echo -n ' '; 
    fi
    # si l'option est la nous recherchons le snap suivant
    if [[ ( "$next_opt" -eq 1 ) ]]; then nextsnap; fi
    # affichage du volume zfs courant
    if [[ ( "$send_opt" -eq 0 ) ]]; then
    	echo -n $z' ' 
    fi
    # juste une ligne pour aider a la lecture de la sortie
    echo
done

# netoyage des fichier temporaire de list de snapshots
if [ "$local_opt" -eq 1 ]; then rm $tmp_file; fi
if [ "$remote_opt" -eq 1 ]; then rm $tmp_remote_file; fi
