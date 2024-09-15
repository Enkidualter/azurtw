#!/bin/bash
# Download apkeep
get_artifact_download_url () {
    # Usage: get_download_url <repo_name> <artifact_name> <file_type>
    local api_url="https://api.github.com/repos/$1/releases/latest"
    local result=$(curl $api_url | jq ".assets[] | select(.name | contains(\"$2\") and contains(\"$3\") and (contains(\".sig\") | not)) | .browser_download_url")
    echo ${result:1:-1}
}

# Artifacts associative array aka dictionary
declare -A artifacts

artifacts["apkeep"]="EFForg/apkeep apkeep-x86_64-unknown-linux-gnu"
artifacts["apktool.jar"]="iBotPeaches/Apktool apktool .jar"

# Fetch all the dependencies
for artifact in "${!artifacts[@]}"; do
    if [ ! -f $artifact ]; then
        echo "Downloading $artifact"
        curl -L -o $artifact $(get_artifact_download_url ${artifacts[$artifact]})
    fi
done

chmod +x apkeep

# Download Azur Lane
if [ ! -f "com.hkmanjuu.azurlane.gp" ]; then
    echo "Get Azur Lane apk"

    # eg: wget "your download link" -O "your packge name.apk" -q
    #if you want to patch .xapk, change the suffix here to wget "your download link" -O "your packge name.xapk" -q
    file_id="1GEZR3WIZeWnls8xo4hWM-ol2qA3mOGVj"
file_name="com.hkmanjuu.azurlane.gp"

# 先请求获取确认令牌，然后使用该令牌下载文件
wget --quiet --save-cookies cookies.txt 'https://drive.google.com/uc?export=download&id='$file_id -O- \
    | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1/p' > confirm.txt

# 使用确认令牌进行实际的文件下载
confirm=$(<confirm.txt)
wget --load-cookies cookies.txt "https://drive.google.com/uc?export=download&confirm=$confirm&id=$file_id" -O $file_name -q

# 清理临时文件
rm -f cookies.txt confirm.txt

# 输出下载完成信息
echo "apk downloaded !"
    
    # if you can only download .xapk file uncomment 2 lines below. (delete the '#')
    #unzip -o com.YoStarJP.AzurLane.xapk -d AzurLane
    #cp AzurLane/com.YoStarJP.AzurLane.apk .
fi

# Download Perseus
if [ ! -d "Perseus" ]; then
    echo "Downloading Perseus"
    git clone https://github.com/Egoistically/Perseus
fi

echo "Decompile Azur Lane apk"
java -jar apktool.jar -q -f d com.hkmanjuu.azurlane.gp

echo "Copy Perseus libs"
cp -r Perseus/. com.hkmanjuu.azurlane.gp/lib/

echo "Patching Azur Lane with Perseus"
oncreate=$(grep -n -m 1 'onCreate' com.hkmanjuu.azurlane.gp/smali_classes2/com/unity3d/player/UnityPlayerActivity.smali | sed  's/[0-9]*\:\(.*\)/\1/')
sed -ir "s#\($oncreate\)#.method private static native init(Landroid/content/Context;)V\n.end method\n\n\1#" com.hkmanjuu.azurlane.gp/smali_classes2/com/unity3d/player/UnityPlayerActivity.smali
sed -ir "s#\($oncreate\)#\1\n    const-string v0, \"Perseus\"\n\n\    invoke-static {v0}, Ljava/lang/System;->loadLibrary(Ljava/lang/String;)V\n\n    invoke-static {p0}, Lcom/unity3d/player/UnityPlayerActivity;->init(Landroid/content/Context;)V\n#" com.hkmanjuu.azurlane.gp/smali_classes2/com/unity3d/player/UnityPlayerActivity.smali

echo "Build Patched Azur Lane apk"
java -jar apktool.jar -q -f b com.hkmanjuu.azurlane.gp -o build/com.hkmanjuu.azurlane.gp.patched.apk

echo "Set Github Release version"
s=($(./apkeep -a com.hkmanjuu.azurlane.gp -l))
echo "PERSEUS_VERSION=$(echo ${s[-1]})" >> $GITHUB_ENV
