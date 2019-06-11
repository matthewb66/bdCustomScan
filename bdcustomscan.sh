#
# v1.0
#
BDSCANFOCUSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$BDSCANFOCUSDIR/bdscanfocusfuncs.inc"

if [ $# -lt 1 ]
then
	error "Usage: bdcustomscan.sh [-focusfile scanfocusfile] [-excludepatterns pattern1,pattern2] [detect_opt1 detect_opt2]\n"
fi

FILESONLY=0
EXCLUDEPATTERNS=
FOCUSFILE=
DETECTOPTS=
debugmsg "bdcustomscan.sh started with options '%s'\n" "$*"
proc_opts $*

if [ -z "$APICODE" -o -z "$HUBURL" ]
then
	error "Please set the API code and BD Server URL\n"
fi

debugmsg "HUBURL=$HUBURL"
debugmsg "APICODE=$APICODE"

TOKEN=$(get_auth_token)
if [ $? -ne 0 ]
then
	debugmsg "Returned API token = $TOKEN"
	error "Unable to get API token"
fi
debugmsg "Returned API token = $TOKEN"

msg "\nRUNNING DETECT SCRIPT IN OFFLINE MODE\n"

debugmsg "Running command 'bash <(curl $CURLOPTS -s -L https://detect.synopsys.com/detect.sh) --detect.tools=SIGNATURE_SCAN --detect.blackduck.signature.scanner.host.url=$HUBURL $DETECTOPTS'"
bash <(curl $CURLOPTS -s -L https://detect.synopsys.com/detect.sh) --detect.tools=SIGNATURE_SCAN --detect.blackduck.signature.scanner.host.url=$HUBURL $DETECTOPTS | tee ${TEMPFILE}_log
if [ $? -ne 0 ]
then
	error "Detect script failed"
fi

debugmsg "Detect completed successfully"
debugfile "${TEMPFILE}_log" bdcustomscan_detect.log
debugmsg "Output file line from detect log = '"`grep -E 'INFO: Creating data output file:.*\.json$' ${TEMPFILE}_log`

JSONSCANFILE="`grep -E 'INFO: Creating data output file:.*\.json$' ${TEMPFILE}_log | cut -f14 -d' '`"
if [ -z "$JSONSCANFILE" ]
then
	error "Cannot extract JSON output file from detect log"
fi
if [ ! -r "$JSONSCANFILE" ]
then
	error "Detect JSON output file $JSONSCANFILE not found"
fi
debugmsg "JSONSCANFILE=$JSONSCANFILE"
msg "\nPROCESSING SCAN OUTPUT\n"

SCANOPTS=
if [ $FILESONLY -eq 1 ]
then
	SCANOPTS='-filesonly'
fi
if [ ! -z "$FOCUSFILE" ]
then
	SCANOPTS="$SCANOPTS -focusfile $FOCUSFILE"
fi
if [ ! -z "$EXCLUDEPATTERNS" ]
then
	SCANOPTS="$SCANOPTS -excludepatterns $EXCLUDEPATTERNS"
fi

DEBUGOPT=
if [ "$DEBUG" == "1" ]
then
	DEBUGOPT='-debug'
fi
debugmsg "Running command 'focus_scan.sh $DEBUGOPT $SCANOPTS -jsonfile $JSONSCANFILE -jsonout ${TEMPFILE}_mod.json'"

"$BDSCANFOCUSDIR/focus_scan.sh" $DEBUGOPT $SCANOPTS -jsonfile "$JSONSCANFILE" -jsonout "${TEMPFILE}_mod.json"
if [ $? -ne 0 ]
then
	error "focus_scan.sh script did not run correctly"
fi

if [ ! -r "${TEMPFILE}_mod.json" ]
then
	error "focus_scan.sh output JSON file missing"
fi
debugmsg "focus_scan.sh completed successfully"
debugfile "${TEMPFILE}_mod.json" bdcustomscan_scanmod.json

msg "\nUPLOADING MODIFIED SCAN RESULTS\n"

debugmsg "Running command 'curl $CURLOPTS -X POST '${HUBURL}/api/scan/data/?mode=replace' \
-H 'Authorization: Bearer $TOKEN' \
-H 'Content-Type: application/ld+json' \
-H 'cache-control: no-cache' \
--data-binary '@${TEMPFILE}_mod.json'"

curl $CURLOPTS -X POST "${HUBURL}/api/scan/data/?mode=replace" \
-H "Authorization: Bearer $TOKEN" \
-H 'Content-Type: application/ld+json' \
-H 'cache-control: no-cache' \
--data-binary "@${TEMPFILE}_mod.json"
if [ $? -ne 0 ]
then
	error "Unable to upload scan data to server $HUBURL"
fi

msg "\nSCAN UPLOADED SUCCESSFULLY\n"
end 0
