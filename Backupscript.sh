#!/bin/bash

{ # Loads entire script into memory before execution
#source Utilites.sh


#	set -xv # debugging -xv

#CloneDisk='SanDisk_Extreme_Pro_12345778CDCB-0:0' # serial number of disk to clone to.
#Source=sda
#Target=sdb
execname=${0##*/}
LogPath="/var/log/${execname%%.*}"
s_time=$(date '+%Y-%m-%dT%H:%M:%S') # 2004-06-14T23:34:30

if ! [ $(id -u) = 0 ]; then #every shell
   echo "Program needs to be run as root!"
   exit 1
fi

#Exclude=( sda6 sda7 sda8 )

# awk '{$1=$2=$3=$4=$5=$6=""; print $0}'
# line 283 filter awk for flags only in
# 1      20,5kB  210MB   210MB   fat32        EFI System Partition          boot, esp
# 2      211MB   68,9GB  68,7GB  ext4         UbuntuDisk                    hidden, legacy_boot
# 3      68,9GB  68,9GB  16,8MB               Microsoft reserved partition  msftres
# 4      68,9GB  122GB   52,7GB  ntfs         Basic data partition          msftdata
# 5      122GB   128GB   6441MB  udf          ESD-USB                       hidden, legacy_boot, msftdata
# 6      128GB   130GB   2147MB  ext4         Persistant
# 7      130GB   250GB   120GB   ntfs                                       msftdata
# 8      250GB   500GB   250GB                Mac OS X

#typeset -a -r Exclude

if [[ "pgrep -x ${0#*\/:1:14} &> /dev/null" == 0 ]]; then
	( log "Another instance is already running." ) | tee -a "${LogPath}/BackupStatus"
	exit=1; exitroutine
fi
mkdir -p ${LogPath}
rm ${LogPath}/BackupStatus &> /dev/null
touch ${LogPath}/BackupStatus
chmod -R --preserve-root 4666 "${LogPath}" #-c

function trapper () {
	#resets the trapper to default
	trap ${1:-'exit=1; exitroutine; exit 1'} ${2:-SIGINT}
}


function pause () {
	#waits for user input with optional delay
	if [[ "$2" != '' ]]; then
		read -r -s -n 1 -p ${1:-[Press any key to continue]} -t $2
	else
		read -r -s -n 1 -p ${1:-[Press any key to continue]}
	fi
}


function exitroutine () {
	touch ${LogPath}/Backup_${s_time}.log
	cat ${LogPath}/BackupStatus | tee -a "${LogPath}/Backup_${s_time}.log" 1> /dev/null

	if [[ "$write" != true ]]; then
		exit=1
	fi
	if [[ "$exit" == "0" ]]; then
		touch ${LogPath}/BackupDone
	fi
	e_time=$(date '+%Y-%m-%dT%H:%M:%S')
	echo "$execname finished with exit code $exit at $e_time" | tee -a "${LogPath}/Backup_${s_time}.log"
	exit $exit #returns error/sucess code
}

function log () { 
	echo "[$(date '+%Y/%m/%d %H:%M:%S')]" "$*";
}

function move_up () {
	#moves cursor up n lines
	for (( i = 0; i < ${1:-1}; i++ )); do
		tput cuu1
	done
}

function move_down () {
	#moves curser down n lines
	for (( i = 0; i < ${1:-1}; i++ )); do
		tput cud1
	done
}

function clear_up () {
	#moves cursor up n lines in terminal and clears all lines traversed
	tput el
	for (( i = 0; i < ${1:-1}; i++ )); do
		tput cuu1
		tput el
	done
}

function menu () {
	#adaptive menu provider
	#set -xv
	REPLY=''
	while [[ "$REPLY" == '' ]]; do
		#for (( i = 1; i < $LINES - ${#@}; i++ )); do
		#	echo ''
		#done
		PS3="$2"
		echo "$(printf %"$(expr $(expr $COLUMNS - ${#1}) / 2)"s | tr " " "=")${1}$(printf %"$(expr $(expr $COLUMNS - ${#1}) / 2)"s | tr " " "=")"
		select opt in "${@:3}"; do
			break
		done
		#printf %"$COLUMNS"s | tr " " "="
		clear_up $(expr ${#@} - 1 )
		#echo -e "\e[$(expr ${#@} + 4 )A\e[K"
	done
}

function arrowkey_menu () {
	#adaptive menu provider with arrow key support
	
	echo "$(printf %"$(expr $(expr $COLUMNS - ${#1}) / 2)"s | tr " " "=")${1}$(printf %"$(expr $(expr $COLUMNS - ${#1}) / 2)"s | tr " " "=")"
	for (( i = 1; i < "$(expr ${#@})"; i++ )); do #build options string
		string="${@:$(expr $i + 1):1}"
		options+="
#   $i) ${string}$(printf %"$(expr $(expr $COLUMNS - ${#string}) - 8)"s)#"
	string=''
	done
	echo -ne "$options"
	read -s -n1 c
	case "$c" in
		?)
			opt=${@:$(expr $i + 1):1}
			REPLY=$c
			;;
		$'\033') 
			read -t.001 -n2 r
			pause
			case "$r" in
				'[A') tput cuu1 ;;	# select item above
				'[B') tput cud1 ;;	# select item below
				'[D') echo '';;		# go into submenu
				'[C') echo '';;		# go out of submenu
			esac
			pause
	esac
	clear_up $(expr ${#@} - 1 )
}

function confirm () {
	# call with a prompt string or use a default
	response=''
	while [[ $response != @(true|false) ]]; do
		read -r -p "${1:-Are you sure? [y/N]}: " response
		case ${response,,} in
			yes|y) 
				response=true
				;;
			no|n)
				response=false
				;;
			\ ) # Default??
				response=false
				;;
			*)
				echo "try again"
				;;
		esac
		clear_up 2
	done
}

function HELP () {
#prints help
echo -ne "Usage: ${execname} [OPTION]...
Clone entire disks reliably, with a test mode
	a, --adjust	adjust partition sizes without prompt (includes -c)
	c, --create	create partitions without prompt
	e, --exclude=	exclude partitions from clone delimited by ','
	f, --force	clone even if disconnected from main power or 
			  the specified disk identifier is not found
	h, --help	prints this help
	i, --install	opens dialog to install ${execname} to bin or 
			  privatebin optionally
			  and or schedules to run during Read only phase of boot
			  with anacron
	r, --resolve	resolves faulty gpt without prompt
	s, --source=	specifies source like 'sda'
	t, --target=	specifies target like 'nvme0'
	   --serial=	specifies a serial number to check if [TARGET]
				  is really the disk meant.
				  Serial number can be optained through:
	   --getSerial=[TARGET]
				  or
				  'udevadm info --query=all --name=/dev/[TARGET] -x | grep ID_SERIAL='
	w, --write	stop simulating the actions 
Exit status:
 0  if OK,
 1  if supressed by Hardware state (POWER,DISK)
 2  if major problem (e.g., cannot proccess flag; clone failed; etc)
(A Log should have been written to ${LogPath})
"
}

BOOTSCRIPT="#!/bin/bash

if ! [ \$(id -u) = 0 ]; then #every shell
   echo \"Bootscript needs to be run as root\!\"
   exit 1
fi

case \$1 in
	start)
		if [[ -f /etc/${execname}.pending ]]; then
			\$command=( \"\$(cat /etc/${execname}.arguments)\" )
			local i
			i=0
			while [[ command[i] != -t|--target=* ]]; do #loop through arguments
				i=\$(expr \$i + 1)
			done
			if [[ \${arg:0:2} == '--' ]]; then
				arg=\${arg#*=}
			else
				i=\$(expr \$i + 1)
				arg=\${command:\$i:1}
			fi
			Target=\$arg
			if [[ \"\$(ls /dev/\${Target} &> /dev/null)\" != \"\$Target\" ]]; then
				echo 'notify-send -u normal -t 170000 -i backups-app -c transfer.error --hint=int:x:20 --hint=int:y:20 'System Backup FAILED' 'plug in disk'' | at now + 10 minutes
			else
			\${command*}
			rm /etc/${execname}.pending
			fi
		fi
		;;
	stop)
		echo \"This is a bootscript. What are you doing??\"
		;;
	*)
		echo \"usage: start|stop
Runs the backupscript if scheduled\"
		;;
esac
"


#	set -xv

if [[ "$*" == '' ]]; then
	HELP
	exit=2
	exitroutine
fi

function ReadArgs () {
	local -i i
	local -i j
	local arg
	i=1
	while [ $i -le ${#@} ]; do
		arg="${@:$i:1}"
		case ${arg,,} in #only lowercase
		--debug)
			set -xv
			;;
		-h|--help)
			HELP
			exit 0
			;;
		-i|--install)
			#installdialog $@
			#	set -xv
			trap 'tput rmcup; exit 1' SIGINT
			tput smcup
			tput clear
			while [ true ]; do
				#menu "Install Menu" "Choose install type: " "Create Bootscript in transition from RAMDISK to RW-mode" "Install to bin" "Install to private bin" "Print current configuration" "Uninstall $execname" "exit"
				arrowkey_menu "Install Menu" "Create Bootscript in transition from RAMDISK to RW-mode" "Install to bin" "Install to private bin" "Print current configuration" "Uninstall $execname" "exit"
				pause
				#echo $opt
				if [[ "$opt" != 'exit' ]]; then
					echo "$(printf %"$(expr 1 )"s | tr " " "-")${opt}$(printf %"$(expr $(expr $COLUMNS - ${#opt}) - 1 )"s | tr " " "-")"
				fi
				case '0' in
					$([[ "$installpath" != '' ]]))
						( log Previously installed script used. ) |tee -a "${LogPath}/BackupStatus"
						;;
					$([[ -f /bin/$execname ]]))
						installpath="/bin/$execname"
						( log /bin install used. ) |tee -a "${LogPath}/BackupStatus"
						;;
					$([[ -f ~/.local/bin/$execname ]]))
						installpath="$(echo ~/.local/bin/$execname)"
						( log privatebin install used. ) |tee -a "${LogPath}/BackupStatus"
						;;
					*)
						installpath=$0
						;;
				esac
				#echo "$(printf %"$COLUMNS"s | tr " " "=")"
				case $REPLY in
					1)
						read -r -p "Interval in days to execute the script: " period
						clear_up 2
						while
							echo "Current config is: $(cat "/etc/${execname}.arguments")"
							read -r -p "Arguments: " arguments
							clear_up 3
							ReadArgs $arguments
							[[ $? != 0 ]] # runs only after first execution
								sleep 2
								clear_up 1
						do true; done
						clear_up 3

						touch /var/log/${execname}.arguments
						sed -i[.backup] "/# ${execname}/,+1 d" '/etc/anacrontab'
						echo -e "${installpath} $arguments" | tee "/etc/${execname}.arguments"
						ANACRONENTRY="
# ${installpath}
$period	0	${execname}	\"touch /etc/${execname}.pending\"
"
						echo -e "$ANACRONENTRY" | tee -a /etc/anacrontab > /dev/null
						( log "Creating bootscript in /etc/init.d/${execname}" ) | tee -a "${LogPath}/BackupStatus"
						echo -e "$BOOTSCRIPT" | tee -p "/etc/init.d/${execname}.bootscript" > /dev/null
						( log "Registering bootscript in runlevel 1 (rescue/ro) as S01${execname}" ) | tee -a "${LogPath}/BackupStatus"
						ln -s "/etc/init.d/${execname}" "/etc/rc1.d/S01${execname}" 2> /dev/null
						pause
						;;
					2)
						( log installing to bin! ) | tee -a "${LogPath}/BackupStatus"
						cp -uH $0 "/bin"
						if [[ -f ~/.local/bin/$execname ]]; then
							rm "~/.local/bin/$execname"
							( log Moved install from privatebin to /bin. ) | tee -a "${LogPath}/BackupStatus"
							sleep 2
							clear_up 1
						fi
						sleep 1
						clear_up 4
						installpath="/bin/$execname"
						;;
					3)
						( log installing to private bin! ) | tee -a "${LogPath}/BackupStatus"
						cp -uH $0 "$(echo ~/.local/bin/)"
						sleep 2
						clear_up 5
						installpath="~/.local/bin/$execname"
						;;
					4)
						cat "/etc/${execname}.arguments"
						pause
						clear_up 4
						;;
					5)
						( log "Removing $execname install!" ) | tee -a "${LogPath}/BackupStatus"
						confirm
						if [[ $response ]]; then
							( log "Clearing Bootscript" ) | tee -a "${LogPath}/BackupStatus"
							rm "/etc/init.d/$execname.bootscript"
							unlink "/etc/rc1.d/S01$execname"
							( log "Clearing bins" ) | tee -a "${LogPath}/BackupStatus"
							rm "/bin/$execname"
							rm "$(echo "~/.local/bin/$execname")"
						else
							( log "Uninstall aborted!" ) | tee -a "${LogPath}/BackupStatus"
						fi
						pause '[Press any key to exit]' # -t 10
						exit=0
						tput rmcup
						exitroutine
						;;
					6)
						exit=0
						echo "Stopping installer"
						sleep 1
						tput rmcup
						exitroutine
						;;
					*)
						echo "invalid option"
						sleep
						clear_up 1
				esac
				tput clear
			done
			trapper
			tput rmcup
			exit=0 #status of script
			exitroutine
			;;
		-s|--source=*)
			if [[ ${arg:0:2} == '--' ]]; then
				arg=${arg#*=}
			else
				i=$(expr $i + 1)
				arg=${@:$i:1}
			fi
			Source=$arg
			;;
		-t|--target=*)
			if [[ ${arg:0:2} == '--' ]]; then
				arg=${arg#*=}
			else
				i=$(expr $i + 1)
				arg=${@:$i:1}
			fi
			Target=$arg
			;;
		--getserial=*)
			( log "Getting serial number for /dev/${arg#*=}: " ) | tee -a "${LogPath}/BackupStatus"
			Serial=$(udevadm info --query=all --name=/dev/${arg#*=} -x | grep ID_SERIAL=)
			echo "			${Serial#*=}" | tee -a "${LogPath}/BackupStatus"
			exit=0
			exitroutine
			;;
		-s|--serial=*)
			if [[ ${arg:0:2} == '--' ]]; then
				arg=${arg#*=}
			else
				i=$(expr $i + 1)
				arg=${@:$i:1}
			fi
			CloneDisk=$arg
			;;
		-f|--force)
			force=true
			;;
		-c|--create)
			create=true
			;;
		-a|--adjust)
			adjust=true
			;;
		-r|--resolve)
			resolve=true
			;;
		-e|--exclude=*)
			if [[ ${arg:0:2} == '--' ]]; then
				arg=${arg#*=}
			else
				i=$(expr $i + 1)
				arg=${@:$i:1}
			fi
			Exclude=( ${arg//,/ } ) # converts ',' delims to spaces
			;;
		-w|--write)
			write=true
			;;
		-??*)
			for (( j = 1; j < ${#arg}; j++ )); do
				ReadArgs -${arg:j:1}
			done
			;;
		*)
			echo "Unregognized argument: ${arg}" |tee -a "${LogPath}/BackupStatus"
			return 1
			HELP
			exit 2
			;;
		esac		
		i=$(expr $i + 1)
	done
	return 0
}

ReadArgs $@

if [[ $Source == '' ]]; then
	( log No Source Specified! ) | tee -a "${LogPath}/BackupStatus"
	HELP
	exit=2
	exitroutine
fi
if [[ $Target == '' ]]; then
	( log No Target Specified! ) | tee -a "${LogPath}/BackupStatus"
	HELP
	exit=2
	exitroutine
fi

function clonefunc () {
		( log Cloning $part to $Target ) | tee -a "${LogPath}/BackupStatus"
		SourceSizePretty=$( echo "scale=2;$SourceSize/2097152" | bc | sed 's/^\./0./' )
		( log ${SourceSizePretty}GiB to go. ) | tee -a "${LogPath}/BackupStatus"
		#the actual cloning part of the program
		cloning="dd if=/dev/$part of=/dev/$targetpart bs=$(cat /sys/block/$Source/queue/physical_block_size 2> /dev/null)K conv=noerror,sync,sparse status=progress"
		if [[ $write == true ]]; then
			echo $cloning
			echo "$(expr $(cat /sys/block/$Source/$part/size 2> /dev/null) \* 512) bytes" # for some reason 511.46875?
			$cloning
		else
			echo "$(expr $(cat /sys/block/$Source/$part/size 2> /dev/null) \* 512) bytes"
			echo "[TEST] $cloning"
		fi
}

if [[ $write == true ]]; then
# DO NOT QUOTE THE ARGUMENTS!
	function sgdiskF () {
		sgdisk ${@}
	}
else
	function sgdiskF () {
		#sgdisk with -Pretend parameter
		sgdisk -P ${@}
	}
fi


trapper

echo "[======Backup script by Chaos_02======]"
if [[ -t 0 ]]; then
	if [[ $write == true ]]; then
		echo "[#######Write Mode activated!#########]"
	else
		echo "[Test Mode.]"
	fi
fi
#if [[ -a /dev/$Source ]] || [[ -a /dev/$Target ]]; then
#	( log $Source or $Target Missing. )
#	echo Source*
#	ls /dev/${Source:0:2}*
#	echo Target*
#	ls /dev/${Target:0:2}*
#	exit 2
#fi
if [[ ${Exclude[*]} != '' ]]; then
	( log Excluding ${Exclude[@]}. ) | tee -a "${LogPath}/BackupStatus"
	sleep 1
fi
# This script is meant to be run by anacron.
# Will Schedule to run another time when it fails in the background if "at" is installed

on_ac_power
if [[ $? == 0 ]] || [[ $? == 255 ]] || [[ $force == true ]]; then #main power or unknown

	if [[ "$(ls /dev/${Source})" != /dev/${Source} ]]; then
		( log Specified Source not found "($Source)" ) | tee -a "${LogPath}/BackupStatus"
		exit=1
		exitroutine
		exit
	fi
	
	if [[ "$(ls /dev/${Target})" != /dev/${Target} ]]; then
		( log Specified target not found "($Target)" ) | tee -a "${LogPath}/BackupStatus"
		exit=1
		exitroutine
		exit
	fi
	connectedDisk=$(udevadm info --query=all --name=/dev/$Target -x | grep --color=never ID_SERIAL=)
	if [[ $CloneDisk == "" || "${connectedDisk##*=}" == "${CloneDisk}" || $force == true ]]; then
		diskfound=true
	else
		( log Disk not found. ) |tee -a "${LogPath}/BackupStatus"
		( log diff: $(diff <(echo "${connectedDisk##*=}" ) <(echo ${CloneDisk})) ) |tee -a "${LogPath}/BackupStatus"
		if [[ ! -t 0 ]]; then
			notify-send -u normal -t 170000 -i backups-app -c transfer.error --hint=int:x:20 --hint=int:y:20 "System Backup FAILED" "plug in disk $CloneDisk"
			( log Restarting script in 60. ) |tee -a "${LogPath}/BackupStatus"
			at now + 1 hour -f "/Backupscript.sh"
		fi
		exit=1
		exitroutine
	fi
	
	if [[ "$diskfound" == true ]]; then
		if [ -a ${LogPath}/BackupDone ]; then #file exists
			( log Last backup finished successfully. ) | tee -a "${LogPath}/BackupStatus"
		else
			LastError=$( grep -P '(?<=\[[0-9]{4}\/[0-9]{2}\/[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\] ERROR )[0-9]{1,3}x[0-9]{1,3}(?!\n*.*ERROR)' ${LogPath}/Backup.log 2> /dev/null )
			( log Last backup FAILED. Last CODE: "'"$LastError"'" ) | tee -a "${LogPath}/BackupStatus"
			echo See ${LogPath}/Backup.log
		fi
		rm ${LogPath}/BackupDone 2> /dev/null
		( log Checking partitions. ) | tee -a "${LogPath}/BackupStatus"
		
		
		#(?<=\/dev\/)(((nvme|mmcblk)[0-9]+p[0-9]+)|((sd|x?vd)[A-Za-z]+[0-9]+))
		
#=====Check if all parts existing, creating missing=====#

		if [[ $(ls /dev/${Target}) ]]; then
			for part in $( ls --color=never /dev/${Source}? | grep -oE '(((nvme|mmcblk)[0-9]+p[0-9]+)|((sd|x?vd)[A-Za-z]+[0-9]+))' ); do
				targetpart=${Target}$( echo $part | grep -oE '((p[0-9]+)|([0-9]+))' )
				if ! printf '%s\n' "${Exclude[@]}" | grep -q -P "^${part}$"; then	#checks if nothing is to be excluded?
					SourceSize=$(cat /sys/block/$Source/$part/size 2> /dev/null)
					if [[ -a /dev/$targetpart ]]; then
						TargetSize=$(cat /sys/block/$Target/$targetpart/size 2> /dev/null)
						if [[ $SourceSize == $TargetSize ]]; then
							( log Size of $part and $targetpart checks out. ) | tee -a "${LogPath}/BackupStatus"
							continue
						else
							( log part size of $targetpart does not match to $part. ) | tee -a "${LogPath}/BackupStatus"
							if [[ $SourceSize -gt $TargetSize ]]; then
								( log ${part} "("$SourceSize")" ">" ${targetpart} "("$TargetSize")" ) | tee -a "${LogPath}/BackupStatus"
							else
								( log ${part} "("$SourceSize")" "<" ${targetpart} "("$TargetSize")" ) | tee -a "${LogPath}/BackupStatus"
							fi
							
							if [[ ! $adjust == true ]]; then
		  						confirm "Adjust? [y/N]"
							else
								response=true
							fi
							if [[ $response == true ]]; then # DOES NOT WORK?? FAULTY.
								response=""
								echo "To automate, supply the -a switch."
								partnum=$(echo $part | grep -oE '[0-9]+')
								if [[ $write == true ]]; then
									sgdiskF -d $partnum /dev/$Target
								else
									sgdiskF -P -d $partnum /dev/$Target
								fi
								createonce=true
							fi
						fi
					else		
						( log Partition $targetpart missing. ) | tee -a "${LogPath}/BackupStatus"
					fi
					if [[ "$create" != true ]] && [[ "$createonce" != true ]]; then
						confirm "Create? [y/N]"
						echo "To automate, supply -c switch"
					else
						response=true
					fi
					if [[ $response == true ]]; then
						response=""
						( log Creating $targetpart. ) | tee -a "${LogPath}/BackupStatus"
						start=$(cat /sys/block/$Source/$part/start 2> /dev/null)
						size=$(cat /sys/block/$Source/$part/size 2> /dev/null)
						declare -i end
						end=$start+$size-1
						partnum=$(echo $part | grep -oE '[0-9]+')
						partname=$(grep PARTNAME /sys/block/$Source/$part/uevent)
						partname=${partname#*=}
						typecode=$(sgdisk -p /dev/$Source | grep -E "^ *${partnum}" | awk '{print $6}')
						( log "$part type code: >$typecode<" ) | tee -a "${LogPath}/BackupStatus"
						partdetails=$(parted /dev/$Source print | grep -E "^ *${partnum}" | grep -E "[ \t\n\r][0-9]+(  )+ ?[^ \t\n\r]+(  )+ ?[^ \t\n\r]*(  )+ ?[^ \t\n\r]*(   ?[A-Za-z0-9]+ {0,9}| {15} ?) ?([^ ]+ ?)+")
						detailsnoflags=$(parted /dev/$Source print | grep -E "^ *${partnum}" | grep -o -E "[ \t\n\r][0-9]+(  )+ ?[^ \t\n\r]+(  )+ ?[^ \t\n\r]*(  )+ ?[^ \t\n\r]*(   ?[A-Za-z0-9]+ {0,9}| {15} ?) ?([^ ]+ ?)+")
						flags=( ${partdetails#$detailsnoflags} )
						( log "$part flags: >${flags[@]}<" ) | tee -a "${LogPath}/BackupStatus"
						# Problem with function and quotes at name?
						sgdisk -a 1 -n $partnum:$start:$end -c $partnum:"$partname" -t $partnum:"${typecode,,}" /dev/$Target #1> /dev/null
						
						#copy part flags
						counter=${#flags[@]}-1
						( log Setting flags ">${flags[@]}<" for $targetpart. )  | tee -a "${LogPath}/BackupStatus"
						for (( i = 0; i <= $counter; i++ )); do
							if [[ $write == true ]]; then
								parted /dev/$Target set $partnum ${flags[$i]%*,} on 1> /dev/null
							fi
						done
						createonce=""
					else
						response=""
						( log Excluding $part. ) | tee -a "${LogPath}/BackupStatus"
						Exclude+=($part)
					fi
				else
					( log Skipped $part from check because excluded. ) | tee -a "${LogPath}/BackupStatus"
				fi
			done
		else
			( log Target $Target not found. ) | tee -a "${LogPath}/BackupStatus"
			exit=1
			exitroutine
		fi
		
#=====Main Program======#
		
		( log Starting clone. ) | tee -a "${LogPath}/BackupStatus"
		for part in $( ls --color=never /dev/${Source}? | grep -oE '(((nvme|mmcblk)[0-9]+p[0-9]+)|((sd|x?vd)[A-Za-z]+[0-9]+))' ); do
		targetpart=${Target}$( echo $part | grep -oE '((p[0-9]+)|([0-9]+))' )
		
			if ! printf '%s\n' "${Exclude[@]}" | grep -q -P "^${part}$"; then
   			( log $part not in exclude. ) | tee -a "${LogPath}/BackupStatus"
   			#(((?<=(nvme|mmcblk)[0-9]+)p[0-9]+)|((?<=(sd|x?vd)[A-Za-z]+)[0-9]+))
   			SourceSize=$(cat /sys/block/$Source/$part/size 2> /dev/null)
   				TargetSize=$(cat /sys/block/$Target/$targetpart/size 2> /dev/null)
   			if [[ $SourceSize == $TargetSize ]]; then
   				clonefunc
   				clone+=( x$? )
				else
					( log Sizes do not match - skipping. ) | tee -a "${LogPath}/BackupStatus"
   			fi

   			sleep 1
   		else	
   			( log Skipped $part because excluded. ) |tee -a "${LogPath}/BackupStatus"
			fi			
		done
		
		
		#Checking if part table is out of bounds
		sgdiskF -v /dev/$Target
   					if [[ $? == 0 ]]; then
   						( log No Problems with $Target part table. ) |tee -a "${LogPath}/BackupStatus"
   						exit=0
   					else
   						sgdiskF -v /dev/$Target|tee -a "${LogPath}/BackupStatus"
   						if [[ ! $resolve == true ]]; then
   							echo "Do you want to solve these errors by removing partitions one by one from the end? (useful if target is smaller than source)"
   							confirm "Resolve Errors? [y/N]"
   						else
   							response=true
   						fi
   						if [[ $response == true ]]; then
   							response=""
   							echo "To automate, supply the -r argument."
   							( log Trying to resolve issues by removing partitions from end until there are no errors. ) |tee -a "${LogPath}/BackupStatus"
   							declare -i counter
   							counter=${#targetpart[@]}-1
   							for (( i = counter; i >= 0; i-- )); do
   								sgdiskF -v /dev/$Target
   								if [[ $? != 0 ]]; then
   									( log Removing ${Target}${i} now. ) |tee -a "${LogPath}/BackupStatus"
   									sgdiskF -d $i /dev/$Target
   								else
   									( log No errors anymore! Continuing. ) |tee -a "${LogPath}/BackupStatus"
   									break
   								fi
   							done
   						else
   							response=""
   						fi
   					fi
		
if false; then # altes script wird nicht ausgeführt!!		
		sleep 60
		if [[ -a /dev/sdb1 ]] && [[ -a /dev/sdb2 ]] && [[ -a /dev/sdb3 ]]; then
			fdisk -l | grep -P '(?<=\/dev\/sd[a-z]*[0-9]*( |\	|\n\r)*\*?( |\	|\n\r)*[0-9]* [0-9]* )[0-9]*(?=( |\	|\n\r)*[0-9]*,?[0-9]*[K,M,G,T] *[0-9]* )'
			if [ $sdb1Size ]; then
				echo
			fi
			notify-send -u normal -t 30 -i backups-app -c transfer "Freezing FS in 30." "The Root Filesystem is being frozen for copying.
Programs might hang during the duration of copying.
Please do not resist."
			sleep 30
			#fsfreeze -f /
			sleep 20
			
			dd if=/dev/sda2 of=/dev/sdb2 bs=512K conv=noerror,sync,sparse status=progress
			#fsfreeze -u /
			sda2=$?
			( log sda2 clone returned $sda2. ) |tee -a "${LogPath}/BackupStatus"
			
			dd if=/dev/sda1 of=/dev/sdb1 bs=1M conv=sync,sparse status=progress
			sda1=$?
			( log sda1 clone returned $sda1. ) |tee -a "${LogPath}/BackupStatus"
		else
			( log Copying sda. ) |tee -a "${LogPath}/BackupStatus"
			dd if=/dev/sda of=/dev/sdb bs=128K conv=noerror,sync,sparse status=progress
		fi
		( log dd finished. ) |tee -a "${LogPath}/BackupStatus"
			if [[ $sda2 != 0 ]] 2> /dev/null || [[ $sda1 != 0 ]] 2> /dev/null; then
				( log ERROR ${sda2}x${sda1}. NOT Restarting script in 5. ) |tee -a "${LogPath}/BackupStatus"
				notify-send -u critical -t 1700000 -i backups-app -c transfer.error "System Backup ERROR" "Code ${sda2}x${sda1}"
				at now + 5 minute -f "/Backupscript.sh"
			else
				notify-send -u normal -t 5000 -i backups-app -c transfer.complete --hint=int:x:20 --hint=int:y:20 "System Backup Done" ""
				touch ${LogPath}/BackupDone
				partprobe
				umount /dev/sdb1
				umount /dev/sdb2
				fsck -Clp /dev/sdb1 > /dev/null
				fsck -Clp /dev/sdb2 > /dev/null
				mount /dev/sdb1
				mount /dev/sdb2
			fi
fi #altes script ende!!
	
	fi
else
	if [[ -t 0 ]]; then #checks if stdout is connected to terminal
		echo "To force, supply the -f argument."
	else
		( log Not connected to main power. Restarting script in 60. ) |tee -a "${LogPath}/BackupStatus"
		notify-send -u normal -t 1700000 -i backups-app -c transfer.error "Backup rescheduled." "Connect to main power."
		at now + 1 hour -f "/Backupscript.sh" # make nameresistant
	fi
	exit=1
fi
exitroutine

exit # Leave here!! counterpart of load into memory
}
