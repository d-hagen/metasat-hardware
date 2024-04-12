#!/bin/bash

# Copyright © 2019-2023
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

output_file=""
global_file=""
copy_folder=""
prepropressor=0

defines_str=""
includes_str=""

# parse command arguments
while getopts D:I:J:O:G:C:Ph flag
do
  case "${flag}" in
    D)  defines+=( ${OPTARG} )
        defines_str+="-D${OPTARG} "
        ;;
    I)  includes+=( ${OPTARG} )
        includes_str+="-I${OPTARG} "
        ;;
    O)  output_file=( ${OPTARG} );;
    C)  copy_folder=($(realpath ${OPTARG}));;
    P)  prepropressor=1;;
    h)  echo "Usage: [-D<macro>] [-I<include-path>] [-J<external-path>] [-O<output-file>] [-C<dest-folder>: copy to] [-G<global_header>] [-P: macro prepropressing] [-h help]"
        exit 0
    ;;
  \?)
    echo "Invalid option: -$OPTARG" 1>&2
    exit 1
    ;;
  esac
done

if [ "$copy_folder" != "" ]; then
    # copy source files   
    mkdir -p $copy_folder
    for dir in ${includes[@]}; do
        find "$dir" -maxdepth 1 -type f | while read -r file; do
            ext="${file##*.}"
            if [ $prepropressor != 0 ] && { [ "$ext" == "v" ] || [ "$ext" == "sv" ]; }; then
                verilator $defines_str $includes_str -E -P $file > $copy_folder/$(basename -- $file)
            else
                cp $file $copy_folder
            fi
        done
    done
fi

if [ "$output_file" != "" ]; then
    {
        if [ "$copy_folder" != "" ]; then
            # dump source files
	    find "${copy_folder##*/}" -maxdepth 1 -type f -name "*_pkg.sv" -print
            find "${copy_folder##*/}" -maxdepth 1 -type f \( -name "*.v" -o -name "*.sv" \) ! -print
        else
            # dump source files
            for dir in ${includes[@]}; do
                find "$(realpath $dir)" -maxdepth 1 -type f -name "*_pkg.sv" -print
            done
            for dir in ${includes[@]}; do
                find "$(realpath $dir)" -maxdepth 1 -type f \( -name "*.v" -o -name "*.sv" \) ! -name "*_pkg.sv" -print
            done
        fi
    } > $output_file
fi
