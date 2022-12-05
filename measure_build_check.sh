#!/bin/bash

ref=main
proj=$(basename $1)
compares=( "${@:2}" )
branches=($ref "${compares[@]}")
temp_dir=$(mktemp -d)
outfile=$temp_dir/time_${proj}.log

if git -C $1 rev-parse --git-dir > /dev/null 2>&1
then
    current_branch=$(git -C $1 branch -l | grep \* | sed 's/^\*\s*//g')
    git -C $1 fetch --all &> /dev/null
else 
    echo "$1 must be git folder."
    exit 0
fi

echo "Store output in: $temp_dir"
cat << EOF >> $outfile
=== Measure building and checking time for $proj ===
Local path: $1
EOF

for branch in "${branches[@]}"
do
    if [[ $current_branch != $branch ]]
    then
        git -C $1 checkout $branch 1>/dev/null 2>1
	current_branch=$branch
	echo -e "\nCurrent branch: $current_branch"
    fi
    echo -e "\n--- Measure branch: $current_branch ---\n" >> $outfile
    echo "1. Build time" >> $outfile
    { time R CMD build $1 2>&1 ; } 2>> $outfile 
    mv *.tar.gz $temp_dir/
    echo -e "\n2. Check time" >> $outfile
    { time R CMD check --as-cran --output=$temp_dir $temp_dir/*.tar.gz 2>&1 ; } 2>> $outfile
done
