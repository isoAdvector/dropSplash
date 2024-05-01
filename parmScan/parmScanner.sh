#!/bin/bash

# Make a sequence of copies of baseCase and change one or more parameters in the
# setup files of each case according the the values in a parameter file.
#
# Example of the parameter file format:
#
# nx        ny      water.nu
# system/blockMeshDict system/blockMeshDict constant/transportProperties
# 50    50    1.5-06
# 100   100   1.5-06
# 50    50    3.0e-05
# 100   100   3.0e-05
#
# Here first line is parameter names, second line is the file where the file can
# be found and the each of the subsequent lines correspond to a new case.
#
# Johan Roenby, 2024
#
# Todo:
# -Make robust against variations in format
# -Enable different delimiters
# -Enable amending existing run
# -Implement list of cases plus info file about parameters in each case folder
# -Enable running other than Allrun
# -Enable specifying of number of processes to run at same time
# -Enable sending to queue system

# Base case to be copied and modified to create test matrix
baseCase=baseCase
# Name of file containing list of parameters to change and values
parmScanFile=parmFile
# Prefix name of created numbered test cases
scanName=parmScan
# Script to execute in each created case
execScript=

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -base)
            baseCase="$2"
            shift
            shift
            ;;
        -file)
            parmScanFile="$2"
            shift
            shift
            ;;
        -name)
            scanName="$2"
            shift
            shift
            ;;
        -exec)
            execScript="$2"
            shift
            shift
            ;;
        -help)
            # Print documentation text
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Description:"
            echo "  Script to generate, run and clean parameter scans based on an OpenFOAM base case."
            echo "  If run with no arguments, default values are used (see defaults in example below)."
            echo "  If case directories do not exist, they are created by the script."
            echo "  If they already exist the script specifoed with -exec is executed in each case (in serial)."
            echo
            echo "Options:"
            echo "  -base <base_case_file>      Specify the base case file to use for generating new cases."
            echo "  -file <test_list_file>      Specify the test list file containing the list of new cases to generate."
            echo "  -name <test_name>           Specify the name of the new test to be generated."
            echo "  -exec <case_script>         Specify the script to be executed in each new case."
            echo
            echo "  -help                           Display this help message and exit."
            echo
            echo "Example showing default values:"
            echo
            echo "  $0 -base baseCase -file parmFile -name parmScan -exec (no default)"
            echo
            echo "Example of parmFile format:"
            echo
            echo "  nx                      ny                      water.nu"
            echo "  system/blockMeshDict    system/blockMeshDict    constant/transportProperties"
            echo "  50                      50                      1.5-06"
            echo "  100                     100                     1.5-06"
            echo "  50                      50                      3.0e-05"
            echo "  100                     100                     3.0e-05"
            echo
            echo "Notes:"
            echo "Uses foamDictionary to set parameters in cases so OpenFOAM must be loaded."
            echo "If a scan is named myScan cases will be named myScan_000, myScan_001, ..."
            echo "The scan can then be deleted by executing \"rm -r myScan_*\" in the terminal."
            echo "To output a list of all cases and their parameter values execute \"cat myScan_*/myScan*\" ."
            echo
            echo "Author: Johan Roenby, 2024"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done


# Reading list of parameters to change
parmNames=($(sed -n '1p' $parmScanFile))
# For each parameter, which case file is it found in?
parmFiles=($(sed -n '2p' $parmScanFile))
# Length of list of new cases to be generated
nCases=$(($(wc -l < $parmScanFile) - 2))
# Number of digits for padding numbers in new case names
# nDigits=$(( ${#nCases} + 2 ))
# Note: The above did not work as intended. If starting with 6 cases and then
# later expanding to 11, 6 first will be recreated with an extra 0 in name.
# Using instead four digits hardcoded assuming never more than 10000 cases:
nDigits=4

#Running through cases and generating or running them
for ((i=0; i<nCases; i++)); do
    caseNumber=$(printf "%0${nDigits}d" "$i")
    #Which line in parmScanFile specifies parameter values of current case 
    parmLineNumber=$((i + 3))
    #Current case parameter values
    caseParms=($(sed -n ${parmLineNumber}p $parmScanFile))
    #Name of current case directory
    caseName=${scanName}_${caseNumber}
    if [ -d "$caseName" ];
    then
        if [ -z "$execScript" ]; then
            echo Case $caseName already exists - doing nothing.
        else
            cd ${caseName}
            echo Running script $caseScript in case $caseName
            ./$execScript
            cd -
        fi
    else
        echo Creating case $caseName
        cp -r $baseCase $caseName
        caseParmFile=$caseName/${caseName}_parms
        echo -n "$caseName: " >> $caseParmFile
        for m in ${!parmNames[*]}
        do
            parmName=${parmNames[$m]}
            parmFile=${parmFiles[$m]}
            parmValue=${caseParms[$m]}
            echo -n "    $parmName: $parmValue" >> $caseParmFile
            foamDictionary -disableFunctionEntries -entry "${parmName}" -set "${parmValue}" ${caseName}/${parmFile} > /dev/null 2>&1
        done
        echo >> $caseParmFile
        cat $caseParmFile
    fi
done
