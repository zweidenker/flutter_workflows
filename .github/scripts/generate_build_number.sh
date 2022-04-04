# Pass in the pubspec.yaml file as the first argument
# Pass in the Build number as the second argument

version=$(awk '/version/{print $NF}' "$1")

IFS='.' read -r -a numbers <<< "$version"
major=${numbers[0]}
minor=${numbers[1]}
IFS='+' read -r -a patchAndBuild <<< "${numbers[2]}"
patch=${patchAndBuild[0]}

buildNumber=$(($(($(((major * 100000000) + (minor * 1000000))) + (patch * 10000))) + $2))

echo "$buildNumber"
