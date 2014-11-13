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


# NOTE: THESE VALUES ARE ONLY THE DSCP CODE POINTS
#   Most devices expect the entire field, so multiple these by 4

# 0x00 - DF, Default Forwarding: All non-critical and misc traffic
# 0x2C - VA, Voice Admit: EF Per Hop Behavior with Call Admission Control
# 0x2E - EF, Expedited Forwarding: Low delay, jitter, and loss. Highest

# 0x0A,0x0C,0x0E - AF11,AF12,AF13: Bulk data xfers, web traffic
# 0x12,0x14,0x16 - AF21,AF22,AF23: Transactional, Database applications
# 0x1A,0x1C,0x1E - AF31,AF32,AF33: Multimedia streaming
# 0x22,0x24,0x26 - AF41,AF42,AF43: Interactive video data traffic

# 0x00 - CS0: See DF
# 0x08 - CS1: Scavenger, less than best effort
# 0x10 - CS2: Network management traffic
# 0x18 - CS3: Telephony signaling
# 0x20 - CS4: Streaming media/video
# 0x28 - CS5: Broadcast Video
# 0x30 - CS6: IP routing and network control
# 0x38 - CS7: Interior network control - no DSCP really needed

# 0x04 - TOS routine lowdelay (Used by SSH)
# 0x02 - TOS routine throughput (used by SCP)

