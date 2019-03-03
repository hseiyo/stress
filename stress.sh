#!/bin/bash

usage()
{
  echo "usage:"
  echo
  echo "CPU stress"
  echo "$0 -c -t seconds ratio"
  echo
  echo "Memory stress"
  echo "$0 -m -t seconds ratio"
}

cpu_stress()
{
  TIMEOUT=$1
  shift
  SECONDS=1
  while [ $SECONDS -lt ${TIMEOUT} ]
  do
    :
  done
}

memory_stress()
{
  TIMEOUT=$1
  shift
  SIZE=$1
  shift
  ( echo $SIZE; echo ${TIMEOUT} )  | perl -e 'my @arr; my $line = <STDIN>; my $timeout = <STDIN>; $line =~ s/[\D]+//g; print $mem . "\n"; while( $#arr < $line ){ push( @arr, "a" x 1024 ); } sleep $timeout;'
  echo "stack done"

}



main()
{
  MODE=$1
  shift
  if [ "$1" = "-t" ]
  then
    shift
    SEC=$1
    shift
  fi
  PERCENTAGE=$1
  shift

  
  UUID=$(uuidgen)
  # cgcreate -g cpu,memory:$UUID
  for d in cpu memory
  do
    mkdir /sys/fs/cgroup/$d/$UUID > /dev/null 2>&1
  done
  case $MODE in
    "-c")
      CPUNUM=$( cat /proc/cpuinfo | grep proce | wc -l )
      echo $( expr 1000000 / $CPUNUM ) > /sys/fs/cgroup/cpu/$UUID/cpu.cfs_period_us
      echo $( expr ${PERCENTAGE} \* 10000 ) > /sys/fs/cgroup/cpu/$UUID/cpu.cfs_quota_us
      echo $$ > /sys/fs/cgroup/cpu/$UUID/tasks

      echo "cpu.cfs_period_us: $(cat /sys/fs/cgroup/cpu/$UUID/cpu.cfs_period_us)"
      echo "cpu.cfs_quota_us: $(cat /sys/fs/cgroup/cpu/$UUID/cpu.cfs_quota_us)"
      echo "tasks: $(cat /sys/fs/cgroup/cpu/$UUID/tasks)"

      for n in $(seq 1 $CPUNUM )
      do
        cpu_stress $SEC ${PERCENTAGE} & 
      done
      vmstat 1 $(( $SEC + 2 ))
      ;;
    "-m")
      TOTALMEM=$( cat /proc/meminfo | grep MemTotal: | egrep -o "[0-9]+" ) # in kilo byte
      MAXUSEMEM=$( expr ${TOTALMEM} / 100 \* ${PERCENTAGE} )K
      echo ${MAXUSEMEM} > /sys/fs/cgroup/memory/$UUID/memory.limit_in_bytes
      echo $$ > /sys/fs/cgroup/memory/$UUID/tasks
      memory_stress $SEC ${MAXUSEMEM} &
      vmstat 1 $(( $SEC + 2 ))
      wait
      echo "done"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
  # cgdelete -g cpu,memory:$UUID
}

main $*
