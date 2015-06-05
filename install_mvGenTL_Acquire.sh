#!/bin/bash
DEF_DIRECTORY=/opt/mvIMPACT_acquire
PRODUCT=mvGenTL-Acquire
API=mvIMPACT_acquire
TARNAME=mvGenTL_Acquire
ABI_POSTFIX=_ABI2
LINK=mvimpact-acquire
GEV_SUPPORT=unknown
U3V_SUPPORT=unknown
USE_DEFAULTS=NO
APT_GET_EXTRA_PARAMS=

# Define the users real name if possible, to prevent accidental mvIA root ownership if script is invoked with sudo
if [ "$(which logname)" == "" ] ; then
    USER=$(whoami)
else
    if [ "$(logname 2>&1)" == "logname: no login name" ] ; then
        USER=$(whoami)
    else
        USER=$(logname)
    fi
fi

function createSoftlink {
    if [ ! -e "$1/$2" ]; then
        echo "Error: File "$1/$2" does not exist, softlink cannot be created! "
        exit 1
    fi
    if ! [ -L "$1/$3" ]; then
        ln -fs $2 "$1/$3" >/dev/null 2>&1
        if ! [ -L "$1/$3" ]; then
            sudo ln -fs $2 "$1/$3" >/dev/null 2>&1
            if ! [ -L "$1/$3" ]; then
                echo "Error: Could not create softlink $1/$3, even with sudo!"
                exit 1
            fi
        fi
    fi
}

# Print out ASCII-Art Logo.
clear;
echo ""
echo ""
echo ""
echo ""
echo "                                ===     ===    .MMMO                             "
echo "                                 ==+    ==     M         ,MMM   ?M MM,           "
echo "                                 .==   .=+     M  MMM   M    M   M   M           "
echo "                                  ==+  ==.     M    M   M ^^^    M   M           "
echo "             ..                   .== ,==       MMMM    'MMMM    M   M           "
echo "   MMMM   DMMMMMM      MMMMMM      =====                                         "
echo "   MMMM MMMMMMMMMMM :MMMMMMMMMM     ====          MMMMMMMMMMMM   MMM             "
echo "   MMMMMMMMMMMMMMMMMMMMMMMMMMMMM                 MMMMMMMMMMMM   MMM              "
echo "   MMMMMMM   .MMMMMMMM    MMMMMM                     MMM       MMM               "
echo "   MMMMM.      MMMMMM      MMMMM                    MM7       MMM                "
echo "   MMMMM       MMMMM       MMMMM                   MMM       IMM                 "
echo "   MMMMM       MMMMM       MMMMM                  MMM       MMMMMMMMMM           "
echo "   MMMMM       MMMMM       MMMMM                                                 "
echo "   MMMMM       MMMMM       MMMMM       M     MMM    MM    M   M  MMM  MMMM   MMMM"
echo "   MMMMM       MMMMM       MMMMM      M M   M   M  M   M  M   M   M   M   M  M   "
echo "   MMMMM       MMMMM       MMMMM     M   M  M      M   M  M   M   M   MMM,   MMM "
echo "   MMMMM       MMMMM       MMMMM     MMMMM  M   M  M  ,M  M   M   M   M   M  M   "
echo "                                     M   M  'MMM'   MMMM, 'MMM'  MMM  M   M  MMMM"
echo "==================================================================================" 
sleep 1

# Analyze the command line arguments and react accordingly
PATH_EXPECTED=NO
SHOW_HELP=NO
while [[ $# > 0 ]] ; do
  if [ "$1" == "-h" ] || [ "$1" == "--help" ] ; then
    SHOW_HELP=YES
    break
  elif [[ ( "$1" == "-u" || "$1" == "--unattended" ) && "$PATH_EXPECTED" == "NO" ]] ; then
    USE_DEFAULTS=YES
  elif [[ ( "$1" == "-p" || "$1" == "--path" ) && "$PATH_EXPECTED" == "NO" ]] ; then
    if [ "$2" == "" ] ; then
      echo
      echo "WARNING: Path option used with no defined path, will use: $DEF_DIRECTORY directory"
      echo
      SHOW_HELP=YES
      break
    else
      PATH_EXPECTED=YES
    fi
  elif [ "$PATH_EXPECTED" == "YES" ] ; then
    DEF_DIRECTORY=$1
    PATH_EXPECTED=NO
  else
    echo 'Please check your syntax and try again!'
    SHOW_HELP=YES
  fi
  shift
done
if [ "$SHOW_HELP" == "YES" ] ; then
  echo
  echo 'Installation script for the '$PRODUCT' driver.'
  echo
  echo "Default installation path: "$DEF_DIRECTORY
  echo "Usage:                     ./install_mvGenTL_Acquire.sh [OPTION] ... "
  echo "Example:                   ./install_mvGenTL_Acquire.sh -p /myPath -u"
  echo
  echo "Arguments:"
  echo "-h --help                  Display this help."
  echo "-p --path                  Set the directory where the files shall be installed."
  echo "-u --unattended            Unattended installation with default settings."
  echo
  exit 1
fi
if [ "$USE_DEFAULTS" == "YES" ] ; then
  echo
  echo "Unattended installation requested, no user interaction will be required and the"
  echo "default settings will be used."
  echo
fi


# Get the targets plattform and if it is called "i686" we know it is a x86 system, else it s x86_64
TARGET=$(uname -m)
if [ "$TARGET" == "i686" ]; then
   TARGET="x86"
fi

# Get the sourcedir (the directory where the files for the installation are) and cd to it
# (The script file must be in the same directory as the source TGZ) !!!
if which dirname >/dev/null; then
    SCRIPTSOURCEDIR=($PWD"/"$(dirname $0))
fi
if [ "$SCRIPTSOURCEDIR" != "$PWD" ]; then
   if [ -z $SCRIPTSOURCEDIR ] || [ "$SCRIPTSOURCEDIR" == "." ]; then
      SCRIPTSOURCEDIR=$PWD
   fi
   cd $SCRIPTSOURCEDIR
fi

# Set variables for GenICam and mvIMPACT_acquire for later use
if grep -q '/etc/ld.so.conf.d/' /etc/ld.so.conf; then
   GENICAM_LDSOCONF_FILE=/etc/ld.so.conf.d/genicam.conf
   ACQUIRE_LDSOCONF_FILE=/etc/ld.so.conf.d/acquire.conf
else
   GENICAM_LDSOCONF_FILE=/etc/ld.so.conf
   ACQUIRE_LDSOCONF_FILE=/etc/ld.so.conf
fi

# Make sure the environment variables are set at the next boot as well
if grep -q '/etc/profile.d/' /etc/profile; then
   GENICAM_EXPORT_FILE=/etc/profile.d/genicam.sh
   ACQUIRE_EXPORT_FILE=/etc/profile.d/acquire.sh
else
   GENICAM_EXPORT_FILE=/etc/profile
   ACQUIRE_EXPORT_FILE=/etc/profile
fi

# Get driver name, version, file
if [ "$( ls | grep -c 'mvGenTL_Acquire.*\.tgz' )" != "0" ] ; then
  TARNAME=`ls mvGenTL_Acquire*.tgz | tail -n 1 | sed -e s/\\.tgz//`
  TARFILE=`ls mvGenTL_Acquire*.tgz | tail -n 1`
  VERSION=`ls mvGenTL_Acquire*.tgz | tail -n 1 | sed -e s/\\mvGenTL_Acquire// | sed -e s/\\-$TARGET// | sed -e s/\\_ABI2-// | sed -e s/\\.tgz//` 
  ACT2=$API-$VERSION
  ACT=$API-$TARGET-$VERSION
fi

# Check if tarfile is correct for the system architecture
if [ "$TARGET" == "x86_64"  ]; then
  if [ "`echo $TARNAME | grep -c x86_ABI2`" != "0" ]; then
    echo "-----------------------------------------------------------------------------------"
    echo "  ABORTING: Attempt to install 32-bit drivers in a 64-bit machine!  " 
    echo "-----------------------------------------------------------------------------------"
    exit
  fi
fi
if [ "$TARGET" == "x86" ]; then
  if [ "`echo $TARNAME | grep -c x86_64_ABI2`" != "0" ]; then
    echo "-----------------------------------------------------------------------------------"
    echo "  ABORTING: Attempt to install 64-bit drivers in a 32-bit machine!  " 
    echo "-----------------------------------------------------------------------------------"
    exit
  fi
fi

# A quick check whether the Version has a correct format (due to other files being in the same directory..?)
if [ "$(echo $VERSION | grep -c '^[0-9]\{1,2\}\.[0-9]\{1,2\}\.[0-9]\{1,2\}')" == "0" ]; then
  echo "-----------------------------------------------------------------------------------"
  echo "  ABORTING: Script could not determine a valid mvIMPACT Acquire *.tgz file!  " 
  echo "-----------------------------------------------------------------------------------"
  echo "  This script could not extract a valid version number from the *.tgz file"
  echo "  This script determined $TARFILE as the file containing the installation data."
  echo "  It is recommended that only this script and the correct *.tgz file reside in this directory."
  echo "  Please remove all other files and try again."
  exit
fi

# A quick check whether the user has been determined
if [ "$USER" == "" ]; then
  echo "-----------------------------------------------------------------------------------"
  echo "  ABORTING: Script could not determine a valid user!  " 
  echo "-----------------------------------------------------------------------------------"
  echo "  This script could not determin the user of this shell"
  echo "  Please make sure this is a valid login shell!"
  exit
fi

YES_NO=
# Ask whether to use the defaults or proceed with an interactive installation
if [ "$USE_DEFAULTS" == "NO" ] ; then
  echo
  echo "Would you like this installation to run in unattended mode?"
  echo "No user interaction will be required, and the default settings will be used!"
  echo "Hit 'n' + <Enter> for 'no', or just <Enter> for 'yes'."
  read YES_NO
else
  YES_NO=""
fi
if [ "$YES_NO" == "n" ] || [ "$YES_NO" == "N" ]; then
  USE_DEFAULTS=NO
else
  USE_DEFAULTS=YES
fi

# Here we will ask the user if we shall start the installation process
echo
echo   "-----------------------------------------------------------------------------------"
echo   "Configuration:"
echo   "-----------------------------------------------------------------------------------"
echo
echo   "Installation for user:          "$USER
echo   "Installation directory:         "$DEF_DIRECTORY
echo   "Source directory:               "$(echo $SCRIPTSOURCEDIR | sed -e 's/\/\.//')
echo   "Version:                        "$VERSION
echo   "Platform:                       "$TARGET
echo   "TAR-File:                       "$TARFILE
echo
echo   "ldconfig:"
echo   "GenICam:                        "$GENICAM_LDSOCONF_FILE
echo   "mvIMPACT_acquire:               "$ACQUIRE_LDSOCONF_FILE
echo
echo   "Exports:"
echo   "GenICam:                        "$GENICAM_EXPORT_FILE
echo   "mvIMPACT_acquire:               "$ACQUIRE_EXPORT_FILE
echo 
echo   "-----------------------------------------------------------------------------------"
echo
echo "Do you want to continue (default is 'yes')?"
echo "Hit 'n' + <Enter> for 'no', or just <Enter> for 'yes'."
if [ "$USE_DEFAULTS" == "NO" ] ; then
  read YES_NO
else
  YES_NO=""
fi

# If the user is choosing no, we will abort the installation, else we will start the process.
if [ "$YES_NO" == "n" ] || [ "$YES_NO" == "N" ]; then
  echo "Quit!"
  exit
fi
 
 # First of all ask whether to dispose of the old mvIMPACT Acquire installation
if [ "$MVIMPACT_ACQUIRE_DIR" != "" ]; then
  echo "Do you want to keep previous installation (default is 'yes')?"
  echo "If you select no, mvIMPACT Acquire will be removed for ALL installed Products!"
  echo "Hit 'n' + <Enter> for 'no', or just <Enter> for 'yes'."
if [ "$USE_DEFAULTS" == "NO" ] ; then
  read YES_NO
else
  YES_NO=""
fi
  if [ "$YES_NO" == "n" ] || [ "$YES_NO" == "N" ]; then
    sudo rm -f /usr/bin/mvDeviceConfigure
    sudo rm -f /usr/bin/mvIPConfigure
    sudo rm -f /usr/bin/wxPropView
    sudo rm -rf $MVIMPACT_ACQUIRE_DIR
    if [ $? == 0 ]; then
      echo "Previous mvIMPACT Acquire Installation ($MVIMPACT_ACQUIRE_DIR) removed successfully!"
    else
      echo "Error removing previous mvIMPACT Acquire Installation ($MVIMPACT_ACQUIRE_DIR)!"
      echo "$?"
    fi
  else
    echo "Previous mvIMPACT Acquire Installation ($MVIMPACT_ACQUIRE_DIR) NOT removed!"
  fi
fi
 
 # Determine whether mvGenTL_Acquire should support GEV, U3V or both device types on this system
echo ""
echo "Should mvGenTL_Acquire support GEV devices, such as mvBlueCOUGAR (default is 'yes')?"
echo "Hit 'n' + <Enter> for 'no', or just <Enter> for 'yes'."
if [ "$USE_DEFAULTS" == "NO" ] ; then
  read YES_NO
else
  YES_NO=""
fi
if [ "$YES_NO" == "n" ] || [ "$YES_NO" == "N" ]; then
    GEV_SUPPORT=FALSE
else
    GEV_SUPPORT=TRUE
fi
echo ""
echo "Should mvGenTL_Acquire support U3V devices, such as mvBlueFOX3 (default is 'yes')?"
echo "Hit 'n' + <Enter> for 'no', or just <Enter> for 'yes'."
if [ "$USE_DEFAULTS" == "NO" ] ; then
  read YES_NO
else
  YES_NO=""
fi
if [ "$YES_NO" == "n" ] || [ "$YES_NO" == "N" ]; then
    U3V_SUPPORT=FALSE
else
    U3V_SUPPORT=TRUE
fi
 
# Create the *.conf files if the system is supporting ld.so.conf.d
if grep -q '/etc/ld.so.conf.d/' /etc/ld.so.conf; then
  sudo rm -f $GENICAM_LDSOCONF_FILE; sudo touch $GENICAM_LDSOCONF_FILE
  sudo rm -f $ACQUIRE_LDSOCONF_FILE; sudo touch $ACQUIRE_LDSOCONF_FILE
fi

# Create the export files if the system is supporting profile.d
if grep -q '/etc/profile.d/' /etc/profile; then
  sudo rm -f $GENICAM_EXPORT_FILE; sudo touch $GENICAM_EXPORT_FILE
  sudo rm -f $ACQUIRE_EXPORT_FILE; sudo touch $ACQUIRE_EXPORT_FILE
fi

# Check if the destination directory exist, else create it
if ! [ -d $DEF_DIRECTORY ]; then
  # the destination directory does not yet exist
  # first try to create it as a normal user
  mkdir -p $DEF_DIRECTORY >/dev/null 2>&1
  if ! [ -d $DEF_DIRECTORY ]; then
    # that didn't work
    # now try it as superuser
    sudo mkdir -p $DEF_DIRECTORY
  fi
  if ! [ -d $DEF_DIRECTORY  ]; then
    echo 'ERROR: Could not create target directory' $DEF_DIRECTORY '.'
    echo 'Problem:'$?
    echo 'Maybe you specified a partition that was mounted read only?'
    echo
    exit
  fi
else
  echo 'Installation directory already exists.'
fi

# in case the directory already existed BUT it belongs to other user
sudo chown -R $USER:$USER $DEF_DIRECTORY

# Check the actual tarfile
if ! [ -r $TARFILE ]; then
  echo 'ERROR: could not read' $TARFILE.
  echo
  exit
fi

# needed at compile time (used during development, but not shipped with the final program)
ACT=$API-$VERSION.tar

# needed at run time
BC=mvGenTL_Acquire_runtime
BCT=$BC-$VERSION.tar

# Now unpack the tarfile into /tmp
cd /tmp
tar xfz $SCRIPTSOURCEDIR/$TARFILE

# Change to destination directory and remove older libs if any
cd $DEF_DIRECTORY
if ! [ -d $DEF_DIRECTORY/runtime ]; then
  mkdir runtime
  if ! [ -d $DEF_DIRECTORY/runtime ]; then
      # that didn't work
      # now try it as superuser
      sudo mkdir --parent $DEF_DIRECTORY/runtime
  fi
fi
cd runtime
# remove older versions (if any)
sudo rm -f lib/libmv*.so*

# Now unpack the mvBlueCOUGAR_runtime files
sudo tar xf /tmp/$BCT

# the runtime tar contains either the i86 or the x64 tgz
if [ -r GenICam_Runtime_gcc40_Linux32_i86_v*.tgz ]; then
   sudo tar xfz GenICam_Runtime_gcc40_Linux32_i86_v*.tgz;
   if [ x$TARGET != xx86 ]; then
      echo 'Platform conflict : GenICam runtime is 32bit, but target is 64bit'
   fi
fi
if [ -r GenICam_Runtime_gcc40_Linux64_x64_v*.tgz ]; then
   sudo tar xfz GenICam_Runtime_gcc40_Linux64_x64_v*.tgz;
   if [ x$TARGET = xx86 ]; then
      echo 'Platform conflict : GenICam runtime is 64bit, but target is 32bit'
   fi
fi

sudo chown -R $USER:$USER xml log licenses bin License_ReadMe.txt

if [ x$TARGET == xx86 ]; then
   GENVER=`echo GenICam_Runtime_gcc40_Linux32_i86_v*.tgz | sed -e s/GenICam_Runtime_gcc40_Linux32_i86_v// | sed -e s/\\.tgz// | sed -e 's/.\{2\}$//'`
else
   GENVER=`echo GenICam_Runtime_gcc40_Linux64_x64_v*.tgz | sed -e s/GenICam_Runtime_gcc40_Linux64_x64_v// | sed -e s/\\.tgz// | sed -e 's/.\{2\}$//'`
fi

if ! [ -r $GENICAM_EXPORT_FILE ]; then
   echo 'Error : cannot write to' $GENICAM_EXPORT_FILE.
   echo 'After the next boot, the required environment variables will not be set.'
   echo
else
   # tests below do not yet check for *commented out* export lines
   if grep -q 'GENICAM_ROOT=' $GENICAM_EXPORT_FILE; then
      echo 'GENICAM_ROOT already defined in' $GENICAM_EXPORT_FILE.
   else
      sudo sh -c "echo 'export GENICAM_ROOT=$DEF_DIRECTORY/runtime' >> $GENICAM_EXPORT_FILE"
   fi
   if grep -q 'GENICAM_ROOT_V$GENVER=' $GENICAM_EXPORT_FILE; then
      echo 'GENICAM_ROOT_V'$GENVER' already defined in' $GENICAM_EXPORT_FILE.
   else
      sudo sh -c "echo 'export GENICAM_ROOT_V$GENVER=$DEF_DIRECTORY/runtime' >> $GENICAM_EXPORT_FILE"
   fi
   if [ x$TARGET = xx86 ]; then
      if grep -q 'GENICAM_GENTL32_PATH=' $GENICAM_EXPORT_FILE; then
         echo 'GENICAM_GENTL32_PATH already defined in' $GENICAM_EXPORT_FILE.
      else
         sudo sh -c "echo 'if [ x\$GENICAM_GENTL32_PATH == x ]; then
   export GENICAM_GENTL32_PATH=$DEF_DIRECTORY/lib/$TARGET
elif [ x\$GENICAM_GENTL32_PATH != x$DEF_DIRECTORY/lib/$TARGET ]; then
   if ! \$(echo \$GENICAM_GENTL32_PATH | grep -q \":$DEF_DIRECTORY/lib/$TARGET\"); then
      export GENICAM_GENTL32_PATH=\$GENICAM_GENTL32_PATH:$DEF_DIRECTORY/lib/$TARGET
   fi
fi' >> $GENICAM_EXPORT_FILE"
      fi
   else
      if grep -q 'GENICAM_GENTL64_PATH=' $GENICAM_EXPORT_FILE; then
         echo 'GENICAM_GENTL64_PATH already defined in' $GENICAM_EXPORT_FILE.
      else
         sudo sh -c "echo 'if [ x\$GENICAM_GENTL64_PATH == x ]; then
   export GENICAM_GENTL64_PATH=$DEF_DIRECTORY/lib/$TARGET
elif [ x\$GENICAM_GENTL64_PATH != x$DEF_DIRECTORY/lib/$TARGET ]; then
   if ! \$(echo \$GENICAM_GENTL64_PATH | grep -q \":$DEF_DIRECTORY/lib/$TARGET\"); then
      export GENICAM_GENTL64_PATH=\$GENICAM_GENTL64_PATH:$DEF_DIRECTORY/lib/$TARGET
   fi
fi' >> $GENICAM_EXPORT_FILE"
      fi
   fi
# Since mvImpact Acquire version 2.7.0, version 2.4 of the GenICam cache should be able to coexist with
# version 2.3, however they must point to different folders!
   if grep -q 'GENICAM_CACHE_V2_3=' $GENICAM_EXPORT_FILE; then
      echo 'GENICAM_CACHE_V2_3 already defined in' $GENICAM_EXPORT_FILE.
   fi
   if grep -q 'GENICAM_CACHE_V2_4=' $GENICAM_EXPORT_FILE; then
      echo 'GENICAM_CACHE_V2_4 already defined in' $GENICAM_EXPORT_FILE.
   else
      sudo mkdir -p $DEF_DIRECTORY/runtime/cache/v2_4
      sudo sh -c "echo 'export GENICAM_CACHE_V2_4='$DEF_DIRECTORY'/runtime/cache/v2_4' >> $GENICAM_EXPORT_FILE"
   fi
   if grep -q 'GENICAM_LOG_CONFIG_V'$GENVER'=' $GENICAM_EXPORT_FILE; then
      echo 'GENICAM_LOG_CONFIG_V'$GENVER' already defined in' $GENICAM_EXPORT_FILE.
   else
      sudo sh -c "echo 'export GENICAM_LOG_CONFIG_V'$GENVER'=$DEF_DIRECTORY/runtime/log/config-unix/DefaultLogging.properties' >> $GENICAM_EXPORT_FILE"
   fi
fi

# Now check if we can unpack the tar file with the device independent stuff
# this is entirely optional
if [ -r /tmp/$ACT ]; then
   cd /tmp
   tar xf /tmp/$ACT
   sudo cp -r $ACT2/* $DEF_DIRECTORY
else
  echo
  echo "ERROR: Could not read: /tmp/"$ACT2
  exit
fi

#Set the necessary exports and library paths
cd $DEF_DIRECTORY
if grep -q 'MVIMPACT_ACQUIRE_DIR=' $ACQUIRE_EXPORT_FILE; then
   echo 'MVIMPACT_ACQUIRE_DIR already defined in' $ACQUIRE_EXPORT_FILE.
else
   sudo sh -c "echo 'export MVIMPACT_ACQUIRE_DIR=$DEF_DIRECTORY' >> $ACQUIRE_EXPORT_FILE"
fi

if grep -q "$DEF_DIRECTORY/lib/$TARGET" $ACQUIRE_LDSOCONF_FILE; then
   echo "$DEF_DIRECTORY/lib/$TARGET already defined in" $ACQUIRE_LDSOCONF_FILE.
else
   sudo sh -c "echo '$DEF_DIRECTORY/lib/$TARGET' >> $ACQUIRE_LDSOCONF_FILE"
fi
if grep -q "$DEF_DIRECTORY/Toolkits/expat/bin/$TARGET/lib" $ACQUIRE_LDSOCONF_FILE; then
   echo "$DEF_DIRECTORY/Toolkits/expat/bin/$TARGET/lib already defined in" $ACQUIRE_LDSOCONF_FILE.
else
   sudo sh -c "echo '$DEF_DIRECTORY/Toolkits/expat/bin/$TARGET/lib' >> $ACQUIRE_LDSOCONF_FILE"
fi
if grep -q "$DEF_DIRECTORY/Toolkits/libudev/bin/$TARGET/lib" $ACQUIRE_LDSOCONF_FILE; then
   echo "$DEF_DIRECTORY/Toolkits/libudev/bin/$TARGET/lib already defined in" $ACQUIRE_LDSOCONF_FILE.
else
   sudo sh -c "echo '$DEF_DIRECTORY/Toolkits/libudev/bin/$TARGET/lib' >> $ACQUIRE_LDSOCONF_FILE"
fi

# now do the shared linker setup
if ! [ -r $GENICAM_LDSOCONF_FILE ]; then
   echo 'Error : cannot write to' $GENICAM_LDSOCONF_FILE.
   echo 'Execution will fail, as at run time, the shared objects will not be found.'
   echo
else
   if [ x$TARGET = xx86 ]; then
      GENILIBPATH=Linux32_i86
   else
      GENILIBPATH=Linux64_x64
   fi
   # tests below do not check for *commented out* link lines
   # must later add substring check
   # genicam libs
   if grep -q "$DEF_DIRECTORY/runtime/bin/$GENILIBPATH" $GENICAM_LDSOCONF_FILE; then
      echo "$DEF_DIRECTORY/runtime/bin/$GENILIBPATH already defined in" $GENICAM_LDSOCONF_FILE.
   else
      sudo sh -c "echo '$DEF_DIRECTORY/runtime/bin/$GENILIBPATH' >> $GENICAM_LDSOCONF_FILE"
   fi
   if grep -q "$DEF_DIRECTORY/runtime/bin/$GENILIBPATH/GenApi/Generic" $GENICAM_LDSOCONF_FILE; then
      echo "$DEF_DIRECTORY/runtime/bin/$GENILIBPATH/GenApi/Generic already defined in" $GENICAM_LDSOCONF_FILE.
   else
      sudo sh -c "echo '$DEF_DIRECTORY/runtime/bin/$GENILIBPATH/GenApi/Generic' >> $GENICAM_LDSOCONF_FILE"
   fi
fi

# This variable must be exported, or else wxPropView-related make problems can arise (wxPropGrid cannot be found)
export MVIMPACT_ACQUIRE_DIR=$DEF_DIRECTORY

# Set the libs to ldconfig
sudo /sbin/ldconfig

#Move all the mvImpact Acquire related libraries to the mvIA/lib folder.
if [ -r /tmp/$ACT ]; then
   cd $DEF_DIRECTORY/lib/$TARGET
   sudo mv $DEF_DIRECTORY/runtime/lib/* .
   sudo rmdir $DEF_DIRECTORY/runtime/lib
fi

# Clen up /tmp
rm -r -f /tmp/$ACT /tmp/$BCT /tmp/$API-$VERSION

#create softlinks for the Toolkits libraries
createSoftlink $DEF_DIRECTORY/Toolkits/expat/bin/$TARGET/lib libexpat.so.0.5.0 libexpat.so.0
createSoftlink $DEF_DIRECTORY/Toolkits/expat/bin/$TARGET/lib libexpat.so.0 libexpat.so
createSoftlink $DEF_DIRECTORY/Toolkits/libusb-1.0.19/bin/$TARGET/lib libusb-1.0.so.0.1.0  libusb-1.0.so.0
createSoftlink $DEF_DIRECTORY/Toolkits/libusb-1.0.19/bin/$TARGET/lib libusb-1.0.so.0  libusb-1.0.so
createSoftlink $DEF_DIRECTORY/Toolkits/libudev/bin/$TARGET/lib libudev.so.0.13.0 libudev.so.0
createSoftlink $DEF_DIRECTORY/Toolkits/libudev/bin/$TARGET/lib libudev.so.0 libudev.so

# apt-get extra parameters
if [ "$USE_DEFAULTS" == "YES" ] ; then
  APT_GET_EXTRA_PARAMS=" -y "
fi

# install needed libraries and compiler
COULD_NOT_INSTALL="Could not find apt-get or yast; please install >%s< manually."

# check if we have g++
if ! which g++ >/dev/null 2>&1; then
   if which apt-get >/dev/null 2>&1; then
      sudo apt-get $APT_GET_EXTRA_PARAMS -q install g++
   elif sudo which yast >/dev/null 2>&1; then
      YASTBIN=`sudo which yast`
      sudo $YASTBIN --install gcc-c++
   else
      printf "$COULD_NOT_INSTALL" "g++"
   fi
fi

INPUT_REQUEST="Do you want to install >%s< (default is 'yes')?\nHit 'n' + <Enter> for 'no', or just <Enter> for 'yes'.\n"
YES_NO=

# do we want to install wxWidgets?
if ! which wx-config >/dev/null 2>&1; then
   echo
   printf "$INPUT_REQUEST" "wxWidgets"
   echo "This is highly recommended, as without wxWidgets, you cannot build wxPropView."
   echo
   if [ "$USE_DEFAULTS" == "NO" ] ; then
     read YES_NO
   else
     YES_NO=""
   fi
   if [ "$YES_NO" == "n" ] || [ "$YES_NO" == "N" ]; then
      echo 'Not installing wxWidgets'
   else
      if which apt-get >/dev/null 2>&1; then
         echo 'Installing wxWidgets'
         sudo apt-get $APT_GET_EXTRA_PARAMS -q install libwxgtk2.8-dev libwxbase2.8-0 libwxbase2.8-dev libwxgtk2.8-0 wx2.8-headers build-essential libgtk2.0-dev
      elif sudo which yast >/dev/null 2>&1; then
         echo 'Installing wxWidgets'
         YASTBIN=`sudo which yast`
         sudo $YASTBIN --install wxGTK-devel
      else
         printf "$COULD_NOT_INSTALL" "wxWidgets"
      fi
   fi
fi

# do we want to install FLTK?
if ! which fltk-config >/dev/null 2>&1; then
   echo
   printf "$INPUT_REQUEST" "FLTK"
   echo "This is only required if you want to build the 'LiveSnapFLTK' sample."
   echo
   if [ "$USE_DEFAULTS" == "NO" ] ; then
     read YES_NO
   else
     YES_NO=""
   fi
   if [ "$YES_NO" == "n" ] || [ "$YES_NO" == "N" ]; then
      echo 'Not installing FLTK'
   else
      if which apt-get >/dev/null 2>&1; then
         echo 'Installing FLTK'
         sudo apt-get $APT_GET_EXTRA_PARAMS -q install libgl1-mesa-dev
         sudo apt-get $APT_GET_EXTRA_PARAMS -q install libfltk1.1-dev
      elif sudo which yast >/dev/null 2>&1; then
         echo 'Installing FLTK'
         YASTBIN=`sudo which yast`
         sudo $YASTBIN --install Mesa-devel
         sudo $YASTBIN --install fltk-devel
      else
         printf "$COULD_NOT_INSTALL" "FLTK"
      fi
   fi
fi

# In case GEV devices should not be supported remove mvIPConfigure 
if [ "$GEV_SUPPORT" == "FALSE" ]; then
    if [ -d $DEF_DIRECTORY/apps/mvIPConfigure ] && [ -r $DEF_DIRECTORY/apps/mvIPConfigure/Makefile ]; then
        sudo rm -rf $DEF_DIRECTORY/apps/mvIPConfigure
    fi
fi

echo
echo "Do you want the tools and samples to be built (default is 'yes')?"
echo "Hit 'n' + <Enter> for 'no', or just <Enter> for 'yes'."
if [ "$USE_DEFAULTS" == "NO" ] ; then
  read YES_NO
else
  YES_NO=""
fi
if [ "$YES_NO" == "n" ] || [ "$YES_NO" == "N" ]; then
   echo
   echo "The tools and samples were not built."
   echo "To build them manually run 'make native' in $DEF_DIRECTORY"
   sudo /sbin/ldconfig
else
   cd $DEF_DIRECTORY
   sudo chown -R $USER $DEF_DIRECTORY
   make $TARGET
   sudo /sbin/ldconfig

# Shall the MV Tools be linked in /usr/bin?
   if [ "$GEV_SUPPORT" == "TRUE" ]; then
       echo "Do you want to set a link to /usr/bin for wxPropView, mvIPConfigure and mvDeviceConfigure (default is 'yes')?"
   else
       echo "Do you want to set a link to /usr/bin for wxPropView and mvDeviceConfigure (default is 'yes')?"
   fi
   echo "Hit 'n' + <Enter> for 'no', or just <Enter> for 'yes'."
   if [ "$USE_DEFAULTS" == "NO" ] ; then
     read YES_NO
   else
     YES_NO=""
   fi
   if [ "$YES_NO" == "n" ] || [ "$YES_NO" == "N" ]; then
      echo "Will not set any new link to /usr/bin."
   else
      if [ -r /usr/bin ]; then
         # Set wxPropView
         if [ -r $DEF_DIRECTORY/apps/mvPropView/$TARGET/wxPropView ]; then
            sudo rm -f /usr/bin/wxPropView
            sudo ln -s $DEF_DIRECTORY/apps/mvPropView/$TARGET/wxPropView /usr/bin/wxPropView
         fi
         # Set mvIPConfigure
         if [ "$GEV_SUPPORT" == "TRUE" ]; then
             if [ -r $DEF_DIRECTORY/apps/mvIPConfigure/$TARGET/mvIPConfigure ]; then
                sudo rm -f /usr/bin/mvIPConfigure
                sudo ln -s $DEF_DIRECTORY/apps/mvIPConfigure/$TARGET/mvIPConfigure /usr/bin/mvIPConfigure
             fi
         fi
         # Set mvDeviceConfigure
         if [ -r $DEF_DIRECTORY/apps/mvDeviceConfigure/$TARGET/mvDeviceConfigure ]; then
            sudo rm -f /usr/bin/mvDeviceConfigure
            sudo ln -s $DEF_DIRECTORY/apps/mvDeviceConfigure/$TARGET/mvDeviceConfigure /usr/bin/mvDeviceConfigure
         fi
      fi
   fi
fi

# copy the mvBF3 boot-device and an universal udev rules file for U3V cameras to the system 
if [ "$U3V_SUPPORT" == "TRUE" ]; then
    echo
    echo "Do you want to copy the necessary files to /etc/udev/rules.d for non-root user support (default is 'yes')?"
    echo "Hit 'n' + <Enter> for 'no', or just <Enter> for 'yes'."
    if [ "$USE_DEFAULTS" == "NO" ] ; then
     read YES_NO
    else
     YES_NO=""
    fi
    if [ "$YES_NO" == "n" ] || [ "$YES_NO" == "N" ]; then
       echo
       echo 'To grant non-root user support,'
       echo 'copy 52-U3V.rules and 52-mvbf3.rules the file to /etc/udev/rules.d'
       echo
    else
       sudo cp -f $DEF_DIRECTORY/Scripts/52-U3V.rules /etc/udev/rules.d
       sudo cp -f $DEF_DIRECTORY/Scripts/52-mvbf3.rules /etc/udev/rules.d
    fi
fi

# check if plugdev group exists and the user is member of it
if [ "$U3V_SUPPORT" == "TRUE" ]; then
    echo ""
    if ! grep -q plugdev /etc/group; then
       echo "Group 'plugdev' don't exists, this is necessary to run as non-root user, do you want to create it"
       echo "and add users to 'plugdev' (default is 'yes')?"
       echo "Hit 'n' + <Enter> for 'no', or just <Enter> for 'yes'."
       if [ "$USE_DEFAULTS" == "NO" ] ; then
         read YES_NO
       else
         YES_NO=""
       fi
       if [ "$YES_NO" == "n" ] || [ "$YES_NO" == "N" ]; then
          echo
          echo "'plugdev' will be not created and you can't run the device as non-root user!"
          echo "If you want non-root users support, you will need to create 'plugdev'"
          echo "and add the users to this group."
       else
          sudo /usr/sbin/groupadd -g 46 plugdev
          sudo /usr/sbin/usermod $USER -A plugdev
          echo "Group 'plugdev' created and user '"$USER"' added to it."
       fi
    fi
fi

# make sure the complete mvIA-tree belongs to the user
sudo chown -R $USER:$USER $DEF_DIRECTORY

#Set the necessary cti softlink
createSoftlink $DEF_DIRECTORY/lib/$TARGET libmvGenTLProducer.so mvGenTLProducer.cti

#Check whether the network buffers are configured
if [ "$GEV_SUPPORT" == "TRUE" ]; then
ERROR=0
echo "------------------------------------GEV Check--------------------------------------"
    if [ "$(which sysctl)" == "" ]; then
       echo "Warning: 'sysctl' not present on the system, network parameters cannot be checked!"
       ERROR=1
    else
       RMEM=$(( $(sysctl -n net.core.rmem_max) / 1048576 ))
       WMEM=$(( $(sysctl -n net.core.wmem_max) / 1048576 ))
       BKLG=$(sysctl -n net.core.netdev_max_backlog) 
       if [ $RMEM -lt 12 ]; then
           if [ $RMEM -lt 1 ]; then
               echo "Warning: 'net.core.rmem_max' Receive buffer settings are low( less than 1MB )!"
           else
               echo "Warning: 'net.core.rmem_max' Receive buffer settings are low($RMEM MB)!"
           fi
           ERROR=1
       fi
       if [ $WMEM -lt 12 ]; then
           if [ $WMEM -lt 1 ]; then
               echo "Warning: 'net.core.rmem_max' Receive buffer settings are low( less than 1MB )!"
           else
               echo "Warning: 'net.core.rmem_max' Receive buffer settings are low($WMEM MB)!"
           fi
           ERROR=1
       fi
       if [ $BKLG -lt 5000 ]; then
           echo "Warning: 'net.core.netdev_max_backlog' input queue settings are low($BKLG elements)!"
           ERROR=1
       fi
       if [ $ERROR == 1 ]; then
           echo "Incomplete frames may occur during image acquisition!"
       fi
   fi
   if [ $ERROR == 1 ]; then
       echo
       echo "Please refer to 'Quickstart/Optimizing the network configuration' section of the "
       echo "User Manual for more information on how to adjust the network buffers"
       echo "http://www.matrix-vision.com/manuals/mvBlueCOUGAR-X/mvBC_page_quickstart.html#mvBC_subsubsection_quickstart_network_configuration_controller"
       echo "-----------------------------------------------------------------------------------"
   else
      echo "                                       OK!                                         "
      echo "-----------------------------------------------------------------------------------"
   fi
fi

#Check whether the USBFS Memory is configured
if [ "$U3V_SUPPORT" == "TRUE" ]; then
ERROR=0
echo "------------------------------------U3V Check--------------------------------------"
    if [ ! -r /sys/module/usbcore/parameters/usbfs_memory_mb ]; then
       echo "Warning: 'usbfs_memory_mb' parameter does not exist or cannot be read!"
       ERROR=1
    else
       USBMEM=$(cat /sys/module/usbcore/parameters/usbfs_memory_mb)
       if [ $USBMEM -lt 128 ]; then
           echo "Warning: 'usbfs_memory_mb' Kernel USB file system buffer settings are low($USBMEM MB)!"
           echo "Incomplete frames may occur during image acquisition!"
           ERROR=1
        fi
   fi
   if [ $ERROR == 1 ]; then
       echo
       echo "Please refer to 'Quickstart/Linux/Optimizing USB performance' section of the "
       echo "User Manual for more information on how to adjust the kernel USB buffers"
       echo "http://www.matrix-vision.com/manuals/mvBlueFOX3/mvBC_page_quickstart.html#mvBC_subsubsection_quickstart_linux_requirements_optimising_usb"
       echo "-----------------------------------------------------------------------------------"
   else
      echo "                                       OK!                                         "
      echo "-----------------------------------------------------------------------------------"
   fi
fi

rm -f $SCRIPTSOURCEDIR/0
echo
source $GENICAM_EXPORT_FILE
echo
echo "-----------------------------------------------------------------------------------"
echo "                            Installation successful!                               "
echo "-----------------------------------------------------------------------------------"
echo

echo 'If the device is not initilising execute the following commands:'
echo '  ' export GENICAM_ROOT=$DEF_DIRECTORY/runtime
echo '  ' export "GENICAM_ROOT_V$GENVER="$DEF_DIRECTORY/runtime
if [ x$TARGET = xx86 ]; then
   echo '  ' export GENICAM_GENTL32_PATH=$DEF_DIRECTORY/runtime/lib
else
   echo '  ' export GENICAM_GENTL64_PATH=$DEF_DIRECTORY/runtime/lib
fi
echo '  ' export "GENICAM_CACHE_V$GENVER="$DEF_DIRECTORY/runtime/cache/v2_4
echo '  ' export "GENICAM_LOG_CONFIG_V$GENVER="$DEF_DIRECTORY/runtime/log/config-unix/DefaultLogging.properties
echo 'or source' $GENICAM_EXPORT_FILE:
echo '  ' . $GENICAM_EXPORT_FILE
echo 'or restart X11 (Ctrl-Alt-Backspace (twice on OpenSuSE)).'
echo '(The exports above have been added to' $GENICAM_EXPORT_FILE.
echo ' This file is read when you log in, which is normally done when starting X11.)'
echo
