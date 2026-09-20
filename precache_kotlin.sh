#!/bin/bash
set -e

BASE="https://maven-central.storage-download.googleapis.com/maven2/org/jetbrains/kotlin"
CACHE="/root/.gradle/caches/modules-2/files-2.1/org.jetbrains.kotlin"

download_jar() {
    local art="$1"
    local ver="$2"
    local sha1="$3"
    local file="${art}-${ver}.jar"
    local dir="${CACHE}/${art}/${ver}/${sha1}"
    mkdir -p "$dir"
    if [ ! -f "$dir/$file" ]; then
        echo "Downloading $file..."
        curl -s -L "${BASE}/${art}/${ver}/${file}" -o "$dir/$file"
    else
        echo "$file already exists"
    fi
}

download_jar "kotlin-scripting-compiler-embeddable" "2.2.20" "d13136286cbdf06f0926ec858125acc09e76cd72"
download_jar "kotlin-daemon-embeddable" "2.2.20" "feff12d48d7f1eb628742b0a721395e16f8755bf"
download_jar "kotlin-scripting-jvm" "2.2.20" "785d5ffea49d9dc289b200d0ff3e0ce6e9ba2395"
download_jar "kotlin-scripting-common" "2.2.20" "79e0c2cc15b84711ac1de87e6a257acd151cb999"
download_jar "kotlin-script-runtime" "2.2.20" "4c679cbeac0bb583b75c3a080013da8eaf240807"

echo "ALL KOTLIN JARS PRE-CACHED SUCCESSFULLY"
