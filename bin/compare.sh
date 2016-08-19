#!/bin/bash

#############################################################################################
#                                                                                            #
#   This Utility is to collect and compare the Hadoop configurations between clusters        #
#   Service configurations are retrieved from ambari via the curl request                    #
#   Note : Run it in ambari server                                                           #
#                                                                                            #
#############################################################################################

GREEN='\033[0;32m'
ORANGE='\033[38;5;166m'
YELLOW='\033[0;93m'
RED='\033[0;31m'
NC='\033[0m' # No Color

declare -A comparefilelist=()
declare -A cluster1_keyval=()
declare -A cluster2_keyval=()
declare -A listA=()
declare -A listB=()
filepos=""
time=`date +%FT%H%M%S`
mkdir -p $HOME/cluster-compare
_staging="$HOME/cluster-compare"
_tmp="$_staging/_dump"
copyAssociateArray="true"
output="$_staging/cluster-comparision.txt"
if [ -f "$output" ];then
rm -rf $output
fi
#Copy and Compare the key value List
getKeyValList(){
  cluster2_keyval=()
  flag=false
  while read line
  do
  if [[ "$line" == \##* ]];then
    property_name=$(echo $line |awk -F ':' '{print $2}' | awk -F ',' '{print $1}'|awk -F '.' '{print $1}')
  fi

  if [[ "$line" == \"properties\"* ]];then
   flag=true
  fi

  if [ $flag == true ]; then
    val+=$line
  fi

  if [[ $line == "}" ]];then
   flag=false
   cluster2_keyval[$property_name]="$val"
   val=""
  fi
  done < ${comparefilelist[$filepos]}

  if [ $copyAssociateArray == true ];then
   copy
  else
   compare
  fi 
}

#Copying array2 to array1 to compare keyvalue list
copy()
{
  for key in "${!cluster2_keyval[@]}"  
  do
  cluster1_keyval["$key"]="${cluster2_keyval["$key"]}"
  done
}

#Read the two files and compare if any changes are available
compare()
{
 cluster1_name=`echo ${comparefilelist[0]} | awk -F '-' '{print $4}'`
 cluster2_name=`echo ${comparefilelist[$filepos]} | awk -F '-' '{print $4}'`
 echo -e "${GREEN}\n******************** Comparing clusters $cluster1_name vs $cluster2_name ********************\n${NC}" 2>&1 | tee --append $output
 diff ${comparefilelist[0]} ${comparefilelist[$filepos]}  >/dev/null
 if [ $? == 0 ];then
 echo -e "Configurations are same" 2>&1 | tee --append $output
 else
 #Iterate and Compare outer key-value list
 for key in "${!cluster1_keyval[@]}";
 do 
  if [ -n "${cluster2_keyval[$key]+1}" ]; then
     val_1=${cluster1_keyval["$key"]}
     val_2=${cluster2_keyval["$key"]}
      if [ "$val_1" != "$val_2" ];then
         echo -e "${YELLOW}\n$key${NC} " 2>&1 | tee --append $output
         listA=()
         listB=()
         #Loading file 1 properties to list    
        _properties=`echo $val_1 | awk -F '"properties" : {' '{print $2}' | sed 's/.$//'`
        echo $_properties | sed 's/\"\,\"/\"\n\"/g' >$_tmp
	       while read line;
           do
            name=$(echo $line | awk -F ':' '{print $1}' | cut -d '"' -f 2)
	        if [ ! -z $name ];then   
            listA[$name]=$line
            fi
           done< $_tmp
        
	     #Loading file 2 properties to list    
        _properties=`echo $val_2 | awk -F '"properties" : {' '{print $2}' | sed 's/.$//'`
        echo $_properties | sed 's/\"\,\"/\"\n\"/g' >$_tmp	       
          while read line;
           do
            name=$(echo $line | awk -F ':' '{print $1}' | cut -d '"' -f 2)
	        if [ ! -z $name ];then   
            listB[$name]=$line
            fi
           done< $_tmp
           
        #Iterate and compare the inner key-value list 
        for val in "${!listA[@]}";
         do
          if [ -n "${listB[$val]+1}" ]; then
            val_1=${listA["$val"]}
            val_2=${listB["$val"]}
              if [ "$val_1" != "$val_2" ];then
               echo -e "${ORANGE}$cluster1_name ${NC}: $val_1" 2>&1 | tee --append $output
               echo -e "${RED}$cluster2_name ${NC}: $val_2" 2>&1 | tee --append $output
              fi
          else
           echo -e "${RED}$cluster2_name ${NC}: Parameter ${listA[$val]} is not exist" 2>&1 | tee --append $output
          fi
         done 
          
        #Iterate inner key-value list and find if any additional parameter is added in file2
         for val in "${!listB[@]}";
           do
           if [ ! -n "${listA[$val]+1}" ]; then
           echo -e "${RED}$cluster2_name ${NC}: Additional parameter ${listB[$val]} is configured" 2>&1 | tee --append $output
           fi
          done  
      fi
  else
    echo -e "${RED}$cluster2_name ${NC}: Property $key does not exist" 2>&1 | tee --append $output
  fi
 done
          
   #Iterate outer key-value list and find if any New property is added in file2
   for val in "${!cluster2_keyval[@]}";
    do
    if [ ! -n "${cluster1_keyval[$val]+1}" ]; then
       echo -e "${RED}$cluster2_name ${NC}: New property '$val' is configured" 2>&1 | tee --append $output
    fi
    done
 fi
}

echo -e "\n${GREEN}How many clusters you want to compare : ${NC}"
read count
num='^[0-9]+$'
if ! [[ $count =~ $num ]] ; then
echo -e "${RED} Please enter valid number${NC}"
exit 1
elif [ $count == 1 ];then
echo -e "${RED} Cluster count should be greater than one${NC}"
exit 1
fi

for((k=0;k<$count;k++))
do
echo -e "${GREEN}Ambari Username : ${NC}"
read username
echo -e "${GREEN}Ambari Password : ${NC}"
read -s passwd
echo -e "${GREEN}\nHostname : ${NC}"
read hostname
echo -e "${GREEN}Ambari Server Port : ${NC}"
read port
echo -e "${GREEN}Clustername : ${NC}"
read clustername
echo -e "${GREEN}Is ambari URL secure (y/n)? :${NC}"
read ssloption
statusdump="$_staging/ambari-servicedump-$clustername-$hostname.txt"
dump="$_staging/status.txt"
servicefile="$_staging/cluster-service"
if [ -f "$statusdump" ];then
rm -rf $statusdump
fi
if echo "$ssloption" | grep -iq "^y" ;then
curl -k -s -u $username:$passwd "https://$hostname:$port/api/v1/clusters/$clustername?fields=Clusters/desired_configs" >$servicefile
else
curl -k -s -u $username:$passwd "http://$hostname:$port/api/v1/clusters/$clustername?fields=Clusters/desired_configs" >$servicefile
fi
returncode=$?
isfail=`cat $servicefile | wc -l`
if [ $returncode != 0 ];then
echo -e "${RED}Failed to download component list from $hostname ${NC}"
exit 1
elif [ "$isfail" -le 5 ];then
echo -e "${RED}Unable to download cluster config.Please check logfile under $_staging/cluster-service${NC}"
exit 1
fi
echo -e "\nDownloading component configuration for https://$hostname:$port/api/v1/clusters/$clustername .. \n"
for i in `cat  $servicefile | grep -i tag -B1 | grep "{" | awk  '{print $1}' | sed -e 's/^"//'  -e 's/"$//'`
do
if echo "$ssloption" | grep -iq "^y" ;then
/var/lib/ambari-server/resources/scripts/configs.sh -u $username -p $passwd -port $port -s get $hostname $clustername $i >>$dump
returncode=`echo $?`
else
/var/lib/ambari-server/resources/scripts/configs.sh -u $username -p $passwd get $hostname $clustername $i >>$dump
returncode=`echo $?`
fi
if [ $returncode != 0 ];then
echo -e "${RED}Failed getting service list dump $i.${NC}"
exit 1
fi
comparefilelist[$k]="$statusdump"
done
cat $dump | egrep -iv "USERID|PASSWORD" >$statusdump
rm -rf $dump
done

for ((i=0;i<${#comparefilelist[@]};i++))
do
   filepos=$i
    if [ $i != 0 ]; then
   copyAssociateArray=false;
   fi
getKeyValList
done
perl -pe 's/\x1b\[[0-9;]*[mG]//g' $output > $_staging/cluster-comparison-$time.txt 
echo -e "${GREEN}\nPlease review the file cluster-comparison-$time.txt for cluster config variations under $_staging directory${NC}"

rm -rf $_staging/ambari-ser*
rm -rf $_staging/_dump
rm -rf $_staging/cluster-service
rm -rf $output
