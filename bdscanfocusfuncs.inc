#
# v1.0
#
BDSCANFOCUSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$BDSCANFOCUSDIR/bdscanfocus.env"
TEMPFILE=/tmp/bds$$
DEBUG=
LOGFILE=DEBUG_bdcustomscan.log
rm -f $LOGFILE

end () {
	rm -f $TEMPFILE ${TEMPFILE}_*
	exit $1
}

msg () {
	STRING="$*"
	if [ "$DEBUG" == "1" ]
	then
		printf "$STRING" >> $LOGFILE
	fi
	printf "$STRING"
}

error () {
	FORSTRING="ERROR: $*"
	printf "$FORSTRING" >&2
	if [ "$DEBUG" == "1" ]
	then
		printf "$FORSTRING" >> $LOGFILE
	fi
	end 1
}

get_auth_token() {
	curl $CURLOPTS -X POST --header "Authorization: token $APICODE" --header "Accept:application/json" $HUBURL/api/tokens/authenticate > $TEMPFILE 2>/dev/null
	if [ $? -ne 0 ] || [ ! -r $TEMPFILE ]
	then
		msg "API request failure\n"
		return -1
	fi

	jq '.bearerToken' $TEMPFILE|sed -e 's/^"//' -e 's/"$//'
	return 0
}

api_call() {
	rm -f $TEMPFILE
	curl $CURLOPTS -X GET --header "Authorization: Bearer $TOKEN" "$1" 2>/dev/null >$TEMPFILE
	if [ $? -ne 0 ] || [ ! -r $TEMPFILE ]
	then
		msg "API Error:\ncurl -X GET --header 'Authorization: Bearer $TOKEN' $1"
		return -1
	fi

	COUNT=`jq -r '.totalCount' $TEMPFILE`
	if [ -z "$COUNT" ]
	then
		return -1
	fi
	
	return $COUNT
}

proc_opts() {
	PREVOPT=
	for opt in $*
	do
		case $opt in
			-filesonly)
				FILESONLY=1
				PREVOPT=
				;;
			-debug)
				DEBUG=1
				> $LOGFILE
				PREVOPT=
				;;
			-focusfile|-excludepatterns|-jsonfile)
				PREVOPT=$opt
				;;
			*)
				if [ "$PREVOPT" == '-focusfile' ]
				then
					FOCUSFILE=$opt
					if [ ! -r "$FOCUSFILE" ]
					then
						error "Focusfile $FOCUSFILE does not exist\n"
					fi
					PREVOPT=
				#elif [ "$PREVOPT" == '-jsonfile' ]
				#then
				#	JSONFILE=$opt
				#	if [ ! -r "$JSONFILE" ]
				#	then
				#		error "JSON file $JSONFILE does not exist\n"
				#	fi
				#	PREVOPT=
				elif [ "$PREVOPT" == "-excludepatterns" ]
				then
					EXCLUDEPATTERNS=$opt
					PREVOPT=
				elif [ -z "$PREVOPT" ]
				then
					DETECTOPTS="$DETECTOPTS $opt"
				fi
		esac
	done
	
	if [ -z "$FOCUSFILE" -a -z "$EXCLUDEPATTERNS" ]
	then
		error 'Please specify either "-focusfile focusfile" or "-excludepatterns patternlist" or both\n'
	fi
}

check_prereqs() {
	#TEST="`echo '{\"test\":100}' | jq .test`"
	hash jq 2>/dev/null
	#if [ -z "$TEST" -o "$TEST" != '100' ]
	if [ $? -ne 0 ]
	then
		msg "jq v1.6+ package required - please install before continuing\n"
		return -1
	fi
	hash curl 2>/dev/null
	if [ $? -ne 0 ]
	then
		msg "curl package required - please install before continuing\n"
		return -1
	fi
	hash awk 2>/dev/null
	if [ $? -ne 0 ]
	then
		msg "awk package required - please install before continuing\n"
		return -1
	fi
	hash sed 2>/dev/null
	if [ $? -ne 0 ]
	then
		msg "sed package required - please install before continuing\n"
		return -1
	fi
	hash tr 2>/dev/null
	if [ $? -ne 0 ]
	then
		msg "tr package required - please install before continuing\n"
		return -1
	fi
	hash sort 2>/dev/null
	if [ $? -ne 0 ]
	then
		msg "sort package required - please install before continuing\n"
		return -1
	fi
	
	return 0
}

debugmsg () {
	if [ "$DEBUG" == "1" ]
	then
		printf "$*" >> $LOGFILE
	fi
}

debugfile () {
	if [ "$DEBUG" == "1" ]
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

check_prereqs
if [ $? -ne 0 ]
then
	error "Missing prerequisites\n"
fi
