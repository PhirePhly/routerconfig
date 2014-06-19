#!/bin/bash
#
# This is the module to configure DSCP-based quality of service
#
#
# The incoming traffic is divided into five flows based on code points:
# realtime	ef,cs5,cs4	33%
# control		cs6,cs3,cs2	7%
# critical	af*			35%
# best effort	df,*			25%
# scavenger	cs1			1%-25% max
#
# This is based on RFC4594 and "Cisco Medianet WAN Aggregation QoS Design"
# http://www.cisco.com/c/en/us/td/docs/solutions/Enterprise/WAN_and_MAN/QoS_SRND_40/QoSWAN_40.pdf


