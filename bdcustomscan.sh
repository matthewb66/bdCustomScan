#
# v1.0
#
BDSCANFOCUSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$BDSCANFOCUSDIR/bdscanfocusfuncs.inc"

if [ $# -lt 1 ]
then
	error Usage: bdcustomscan.sh scanfocusfile [detect_opt1 detect_opt2]
fi

if [ -z "$APICODE" -o -z "$HUBURL" ]
then
	error "Please set the API code and BD Server URL"
fi

FILESONLY=0
if [ "$1" == '-filesonly' ]
then
	FILESONLY=1
	shift
fi

FOCUSFILE=$1
if [ -z "$FOCUSFILE" ]
then
	error 'Please provide scanfocus file containing list of built files'
fi
if [ ! -r "$FOCUSFILE" ]
then
	error "Scanfocus file $FOCUSFILE does not exist"
fi

shift
DETECTOPTS=$*

TOKEN=$(get_auth_token)
if [ $? -ne 0 ]
then
	error "Unable to get API token"
fi

echo
echo RUNNING DETECT SCRIPT IN OFFLINE MODE
bash <(curl $CURLOPTS -s -L https://detect.synopsys.com/detect.sh) --detect.tools=SIGNATURE_SCAN --detect.blackduck.signature.scanner.host.url=$HUBURL $DETECTOPTS | tee ${TEMPFILE}_log
if [ $? -ne 0 ]
then
	error "Detect script failed"
fi

JSONSCANFILE="`grep -E 'INFO: Creating data output file:.*\.json$' ${TEMPFILE}_log | cut -f14 -d' '`"
if [ -z "$JSONSCANFILE" ]
then
	error "Cannot extract JSON output file from detect log"
fi
if [ ! -r "$JSONSCANFILE" ]
then
	error "Detect JSON output file $JSONSCANFILE not found"
fi

echo
echo PROCESSING SCAN OUTPUT
if [ $FILESONLY -eq 1 ]
then
	FILESONLYOPT='-filesonly'
fi
$BDSCANFOCUSDIR/focus_scan.sh $FILESONLYOPT $JSONSCANFILE $FOCUSFILE ${TEMPFILE}_mod.json
if [ $? -ne 0 ]
then
	error "focus_scan.sh script did not run correctly"
fi

if [ ! -r "${TEMPFILE}_mod.json" ]
then
	error "focus_scan.sh output JSON file missing"
fi

echo
echo UPLOADING MODIFIED SCAN RESULTS
curl $CURLOPTS -X POST "${HUBURL}/api/scan/data/?mode=replace" \
-H "Authorization: Bearer $TOKEN" \
-H 'Content-Type: application/ld+json' \
-H 'cache-control: no-cache' \
--data-binary "@${TEMPFILE}_mod.json"
if [ $? -ne 0 ]
then
	error "Unable to upload data to server $HUBURL"
fi

echo 
echo SCAN UPLOADED SUCCESSFULLY
end 0
