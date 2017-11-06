#!/bin/bash

##############################
# IPA auto-build script
# 
##############################

##输入
BundleId="com.gz.ability"
AppName="Ability"
ShortVersion="1.0"
BuildVersion="20171106"

cd "$(dirname "$0")";
##当前脚本运行目录
ProjectPath=$(pwd) 
##当前project或者workspace的文件名
ProjectName="TempApp"
##描述文件路径
ProvisionFile="${ProjectPath}/Ability.mobileprovision"

WorkspacePath="${ProjectPath}/${ProjectName}.xcworkspace"
ArchivePath="${ProjectPath}/build/${ProjectName}.xcarchive"
Scheme="${ProjectName}"
InfoPlistPath="${ProjectPath}/${ProjectName}/Info.plist"
OutputPath="${ProjectPath}/build/Release-iphoneos"
ExportOptionsPath="${ProjectPath}/ExportOptions.plist"
ProvisionPlistFile="${ProjectPath}/ProvisionFile.plist"

##第一步:将描述文件转成plist，并读取里面的关键字段
security cms -D -i "${ProvisionFile}" > "${ProvisionPlistFile}"

###获取UUID
Provision_UUID=`defaults read "${ProvisionPlistFile}" UUID`
echo "UUID:"${Provision_UUID}

###获取TeamID
Provision_TeamIdentifier=`defaults read "${ProvisionPlistFile}" TeamIdentifier`
echo "TeamIdentifier:"${Provision_TeamIdentifier}

###放到临时文件再取出来，这里有点曲折，原因是读出来的无法去掉 "长空格"
Provision_TeamIdentifier=${Provision_TeamIdentifier/(/} #去掉左(
Provision_TeamIdentifier=${Provision_TeamIdentifier/)/} #去掉右)

touch temp.txt
echo ${Provision_TeamIdentifier} > temp.txt
Provision_TeamIdentifier=`cat temp.txt | awk '{print $0}'`
echo ${Provision_TeamIdentifier}
rm temp.txt

###获取TeamName
Provision_TeamName=`defaults read "${ProvisionPlistFile}" TeamName`
echo "TeamName:"${Provision_TeamName}

###获取描述文件名称
Provision_Name=`defaults read "${ProvisionPlistFile}" Name`
echo "Name:"${Provision_Name}

##第二步:生成 build.xcconfig，并写入配置信息
XcconfigPath="${ProjectPath}/build.xcconfig"
cat>${XcconfigPath}<<EOF
DevelopmentTeam =${Provision_TeamIdentifier}
PROVISIONING_PROFILE = ${Provision_UUID}
CODE_SIGN_IDENTITY = iPhone Distribution: ${Provision_TeamName}
PRODUCT_BUNDLE_IDENTIFIER = ${BundleId}
EOF

##第三步:生成 exportOptions.plist
cat>${ExportOptionsPath}<<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>provisioningProfiles</key>
	<dict>
		<key>${BundleId}</key>
		<string>${Provision_Name}</string>
	</dict>
	<key>teamID</key>
	<string>${Provision_TeamIdentifier}</string>
	<key>method</key>
	<string>enterprise</string>
	<key>uploadSymbols</key>
	<true/>
</dict>
</plist>
EOF
# exit

###第四步：修改Info.plist文件信息
##通过defaults write 的方式会让plist变成乱码文件，但不影响使用
##修改显示名称 => CFBundleDisplayName
defaults write ${InfoPlistPath} "CFBundleDisplayName" "${AppName}"
##修改短版本 => CFBundleShortVersionString
defaults write ${InfoPlistPath} "CFBundleShortVersionString" "${ShortVersion}"
##修改build版本 => CFBundleVersion
defaults write ${InfoPlistPath} "CFBundleVersion" "${BuildVersion}"
##修改 Bundle ID => CFBundleIdentifier
defaults write ${InfoPlistPath} "CFBundleIdentifier" "${BundleId}"

###第五步：执行clean,archive,export
## clean project
xcodebuild clean -workspace "${WorkspacePath}" -scheme "${Scheme}" -configuration Release
## archive project
xcodebuild archive -workspace "${WorkspacePath}" -scheme "${Scheme}" -archivePath "${ArchivePath}" -xcconfig "${XcconfigPath}"
## export ipa
xcodebuild -exportArchive -archivePath "${ArchivePath}" -exportPath "${OutputPath}" -exportOptionsPlist "${ExportOptionsPath}"

###第六步：重命名ipa
#rename : bundleid_version.ipa
mv ${OutputPath}/${ProjectName}.ipa ${OutputPath}/${BundleId}_${ShortVersion}.ipa 

exit