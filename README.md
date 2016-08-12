# ambari

##Cluster Configuration comparision

###Purpose

Utility is to collect and compare all the Hadoop configurations from multiple clusters (example output: doc/compare.sh-screenshot.png)

###Usage 

./compare.sh


###Input 

How many clusters you want to compare :

Ambari Username :

Ambari Password :

Hostname :

Ambari Server Port :

Clustername :

Is ambari URL secure (y/n)? (HTTPS/HTTP):


###Notes 

Run the script from one of Ambari Server. 

It uses curl request for retrieving service configuration from Ambari.
