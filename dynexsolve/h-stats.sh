#!/usr/bin/env bash

#######################
# Functions
#######################

get_cards_hashes(){
#05-12-2022 21:41:25 [GPU 0] 220005386 STEPS (+31872188) | 87.57540s | FLOPS = 363.940 kFLOPS | HR = 21.506 H | AVG(O)n ^ 1.03324 | CIRCUIT SIMULATION (0.15h)
  hs=''; local t_hs=0
  local i=0
  for (( i=0; i < ${GPU_COUNT_NVIDIA}; i++ )); do
    t_hs=`cat $log_name | tail -n 200 | grep "\[GPU $i\]" | grep "HR = " | tail -n 1 | cut -f 18 -d " " -s`
    hs+="$t_hs "
  done
}


get_total_hashes(){
#05-12-2022 21:41:25 [GPU *] 321048393 STEPS (+35087218) | 105.25s | FLOPS = 333.371 kFLOPS | HR = 21.506 H | AVG(O)n ^ 1.06397
  khs=0
  khs=`cat $log_name | tail -n 200 | grep "\[GPU \*\]" | grep "HR = " | tail -n 1 | cut -f 18 -d " " -s | awk '{ printf($1/1000) }'`
}

get_shares(){
#05-12-2022 21:45:19 [STRATUM] SHARE ACCEPTED BY POOL (19/0)
  local t_sh=
  t_sh=`cat $log_name | tail -n 200 | grep "SHARE ACCEPTED" | tail -n 1 | cut -f 8 -d " " -s`
  ac=`echo "${t_sh}" | cut -d "(" -f 2 -s | cut -f 1 -d "/" -s`
  rj=`echo "${t_sh}" | cut -f 2 -d "/" -s | cut -d ")" -f 1 -s`
}

get_miner_uptime(){
  local a=0
  let a=`stat --format='%Y' $log_name`-`stat --format='%Y' $conf_name`
  echo $a
}

get_log_time_diff(){
  local a=0
  let a=`date +%s`-`stat --format='%Y' $log_name`
  echo $a
}

#######################
# MAIN script body
#######################

. /hive/miners/custom/dynexsolve/h-manifest.conf

local temp=$(jq '.temp' <<< $gpu_stats)
local fan=$(jq '.fan' <<< $gpu_stats)

temp=$(jq -rc ".$nvidia_indexes_array" <<< $temp)
fan=$(jq -rc ".$nvidia_indexes_array" <<< $fan)

local log_name="$CUSTOM_LOG_BASENAME.log"
local conf_name="$CUSTOM_CONFIG_FILENAME"

local ac=0
local rj=0

[[ -z $GPU_COUNT_NVIDIA ]] && GPU_COUNT_NVIDIA=`gpu-detect NVIDIA`

# Calc log freshness
local diffTime=$(get_log_time_diff)
local maxDelay=120

# echo $diffTime

local algo="cryptonight"

# If log is fresh the calc miner stats or set to null if not
if [ "$diffTime" -lt "$maxDelay" ]; then
  get_cards_hashes                 # hashes
  get_total_hashes                 # total hashes
  get_shares                       # accepted, rejected
  local hs_units='hs'              # hashes utits
  local uptime=$(get_miner_uptime) # miner uptime

# make JSON
#--argjson hs "`echo ${hs[@]} | tr " " "\n" | jq -cs '.'`" \

  stats=$(jq -nc \
        --argjson hs "`echo ${hs[@]} | tr " " "\n" | jq -cs '.'`" \
        --arg hs_units "$hs_units" \
        --argjson temp "`echo ${temp[@]} | tr " " "\n" | jq -cs '.'`" \
        --argjson fan "`echo ${fan[@]} | tr " " "\n" | jq -cs '.'`" \
        --arg ac "$ac" --arg rj "$rj" \
        --arg uptime "$uptime" \
        --arg algo "$algo" \
        --arg ver "$CUSTOM_VERSION" \
        '{$hs, $hs_units, $temp, $fan, $uptime, $algo, ar: [$ac, $rj], $ver}')
else
  stats=""
  khs=0
fi

# debug output
#echo temp:  $temp
#echo fan:   $fan
#echo stats: $stats
#echo khs:   $khs
