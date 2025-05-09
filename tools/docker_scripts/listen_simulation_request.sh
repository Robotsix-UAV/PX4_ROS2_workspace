#!/bin/bash

# Listen to a simulation request using netcat on port 6666


echo "Listening for simulation request on port 6666"
while true; do
    message=$(nc -l -p 6666)

    case $message in
	    "simulation_up")
	        echo "Starting simulation"
	        ./launch_simulation.sh -f ../configurations/simulation_config_custom.yaml #-t release/1.14
	        ;;

	    "simulation_down")
		echo "Stopping simulation"
		docker stop px4_sitl
		;;
		
	    *)
		echo "Unknown command"
		;;
    esac
done
