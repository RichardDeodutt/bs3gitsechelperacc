#!/bin/bash

#Richard Deodutt
#08/15/2022
#This script is meant to securely and automatically create a git user and push changes to any branch but main, placing the git user in a GitAcc group, doing git add and commit while also handling sensitive personal information such as phone numbers or SSN before pushing.

GitLogsLocation='.git/.gitlogs'

#Default git user name, can be changed if desired
GitSecureUser='gituser'

#Default git account group name, can be changed if desired
GitSecureGroup='GitAcc'

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
    id -nG $MemberCheckGitUser 2> /dev/null | grep -w $MemberCheckGitGroup > /dev/null 2>&1
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

#Function to check if the current git repository is modified
GitModifiedCheck(){
    #The git status of the current working directory checking if the text contains 'modified:'
    git status 2> /dev/null | grep -w "modified:" > /dev/null 2>&1
    #return the exit status of grep, 0 is a match anything else is not
    return $?
}

#Function to get the filenames of the modified and new untracked files
GitGetModifiedNewFilenames(){
    #Print the list of modified files and new untracked files
    git ls-files -mo --exclude-standard
}

#Function to censor a specific phone number on a specific line in a speicific file
CensorPhoneNumber(){
    #First arugment is the phone number to censor
    CensorPhoneNumber=$1
    #Second argument is the file where it is in
    CensorPHFileName=$2
    #Third Argument is the line which the phone number is located
    CensorPHLineNumber=$3
    #Replace the phone number with this
    CensoredPHText=${CensorPhoneNumber//[0-9]/X}
    #Censor the phone number
    sed -i "${CensorPHLineNumber}s/$CensorPhoneNumber/$CensoredPHText/" $CensorPHFileName
    #Check if censor worked
    if [ $? -ne 0 ]; then
        #Censor failed
        Log "Block phone number '$CensorPhoneNumber' in file '$CensorPHFileName' failed"
        exit 1
    else
        #Censor worked
        Log "Block phone number '$CensorPhoneNumber' in file '$CensorPHFileName' successful"
    fi
}

#Scrub a file of phone numbers
ScrubPhoneNumbers(){
    #First arugment is the filename of the file to scrub for phone numbers
    ScrubPhoneNumbersFile=$1
    #Check for phone numbers, matches any 3 numbers with or without parentheses followed by any 3 numbers then any 4 numbers seperating the three parts with a hypen or space
    FoundPhoneNumbers="$(grep -w '\(\(([0-9]\{3\})\|[0-9]\{3\}\)[ -]\?\)\{2\}[0-9]\{4\}' $ScrubPhoneNumbersFile)"
    #Number of phone numbers found
    NumbPhoneNumbers=$(printf "%s\n" "$FoundPhoneNumbers" | wc -l)
    #Check if phone numbers were found in the file
    if [ -n "$FoundPhoneNumbers" ]; then
        #List out all the found phone numbers
        for ((j=1;j<=NumbPhoneNumbers;j++)); do
            #Current Phone number from the found phone number list for this run of the loop
            PhoneNumber=$(printf "%s\n" "$FoundPhoneNumbers" | sed -n "$j"p | sed 's/\r$//')
            #Log the phone number and where it was found
            Log "Found phone number '$PhoneNumber' in file '$ScrubPhoneNumbersFile'"
            #Ask the user if to block it by censoring it
            if PromptYN "Block phone number '$PhoneNumber' in file '$ScrubPhoneNumbersFile'?"; then
                #Block or censor the phone nummber if they want to do that
                CensorPhoneNumber "$PhoneNumber" "$ScrubPhoneNumbersFile" "$j"
            else
                #User did not want to block that phone number
                Log "You do not want to block phone number '$PhoneNumber' in file '$ScrubPhoneNumbersFile'"
            fi
        done
    fi
}

#Function to censor a specific SSN on a specific line in a speicific file
CensorSSN(){
    #First arugment is the SSN to censor
    CensorSSN=$1
    #Second argument is the file where it is in
    CensorSSNFileName=$2
    #Third Argument is the line which the SSN is located
    CensorSSNLineNumber=$3
    #Replace the SSN with this
    CensoredSSNText=${CensorSSN//[0-9]/X}
    #Censor the SSN
    sed -i "${CensorSSNLineNumber}s/$CensorSSN/$CensoredSSNText/" $CensorSSNFileName
    #Check if censor worked
    if [ $? -ne 0 ]; then
        #Censor failed
        Log "Block SSN '$CensorSSN' in file '$CensorSSNFileName' failed"
        exit 1
    else
        #Censor worked
        Log "Block SSN '$CensorSSN' in file '$CensorSSNFileName' successful"
    fi
}

#Scrub a file of SSNs
ScrubSSNs(){
    #First arugment is the filename of the file to scrub for SSNs
    ScrubSSNFile=$1
    #Check for SSNs, matches any 3 numbers followed by any 2 numbers then any 4 numbers seperating the three parts with a hypen or space
    #Further filter according to valid SSN rules no field should be equal to 0 and the first field can't be 666 or above 900
    FoundSSNs="$(grep -w "\([0-9]\{3\}\)[ -]\?\([0-9]\{2\}\)[ -]\?\([0-9]\{4\}\)" $ScrubSSNFile | awk -F ' |-' '$1!=0 && $1!=666 && $1<900 && $2!=0 && $3!=0 {print $0}')"
    #Number of SSNs found
    NumbSSNs=$(printf "%s\n" "$FoundSSNs" | wc -l)
    #Check if SSNs were found in the file
    if [ -n "$FoundSSNs" ]; then
        #List out all the found SSNs
        for ((k=1;k<=NumbSSNs;k++)); do
            #Current SSN from the found SSNs list for this run of the loop
            SSN=$(printf "%s\n" "$FoundSSNs" | sed -n "$k"p | sed 's/\r$//')
            #Log the SSN and where it was found
            Log "Found SSN '$SSN' in file '$ScrubSSNFile'"
            #Ask the user if to block it by censoring it
            if PromptYN "Block SSN '$SSN' in file '$ScrubSSNFile'?"; then
                #Block or censor the SSN if they want to do that
                CensorSSN "$SSN" "$ScrubSSNFile" "$k"
            else
                #User did not want to block that SSN
                Log "You do not want to block SSN '$SSN' in file '$ScrubSSNFile'"
            fi
        done
    fi
}

#Scrub a file of sensitive information
Scrub(){
    #First arugment is the filename of the file to scrub
    ScrubFile=$1
    #Scrub the file of phone numbers
    ScrubPhoneNumbers $ScrubFile
    #Scrub the file of SSNs
    ScrubSSNs $ScrubFile
}

#Function to check modified files for sensitive information
ScrubFiles(){
    #Tell the user what we are about to do
    Log "Scrubbing files of sensitive information"
    #Get the list of modified files and new untracked files
    Filenames=$(GitGetModifiedNewFilenames)
    #Number of modified and new untracked files
    NumbFiles=$(printf "%s\n" "$Filenames" | wc -l)
    #Go through all the modified files and new untracked files to scrub them using a for loop
    for ((i=1;i<=NumbFiles;i++)); do
        #Filename of the file for this run of the loop
        Filename=$(printf "%s\n" "$Filenames" | sed -n "$i"p | sed 's/\r$//')
        #Scrub the file using the filename to find it
        Scrub $Filename
    done
    Log "Scrubbed files of sensitive information"
}


GitOps(){
    GitModifiedCheck
    if [ $? -eq 0 ]; then
        ScrubFiles
    else
        Log "Nothing was changed in the current git repository"
    fi
}



#Add Changes with prompt FUNC

#Check if there are changes to commit FUNC

#Commit Changes with prompt FUNC

#Add and Commit Controller FUNC

#Test everything



#Main script

#Set up everything
#Init

GitOps