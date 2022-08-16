#!/bin/bash

#Richard Deodutt
#08/15/2022
#This script is meant to securely and automatically create a git user and push changes to any branch but main, placing the git user in a GitAcc group, doing git add and commit while also handling sensitive personal information such as phone numbers or SSN before pushing.

GitLogsLocation='.git/.gitlogs'

#Default git user name, can be changed if desired
GitSecureUser='gitsecuser'

#Default git account group name, can be changed if desired
GitSecureGroup='gitsecacc'

#This controls the option to log to a file, should be left on true by default
CanFileLog=true

#This controls the option to push to main, should be left on false
CanPushMain=false

#Function to get a timestamp
timestamp(){
    #Two Different Date and Time Styles
    #date +"%m/%d/%Y %H:%M:%S %Z"
    date +"%a %b %d %Y %I:%M:%S %p %Z"
}

#Function to log output of script
Log(){
    #First argument is the text to log
    Text=$1
    #Second arugment is if to log to file or not
    FileLogThis=$2
    #Assign $FileLogThis to true if nothing is provided as the second arugment
    if [ -z "$FileLogThis" ] ; then
        FileLogThis=true
    fi
    #Only logs to a file if $CanFileLog is true and $FileLogThis is true
    if $CanFileLog && $FileLogThis; then
        printf "%s || %s\n" "$(timestamp)" "$Text" | tee -a $GitLogsLocation
    else
        printf "%s || %s\n" "$(timestamp)" "$Text"
    fi
}

#Funtion for checking if git is installed and where the script is run, required git to run and to run this script in a local git repository
GitCheck(){
    #Check if git is installed
    which git > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        Log "This script needs git to run, run it again when git is installed\n" false
        exit 1
    fi
    #Check if this is a local git repository
    git status > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        Log "This script was not run in a local git repository, run it again in a local git repository" false
        exit 1
    fi
}

#Funtion for root/admin permissions check, require admin permissions to run this script
PermissionsCheck(){
    if [ $UID != 0 ]; then
        Log "This script was not run with admin permissions, run it again with admin permissions"
        exit 1
    fi
}

#Run on script start up
Init(){
    GitCheck
    PermissionsCheck
    Log "Script execution started"
    Log "Logs are located at $GitLogsLocation"
}



#Main script

Init