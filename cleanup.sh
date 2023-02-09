#!/bin/bash

vtemp1=$1
[ "Z$vtemp1" == "Z" ] && export TMPDIR=/tmp/tf


# Cleanup old instance
if kill $(ps axuw |grep 'vault server'|grep -v grep |awk '{print $2}') 2>/dev/null; then
  while nc localhost 8200; do sleep 1; done
  sleep 1
fi

# Cleanup the directories
rm -rf $TMPDIR/*
rm -rf /var/lib/softhsm/tokens/*
mkdir -p $TMPDIR/data/raft
mkdir -p $TMPDIR/tf

