# OVERVIEW

Bash script to perform a custom scan using Synopsys Detect which can be focussed using a list of folders or files supplied in a file to reduce the number of OSS components detected (reducing the discovery of OSS components within other components which are not desired).

The script executes Synopsys Detect dynamically to perform a full signature scan in offline mode, and then process the output json file to remove entries which are not within the supplied filter file.

The filter file needs to contain 

Uses jq to format JSON data from API calls (must be preinstalled).

# SUPPORTED PLATFORMS

Linux & MacOS (bash required)

# PREREQUISITES

JQ must be pre-installed (https://stedolan.github.io/jq/) - can be installed using yum/brew etc.

# INSTALLATION

1. Extract the project files to a chosen folder.
2. Ensure script files `*.sh` have execute permission (chmod +x)
3. Add the scripts folder to the path (e.g. `export PATH=$PATH:/user/myuser/bdCustomScan`)
4. Create an API code (user access token) in the BD interface (use `Username-->My Profile-->User Access Token`)
5. Update the *HUBURL* and *APICODE* values in the *bdscanfocus.env* file to represent your BD server and API code.
6. If you are using an on-premises Hub without valid SSL certificate then add *-k* to the *CURLOPTS* variable.

# FILTER FILE

Create a filter file containing a list of either files or folders which you want to use to focus the scan.
This could be a list of compiled source files.

The entries must either be absolute (starting with /) or relative (starting with ./) and can either be folders (terminated with /) or files. Lines in the filter file not starting with / or ./ will be ignored.

All parent paths for each entry will be added to the filter list, for example if the entry `./myproject/myfolder/file.cpp` is added to the file, then the folders `./, ./myproject/ and ./myproject/myfolder/` will automatically be added to the list of folders to be included in the scan.

# USAGE

1. Change directory to the location to be scanned
2. Run the command `bdcustomscan.sh filter_file detect_options` where detect_options are any additional Synopsys Detect options required to run the scan. You do not need to specify the Hub URL or credentials as they are provided in the bdscanfocus.env file. For example `bdcustomscan myfilterfile.txt --detect.project.name=MyProject --detect.project.version.name=version1`.

This will perform an offline Detect signature (file/folder) scan only, locate the output JSON file from the ~/blackduck/runs folder, filter the scan based on the filter_file and upload the results to the Hub server automatically.


