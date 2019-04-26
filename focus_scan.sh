#
# v1.0
#
FILESONLY=0
if [ "$1" == '-filesonly' ]
then
	FILESONLY=1
	shift
fi

JSONFILE=$1
FILELISTFILE=$2
OUTPUTFILE=$3
TEMPFILE=/tmp/rd$$

end () {
	rm -f $TEMPFILE ${TEMPFILE}_*
	rm -f outstream.pdf
	exit $1
}

error () {
	echo "ERROR: $*" >&2
	end 1
}

if [ $# -lt 2 ]
then
	echo "Usage: focus_scan.sh [-filesonly] jsonfile filelist [outputfile]"
	end 1
fi

if [ ! -r "$JSONFILE" ]
then
	error "No json file specified"
fi
if [ ! -r "$FILELISTFILE" ]
then
	error "No compiled list file specified"
fi
if [ -z "$OUTPUTFILE" ]
then
	OUTFILE="`echo $JSONFILE| sed -e 's/\.json$//'`"_focussed.json
else
	OUTFILE=$OUTPUTFILE
fi
if [ -r $OUTFILE ]
then
	error "Output file $OUTFILE already exists"
fi

echo "Filelist file: " $FILELISTFILE
echo "Reading JSON file: " $JSONFILE
echo "Outputting to file: " $OUTFILE
if [ $FILESONLY -eq 1 ]
then
	echo "Will process files only from filelist file"
fi
# Process JSON file
jq . $JSONFILE > ${TEMPFILE}_json

#cp ${TEMPFILE}_json scan.json

# Process the listfile
# Remove lines not starting with './'
# Strip crlfs
# Remove leading ./
if [ $FILESONLY -eq 0 ]
then
	# Remove filenames leaving only folders
	cat $FILELISTFILE | tr -d '\r' | grep '^\./' | sed -e 's:^\./::' -e 's:/[^/]*$:/:' | sort -u > $TEMPFILE
else
	cat $FILELISTFILE | tr -d '\r' | grep '^\./' | sed -e 's:^\./::' | sort -u > $TEMPFILE
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
		cat $FILELISTFILE | tr -d '\r' | grep '^/' | sed -e "s:^${THISDIR}/::" -e 's:/[^/]*$:/:' | sort -u > $TEMPFILE
	else
		cat $FILELISTFILE | tr -d '\r' | grep '^/' | sed -e "s:^${THISDIR}/::" | sort -u > $TEMPFILE
	fi

	LINES=`cat $TEMPFILE | wc -l`
	if [ $LINES -lt 1 ]
	then
		error "Unable to process scan focus file $FILELISTFILE - please ensure file locations start with ./ or /"
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
} ' $TEMPFILE ${TEMPFILE}_json > $OUTFILE

end 0
