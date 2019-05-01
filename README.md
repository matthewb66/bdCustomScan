# OVERVIEW

Bash script to perform a custom scan using Synopsys Detect which can then be focussed either using a list of folders or files supplied in a file and/or by specifying exclusion patterns for files to reduce the number of OSS components detected (reducing the discovery of OSS components within other components which are not desired).

The script executes Synopsys Detect dynamically to perform a full signature scan in offline mode, and then process the output json file to remove entries which are either not within the supplied filter file or match the exclude patterns.

The filter file needs to contain a list of files or folders which will be used to remove all other scan results not within the list.

Requires jq package to be installed to format JSON data from API calls.

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

# USAGE

1. Change directory to the location to be scanned
2. Run the command `bdcustomscan.sh -focusfile filter_file detect_options` or `bdcustomscan.sh -excludepatterns patterns detect_options` where 'detect_options' are any additional Synopsys Detect options required to run the scan.

The '-focusfile' and '-excludepatterns' options can also be combined in a single command. You do not need to specify the Hub URL or credentials as they are provided in the bdscanfocus.env file.

Example commands:

`bdcustomscan -focusfile myfilterfile.txt --detect.project.name=MyProject --detect.project.version.name=version1`.

This will download Synopsys Detect, perform an offline Signature (file/folder) scan only, locate the JSON file created by the scan from the ~/blackduck/runs folder, filter the scan to remove element NOT specified in the file 'myfilterfile.txt' and upload the results to the Hub server in the project 'MyProject' and version 'version1' automatically.

`bdcustomscan -excludepatterns '.js,.ps' --detect.project.name=MyProject --detect.project.version.name=version1`.

This will download Synopsys Detect, perform an offline Signature (file/folder) scan only, locate the JSON file created by the scan from the ~/blackduck/runs folder, filter the scan to remove any entries for files ending in .ps or .js and upload the results to the Hub server in the project 'MyProject' and version 'version1' automatically.

See below for more information about the filter file and pattern definition.

# FILTER FILE

Create a filter file containing a list of either files or folders which you want to use to focus the scan.
This could be a list of compiled source files.

The entries must either be absolute (starting with /) or relative (starting with ./) and can either be folders (terminated with /) or files. Lines in the filter file not starting with / or ./ will be ignored.

All parent paths for each entry will be added to the filter list, for example if the entry `./myproject/myfolder/file.cpp` is added to the file, then the folders `./, ./myproject/ and ./myproject/myfolder/` will automatically be added to the list of folders to be included in the scan.
## Example Filter Files

Filter file of compiled source files with relative path:
  
    ************************************
    Checking ./usr/lib/ssl/engines/libgmp.so
    ************************************

    ==> SOURCES:

    ./Openssl/openssl-1.0.2n/engines/e_gmp.c
    ./Openssl/openssl-1.0.2n/crypto/ossl_typ.h
    ./Openssl/openssl-1.0.2n/include/openssl/ossl_typ.h
    ./Openssl/openssl-1.0.2n/crypto/crypto.h
    ./Openssl/openssl-1.0.2n/include/openssl/crypto.h
    ./Openssl/openssl-1.0.2n/crypto/asn1/asn1.h
    ./Openssl/openssl-1.0.2n/include/openssl/asn1.h
    ./Openssl/openssl-1.0.2n/crypto/rsa/rsa.h
    ./Openssl/openssl-1.0.2n/include/openssl/rsa.h
    ./Openssl/openssl-1.0.2n/crypto/objects/objects.h
    ./Openssl/openssl-1.0.2n/include/openssl/objects.h
    ./Openssl/openssl-1.0.2n/crypto/pkcs7/pkcs7.h
    ./Openssl/openssl-1.0.2n/include/openssl/pkcs7.h
    ./Openssl/openssl-1.0.2n/crypto/x509/x509.h
    ./Openssl/openssl-1.0.2n/include/openssl/x509.h
    ./Openssl/openssl-1.0.2n/crypto/engine/engine.h
    ./Openssl/openssl-1.0.2n/include/openssl/engine.h

Filter file containing folders with absolute path:
  
    ************************************
    Checking ./usr/lib/ssl/engines/libgmp.so
    ************************************
    /home/user1/Openssl/openssl-1.0.2n/engines/
    /home/user1/Openssl/openssl-1.0.2n/crypto/
    /home/user1/Openssl/openssl-1.0.2n/include/
    /home/user1/Openssl/openssl-1.0.2n/include/openssl/
    /home/user1/Openssl/openssl-1.0.2n/crypto/asn1/
    /home/user1/Openssl/openssl-1.0.2n/crypto/objects/
    /home/user1/Openssl/openssl-1.0.2n/crypto/pkcs7/
    /home/user1/Openssl/openssl-1.0.2n/crypto/x509/

# EXCLUDE PATTERNS

The exclude patterns must be specified as a comma separated list which match the end of the file names for scan elements to be removed.

For example, the pattern `.js,.ps` would exclude any files which match *.js or *.ps.


