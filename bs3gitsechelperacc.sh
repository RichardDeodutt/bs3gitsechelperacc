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
    #First argument is the git user to check existence
    ExistCheckGitUser=$1
    #Check if user exists
    id -u $ExistCheckGitUser > /dev/null 2>&1
    #return the return value of the last command
    return $?
}

#Check if the git group exists
GitGroupExists(){
    #First argument is the git group to check existence
    ExistCheckGitGroup=$1
    #Check if the group exists
    id -g $ExistCheckGitGroup > /dev/null 2>&1
    #return the return value of the last command
    return $?
}

GitMembershipCheck(){
    #First argument is the gitusername for membership check
    MembershipCheckGitUser=$1
    #Second argument is the gitgroupname for membership check
    MembershipCheckGitGroup=$2
    #Check if the git user is a member of the git group
    id -nG $MemberCheckGitUser | grep -w $MemberCheckGitGroup > /dev/null 2>&1
    #return the return value of the last command
    return $?
}

#Funtion for root/admin permissions check, require admin permissions to run this script if it's needed
PermissionsCheck(){
    #First argument is the gitusername for permission check
    PermCheckGitUser=$1
    #Second argument is the gitgroupname for permission check
    PermCheckGitGroup=$2
    #Check if script is running with admin permissions
    if [ $UID != 0 ]; then
        #Not running with admin permissions
        #Check if git user and git group exists, if they do then admin permissions is not needed
        if GitUserExists $PermCheckGitUser && GitGroupExists $PermCheckGitGroup && GitMembershipCheck $PermCheckGitUser $PermCheckGitGroup; then
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
        if GitUserExists $PermCheckGitUser && GitGroupExists $PermCheckGitGroup; then
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
    #Second arugment is if to skip the prompt or not, empty means no skipping the prompt else pass a true or false to force that answer
    Skip=$2
    #If $Skip is not empty then skip based on if it is true or false
    if [ -n "$Skip" ]; then
        if Skip; then
            #If $Skip is true return 0 meaning Y(Yes)
            Log "Skipping prompt: '$Prompt Y/N?', selecting: Y"
            return 0
        else
            #if $Skip is false return 1 meaning N(No)
            Log "Skipping prompt: '$Prompt Y/N?', selecting: N"
            return 1
        fi
    fi
    #Prompt the user
    read -p "$(timestamp) || $Prompt Y/N? " Response
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
    #First arugment is the git username
    GitSecureUserName=$1
    #Second arugment is if to skip the prompt or not, empty means no skipping the prompt else pass a true or false to force that answer
    GitUserCheckSkip=$2
    #Check if user exists
    if ! GitUserExists $GitSecureUserName; then
        #The git user does not exist
        Log "Git secure user: '$GitSecureUserName' does not exist"
        #Prompt the user asking if to create the secure git user
        if PromptYN "Create git secure user: '$GitSecureUserName'" $GitUserCheckSkip; then
            #Create the git user
            GitCreateUser $GitSecureUserName
        else
            #Can't run script without a git user so exit
            Log "Git secure user: '$GitSecureUserName' is not set up can't continue, run it again when you are ready"
            exit 0
        fi
    else
        #Git user already exists
        Log "Git secure user: '$GitSecureUserName' is set up"
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
    #First argument is the git group
    GitSecureGroupName=$1
    #Second arugment is if to skip the prompt or not, empty means no skipping the prompt else pass a true or false to force that answer
    GitGroupCheckSkip=$2
    #Check if the group exists
    if ! GitGroupExists $GitSecureGroupName; then
        #The git group does not exist
        Log "Git secure group: '$GitSecureGroupName' does not exist"
        #Prompt the user asking if to create the secure git group
        if PromptYN "Create git secure group: '$GitSecureGroupName'" $GitGroupCheckSkip; then
            #Create the git group
            GitCreateGroup $GitSecureGroupName
        else
            #Can't run script without a git group so exit
            Log "Git secure group: '$GitSecureGroupName' is not set up can't continue, run it again when you are ready"
            exit 0
        fi
    else
        #Git group already exists
        Log "Git secure group: '$GitSecureGroupName' is set up"
    fi
}

#Function to add to the git group a git user
GitGroupAddUser(){
    #First argument is the git group
    MemberAddGitGroup=$1
    #Second arugment is the git user
    MemberAddGitUser=$2
    #Add to the git group the git user
    usermod -a -G $MemberCheckGitGroup $MemberCheckGitUser
    #Check if git group add failed
    if [ $? -ne 0 ]; then
        #Git group add failed so exit
        Log "Adding to git group: '$MemberAddGitGroup' git user: '$MemberAddGitUser' failed"
        exit 1
    else
        #Git group add worked
        Log "Adding to git group: '$MemberAddGitGroup' git user: '$MemberAddGitUser' successful"
    fi
}

#Function to check if the git user is a member of the git group and if not set it up
GitMemberCheck(){
    #First argument is the git user
    MemberCheckGitUser=$1
    #Second arugment is the git group
    MemberCheckGitGroup=$2
    #Third arugment is if to skip the prompt or not, empty means no skipping the prompt else pass a true or false to force that answer
    GitMemberCheckSkip=$3
    #Check if the git user is a member of the git group
    if ! GitMembershipCheck $MemberCheckGitUser $MemberCheckGitGroup; then
        #Git user is not a member of git group
        Log "git user: '$MemberCheckGitUser' is not a member of git group: '$MemberCheckGitGroup'"
        #Prompt the user asking if to add the git user to the git group
        if PromptYN "Add git secure user: '$MemberCheckGitUser' to git secure group: '$MemberCheckGitGroup'" $GitMemberCheckSkip; then
            #Add to the git group the git user
            GitGroupAddUser $MemberCheckGitGroup $MemberCheckGitUser
        else
            #Can't run script without the git user in the git group so exit
            Log "Git secure user: '$MemberCheckGitUser' is not in git secure group: '$MemberCheckGitGroup' can't continue, run it again when you are ready"
            exit 0
        fi
    else
        #Git user is a member of git group
        Log "git user: '$MemberCheckGitUser' is a member of git group: '$MemberCheckGitGroup'"
        return 0
    fi
}

#Setup everything related to the git user and git group
GitSetup(){
    #First argument is the git user
    SetupGitUser=$1
    #Second arugment is the git group
    SetupGitGroup=$2
    #Third arugment is if to skip the prompt or not, empty means no skipping the prompt else pass a true or false to force that answer
    GitSetupSkip=$3
    #Check the permission of this script
    PermissionsCheck $SetupGitUser $SetupGitGroup
    #Git user check and setup
    GitUserCheck $SetupGitUser $GitSetupSkip
    #Git group check and setup
    GitGroupCheck $SetupGitGroup $GitSetupSkip
    #Git group user membership check and setup
    GitMemberCheck $SetupGitUser $SetupGitGroup $GitSetupSkip
}

#Run on script start up to set everything up
Init(){
    #Check git is installed and the script is run in a git local repository
    GitCheck
    #Script inform user of starting script
    Log "Script execution started"
    #Script inform user of who is running the script
    Log "Executed as '$USER'"
    #Script inform user of where logs are located for the script
    Log "Logs are located at '$GitLogsLocation'"
    #Script setup everything related to git user and git group for the script, third argument for skiping the prompt is empty so it will prompt
    GitSetup $GitSecureUser $GitSecureGroup
}



#Check if there are changes to add FUNC

#Check if there is sensitive info in changes FUNC

#Do Stuff with sensitive info with prompt FUNC

#Add Changes with prompt FUNC

#Check if there are changes to commit FUNC

#Commit Changes with prompt FUNC

#Add and Commit Controller FUNC

#Test everything


#Main script

Init