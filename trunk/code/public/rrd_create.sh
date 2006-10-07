export PATH=$PATH:/usr/local/rrdtool-1.0.28/bin

for sensor in attic dining_vault master_vault outside living_room eric_bedroom nicole_bedroom master_bedroom office utility_room playroom garage pond bathroom bathroom_vault
do
	rrdtool create /home/dbl/mh/data/rrd/temp/new-$sensor.rrd -s 300 \
		-b 970316700 \
		DS:temp:GAUGE:600:-40:140 \
		RRA:AVERAGE:0.5:1:2400 \
		RRA:MIN:0.5:12:4800 \
		RRA:MAX:0.5:12:4800 \
		RRA:AVERAGE:0.5:12:4800 \
		RRA:LAST:0.5:1:2400 
done
