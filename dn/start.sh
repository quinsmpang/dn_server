#!/bin/sh
default_config="config"
if [ -z $1 ]; then
	config=$default_config
else
	config=$1
fi

test ! -f $config && echo "Config file '$config' not found" && exit 
test ! -f ./skynet && echo "Missing skynet exec file! Try 'make' first." && exit

daemon=`lua -e "package.path=\"./?\" require \"$config\" print(runasdaemon)"`

if [ "$daemon" == "nil" ] || [ "$daemon" == "0" ] ; then
	# not daemon
	./skynet $config
else
	# run as daemon
	logger=`lua -e "package.path=\"./?\" require \"$config\" print(logger)"`
	if [ "$logger" == "nil" ]; then
		logger="stderr.log"
	fi
	./skynet $config > /dev/null 2>>$logger
	echo -e "Run as daemon\nRedirect stderr to $logger"
fi

