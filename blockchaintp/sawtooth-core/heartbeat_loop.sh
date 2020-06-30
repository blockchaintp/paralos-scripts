#!/bin/bash
URL=$1
KEY=$2
PERIOD=$3

if [ -z "$PERIOD" ]; then
  PERIOD=30
fi

touch /etc/sawtooth/iam.healthy
intkey set ${KEY} 0 ; 
THEN=0
while /bin/true; do 
  intkey inc ${KEY} 1 ; 
  sleep $PERIOD;
  NOW=`intkey show ${KEY}`;
  if [ "$NOW" = "$THEN" ]; then
    rm -f /etc/sawtooth/iam.healthy
  elif [ -z "$NOW" ]; then
    intkey set ${KEY} 0;
  else
    touch /etc/sawtooth/iam.healthy
  fi
  THEN=$NOW
done
