#!/bin/bash -ex

getip()
{
  ip=$(/sbin/ifconfig eth0 | grep 'inet ' | awk '{ print $2}')
  echo $ip
}

IP=`getip`

allssh()
{
  CMDS=$@
  DEFAULT_OPTS="-q -o LogLevel=ERROR -o StrictHostKeyChecking=no"
  EXTRA_OPTS=${ALLSSH_OPTS-"-t"}
  OPTS="$DEFAULT_OPTS $EXTRA_OPTS"
  for i in `svmips`
  do
    if [ -z "$i" ]
    then
      continue
    else
      if [ "x$i" == "x$IP" ]
      then
         continue
      fi
      echo "================== "$i" ================="
      /usr/bin/ssh $OPTS $i "source /etc/profile; export USE_SAFE_RM=yes; $@"
    fi
  done
  echo "================== "$IP" ================="
  /usr/bin/ssh $OPTS $IP "source /etc/profile; export USE_SAFE_RM=yes; $@"
}

#PCDOMAINNAME=goodvibes.ntnxlab.local
#PCDOMAINNAME=dsta.local
PCDOMAINNAME=`cat /etc/resolv.conf |grep ^search|awk  '{print $2}'`

USERHOME=$HOME

WORKDIR=$HOME/.t

if [ -d "${WORKDIR}" ]
then
    /bin/rm -rf ${WORKDIR}
fi

mkdir ${WORKDIR}

allssh 'ping -c 1 iam-proxy.ntnx-base' | tee ${WORKDIR}/iam-proxy.out
cat ${WORKDIR}/iam-proxy.out | awk '$1 == "==================" && $2 != "=================" { print $2 }' | tee ${WORKDIR}/pcvms.txt
cat ${WORKDIR}/iam-proxy.out | grep 'bytes from' | cut -d "(" -f2 | cut -d ")" -f1 | tee ${WORKDIR}/iam-proxies.txt

pcvms=`cat ${WORKDIR}/pcvms.txt`
iams=`cat ${WORKDIR}/iam-proxies.txt`

i=1

for pcvm in ${pcvms}
do
    if [ -f "${WORKDIR}/hosts.${pcvm}" ]
    then
        /bin/rm ${WORKDIR}/hosts.${pcvm}
    fi
done

for pcvm in ${pcvms}
do
    fmt='$'$i
    t=`echo ${iams} | awk '{ print '"$fmt"' }'`
    echo '#################################' | tee -a ${WORKDIR}/hosts.${pcvm}
    echo $t  iam-proxy.ntnx-base iam-proxy.ntnx-base.${PCDOMAINNAME} | tee -a ${WORKDIR}/hosts.${pcvm}
    j=1
    for entry in ${iams}
    do
        if [ $i ==  $j ]; then
            :
        else
            echo ${entry}  iam-proxy.ntnx-base iam-proxy.ntnx-base.${PCDOMAINNAME} | tee -a ${WORKDIR}/hosts.${pcvm}
        fi
        j=`expr $j + 1`
    done
    i=`expr $i + 1`
done

src=`hostname -I| awk '{ print $1}'`
opt="-t -q -o LogLevel=ERROR -o StrictHostKeyChecking=no"


for pcvm in ${pcvms}
do
    srcpathname=nutanix@${src}:${WORKDIR}/hosts.${pcvm}
    destpathname=nutanix@${pcvm}:hosts

    scp ${srcpathname} ${destpathname}
done

/bin/rm -rf ${WORKDIR}

allssh "cat /home/nutanix/hosts | sudo tee -a /etc/hosts"
allssh "sudo sh -c 'shutdown -r now'"

