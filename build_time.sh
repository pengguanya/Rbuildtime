#!/bin/bash
#
# =============================================================================
# Script Name      : build_time.sh
# Description      : Bash script to measure R package build and check time
# Author           : Guanya Peng
# Email            : guanya.peng@roche.com 
# Date             : 2022 DEC 08
# Version          : 0.0.1
# Usage            : See the help with ./build_time.sh -h or ./build_time.sh
# Notes            : Requires R 4.x and Git 
# Bash version     : 5.0.17
# =============================================================================
#
# Constant and configurable variables
optspec="ab:n:o:h"
base=main
out_file_ext=log

# --- Functions ---

# Get the local branch with a given path of a local git folder
get_current_branch () {
    local repo=$1
    git -C $repo branch -l | grep \* | sed 's/^\*\s*//g'
}

# Get all remote branch names with a given path of a local git folder
get_all_remotes () {
    local repo=$1
    local top=$2
    local all_remotes=( $(git -C $repo branch -r | sed 's/^.*\///') ) 
    local all_ordered=( $top "${all_remotes[@]}" ) 
    echo "${all_ordered[@]}" | tr [:space:] '\n'| awk '!x[$0]++'
}

# Print information for repetitions
print_repetition_info () {
    local max=$1
    local n=${2:-1}
    local only_total=${3:-T}
    if [[ $only_total == "T" && $max -gt 1 ]]
    then
        echo "The building/checking time measurement will repeat $max times for the same repo and branches defined."
    elif [[ $max -gt 1 ]]
    then
        echo -e "\n#### Repetition number: $n ####\n"
    fi
}

# Pad to a fix width format for a given integer number
pad_to_width () {
    local width=$1
    local n=$2
    printf "%0*d\n" "$width" "$n"
}

# Create a filename string for the output file
make_file_name () {
    local dir=$1
    local filename=$2
    local max_number=$3
    local index=$4
    local ext=$5
    if [[ $max_number -gt 1 ]]
    then
        width=$(( ${#max_number} + 1 ))
        appendix=$(pad_to_width $width $index)
        echo "${dir}/${filename}_${appendix}.${ext}"
    else
        echo "${dir}/${filename}.${ext}"
    fi
}

# Print help information
print_help() {
  echo "Measure building and checking time for R package in a local git repo"
  echo "Usage: $0 [flags] <repo path> <branch_to_measure_1> <branch_to_measure_2> ..."
  echo "Note: The flags options must be specified before positional arguments"
  echo "Flags:"
  echo "No flags for measuring build/check time of specified branches + default branch [$base] with no repetition."
  echo "-a to measure all remote branches"
  echo "-b to define base branch, default [$base]"
  echo "-n to define the repetition number, default 1"
  echo "-o to define the path of the directory where output files are saved. If this option is ommited, a temporary directory will be created. The path is printed to standard output."
  echo "-h for help."
  echo "If positional arguments <branch_to_measure_1>, <branch_to_measure_2>, <branch_to_measure_3> ... are omitted, only default branch [$base] will be measured"
}


# --- Script option and arguments ---
if [[ $# == 0 ]]
then
    print_help
    exit 0
fi

# Default option argument
max_trials=1
all=False
outdir=$(mktemp -d)

# Parsing command line arguments
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
	n)
	    max_trials=${OPTARG}
	    ;;
    o)  
        outdir=${OPTARG}
        ;;
	:)
        echo "Error: -${OPTARG} requires an argument."
	    exit 1
	    ;;
    ?)
	    echo "Error: Invalid options: - [${OPTARG}]"	
	    exit 0
	    ;;
    esac
done

# Remove the parsed flags from the arguments array with shift.
shift $(( ${OPTIND} - 1 ))

# Helper/derived variables
repo_path="$1"
proj=$(basename ${repo_path})
compares=( "${@:2}" )
branches=( $base "${compares[@]}" )
main_filename=time_${proj}

# Get git branch info
if git -C "$repo_path" rev-parse --git-dir > /dev/null 2>&1
then
    git -C "$repo_path" fetch -p --all &> /dev/null
    current_branch=$(get_current_branch $1)
    if [[ $all == "True" ]] 
    then
        branches=( $(get_all_remotes $1 $base) )   
	printf "All remote branches will be measured:\n"
	printf ' - %s\n' "${branches[@]}" 
	printf '\n'
    fi
else 
    echo "${repo_path} must be git folder."
    exit 0
fi

mkdir -p "$outdir"
echo "Find output in: ${outdir}"
echo "Local path: $repo_path"
print_repetition_info "$max_trials" 

# Main loop to loop over trials and branches and measure building/checking time for specified repo
for trial in $(seq ${max_trials})
do
    outfile=$(make_file_name "$outdir" "$main_filename" "$max_trials" "$trial" "$out_file_ext")
    
    echo "=== Measure building and checking time for $proj ===" >> "$outfile" 

    print_repetition_info "$max_trials" "$trial" "F"

    for branch in "${branches[@]}"
    do
        if [[ $current_branch != $branch ]]
        then
            git -C $1 checkout "$branch" 1>/dev/null 2>1
    	current_branch="$branch"
        fi
        echo -e "\n--- Measure branch: $current_branch ---\n" | tee "$outfile"
        echo "Building package ..."
        echo "1. Build time" >> $outfile
        { time R CMD build ${repo_path} 2>&1 ; } 2>> "$outfile"
        mv *.tar.gz ${outdir}/
        echo -e "\nChecking package ..."
        echo -e "\n2. Check time" >> "$outfile"
        { time R CMD check --as-cran --output="$outdir" ${outdir}/*.tar.gz 2>&1 ; } 2>> "$outfile"
    done
done
