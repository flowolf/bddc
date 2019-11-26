![unmaintained](https://img.shields.io/badge/code-unmaintained-orange)

```
# bddc - Bash Dyn DNS Checker                                                  #
# http://bddc.klienux.org/                                                     #
# Copyright (c) <2006 - 2011> <florian[at]klien[dot]cx>                        #
#                                                                              #
# Permission is hereby granted, free of charge, to any person obtaining a copy #
# of this software and associated documentation files (the "Software"), to     #
# deal in the Software without restriction, including without limitation the   #
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or  #
# sell copies of the Software, and to permit persons to whom the Software is   #
# furnished to do so,                                                          #
# subject to the following conditions:                                         #
#                                                                              #
#                                                                              #
# The above copyright notice and this permission notice shall be included in   #
# all copies or substantial portions of the Software.                          #
#                                                                              #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR   #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,     #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE  #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER       #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING      #
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS #
# IN THE SOFTWARE.                                                             #
```

# What is bddc

'bddc' stands for 'Bash Dyn DNS Checker'. 
i wrote bddc because i wanted a small and easy editable program to keep track of my changing IP-address.
bddc grew to a full equipped bash script that should fulfill the needs of the average dyn dns user in any way. 

## Features

the features of bddc in the current version: 
receiving IP from:
 * ifconfig
 * a remote website
 * a local network router.
   - DLink DI-624
   - DLink DI-624+
   - DLink DI-524 (included since version 0.3)
   - Netgear TA612V
   - Netgear WGT-624
   - Digitus DN 11001
   - Philips Wireless PSTN (since version 0.0.9.3, and not yet confirmed to work)
   - Westell 327W DSL Router (since version 0.0.9.4, and not yet confirmed to work)
   - La Fonera (tested on Model: FON2100A/B/C, Firmware 0.7.1 r3)
   ...more to come...
 
### updating your new IP is possible with: 
 * afraid.org
 * dyndns.org
 * no-ip.com
 ...suggestions are welcome...
### other features:
 * checking if the dns update did work
 * lightweight and easy editable.
 * dynamically searching for available fetching tools (currently wget or curl).
 * running on many different platforms. (any Linux, Mac, OpenWrt...)

## Changelog

 - 0.3.9: added twitter support. you can twitter the logs now.
 - 0.3.5: added check for private IPs. update is really useless with e.g. 192.168.0.1.
 - 0.3.3: fixed codebreak from whatismyip.com.
 - 0.3.2: changed handling of errors from afraid.org.
 - 0.3.1: little bugfix on an infinite update loop, when afraid.org returns an ERROR on "ip did not change". fixed an issue with non maching ip for Dlink624 on wrt enironments.
 - 0.3: fixed issue on "expr substr" for mac users. added support for DLink DI-524.
 - 0.2: added support for La Fonera.
 - 0.1: now running on wrt environments, with busybox. fetching ip from many different remote websites. dynamically searching for available fetching tools. added an extra logging level for additional status information.
 - 0.0.9.4: added support for Westell 327W DSL Router.
 - 0.0.9.3: added support for Philips Wireless PSTN.
 - 0.0.9.2: added some comments, for easier configuration.
 - 0.0.9.1: major bugfix in DLink section. you see it in line 330.
 - 0.0.9: bugfix in ping check, disabled it in default settings.
 - 0.0.8: added support for Digitus DN 11001, added ping check feature (checks for success of dns update).
 - 0.0.7: bugfixes, catching timeouts for curl requests, added logout for netgear routers.
 - 0.0.6: added support for no-ip.com.
 - 0.0.5: added support for Netgear TA612V, Netgear WGT-624.
 - 0.0.3: support for D-Link DI-624, afraid.org and dyndns.org.

