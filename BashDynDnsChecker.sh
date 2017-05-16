#!/bin/bash
bddc_version="0.3.9"
################################################################################
# licensed under the                                                           #
# The MIT License                                                              #
#                                                                              #
# Copyright (c) <2006 - 2009> <florian[at]klien[dot]cx>                        #
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
#                                                                              #
################################################################################
#                                                                              #
# BashDynDnsChecker (bddc)                                                     #
#                                                                              #
# This is a dyndns check and synchronizing script                              #
# the executables it needs are:                                                #
# grep, egrep, expr, curl, echo, sed, ifconfig, date, tail, uniq, cut, cat,    #
# ping, rm and wget or curl.                                                   #
# which should be available in every *nix system.                              #
#                                                                              #
# copyright 2006 - 2009 by florian klien                                       #
# florian[at]klien[dot]cx                                                      #
#                                                                              #
# supports ip reception from ifconfig, an external url (by http)               #
# and parsing from a router.                                                   #
#                                                                              #
# supports dyndns synchronization with afraid.org, dyndns.org and no-ip.com    #
#                                                                              #
# (!) it needs to be called in crontab as a cronjob, or any other similar      #
# perpetual program.                                                           #
#                                                                              #
# (!) if you use bddc on a wrt environment, change the very first line from    #
# '#/bin/bash' to '#/bin/sh', without the quotes                               #
# and clear the cutting_string variable at the end of the edit space           #
# you should further turn the log level very low, after you made sure bddc     #
# works correctly. this would otherwise fill up your memory quickly.           #
#                                                                              #
# (!) Ping-Check is a feature that controls the update of your new dyn-ip.     #
#  Just use it if you know what it does!                                       #
#  If you want a safety net for your home server enable Ping-Check.            #
#  BE CAREFUL about your settings!                                             #
#  You MUST NOT choose an update interval that is too short (interval < 5min)  #
#  You MUST NOT use an internal DNS server with your dyn-hostname as a record. #
#   This record is most likely to send an internal IP for this hostname. Make  #
#   sure you get a DNS result from an external server, with the correct IP.    #
#  How does it work?                                                           #
#   Ping-Check compares the IP it gets back from the ping. The ping is of      #
#   course done against the dyn-hostname. If the IP is not the same as on      #
#   record an other update is forced.                                          #
#                                                                              #
# (I) if you want your router to be supported,                                 #
# *) send us a patch of your changes (plus the version number of bddc on       #
#    which the patch works on.)                                                #
# OR                                                                           #
# *) send us your own parsing string and                                       #
# *) the value of the ip when offline (maybe other possible errors)            #
#  as we do in the script and put it on the feature request forum on           #
#  sourceforge.net.                                                            #
# *) plus full name of the router                                              #
# *) your name and email address for contact and testing purpose before        #
#    a release is done.                                                        #
# OR                                                                           #
# add the following information to the feature request site on                 #
# sourceforge.net:                                                             #
# *) the url under which the external ip can be read from your router          #
# *) a copy of the html source code from this site (each online and offline)   #
# *) the complete name of your router                                          #
# *) the url to call for logout of the router                                  #
# *) your name and email address for contact and testing purpose before        #
#    a release is done.                                                        #
#                                                                              #
# exit codes:                                                                  #
# 0  -> everything went fine                                                   #
# 1  -> some error occured during runtime                                      #
# 2  -> some config error was caught                                           #
# 11 -> ip address was private                                                 #
# 28 -> timeout at connecting to some host                                     #
#                                                                              #
################################################################################
# change to your needs                                                         #
################################################################################

# executable paths
cat=cat
curl=curl
cut=cut
date=date
echo=echo
egrep=egrep
expr=expr
grep=grep
ifconfig=ifconfig
ping=ping
sed=sed
tail=tail
uniq=uniq
wget=wget


######################
# change logging level
# 4 -> log every step, this is fine to see what bddc does (debugging mode)
#      this is only prompted to the console if SILENT=0 AND LOGGING=4
# 3 -> log whenever a check is done
# 2 -> log when ip changes
# 1 -> log errors (recommended for WRT environments)
# 0 -> log nothing
LOGGING=${BDDC_LOG_LEVEL-3}
LOGFILE=${BDDC_LOG-/var/log/bddc.log}
#LOGFILE=/tmp/bddc.log # (recommended for WRT environments)

# cache file for ip address
ip_cache=/tmp/bddc-ip-add.cache

html_tmp_file=/tmp/bddc_html_tmp_file

# turn silent mode on (no echo while running, [1 is silent])
SILENT=0

# submit your log also to twitter 
# (this can be a security issue, since your ip can be seen by anyone)
# use 0 for no twittering
# 1 for logging errors (although it might be that they do not make it to twitter)
# 2 for twittering whenever ip changes
# 3 for whenever a check is done (twitter will not accept identical messages)
# 4 for twittering every little step (NOT RECOMMENDED)
# use "USERNAME:PASSWD"
TWITTER=0
TUSERPWD="USER:PASSWD"
#################################
# mode of ip checking
# 1 -> output of ifconfig
# 2 -> remote website
# 3 -> router info over http
CHECKMODE=${BDDC_CHECKMODE-2}

#################################
# ad 1: your internet interface (eth0,eth1,en0,en1...)
inet_if=${BDDC_INET_IF-eth0}

#################################
# ad 2: remote url to get ip from over http
# (!) changing this needs you to change the 
# parsing string further down in the code.
check_url=http://ipv4bot.whatismyipaddress.com/
# seconds to try for remote host:
remote_timeout=10

########### R O U T E R #########
# ad 3: router model
# 1 -> DLink DI-624/DI-624+/DI-524
# 2 -> Netgear-TA612V
# 3 -> Netgear WGT-624
# 4 -> Digitus DN 11001
# 5 -> Philips Wireless PSTN (currently testing...)
# 6 -> Verizon Westell 327W (currently testing...)
# 7 -> La Fonera (remote over wlan)
ROUTER=1
router_timeout=5
router_tmp_file=/tmp/bddc_router_tmp_file

#-------DLink-DI-624/DI-624+/DI-524---------
# ad 1: DLink DI-624/DI-624+/DI-524 conf
dlink_user="ADMIN"
dlink_passwd="PASSWD"
dlink_ip=192.168.0.1
#choose one only
dlink_wan_mode=PPTP/PPPoE/DHCP
# this helps parsing, uncomment your router version
dlink_url=st_devic.html  # DI-624/DI-624+
#dlink_url=st_device.html  # DI-524
dlink_mode=WAN
#------/Dlink-DI-624/DI-624+/DI-524---------

#-------Netgear-TA612V--------
# ad 2: Netgear-TA612V conf
netgear1_user="ADMIN"
netgear1_passwd="PASSWD"
netgear1_ip=192.168.0.1
# this helps parsing (do not change)
netgear1_url=s_status.htm
netgear1_logout=logout.htm
#------/Netgear-TA612V--------

#-------Netgear WGT-624--------
# ad 3: WGT 624 conf
wgt624_user="ADMIN"
wgt624_passwd="PASSWD"
wgt624_ip=192.168.0.1
# this helps parsing (do not change)
wgt624_url=RST_status.htm
wgt624_logout=LGO_logout.htm
#-------/Netgear WGT-624-------

#-------Digitus DN 11001-------
# ad 4: Digitus DN 11001 conf
digitusDN_user="ADMIN"
digitusDN_passwd="PASSWD"
digitusDN_ip=192.168.0.1
# this helps parsing (do not change)
digitusDN_url=status.htm
#-------/Digitus DN 11001------

#-------Philips Wireless PSTN------- Not confirmed working...
# ad 5: Philips Wireless PSTN conf
philipsPSTN_user="ADMIN"
philipsPSTN_passwd="PASSWD"
philipsPSTN_ip=192.168.0.1
# this helps parsing (do not change)
philipsPSTN_url=status_main.stm
philipsPSTN_loginpath=cgi-bin/login.exe
philipsPSTN_logoutpath=cgi-bin/logout.exe
#-------/Philips Wireless PSTN------

#-------Westell 327W------- Not confirmed working...
# ad 6: Westell 327W conf
west327_user="ADMIN"
west327_passwd="PASSWD"
west327_ip=192.168.0.1
west327_url=advstat.htm
#------/Westell 327W-------

#-------La Fonera (FON2100A/B/C)-------
# ad 7: La Fonera conf
lafonera_user="ADMIN" # is not needed, status page is accessable without username 
lafonera_passwd="PASSWD" # is not needed, status page is accessable without pwd
lafonera_ip=192.168.10.1
lafonera_url=cgi-bin/status.sh
#------/La Fonera (FON2100A/B/C)-------
######### / R O U T E R #########

########## DNS Server Section ###########
# mode of syndication
# 1 -> use afraid.org url
# 2 -> use dyndns.org
# 3 -> use no-ip.com
# T -> testing option (doing nothing)
IPSYNMODE=${BDDC_IPSYNMODE-T}

#------------afraid.org-----------------
# ad 1: your update url using afraid.org
# enter your syndication url from afraid.org
afraid_url=http://freedns.afraid.org/dynamic/update.php?$BDDC_AFRAID_KEY
#-----------/afraid.org-----------------


#------------dyndns.org----------------
# ad 2: data you got at dyndns.org
dyndnsorg_username="USER"
dyndnsorg_passwd="PASSWD"
dyndnsorg_hostnameS=1st.domain.com,2nd.domain.com
#--do not edit-----
dyndnsorg_wildcard=NOCHG
dyndnsorg_mail=NOCHG
dyndnsorg_backmx=NOCHG
dyndnsorg_offline=NO
#for testing
dyndnsorg_ip=
#-----------/dyndns.org----------------

#------------no-ip.com-----------------
# ad 3: your data you got at no-ip.com
# username is an email address
noipcom_username="USERNAME@yourdomain.com"
noipcom_passwd="PASSWD"
noipcom_hostnameS=1st.domain.com,2nd.domain.com
#for testing
noipcom_ip=
#-----------/no-ip.com-----------------
########## / DNS Server Section ###########

# the name of the client that is sent with updates and requests (do not change)
bddc_name="bashdyndnschecker (bddc v${bddc_version})/bddc.klienux.org"

# Ping check !!! - ONLY ENABLE IF YOU KNOW WHAT THIS DOES - !!!
# see header for details, or http://bddc.klienux.org/faq.php
# checks if the dns service edited your ip.
# pings your hostname (my_url) to check for the ip.
# updates again if ip differs from current ip. 
# enabled if 1.
ping_check=0

# the url that needs the dyndns
# is used for Ping-Check, to check for successful dns update.
# only used when ping_check is enabled. (if you are using multiple domains, 
# you MUST ONLY list one.)
my_url=your.domain.com

# list of preferred url fetchers
# it is safe to leave this at default setting. this simply specifies order in
# which they are checked. must not be empty.
preferred_fetchers="$wget $curl"

# if you are using bddc on a wrt environment clear the cutting_string variable 
# do NOT edit this otherwise
cutting_string="$echo ${str:${in1}:${in2}};" # for full featured Linux and Mac Os X
#cutting_string= # (essential for WRT environments!!!)

################################################################################
# End of editspace, just go further if you know what you are doing             #
################################################################################


#######################################
#### Functions 
 
# choose_fetcher: finds available url fetchers and sets variable "fetcher" to point 
# to correct wrapper function;
choose_fetcher() {
    #  Go through preferred fetchers list and try to find which program is available
    [ -z "$preferred_fetchers" ] && { msg_error "Fetchers list empty, check settings"; exit 2; }
    local urlfetcher
    for urlfetcher in $preferred_fetchers; do
          #  First check if it even exists
        $urlfetcher --help >/dev/null 2>&1
        [ $? -eq 127 ] && continue

              #  Get the id string
        urlfetcher_id=$($urlfetcher --version 2>&1 |head -n1)
        if expr "$urlfetcher_id" : ".*unrecognized option.*" >/dev/null; then urlfetcher_id=$($urlfetcher --help 2>&1 |head -n1); fi
        
              #  See what we have
        case "$urlfetcher_id" in
            BusyBox*)    fetcher="_fetcher_bbwget" ;;
            curl*)       fetcher="$curl" ;;
            "GNU Wget"*) fetcher="_fetcher_wget" ;;
        esac
        
       #  Verify that we have it/it's implemented, if not reset $fetcher so we can try another one
        $fetcher --help >/dev/null 2>&1
        [ $? -eq 127 ] && fetcher=
    done        #for urlfetcher in $preferred_fetchers
    [ -z "$fetcher" ] && { msg_error "Could not find any suitable fetchers, function can be unimplemented"; exit 1; }
    return 0
}

login_data_valid () {
    if [ "$1" == "ADMIN" ] || [ "$2" == "PASSWD" ]; then
        msg_error "check the login settings for your router"
        return 0;
    fi
    return 1;
}

# msg_error: print and/or log message of level error (1) according to settings; pass msg as arg;
msg_error() {
    [ $SILENT -eq 0 ] && _msg_console "$@"
    [ $LOGGING -ge 1 ] && _msg_log "ERROR: $@"
    [ $TWITTER -ge 1 ] && _msg_tw "ERROR: $@"
}

msg_info() {
    [ $SILENT -eq 0 ] && _msg_console "$@"
    [ $LOGGING -ge 2 ] && _msg_log "INFO: $@"
    [ $TWITTER -ge 2 ] && _msg_tw "INFO: $@"
}

msg_verbose() {
    [ $SILENT -eq 0 ] && _msg_console "$@"
    [ $LOGGING -ge 3 ] && _msg_log "VERBOSE: $@"
    [ $TWITTER -ge 3 ] && _msg_tw "VERBOSE: $@"
}

msg_tattle() {
    if [ $LOGGING -ge 4 ]; then 
        _msg_log "TATTLE: $@"
        [ $SILENT -eq 0 ] && _msg_console "$@"
    fi
    [ $TWITTER -ge 4 ] && _msg_tw "$@"
}

# _fetcher_bbwget: download specified target with busybox's wget; expects options 
# for curl and translates them to wget if possible;
_fetcher_bbwget() {
    #  Catch parameters and use whichever you can
    local optstr=
    local proto=
    local host=
    local address=
    local have_out=0
    for a in $(seq 1 $#); do
        case $1 in
            -d)
              #  data as POST; unsupported, better scream cause there's gonna be problems
                msg_error "Fetcher cannot proceed, command not supported, aborting ..."
                exit 1
                ;;
            --help)
              #  print help
                optstr="${optstr:+$optstr }--help"
                shift; continue
                ;;
            -o)
              #  outfile
                have_out=1
                optstr="${optstr:+$optstr }-O \"$2\""
                shift 2; continue
                ;;
            -s)
              #  silent
                optstr="${optstr:+$optstr }-q"
                shift; continue
              ;;
            -u)
              #  user/pass; lets try to pass it in the URL
                local authstr=$2
                shift 2; continue
                ;;
            http*|ftp*)
              #  remote address
                proto="${1%%:*}"
                host="${1#*://}"
                shift; continue
                ;;
            '')
              #  ignore
                continue
                ;;
            *)
              #  catchall for all possibly unsupported options (should not effect functionality)
                msg_tattle "Fetcher got an unrecognized argument, ignoring ($1)"
                shift; continue
                ;;
        esac
    done
    #  Curl by default dumps to stdout, so if -o wasn't specified assume that.
    [ "$have_out" -eq "0" ] && optstr="${optstr:+$optstr }-O -"
    
    #  Assemble the address
    address="${proto}://${authstr:+$authstr@}${host}"
    
    #  Ready to roll
    # eval echo wget "$optstr" "\"$address\"" >&2
    eval wget "$optstr" "\"$address\""
    return $?
}

# this is for normal wget
_fetcher_wget() {
    #  Catch parameters and use whichever you can
    local optstr=
    local proto=
    local host=
    local address=
    local have_out=0
    for a in $(seq 1 $#); do
        case $1 in
            --connect-timeout)
                # timeout 
                optstr="${optstr:+$optstr }--timeout=$2"
                shift 2; continue
                ;;
            -d)
              #  data as POST;
                optstr="${optstr:+$optstr }--post-data=\"$2\""
                shift 2; continue
                ;;
            --help)
              #  print help
                optstr="${optstr:+$optstr }--help"
                shift; continue
                ;;
            -o)
              #  outfile
                have_out=1
                optstr="${optstr:+$optstr }-O \"$2\""
                shift 2; continue
                ;;
            -s)
              #  silent
                optstr="${optstr:+$optstr }-q"
                shift; continue
                ;;
            -u)
              #  user/pass; lets try to pass it in the URL
                local authstr=$2
                shift 2; continue
                ;;
            http*|ftp*)
              #  remote address
                proto="${1%%:*}"
                host="${1#*://}"
                shift; continue
                ;;
            '')
              #  silent ignore
                continue
                ;;
            -A)
                # setting bddc as reference URL
                optstr="${optstr:+$optstr }--referer=\"$2\""
                shift 2; continue
                ;;
            *)
              #  catchall for all possibly unsupported options
                msg_verbose "Fetcher got an unrecognized argument, ignoring ($1)"
                shift; continue
                ;;
        esac
    done
    #  Curl by default dumps to stdout, so if -o wasn't specified assume that.
    [ "$have_out" -eq "0" ] && optstr="${optstr:+$optstr }-O -"
    
    #  Assemble the address
    address="${proto}://${authstr:+$authstr@}${host}"

    echo $host
    echo $address
    echo $optstr
    echo $authstr

    #  Ready to roll
    # eval echo wget "$optstr" "\"$address\"" >&2
    eval wget "$optstr" "\"$address\""
    return $?
}

_cut_string() {
    str=$1
    in1=$2
    in2=$3
    if [ "$( $expr substr "okokokok" 1 2 2> /dev/null )" == "ok" ]; then 
        $echo $( $expr substr "${str}" ${in1} ${in2} )
    else 
        let "in1=$in1 - 1"
        # moved this line into config space 
        # (wrt users will get an error if this line is in the code) 
        #        $echo ${str:${in1}:${in2}}; 
        ${cutting_string}
    fi 
}

# _msg_console: print message to console; pass msg as arg;
_msg_console() {
    $echo -e "$@"
}

_msg_log() {
    $echo -e "[`$date +%d/%b/%Y:%T`] | $@" >> $LOGFILE
}

_msg_tw() {
    # it may occur that twitter does not update every time (especially when the message
    # does not change). in this case try embedding the timestamp (as below).
    #text="[`$date +%d/%b/%Y:%T`] $@"
    text="$@" 
    chars=$(echo -ne $text| wc -c)
    if [ "$chars" -gt "140" ]; then 
      #msg_error "twitter msg too long"; return; fi
      msg_tattle "cropping next msg for twitters 140 chars"
      text=${text:0:140}
    fi
    user=$TUSERPWD
    curl -s --basic --user $user --data-ascii "status=$text" "http://twitter.com/statuses/update.json" 1> /dev/null && _msg_log "twitter update successful"
}

#### end of Functions
#######################################

if [ $LOGGING -ge 1 ]; then
    if [ ! -e ${LOGFILE} ] || [ ! -s ${LOGFILE} ]; then
        $echo "${bddc_name} Logfile:" >> ${LOGFILE} 2> /dev/null
    fi
    if [ ! -r ${LOGFILE} ] || [ ! -w ${LOGFILE} ] || [ -d ${LOGFILE} ]; then
        $echo "ERROR: Script has no write and/or no read permission for logfile ${LOGFILE}!"
        exit 2
    fi
fi

if [ ! -e ${ip_cache} ] || [ ! -s ${ip_cache} ]; then
    $echo "0.0.0.0" > ${ip_cache} 2> /dev/null
fi
if [ ! -r ${ip_cache} ] || [ ! -w ${ip_cache} ] || [ -d ${ip_cache} ]; then
    msg_error "Script has no write and/or no read permission for ${ip_cache}!"
    [ $CHECKMODE -eq 3 ] && msg_verbose "NOTICE: the script needs permission to write to this file too: ${router_tmp_file}";
    exit 2
fi

if [ $CHECKMODE -eq 2 ]; then
    echo "" > ${html_tmp_file}
    if [ ! -r ${html_tmp_file} ] || [ ! -w ${html_tmp_file} ] || [ -d ${html_tmp_file} ]; then
        msg_error "Script has no write and/or no read permission for ${html_tmp_file}!"
        exit 2
    fi
fi
if [ $CHECKMODE -eq 3 ]; then
    echo "" > ${router_tmp_file}
    if [ ! -r ${router_tmp_file} ] || [ ! -w ${router_tmp_file} ] || [ -d ${router_tmp_file} ]; then
        msg_error "Script has no write and/or no read permission for ${router_tmp_file}!"
        exit 2
    fi
fi

msg_tattle "Looking for URL fetcher"
fetcher=
choose_fetcher
msg_tattle "Using fetcher: \"$fetcher\""

case "$CHECKMODE" in
	# ifconfig mode
    1)
        feedback=`$ifconfig | $grep $inet_if`
        if [ -z "$feedback" ]; then
            msg_error "internet interface ($inet_if) is down!"
            exit 1
        fi
        current_ip=`$ifconfig ${inet_if} |$grep "inet " | $sed 's/[^0-9]*//;s/ .*//'`;
        ;;
    # remote website mode 
    2)
    	# only edit if you know what you do!
    	# edit line of current_ip to a form that only the ip remains when you get the html file
	# in this format: '123.123.132.132'
        string=`$fetcher --connect-timeout "${remote_timeout}" -s -A "${bddc_name}" $check_url -o ${html_tmp_file}`
    
        # this fixes return values without ending newline, like wahtismyip.com automation page
        $echo -ne "\n\n" >> ${html_tmp_file} 
        case $? in
            28) msg_error "timeout (${remote_timeout} second(s) tried on host: ${check_url})"; exit 28 ;;
            1)  msg_error "Could not download from host: \"${check_url}\", is it up?"; exit 1 ;;
            0)  msg_tattle "Got IP address from host: \"${check_url}\"" ;;
        esac
        #  Note: this was tested on few different sites and it works.  Your mileage may vary.
        #+ This looks for anything that is formatted like an IP number and prints it.
        #  Sites tested:
        #o http://www.whatismyip.com/automation/n09230945.asp 
        #o http://ipdetect.dnspark.com:8888/
        #o http://www.ipchicken.com/
        #o http://checkip.dyndns.org/
        #o http://www.ip-number.com/index.asp
        #o http://www.lawrencegoetz.com/programs/ipinfo/
        #o http://www.cloudnet.com/support/getting_Connected/system.php
        #o http://www.mediacollege.com/internet/utilities/show-ip.shtml
        #  alt : |$sed -ne "s/[^0-9.]*\(\([0-9]\{1,3\}\.\)\{3\}\([0-9]\{1,3\}\)\).*/\1/p"  # doesn't work when there's a dot in the same line BEFORE the addr
        #  alt2: |$sed -ne "s/.*[^0-9]\(\([0-9]\{1,3\}\.\)\{3\}\([0-9]\{1,3\}\)\).*/\1/p"  # works well, one exception is when addr is on beginning of the line
        #  alt3: |$sed -ne "s/\(^\|.*[^0-9]\)\(\([0-9]\{1,3\}\.\)\{3\}\([0-9]\{1,3\}\)\).*/\2/p" |uniq  # works with all tested sites
        current_ip=`$cat $html_tmp_file |$sed -ne "s/\(^\|.*[^0-9]\)\(\([0-9]\{1,3\}\.\)\{3\}\([0-9]\{1,3\}\)\).*/\2/p" |$uniq`
        # current_ip=`$cat $html_tmp_file |$sed -ne "s/.*[^0-9]\(\([0-9]\{1,3\}\.\)\{3\}\([0-9]\{1,3\}\)\).*/\1/p" | $uniq ` # works well on Mac Os X
        #current_ip=`$cat $html_tmp_file | $egrep -e ^[\ \t]*\([0-9]\{1,3\}\.\)\{3\}[0-9]\{1,3\}| $sed 's/ //g'`

        ## uncomment the next two lines for testing, to see if it works:
        # $echo $current_ip
        # exit 0
        rm $html_tmp_file
        ;;
    ######################    
    # router per http mode
    3)   
        case $ROUTER in
             # DLink DI-624/524
            1)
             	login_data_valid ${dlink_user} ${dlink_passwd}
             	loginIsValid=$?
                if [ $loginIsValid == 0 ]; then
                    exit 2
               	fi
                string=`$fetcher --connect-timeout "${router_timeout}" -s --anyauth -u ${dlink_user}:"${dlink_passwd}" -o "${router_tmp_file}" http://${dlink_ip}/${dlink_url}`
                case $? in
                    28) msg_error "timeout (${router_timeout} second(s) tried on host: http://${dlink_ip}/${dlink_url})"; exit 28 ;;
                    1)  msg_error "Could not download from host: \"http://${dlink_ip}/${dlink_url}\", is it up?"; exit 1 ;;
                    0)  msg_tattle "Got IP address from host: \"http://${dlink_ip}/${dlink_url}\"" ;;
                esac
                line=`$grep -A 20 ${dlink_mode} ${router_tmp_file} | $grep onnected`
                line2=${line#"                    ${dlink_wan_mode} "}
                #  In ASH/BusyBox we don't have that construct, unfortunatelly
                #disconnected=${line2:0:9} # cutting Connected out of file
                disconnected=$(_cut_string "${line2}" 1 9) # cutting Connected out of file
                if [ "$disconnected" != "Connected" ]; then
				  # Try the DI-524 version
                    disconnected=$(_cut_string "${line2}" 14 9)
                    if [ "$disconnected" != "Connected" ]; then
                      msg_error "DLink DI-624/524 internet interface is down!"
                      exit 1
                    fi
                fi
                current_ip=`$grep -A 30 ${dlink_mode} ${router_tmp_file}|$grep -A 9 ${dlink_wan_mode} |$egrep -e \([0-9]\{1,3\}\.\)\{3\}[0-9]\{1,3\} | $sed 's/<[^>]*>//g;/</N;'|$sed 's/^[^0-9]*//;s/[^0-9]*$//' |$egrep -e \([0-9]\{1,3\}\.\)\{3\}[0-9]\{1,3\}`
                ;;
            
             # Netgear-TA612V
            2)
             	login_data_valid ${netgear1_user} ${netgear1_passwd}
             	loginIsValid=$?
                if [ $loginIsValid == 0 ]; then
                    exit 2
               	fi
               	string=`$fetcher --connect-timeout "${router_timeout}" -s --anyauth -u ${netgear1_user}:"${netgear1_passwd}" -o "${router_tmp_file}" http://${netgear1_ip}/${netgear1_url}`
                case $? in
                    28) msg_error "timeout (${router_timeout} second(s) tried on host: http://${netgear1_ip}/${netgear1_url})"; exit 28 ;;
                    1)  msg_error "Could not download from host: \"http://${netgear1_ip}/${netgear1_url}\", is it up?"; exit 1 ;;
                    0)  msg_tattle "Got IP address from host: \"http://${netgear1_ip}/${netgear1_url}\"" ;;
                esac
               	current_ip=`$grep -A 20 "Internet Port" ${router_tmp_file} |$grep -A 1 "IP Address"|egrep -e \([0-9]\{1,3\}\.\)\{3\}[0-9]\{1,3\} | $sed 's/<[^>]*>//g;/</N;'|$sed 's/^[^0-9]*//;s/[^0-9]*$//'` 
                if [ -z "$current_ip" ]; then
                    msg_error "Netgear-TA612V internet interface is down!"
                    exit 1
                fi
                $fetcher --connect-timeout "${router_timeout}" -s --anyauth -u ${netgear1_user}:${netgear1_passwd} http://${netgear1_ip}/${netgear1_logout}
                case $? in
                    28) msg_error "timeout (${router_timeout} second(s) tried on host: http://${netgear1_ip}/${netgear1_logout}"; exit 28 ;;
                    1)  msg_error "Could not log out from host: \"http://${netgear1_ip}/${netgear1_logout}\", is it up?" ;;  
                    0)  msg_tattle "Log out from host: \"http://${netgear1_ip}/${netgear1_logout}\"" ;;
                esac
                ;;

            # Netgear WGT 624
            3)
             	login_data_valid ${wgt624_user} ${wgt624_passwd}
             	loginIsValid=$?
                if [ $loginIsValid == 0 ]; then
                    exit 2
                fi
                string=`$fetcher --connect-timeout "${router_timeout}" -s --anyauth -u ${wgt624_user}:"${wgt624_passwd}" -o "${router_tmp_file}" http://${wgt624_ip}/${wgt624_url}`
                case $? in
                    28) msg_error "timeout (${router_timeout} second(s) tried on host: http://${wgt624_ip}/${wgt624_url})"; exit 28 ;;
                    1)  msg_error "Could not download from host: \"http://${wgt624_ip}/${wgt624_url}\", is it up?"; exit 1 ;;
                    0)  msg_tattle "Got IP address from host: \"http://${wgt624_ip}/${wgt624_url}\"" ;;
                esac

                current_ip=`$grep -A 20 "Internet Port" ${router_tmp_file}| $grep -A 1 "IP Address" | $egrep -e \([0-9]\{1,3\}\.\)\{3\}[0-9]\{1,3\} | $sed 's/<[^>]*>//g;/</N;'| $sed 's/^[^0-9]*//;s/[^0-9]*$//'`
                if [ "$current_ip" == "0.0.0.0" ]; then
                    msg_error "WGT 624 internet interface is down!"
                    exit 1
                fi
                $fetcher --connect-timeout "${router_timeout}" -s --anyauth -u ${wgt624_user}:${wgt624_passwd} http://${wgt624_ip}/${wgt624_logout}
                case $? in
                    28) msg_error "timeout (${router_timeout} second(s) tried on host: http://${wgt624_ip}/${wgt624_logout})"; exit 28 ;;
                    1)  msg_error "Could not log out from host: \"http://${wgt624_ip}/${wgt624_logout}\", is it up?" ;;
                    0)  msg_tattle "Log out from host: \"http://${wgt624_ip}/${wgt624_logout}\"" ;;
                esac
                ;;

             # Digitus DN 11001
            4)
             	login_data_valid ${digitusDN_user} ${digitusDN_passwd}
             	loginIsValid=$?
                if [ $loginIsValid == 0 ]; then
                    exit 2
                fi
                string=`$fetcher --connect-timeout "${router_timeout}" -s --anyauth -u ${digitusDN_user}:"${digitusDN_passwd}" -o "${router_tmp_file}" http://${digitusDN_ip}/${digitusDN_url}`
                case $? in
                    28) msg_error "timeout (${router_timeout} second(s) tried on host: http://${digitusDN_ip}/${digitusDN_url})"; exit 28 ;;
                    1)  msg_error "Could not download from host: \"http://${digitusDN_ip}/${digitusDN_url}\", is it up?"; exit 1 ;;
                    0)  msg_tattle "Got IP address from host: \"http://${digitusDN_ip}/${digitusDN_url}\"" ;;
                esac
                current_ip=`$grep IP ${router_tmp_file}|$grep Adr |$egrep -e \([0-9]\{1,3\}\.\)\{3\}[0-9]\{1,3\} | $sed 's/<[^>]*>//g;/</N;'| $sed 's/^[^0-9]*//;s/[^0-9]*$//'`
                if [ "$current_ip" == "0.0.0.0" ]; then
                    msg_error "Digitus DN 11001 internet interface is down!"
                    exit 1
                fi
                ;;
             # Philips Wireless PSTN
            5)
             	login_data_valid ${philipsPSTN_user} ${philipsPSTN_passwd}
             	loginIsValid=$?
                if [ $loginIsValid == 0 ]; then
                    exit 2
                fi
                # login to router
                #$wget --timeout=${router_timeout} --post-data 'pws=${philipsPSTN_passwd}' http://${philipsPSTN_ip}/${philipsPSTN_loginpath}
                #$curl --max-time ${router_timeout} -d name=${philipsPSTN_user} -d pws=${philipsPSTN_passwd} http://${philipsPSTN_ip}/${philipsPSTN_loginpath}
                $fetcher --max-time ${router_timeout} -d pws=${philipsPSTN_passwd} http://${philipsPSTN_ip}/${philipsPSTN_loginpath}
                string=`$fetcher --connect-timeout "${router_timeout}" -s -o "${router_tmp_file}" http://${philipsPSTN_ip}/${philipsPSTN_url}`
                case $? in
                    28) msg_error "timeout (${router_timeout} second(s) tried on host: http://${philipsPSTN_ip}/${philipsPSTN_url})"; exit 28 ;;
                    1)  msg_error "Could not download from host: \"http://${philipsPSTN_ip}/${philipsPSTN_url}\", is it up?"; exit 1 ;;
                    0)  msg_tattle "Got IP address from host: \"http://${philipsPSTN_ip}/${philipsPSTN_url}\"" ;;
                esac
                current_ip=`$grep "var wan_ip" "${router_tmp_file}" | cut -d \" -f 2`
                if [ "$current_ip" == "0.0.0.0" ]; then
                    msg_error "Philips Wireless PSTN internet interface is down!"
                    exit 1
                fi
                # logout from router
                $fetcher http://${philipsPSTN_ip}/${philipsPSTN_logoutpath} 2> /dev/null
                ;;
            # Westell 327W
            6)
             	login_data_valid ${west327_user} ${west327_passwd}
             	loginIsValid=$?
                if [ $loginIsValid == 0 ]; then
                    exit 2
                fi
                string=`$fetcher --connect-timeout "${router_timeout}" -s --anyauth -u ${west327_user}:"${west327_passwd}" -o "${router_tmp_file}" http://${west327_ip}/${west327_url}`
                case $? in
                    28) msg_error "timeout (${router_timeout} second(s) tried on host: http://${west327_ip}/${west327_url})"; exit 28 ;;
                    1)  msg_error "Could not download from host: \"http://${west327_ip}/${west327_url}\", is it up?"; exit 1 ;;
                    0)  msg_tattle "Got IP address from host: \"http://${west327_ip}/${west327_url}\"" ;;
                esac
                #current_ip=`$grep -A 1 Secondary ${router_tmp_file} |$egrep -e \([0-9]\{1,3\}\.\)\{3\}[0-9]\{1,3\} | gawk -F";" ' {print $2}' | $sed 's/<br>&nbsp//'`
                current_ip=`$grep -A 1 Secondary ${router_tmp_file} | $egrep -e \([0-9]\{1,3\}\.\)\{3\}[0-9]\{1,3\} | $cut -d ';' -f 2 | $sed 's/<br>&nbsp//'`
                if [ "$current_ip" == "0.0.0.0" ]; then
                    msg_error "Westell 327W internet interface is down!"
                    exit 1
                fi
                ;;
            # La Fonera
            7)
                string=`$fetcher --connect-timeout "${router_timeout}" -s -o "${router_tmp_file}" http://${lafonera_ip}/${lafonera_url}`
                case $? in
                    28) msg_error "timeout (${router_timeout} second(s) tried on host: http://${lafonera_ip}/${lafonera_url})"; exit 28 ;;
                    1)  msg_error "Could not download from host: \"http://${lafonera_ip}/${lafonera_url}\", is it up?"; exit 1 ;;
                    0)  msg_tattle "Got IP address from host: \"http://${lafonera_ip}/${lafonera_url}\"" ;;
                esac
                current_ip=`$cat ${router_tmp_file} | $grep -A 2 -i Internet | $grep IP| $cut -d : -f 2 | $sed 's/<[^>]*>//g' | $sed 's/ //g'`
                if [ "$current_ip" == "N/A" ]; then
                    msg_error "La Fonera internet interface is down!"
                    exit 1
                fi
                ;;
        esac
        rm ${router_tmp_file}
        ;;
esac

#---------IP-checking-part-----------------------
# check if ip is in a private range == not visible to others
if [ "$current_ip" != "$old_ip" ]; then
    first_part=`echo $current_ip | cut -d . -f 1`
    second_part=`echo $current_ip | cut -d . -f 2`
    case $current_ip in
        127.0.0.1)
                msg_error "IP address $current_ip is localhost"
                exit 11
                ;;
        255.255.255.255)
                msg_error "IP address $current_ip is broadcast"
                exit 11
                ;;
    esac
    if [ "$BDDC_ALLOW_PRIVATE" -ne 1 ]; then
		case $first_part in
			10)
					msg_error "IP address $current_ip is part of private network"
					exit 11
					;;
			169)
				if [ "$second_part" == "254" ]; then
					msg_error "IP address $current_ip is part of private network"
					exit 11
				fi
					;;
			172)
				if [ $second_part -ge 16 ] && [ $second_part -le 31 ]
				 then
					msg_error "IP address $current_ip is part of private network"
					exit 11
				fi
					;;
			192)
				if [ "$second_part" == "168" ]; then
					msg_error "IP address $current_ip is part of private network"
					exit 11
				fi
					;;
		esac
	fi
msg_tattle "IP  $current_ip seems alright, passing to syndication part"
fi



#---------IP-syndication-part--------------------
old_ip=`$cat $ip_cache`
if [ "$current_ip" != "$old_ip" ]
    then
    
    case $IPSYNMODE in
        # afraid.org
        1)
      	    # afraid.org gets IP over the http request of your url
      	    afraid_url+="&address=$current_ip"
            afraid_feedback=`$fetcher --connect-timeout "${remote_timeout}" -A "${bddc_name}" -s "$afraid_url"`
            case $? in
                28) msg_error "timeout (${remote_timeout} second(s) tried on host: ${afraid_url})"; 
                    exit 28 ;;
                1)  msg_error "Could not download from host: \"${afraid_url}\", is it up?"; exit 1 ;;
                0)  # everything went fine
                    msg_tattle "Updated IP address on host: \"${afraid_url}\"" 
                    ;;
            esac
            # those are the possible error messages from afraid.org:
            #"ERROR: \"$address\" is an invalid IP address.";
			#"ERROR: Please clear your RBL listing of $address with: $return";
			#"ERROR: Missing S/key and DataID, check your update URL.";
			#"ERROR: Hostname has been ICED.";
			#"ERROR: Address $address has not changed.";
			#"ERROR: Account frozen.";
			#"ERROR: $resp";
			#"ERROR: " . $res['matchitem'] . " is listed on SBL : " . $res['rblresults'] . ".  Please clear your listing with them first.";
			#"ERROR: " . $res['matchitem'] . " is on the local banned IP list.";
			#"ERROR: Only premium members are permitted to point to IPs into this range.";
			
            if [ "ERROR" = "$(_cut_string "${afraid_feedback}" 1 5)" ]; then
                msg_error "afraid.org: ${afraid_feedback}"
                # do not exit on any error, timeout is there too
            fi
            ;;

    # dyndns.org
        2)
	    dyndnsorg_ip=$current_ip;
            myurl=`$echo "http://${dyndnsorg_username}:${dyndnsorg_passwd}@members.dyndns.org/nic/update?system=dyndns&hostname=${dyndnsorg_hostnameS}&myip=${dyndnsorg_ip}&wildcard=${dyndnsorg_wildcard}&mx=${dyndnsorg_mail}&backmx=${dyndnsorg_backmx}&offline=${dyndnsorg_offline}"`
            dyndnsorg_feedback=`$fetcher --connect-timeout "${remote_timeout}" -s -A "${bddc_name}" ${myurl}`
            case $? in
                28) msg_error "timeout (${remote_timeout} second(s) tried on host: ${myurl})"; exit 28 ;;
                1)  msg_error "Could not connect to host: \"${myurl}\", is it up?"; exit 1 ;;
                0)  # everything went fine
                    msg_tattle "Connected to host: \"${myurl}\"" 
                    ;;
            esac

            if [ "$(_cut_string "${dyndnsorg_feedback}" 1 8)" == "badagent" ]; then
                msg_error "dyndns.org: ERROR The user agent that was sent has been blocked for not following the specifications (${dyndnsorg_feedback})"
                exit 1
            fi
            if [  "$(_cut_string "${dyndnsorg_feedback}" 1 5)" == "abuse" ]; then
                msg_error "dyndns.org: ERROR account blocked because of abuse (${dyndnsorg_feedback})"
                exit 1
            fi
            if [ "$(_cut_string "${dyndnsorg_feedback}" 1 7)" == "notfqdn" ]; then
                msg_error "dyndns.org: ERROR domain name is not fully qualified (${dyndnsorg_feedback})"
                exit 1
            fi
            if [ "$(_cut_string "${dyndnsorg_feedback}" 1 7)" == "badauth" ]; then
                msg_error "dyndns.org: ERROR bad authentication (${dyndnsorg_feedback})"
                exit 2
            fi
            if [ "$(_cut_string "${dyndnsorg_feedback}" 1 4)" == "good" ]; then
                msg_info "dyndns.org: update successful (${dyndnsorg_feedback})"
            fi
            if [ "$(_cut_string "${dyndnsorg_feedback}" 1 5)" == "nochg" ]; then
                msg_verbose "dyndns.org: still the same ip (${dyndnsorg_feedback})"
            fi
            msg_tattle "dyndns.org: $dyndnsorg_feedback"
            ;;

        3)
            noipcom_ip=$current_ip;
            myurl=`$echo "http://dynupdate.no-ip.com/nic/update?hostname=${noipcom_hostnameS}&myip=${noipcom_ip}"`
            noipcom_feedback=`$fetcher --connect-timeout "${remote_timeout}" -s -A "${bddc_name}" --basic -u ${noipcom_username}:${noipcom_passwd} ${myurl}`
            case $? in
                28) msg_error "timeout (${remote_timeout} second(s) tried on host: ${myurl})"; exit 28 ;;
                1)  msg_error "Could not connect to host: \"${myurl}\", is it up?"; exit 1 ;;
                0)  msg_tattle "Connected to host: \"${myurl}\"" ;;
            esac
            if [ "$(_cut_string "${noipcom_feedback}" 1 8)" == "badagent" ]; then
                msg_error "no-ip.com: ERROR The user agent that was sent has been blocked for not following the specifications (${noipcom_feedback})"
                msg_error "no-ip.com: ERROR Client disabled. Client should exit and not perform any more updates without user intervention. (${noipcom_feedback})"
                exit 1
            fi
            if [  "$(_cut_string "${noipcom_feedback}" 1 5)" == "abuse" ]; then
                msg_error "no-ip.com: ERROR Account disabled due to violation of No-IP terms of service. Our terms of service can be viewed at http://www.no-ip.com/legal/tos (${noipcom_feedback})"
                exit 1
            fi
            if [ "$(_cut_string "${noipcom_feedback}" 1 6)" == "nohost" ]; then
                msg_error "no-ip.com: ERROR Hostname supplied does not exist (${noipcom_feedback})"
                exit 1
            fi
            if [ "$(_cut_string "${noipcom_feedback}" 1 7)" == "badauth" ]; then
                msg_error "no-ip.com: ERROR Invalid username (${noipcom_feedback})"
                exit 2
            fi
            if [ "$(_cut_string "${noipcom_feedback}" 1 4)" == "good" ]; then
                msg_info "no-ip.com: DNS hostname update successful (${noipcom_feedback})"
            fi
            if [ "$(_cut_string "${noipcom_feedback}" 1 5)" == "nochg" ]; then
                msg_verbose "no-ip.com: IP address is current, no update performed (${noipcom_feedback})"
            fi
            msg_tattle "no-ip.com: $noipcom_feedback"
            ;;

        T)
            # testing option for scripting, that you dont get banned from a service
            msg_info "Performing no update (T option active) ;)"
            ;;
    esac

    msg_tattle "writing current ip '$current_ip' to ip cache '$ip_cache'"
    $echo $current_ip > $ip_cache

    msg_info "ip changed: $current_ip"
else
    msg_tattle "IP Address not changed since last update, skipping."
fi #/ if ip changed

# check if nameserver got ip!
if [ $ping_check -eq 1 ]; then
    sleep 20
    ns_ip=`$ping -c 1 ${my_url} | $grep PING | $cut -d \( -f 2 | $cut -d \) -f 1`
    msg_tattle "Performed ping check, NS returned IP: $ns_ip"
    if [ "$current_ip" != "$ns_ip" ]; then
        msg_tattle "Nameservers did not register the change yet."
        if [ "$old_ip" == "--NOT---SYNCED--" ]; then
            msg_error "your dns service did not update your ip the first time\nMaybe you forgot to set the IPSYNMODE option to a correct value (T is just for testing)\ndns record: $ns_ip | your ip: $current_ip"
        fi
        # this forces an update at next check and prompts the error message
        msg_tattle "writing '--NOT---SYNCED--' to ip cache to force update!!!"
        $echo "--NOT---SYNCED--" > $ip_cache
    fi
fi
#/ check if nameserver got ip!

msg_verbose "current ip: $current_ip"
exit 0

