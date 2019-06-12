#
# v1.0
#
FILESONLY=0
EXCLUDELIST=
FOCUSFILE=
DETECTOPTS=

TEMPFILE=/tmp/rd$$

end () {
	rm -f $TEMPFILE ${TEMPFILE}_*
	exit $1
}

error () {
	echo "ERROR: $*" >&2
	end 1
}

proc_opts() {
	PREVOPT=
	for opt in $*
	do
		case $opt in
			-filesonly)
				FILESONLY=1
				PREVOPT=$opt
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
						error "Focusfile $FOCUSFILE does not exist"
					fi
					PREVOPT=
				elif [ "$PREVOPT" == '-jsonfile' ]
				then
					JSONFILE=$opt
					if [ ! -r "$JSONFILE" ]
					then
						error "JSON file $JSONFILE does not exist"
					fi
					PREVOPT=
				elif [ "$PREVOPT" == '-jsonout' ]
				then
					JSONOUT=$opt
					if [ -r "$JSONOUT" ]
					then
						error "JSON output file $JSONOUT exists"
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
		error 'Please specify either "-focusfile focusfile" or "-excludepatterns patternlist" or both'
	fi
}

if [ $# -lt 2 ]
then
	printf "Usage: focus_scan.sh [-filesonly] -jsonfile jsonfile [-focusfile filelist|-excludepatterns patt1,patt2] [-jsonout outputfile]\n"
	end 1
fi

proc_opts $*

if [ ! -r "$JSONFILE" ]
then
	error "No json file specified"
fi

if [ -z "$JSONOUT" ]
then
	OUTFILE="`echo $JSONFILE| sed -e 's/\.json$//'`"_focussed.json
else
	OUTFILE=$JSONOUT
fi

printf "Filelist file: \t\t%s\n" $FOCUSFILE
printf "Input JSON file: \t%s\n" $JSONFILE
printf "Output JSON file: \t%s\n" $OUTFILE
printf "Exclude pattern: \t%s\n" $EXCLUDELIST
if [ $FILESONLY -eq 1 ]
then
	printf "Will process files only from filelist file\n"
fi
# Process JSON file
jq . $JSONFILE > ${TEMPFILE}_json

#cp ${TEMPFILE}_json scan.json
if [ ! -z "$FOCUSFILE" ]
then
	# Process the listfile
	# Remove lines not starting with './'
	# Strip crlfs
	# Remove leading ./
	if [ $FILESONLY -eq 0 ]
	then
		# Remove filenames leaving only folders
		cat $FOCUSFILE | tr -d '\r' | grep '^\./' | sed -e 's:^\./::' -e 's:/[^/]*$:/:' | sort -u > $TEMPFILE
	else
		cat $FOCUSFILE | tr -d '\r' | grep '^\./' | sed -e 's:^\./::' | sort -u > $TEMPFILE
	fi

	LINES=`cat $TEMPFILE | wc -l`
	if [ $LINES -lt 1 ]
	then
		#
		# Try looking for full paths
		THISDIR=`pwd`
		if [ $FILESONLY -eq 0 ]
		then
			# Remove filenames leaving only folders
			cat $FOCUSFILE | tr -d '\r' | grep '^/' | sed -e "s:^${THISDIR}/::" -e 's:/[^/]*$:/:' | sort -u > $TEMPFILE
		else
			cat $FOCUSFILE | tr -d '\r' | grep '^/' | sed -e "s:^${THISDIR}/::" | sort -u > $TEMPFILE
		fi

		LINES=`cat $TEMPFILE | wc -l`
		if [ $LINES -lt 1 ]
		then
			error "Unable to process scan focus file $FOCUSFILE - please ensure file locations start with ./ or /"
		fi
	fi

	# Now check that first entry exists in JSON file
	read FILECHECK < $TEMPFILE

	FOUNDINJSON="`grep '"path"' ${TEMPFILE}_json | cut -f4 -d'"' | grep $FILECHECK | sed -n '1p'`"
	if [ -z "$FOUNDINJSON" ]
	then
		error "Cannot process JSON file"
	fi

	if [ "$FOUNDINJSON" != "$FILECHECK" ]
	then
		# Cannot find first entry from listfile in JSON
		error "Cannot find first entry from listfile in JSON file"
	fi

printf "Processing focus file ...\n"
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
				for (i=0; i<length(storedlines); i++) {
					print storedlines[i]
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
			for (i=0; i<length(storedlines)-1; i++) {
				print storedlines[i]
			}
		}
		print "}"
		print $0
		initialfinalblock=1
	}
}

END {
	printf("Scan Entries Processed/Removed/Retained = %d/%d/%d\n", allblocks, removedblocks, allblocks - removedblocks) > "/dev/tty"
} ' $TEMPFILE ${TEMPFILE}_json > ${TEMPFILE}_out
fi

#
# Create the file match string
if [ ! -z "$EXCLUDELIST" ]
then
	printf "Processing exclusion patterns ...\n"
	if [ ! -z "$FOCUSFILE" -a -r "${TEMPFILE}_out" ]
	then
		mv ${TEMPFILE}_out ${TEMPFILE}_json
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
				for (i=0; i<length(storedlines); i++) {
					print storedlines[i]
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
			for (i=0; i<length(storedlines)-1; i++) {
				print storedlines[i]
			}
		}
		print "}"
		print $0
		initialfinalblock=1
	}
}

END {
	printf("Scan Entries Processed/Removed/Retained = %d/%d/%d\n", allblocks, removedblocks, allblocks - removedblocks) > "/dev/tty"
} ' ${TEMPFILE}_json > $OUTFILE
else
	cp ${TEMPFILE}_out $OUTFILE
fi

end 0
