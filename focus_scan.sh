#
# v1.0
#
FILESONLY=0
EXCLUDEPATTERNS=
FOCUSFILE=
DETECTOPTS=
FSDEBUG=0
LOGFILE=DEBUG_focus_scan.log
rm -f $LOGFILE
FSTEMPFILE=/tmp/rd$$

fsend () {
	rm -f $FSTEMPFILE ${FSTEMPFILE}_*
	exit $1
}

fserror () {
	FORSTRING="ERROR: $*"
	printf "$FORSTRING" >&2
	if [ "$FSDEBUG" == "1" ]
	then
		printf "$FORSTRING" >> $LOGFILE
	fi
	fsend 1
}

fsproc_opts() {
	PREVOPT=
	for opt in $*
	do
		case $opt in
			-filesonly)
				FILESONLY=1
				PREVOPT=
				;;
			-debug)
				FSDEBUG=1
				> $LOGFILE
				PREVOPT=
				;;
			-focusfile|-excludepatterns|-jsonfile|-jsonout)
				PREVOPT=$opt
				;;
			*)
				if [ "$PREVOPT" == '-focusfile' ]
				then
					FOCUSFILE=$opt
					if [ ! -r "$FOCUSFILE" ]
					then
						fserror "Focusfile $FOCUSFILE does not exist\n"
					fi
					PREVOPT=
				elif [ "$PREVOPT" == '-jsonfile' ]
				then
					JSONFILE=$opt
					if [ ! -r "$JSONFILE" ]
					then
						fserror "JSON file $JSONFILE does not exist\n"
					fi
					PREVOPT=
				elif [ "$PREVOPT" == '-jsonout' ]
				then
					JSONOUT=$opt
					if [ -r "$JSONOUT" ]
					then
						fserror "JSON output file $JSONOUT exists\n"
					fi
					PREVOPT=
				elif [ "$PREVOPT" == "-excludepatterns" ]
				then
					EXCLUDELIST=$opt
					PREVOPT=
				elif [ -z "$PREVOPT" ]
				then
					DETECTOPTS="$DETECTOPTS $opt"
				fi
				;;
		esac
	done
	
	if [ -z "$FOCUSFILE" -a -z "$EXCLUDELIST" ]
	then
		fserror 'Please specify either "-focusfile focusfile" or "-excludepatterns patternlist" or both\n'
	fi
}

fsdebugmsg () {
	STRING="$1"
	shift
	if [ "$FSDEBUG" == "1" ]
	then
		printf "$STRING" >> $LOGFILE
	fi
}

fsdebugfile () {
	if [ "$FSDEBUG" == "1" ]
	then
		if [ $# -ne 2 ]
		then
			return
		fi
		if [ -r "$1" ] 
		then
			cp -f "$1" "DEBUG_$2"
			printf "Copied file %s to %s\n" "$1" "DEBUG_$2" >> $LOGFILE
		fi
	fi	
}

fsmsg () {
	STRING="$1"
	if [ "$FSDEBUG" == "1" ]
	then
		printf "$STRING" >> $LOGFILE
	fi
	printf "$STRING"
}

fsdebugmsg "focus_scan.sh called with arguments '$*'\n"
if [ $# -lt 2 ]
then
	fsmsg "Usage: focus_scan.sh [-filesonly] -jsonfile jsonfile [-focusfile filelist|-excludepatterns patt1,patt2] [-jsonout outputfile]\n"
	fsend 1
fi

fsproc_opts $*

if [ ! -r "$JSONFILE" ]
then
	fserror "No json file specified\n"
fi

if [ -z "$JSONOUT" ]
then
	OUTFILE="`echo $JSONFILE| sed -e 's/\.json$//'`"_focussed.json
else
	OUTFILE=$JSONOUT
fi

fsmsg "Filelist file: \t\t$FOCUSFILE\n" 
fsmsg "Input JSON file: \t$JSONFILE\n" 
fsmsg "Output JSON file: \t$OUTFILE\n" 
fsmsg "Exclude pattern: \t$EXCLUDEPATTERNS\n" 
fsdebugmsg "FILESONLY=$FILESONLY\n"

if [ $FILESONLY -eq 1 ]
then
	fsmsg "Will process files only from filelist file\n"
fi
# Process JSON file
jq . "$JSONFILE" > "${FSTEMPFILE}_json"
if [ ! -r "${FSTEMPFILE}_json" ]
then
	fserror "Unable to run jq on $JSONFILE\n" 
fi
fsdebugmsg "Created ${FSTEMPFILE}_json output file from jq\n"

fsdebugfile ${FSTEMPFILE}_json focus_scan_scanin.json
if [ ! -z "$FOCUSFILE" ]
then
	# Process the listfile
	# Remove lines not starting with './'
	# Strip crlfs
	# Remove leading ./
	if [ $FILESONLY -eq 0 ]
	then
		# Remove filenames leaving only folders
		cat "$FOCUSFILE" | tr -d '\r' | grep '^\./' | sed -e 's:^\./::' -e 's:/[^/]*$:/:' | sort -u > "$FSTEMPFILE"
	else
		cat "$FOCUSFILE" | tr -d '\r' | grep '^\./' | sed -e 's:^\./::' | sort -u > "$FSTEMPFILE"
	fi

	LINES=`cat "$FSTEMPFILE" | wc -l`
	if [ $LINES -lt 1 ]
	then
		#
		# Try looking for full paths
		THISDIR=`pwd`
		if [ $FILESONLY -eq 0 ]
		then
			# Remove filenames leaving only folders
			cat "$FOCUSFILE" | tr -d '\r' | grep '^/' | sed -e "s:^${THISDIR}/::" -e 's:/[^/]*$:/:' | sort -u > "$FSTEMPFILE"
		else
			cat "$FOCUSFILE" | tr -d '\r' | grep '^/' | sed -e "s:^${THISDIR}/::" | sort -u > "$FSTEMPFILE"
		fi

		LINES=`cat "$FSTEMPFILE" | wc -l`
		if [ $LINES -lt 1 ]
		then
			fserror "Unable to process scan focus file $FOCUSFILE - please ensure file locations start with ./ or /\n" 
		fi
	fi
	fsdebugfile "$FSTEMPFILE" focus_scan_focusfileprocessed.txt
	fsdebugmsg "Processed focus file has $LINES lines\n" 

	# Now check that first entry exists in JSON file
	read FILECHECK < "$FSTEMPFILE"
	fsdebugmsg "FILECHECK=$FILECHECK\n" 

	FOUNDINJSON="`grep '"path"' ${FSTEMPFILE}_json | cut -f4 -d'"' | grep \"^$FILECHECK\$\"`"
	fsdebugmsg "FOUNDINJSON=$FOUNDINJSON\n"
	if [ -z "$FOUNDINJSON" ]
	then
		fserror "Cannot process JSON file\n"
	fi

fsmsg "Processing focus file ...\n"
awk '
BEGIN {
	blocklinecount=0
	outputblock=1
	allblocks=0
	removedblocks=0
	outputblocks=0
	initialfinalblock=1
	filelistarray["/"]=1
}

FILENAME==ARGV[1] {
	filepath=$1
	#gsub("^\./","",filepath)
	#printf("File in list %s\n", filepath) > "/dev/tty"
	while (filepath != "") {
		if (filelistarray[filepath]==0) {
			filelistarray[filepath]=1
			#printf("Storing %s\n", filepath) > "/dev/tty"
		}
		gsub("/$", "", filepath)
		if (filelistarray[filepath]==0) {
			filelistarray[filepath]=1
			#printf("Storing %s\n", filepath) > "/dev/tty"
		}
		gsub("[^/]*$", "", filepath)
	}
	next
}

FILENAME==ARGV[2] {
	#Print the header
	if (initialfinalblock==1) print $0
	else {
		if ($1 ~ /},/) {
			allblocks++
			if (outputblock==1) {
				outputblocks++
				if (outputblocks>1) {
					print "},"
				}
				i=0
				for (a in storedlines) {
					print storedlines[i++]
				}
			}
			else {
				removedblocks++
				#if ((removedblocks%1000) == 0) printf("Scan Entries Processed/Removed/Retained = %d/%d/%d\033[1A\n", allblocks, removedblocks, allblocks - removedblocks) > "/dev/tty"
			}
			
			blocklinecount=0
			outputblock=1
			delete storedlines
		} else {
			storedlines[blocklinecount++]=$0
		}
		if ( $0 ~ /\"path\"/) {
			#Check to see if the path is in filelist
			filepath=$2
			gsub("\"", "", filepath)
			gsub(",", "", filepath)
			if ( '${FILESONLY}' == 0 ) {
				#printf("Stripping filename from %s\n", filepath) > "/dev/tty"
				gsub("/[^/]*$", "/", filepath)
			}
			if (filelistarray[filepath]==1) {
				#Found in filelistfile
	#printf("Found file entry %s\n", filepath) > "/dev/tty"
				outputblock=1
			} else {
				#Not found in filelistfile
				outputblock=0
			}
		}
	}

	if ( $0 ~ /\"scanNodeList\"/) {
		initialfinalblock=0
	}

	if ( $0 ~ /],/) {
		if (printblock == 1) {
			i=0
			for (a in storedlines) {
				print storedlines[i++]
			}
		}
		print "}"
		print $0
		initialfinalblock=1
	}
}

END {
	printf("Scan Entries Processed/Removed/Retained = %d/%d/%d\n", allblocks, removedblocks, allblocks - removedblocks) > "/dev/tty"
} ' "$FSTEMPFILE" "${FSTEMPFILE}_json" > "${FSTEMPFILE}_out"
	if [ $? -ne 0 ]
	then
		fserror "Awk for filelist failed\n"
	fi
	fsdebugfile "${FSTEMPFILE}_out" focus_scan_awk1.out
fi

#
# Create the file match string
if [ ! -z "$EXCLUDELIST" ]
then
	fsmsg "Processing exclusion patterns ...\n"
	if [ ! -z "$FOCUSFILE" -a -r "${FSTEMPFILE}_out" ]
	then
		mv "${FSTEMPFILE}_out" "${FSTEMPFILE}_json"
	fi
	
awk '
BEGIN {
	blocklinecount=0
	outputblock=1
	allblocks=0
	removedblocks=0
	outputblocks=0
	initialfinalblock=1
	split("'$EXCLUDELIST'", patterns, ",")
}

FILENAME==ARGV[1] {
	#Print the header
	if (initialfinalblock==1) print $0
	else {
		if ($1 ~ /},/) {
			allblocks++
			if (outputblock==1) {
				outputblocks++
				if (outputblocks>1) {
					print "},"
				}
				i=0
				for (a in storedlines) {
					print storedlines[i++]
				}
			}
			else {
				removedblocks++
				if ((removedblocks%1000) == 0) printf("Scan Entries Processed/Removed/Retained = %d/%d/%d\033[1A\n", allblocks, removedblocks, allblocks - removedblocks) > "/dev/tty"
			}
			
			blocklinecount=0
			outputblock=1
			delete storedlines
		} else {
			storedlines[blocklinecount++]=$0
		}
		if ( $0 ~ /\"path\"/) {
			outputblock=1
			# Now check if file matches excludepatterns
			fullfile=$2
			for (pattern in patterns) {
				foundpos = index(fullfile, patterns[pattern])
				if ( foundpos > 0 && foundpos == length(fullfile) - length(patterns[pattern]) - 1) {
					#printf("Found pattern %s\n", fullfile) > "/dev/tty"
					#printf("foundpos %d fullfile %d pattern %d\n", foundpos, length(fullfile), length(patterns[pattern])) > "/dev/tty"
					outputblock=0
				}
			}
		}
	}

	if ( $0 ~ /\"scanNodeList\"/) {
		initialfinalblock=0
	}

	if ( $0 ~ /],/) {
		if (printblock == 1) {
			i=0
			for (a in storedlines) {
				print storedlines[i++]
			}
		}
		print "}"
		print $0
		initialfinalblock=1
	}
}

END {
	printf("Scan Entries Processed/Removed/Retained = %d/%d/%d\n", allblocks, removedblocks, allblocks - removedblocks) > "/dev/tty"
} ' "${FSTEMPFILE}_json" > "${FSTEMPFILE}_out"
	if [ $? -ne 0 ]
	then
		fserror "Awk for filelist failed\n"
	fi
	fsdebugfile "${FSTEMPFILE}_out" focus_scan_awk2.out
fi

if [ -r "${FSTEMPFILE}_out" ]
then
	cp -f "${FSTEMPFILE}_out" "$OUTFILE"
else
	fserror "No output file created from awk executions\n"
fi

fsdebugmsg "focus_scan.sh completed successfully\n"
fsend 0
