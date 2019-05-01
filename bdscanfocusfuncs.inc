#
# v1.0
#
BDSCANFOCUSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$BDSCANFOCUSDIR/bdscanfocus.env"
TEMPFILE=/tmp/bds$$

end () {
	rm -f $TEMPFILE ${TEMPFILE}_*
	rm -f outstream.pdf
	exit $1
}

error () {
	printf "ERROR: $*\n" >&2
	end 1
}

get_auth_token() {
	curl $CURLOPTS -X POST --header "Authorization: token $APICODE" --header "Accept:application/json" $HUBURL/api/tokens/authenticate > $TEMPFILE 2>/dev/null
	if [ $? -ne 0 ] || [ ! -r $TEMPFILE ]
	then
		printf "API request failure\n" >&2
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
		printf "API Error:\ncurl -X GET --header 'Authorization: Bearer %s' %s\n" $TOKEN $1 >&2
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
				PREVOPT=$opt
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
						error "Focusfile $FOCUSFILE does not exist"
					fi
					PREVOPT=
				#elif [ "$PREVOPT" == '-jsonfile' ]
				#then
				#	JSONFILE=$opt
				#	if [ ! -r "$JSONFILE" ]
				#	then
				#		error "JSON file $JSONFILE does not exist"
				#	fi
				#	PREVOPT=
				elif [ "$PREVOPT" == "-excludepatterns" ]
				then
					EXCLUDELIST=$opt
					PREVOPT=
				elif [ -z "$PREVOPT" ]
				then
					DETECTOPTS="$DETECTOPTS $opt"
				fi
		esac
	done
	
	if [ -z "$FOCUSFILE" -a -z "$EXCLUDELIST" ]
	then
		error 'Please specify either "-focusfile focusfile" or "-excludepatterns patternlist" or both'
	fi
}

check_prereqs() {
	#TEST="`echo '{\"test\":100}' | jq .test`"
	hash jq 2>/dev/null
	#if [ -z "$TEST" -o "$TEST" != '100' ]
	if [ $? -ne 0 ]
	then
		echo "jq package required - please install before continuing" >&2
		return -1
	fi
	hash curl 2>/dev/null
	if [ $? -ne 0 ]
	then
		echo "curl package required - please install before continuing" >&2
		return -1
	fi
	hash awk 2>/dev/null
	if [ $? -ne 0 ]
	then
		echo "awk package required - please install before continuing" >&2
		return -1
	fi
	hash sed 2>/dev/null
	if [ $? -ne 0 ]
	then
		echo "sed package required - please install before continuing" >&2
		return -1
	fi
	hash tr 2>/dev/null
	if [ $? -ne 0 ]
	then
		echo "tr package required - please install before continuing" >&2
		return -1
	fi
	hash sort 2>/dev/null
	if [ $? -ne 0 ]
	then
		echo "sort package required - please install before continuing" >&2
		return -1
	fi
	
	return 0
}

check_prereqs
if [ $? -ne 0 ]
then
	error "Missing prerequisites"
fi