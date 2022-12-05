#!/bin/bash

optspec="ab:h"
base=main
all=False

print_help() {
  echo "Measure building and checking time for R package in a local git repo"
  echo "Usage: $0 [flags] <repo path> <branch_to_measure_1> <branch_to_measure_2> ..."
  echo "Flags:"
  echo "No flags for measuring build/check time of specified branches + default branch [$base]"
  echo "-a to measure all remote branches"
  echo "-b to define base branch, default [$base]"
  echo "-h for help."
  echo "If positional arguments <branch_to_measure_1>, <branch_to_measure_2>, <branch_to_measure_3> ... are omitted, only default branch [$base] will be measured"
}

if [[ $# == 0 ]]
then
    print_help
    exit 0
fi

while getopts $optspec opt
do
    case $opt in
        a)
	    all=True
	    ;;
	b)
	    base=${OPTARG}
	    ;;
        h)
	    print_help
 	    exit 0
            ;;
	:)
            echo "Error: -${OPTARG} requires an argument."
	    exit 1
	    ;;
        ?)
	    echo "Error: Invalid options: -${OPTARG}."	
	    exit 0
	    ;;
    esac
done

# Remove the parsed flags from the arguments array with shift.
shift $(( ${OPTIND} - 1 ))

proj=$(basename $1)
compares=( "${@:2}" )
branches=( $base "${compares[@]}" )
temp_dir=$(mktemp -d)
outfile=$temp_dir/time_${proj}.log

get_current_branch () {
    local repo=$1
    git -C $repo branch -l | grep \* | sed 's/^\*\s*//g'
}

get_all_remotes () {
    local repo=$1
    local top=$2
    local all_remotes=( $(git -C $repo branch -r | sed 's/^.*\///') )
    local all_ordered=( $top "${all_remotes[@]}" )
    echo "${all_ordered[@]}" | tr [:space:] '\n'| awk '!x[$0]++'
}

if git -C $1 rev-parse --git-dir > /dev/null 2>&1
then
    git -C $1 fetch -p --all &> /dev/null
    current_branch=$(get_current_branch $1)
    if [[ "$all" == True ]] 
    then
        branches=( $(get_all_remotes $1 $base) )   
	printf "All remote branches will be measured:\n"
	printf ' - %s\n' "${branches[@]}" 
	printf '\n'
    fi
else 
    echo "$1 must be git folder."
    exit 0
fi

echo "Find output in: $temp_dir"
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
    fi
    echo -e "\nCurrent branch: $current_branch"
    echo -e "\n--- Measure branch: $current_branch ---\n" >> $outfile
    echo "1. Build time" >> $outfile
    { time R CMD build $1 2>&1 ; } 2>> $outfile 
    mv *.tar.gz $temp_dir/
    echo -e "\n2. Check time" >> $outfile
    { time R CMD check --as-cran --output=$temp_dir $temp_dir/*.tar.gz 2>&1 ; } 2>> $outfile
done
