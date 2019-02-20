#!/bin/sh

usage()
{
  echo "usage:"
  echo
  echo "CPU stress"
  echo "$0 -c -t seconds [percentage]"
  echo
  echo "Memory stress"
  echo "$0 -m -t seconds [percentage]"
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
  MEMDIR=.stress
  TIMEOUT=$1
  shift
  SIZE=$1
  shift
  if [ ! -x ${MEMDIR} ]
  then
    mkdir ${MEMDIR}
    mount -t tmpfs /dev/shm ${MEMDIR} -o size=$SIZE && echo "mount done"
    dd if=/dev/zero of=.stress/stress iflag=fullblock bs=$( echo $SIZE | cut -c1-$( expr $(echo $SIZE | wc -c) - 6 )  )M count=10 > /dev/null 2>&1
    echo "dd done"
  else
    echo "FATAL: ${MEMDIR} directory is already exists! exited."
    exit 1
  fi
  sleep ${TIMEOUT}
  umount ${MEMDIR} || ( echo "ERROR: umount ${MEMDIR} failed."; exit 1 )
  rmdir ${MEMDIR} || ( echo "ERROR: rmdir ${MEMDIR} failed."; exit 1 )

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
  cgcreate -g cpu,memory:$UUID

  case $MODE in
    "-c")
      CPUNUM=$( cat /proc/cpuinfo | grep proce | wc -l )
      echo $( expr 1000000 / $CPUNUM ) | tee /sys/fs/cgroup/cpu/$UUID/cpu.cfs_period_us
      echo $( expr ${PERCENTAGE} \* 10000 ) | tee /sys/fs/cgroup/cpu/$UUID/cpu.cfs_quota_us
      echo $$ | tee /sys/fs/cgroup/cpu/$UUID/tasks

      for n in $(seq 1 $CPUNUM )
      do
        cpu_stress $SEC ${PERCENTAGE} & 
      done
      vmstat 1 $(( $SEC + 2 ))
      ;;
    "-m")
      TOTALMEM=$( cat /proc/meminfo | grep MemTotal: | egrep -o "[0-9]+" ) # in kilo byte
      MAXUSEMEM=$( expr ${TOTALMEM} / 100 \* ${PERCENTAGE} )K
      echo ${MAXUSEMEM} | tee /sys/fs/cgroup/memory/$UUID/memory.limit_in_bytes
      echo $$ | tee /sys/fs/cgroup/memory/$UUID/tasks
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
  cgdelete -g cpu,memory:$UUID
}

main $*
