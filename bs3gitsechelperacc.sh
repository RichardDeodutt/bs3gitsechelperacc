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
    #Two different date and time styles
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
    if [ -z "$FileLogThis" ]; then
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

#Check if the git user exists
GitUserExists(){
    #Check if user exists
    id -u $GitSecureUser > /dev/null 2>&1
    #return the return value of the last command
    return $?
}

#Check if the git group exists
GitGroupExists(){
    #Check if the group exists
    id -g $GitSecureGroup > /dev/null 2>&1
    #return the return value of the last command
    return $?
}

#Funtion for root/admin permissions check, require admin permissions to run this script if it's needed
PermissionsCheck(){
    #Check if script is running with admin permissions
    if [ $UID != 0 ]; then
        #Not running with admin permissions
        #Check if git user and git group exists, if they do then admin permissions is not needed
        if GitUserExists && GitGroupExists; then
            #No need for admin permissions as it is not needed now
            Log "This script was not run with admin permissions, but it is not need now"
            return 0
        else
            #Need admin permissions to create a user or group so exit if it does not have it but needs it
            Log "This script was not run with admin permissions, but it is needed so run it again with admin permissions"
            exit 1
        fi
    else
        #Running with admin permissions
        #Check if git user and git group exists, if they do then admin permissions is not needed
        if GitUserExists && GitGroupExists; then
            #No need for admin permissions as it is not needed now
            Log "This script was run with admin permissions, but it is not need now"
            return 0
        else
            #Need admin permissions to create a user or group so exit if it does not have it but needs it
            Log "This script was run with admin permissions, but it is needed now"
            return 0
        fi
    fi
}

#Prompts the user with a choice of Y(Yes) or N(No), anything else defaults to N(No)
PromptYN(){
    #First argument is the prompt
    Prompt=$1
    #Prompt the user
    read -p "$Prompt" Response
    #Lowercase the response and get the first character only
    Response=$(printf "%s" $Response | tr [:upper:] [:lower:] | cut -c 1)
    #if response is 'y' a yes then return true else assume 'n' a no then return false
    if [[ $Response == 'y' ]]; then
        #Response was a yes so return 0 meaning true
        return 0
    elif [[ $Response == 'n' ]]; then
        #Response was a no so return 1 meaning false
        return 1
    else
        #Response was not understood so assume no and return 1 meaning false
        Log "Did not understand that assuming no"
        return 1
    fi
}

#Function to create the git user
GitCreateUser(){
    #First arugment is the git username
    GitUserName=$1
    #Creating user with no home folder
    useradd $GitUserName
    #Check if git user creation failed
    if [ $? -ne 0 ]; then
        #Git user creation failed so exit
        Log "Creating git user: $GitUserName failed"
        exit 1
    else
        #Git user creation worked
        Log "Creating git user: $GitUserName successful"
    fi
}

#Function to check if the git user is set up and if not set it up
GitUserCheck(){
    #Check if user exists
    if ! GitUserExists; then
        #The git user does not exist
        Log "Git secure user: '$GitSecureUser' does not exist"
        #Prompt the user asking if to create the secure git user
        if PromptYN "$(timestamp) || Create git secure user: '$GitSecureUser' Y/N? "; then
            #Create the git user
            GitCreateUser $GitSecureUser
        else
            #Can't run script without a git user so exit
            Log "Git secure user: '$GitSecureUser' is not set up can't continue, run it again when you are ready"
            exit 0
        fi
    else
        #Git user already exists
        Log "Git secure user: '$GitSecureUser' is set up"
    fi
}

#Function to create the git group
GitCreateGroup(){
    #First arugment is the git groupname
    GitGroupName=$1
    #Creating group
    groupadd $GitGroupName
    #Check if git group creation failed
    if [ $? -ne 0 ]; then
        #Git group creation failed so exit
        Log "Creating git group: $GitGroupName failed"
        exit 1
    else
        #Git group creation worked
        Log "Creating git group: $GitGroupName successful"
    fi
}

#Function to check if the git group is set up and if not set it up
GitGroupCheck(){
    #Check if the group exists
    if ! GitGroupExists; then
        #The git group does not exist
        Log "Git secure group: '$GitSecureGroup' does not exist"
        #Prompt the user asking if to create the secure git group
        if PromptYN "$(timestamp) || Create git secure group: '$GitSecureGroup' Y/N? "; then
            #Create the git group
            GitCreateGroup $GitSecureGroup
        else
            #Can't run script without a git group so exit
            Log "Git secure group: '$GitSecureGroup' is not set up can't continue, run it again when you are ready"
            exit 0
        fi
    else
        #Git group already exists
        Log "Git secure group: '$GitSecureGroup' is set up"
    fi
}

#Run on script start up
Init(){
    GitCheck
    Log "Script execution started"
    Log "Executed as '$USER'"
    Log "Logs are located at '$GitLogsLocation'"
    PermissionsCheck
    GitUserCheck
    GitGroupCheck
}

#Add User to Group FUNC

#Setup User and Group FUNC

#^ Should be in Init

#Check if there are changes to add FUNC

#Check if there is sensitive info in changes FUNC

#Do Stuff with sensitive info with prompt FUNC

#Add Changes with prompt FUNC

#Check if there are changes to commit FUNC

#Commit Changes with prompt FUNC

#Add and Commit Controller FUNC

#Main script

Init