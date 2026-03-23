#!/bin/bash
while :; do
  PID=$(ps ax|grep LangSwitch|grep -v grep|awk '{print $1}')
  while kill -0 $PID 2>/dev/null; do
    sleep 5
  done
  open LangSwitch.app
  sleep 5
done