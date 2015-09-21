#!/bin/sh
#
# code by Qin Hong @ 21 Sep, 2015
#

xcodeGhostKeyWords="icloud-analysis.com"
dumpToolPath="/var/root/dumpdecrypted.dylib"
appDir="/var/mobile/Containers/Bundle/Application"

function processPlist() {
	local plistPath
	plistPath=$1
	bundleIdentifier=`plutil -key CFBundleIdentifier "${plistPath}"`
	executableName=`plutil -key CFBundleExecutable "${plistPath}"`
	displayName=`plutil -key CFBundleDisplayName "${plistPath}" 2>/dev/null`
	bundleName=`plutil -key CFBundleName "${plistPath}" 2>/dev/null`
	version=`plutil -key CFBundleVersion "${plistPath}" 2>/dev/null`
	shortVersion=`plutil -key CFBundleShortVersionString "${plistPath}" 2>/dev/null`
	
	versionString="$shortVersion ($version)"
	if [ "${shortVersion}" == "" ];then
		versionString=$version
	fi

	appName=$displayName
	if [ "${displayName}" == "" ];then
		appName=$bundleName
	fi

	appDir=$(dirname "${plistPath}")
	executablePath="${appDir}/$executableName"

	echo "==========================="
	echo "APP Name: $appName"
	echo "Version: $versionString"
	echo "Bundle ID: $bundleIdentifier"
	echo "Executable: $executableName"
	#echo "Type: "

	isEncrypted=`otool -l "${executablePath}" |grep cryptid |awk '{print $1$2}' |grep cryptid1`

	if [ -n "${isEncrypted}" ];then
		echo "dumping mach-O..."

		#check UNICODE string
		isANSI=`echo "${executableName}" |grep [^a-z0-9_-]`
		if [ -n "$isANSI" ];then
			#copy and rename executable file
			executableCopyPath="${appDir}/${bundleIdentifier}"
			decryptedPath="`pwd`/${bundleIdentifier}.decrypted"
			cp "${executablePath}" "${executableCopyPath}"
		fi

		decryptedPath="`pwd`/${executableName}.decrypted"

		DYLD_INSERT_LIBRARIES="${dumpToolPath}" "${executablePath}" > /dev/null 2>&1
		if [ -f "$decryptedPath" ];then
			decryptedMachOPath=$decryptedPath
		else
			echo "Error: decrypt failed!"
		fi
	else
		decryptedMachOPath=$executablePath
	fi

	#check code
	isContainsKeyWords=`strings "${decryptedMachOPath}" |grep "${xcodeGhostKeyWords}"`
	if [ -n "${isContainsKeyWords}" ];then
		echo -e "\033[31mWarning: found XCodeGhost!\033[0m"
		removePath=$(dirname "${appDir}")
		rm -rf "${removePath}"
	else
		echo "App is OK."
	fi

	#clean
	if [ -n "${executableCopyPath}" ];then
		rm -rf "${executableCopyPath}"
	fi
	if [ -n "${isEncrypted}" ];then
		rm -rf "${decrpytedMatchOPath}"
	fi
}


IFS=$'\n'

for plistPath in `find "${appDir}" -name Info.plist`
do
	appPath=$(dirname "${plistPath}")
	appPathBaseName=$(basename "${appPath}")
	appPathExtension="${appPathBaseName##*.}"

	if [ $appPathExtension == "app" ];then
		processPlist "${plistPath}"
	fi
done

exit 0
