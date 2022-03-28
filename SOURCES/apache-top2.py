#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# apache-top
# Copyright (C) 2006  Carles Amigó
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#

from HTMLParser import HTMLParser
from distutils.version import StrictVersion
import operator
import sys
import urllib
import curses
import traceback
import getopt
import time
import re

# Compiled re for info searching
RE_UPTIME = re.compile('^Server uptime: +(.*)$')
RE_RESTART = re.compile('^Restart Time: (.*)$')
RE_CPU = re.compile('^CPU Usage: (.*)$')
RE_RPS = re.compile('(.*requests/sec.*)')
RE_REQUESTS = re.compile('^([0-9]+) requests currently being processed, ([0-9]+) idle workers')

class ApacheStatusParser(HTMLParser):
    """
    Clase que parseja la sortida del handler server-status de apache
    """

    performance_info = 2
    scoreboard = 3
    proceses = 4

    status = 0

    store = False # defineix si el contingut s'ha de guardar o no
    append = False # defineix si els seguents caracters s'han d'afegir o posar en un altre camp

    performance_info_data = []
    scoreboard_data = []
    proceses_data = []

    def __init__(self):
        HTMLParser.__init__(self)
        self.performance_info_data = []
        self.scoreboard_data = []
        self.proceses_data = []
        self.store = False
        self.append = False
        self.status = 1

    def set_apache_version(self, version):
        self.apache_version = version
        self.apache_sversion = StrictVersion(self.apache_version)

        # New fields (protocol etc) in commit https://github.com/apache/httpd/commit/909aa9a
        # broke display of request
        if self.apache_sversion >= StrictVersion('2.4.19'):
            self.status_format = 3
            self.scoreboard = 4
            self.proceses = 5

        # There is new thread (async requests) in 2.4.x at start so
        # we have to increase table indexes
        elif self.apache_sversion >= StrictVersion('2.4.0'):
            self.status_format = 2
            self.scoreboard = 4
            self.proceses = 5

        # old extended status without threads table
        else:
            self.status_format = 1

    def handle_starttag(self, tag, attrs):
        if tag == "b":
            return
        self.store = False
        if self.status <= self.performance_info:
            if tag == "dt":
                self.store = True
        elif self.status <= self.scoreboard:
            if tag == "pre":
                self.store = True
        elif self.status <= self.proceses:
            if tag == "tr":
                #if len(self.proceses_data[-1]) != 0:
                if len (self.proceses_data) == 0:
                    self.proceses_data.append([])
                else:
                    if len(self.proceses_data[-1]) > 0:
                        self.proceses_data.append([])

            elif tag == "td":
                self.store = True

    def handle_endtag(self, tag):
        if tag == "b":
            return
        self.store = False
        self.append = False
        if self.status <= self.performance_info and tag == "dl":
            self.status += 1
        elif self.status <= self.scoreboard and tag == "pre":
            self.status += 1
        elif self.status <= self.proceses and tag == "table":
            self.status += 1

    def handle_data(self,data):
        if self.store and data != "\n":
            if self.status <= self.performance_info:
                self.performance_info_data.append(data.replace("\n",""))
            elif self.status <= self.scoreboard:
                self.scoreboard_data.append(data.replace("\n",""))
            elif self.status <= self.proceses:
                if not self.append:
                    self.proceses_data[-1].append(data.replace("\n",""))
                else:
                    self.proceses_data[-1][-1] += data.replace("\n","")

    def handle_charref(self, ref):
        self.append = True
        self.handle_data("&#%s;" % ref)

    def handle_entityref(self, ref):
        self.append = True
        self.handle_data("&%s;" % ref)

    def eval_data(self):
        for process in self.proceses_data:
            # PID
            try:
                process[1] = eval(process[1])
            except:
                process[1] = 0
            # Acc Number of accesses this connection / this child / this slot
            process[2] = process[2].split("/")
            process[2][0] = eval(process[2][0])
            process[2][1] = eval(process[2][1])
            process[2][2] = eval(process[2][2])
            # M Mode of operation
            #pass
            # CPU CPU usage, number of seconds
            process[4] = eval(process[4])
            # SS Seconds since beginning of most recent request
            process[5] = eval(process[5])
            # Req Milliseconds required to process most recent request
            process[6] = eval(process[6])
            # Conn Kilobytes transferred this connection
            process[7] = eval(process[7])
            # Child Megabytes transferred this child
            process[8] = eval(process[8])
            # Slot Total megabytes transferred this slot
            process[9] = eval(process[9])

def usage(exit = 1):
    print main.__doc__
    sys.exit(exit)

def print_screen(screen, url, show_scoreboard, apache_version):
    screen = stdscr.subwin(0, 0)
    screen.nodelay(1)

    end = False
    sort = 5
    message = ""
    reverse = True
    show_only_active = True
    y = 0
    c = ""

    while not end:
        try:
            try:
                c = screen.getkey()
            except:
                pass

            if c == "q":
                # sortir
                end = True
                break
            elif c == "P":
                # ordenar per PID
                sort = 1
                message = "Sort by PID"
            elif c == "C":
                # ordenar per cpu
                sort = 4
                message = "Sort by CPU usage"
            elif c == "S":
                # ordenar per SS"
                sort = 5
                message = "Sort by Seconds since beginning of most recent request"
            elif c == "V":
                # ordenar per vhost
                sort = 11
                message = "Sort by VirtualHost"
            elif c == "M":
                # ordenar per Mode of operation
                sort = 3
                message = "Sort by Mode of operation"
            elif c == "R":
                # ordenar per request
                sort = 12
                message = "Sort by Request"
            elif c == "I":
                # ordenar per ip
                sort = 10
                message = "Sort by IP"
            elif c == "s":
                # mostrar scoreboard"
                if show_scoreboard == 0:
                    show_scoreboard = 1
                    message = "Showing mod_status scoreboard"
                else:
                    show_scoreboard = 0
                    message = "Hiding mod_status scoreboard"
                    y = 0
            elif c == "a":
                # mostra els actius
                if show_only_active:
                    show_only_active = False
                    message = "Show all processes"
                else:
                    show_only_active = True
                    message = "Show only active processes"
            elif c == "r":
                # cambiar l'ordre
                if reverse:
                    reverse = False
                    message = "Reversed sorting"
                else:
                    reverse = True
                    message = "Normal sorting"
            c = ""

            data = ApacheStatusParser()
            data.set_apache_version(apache_version)
            statusdata = urllib.urlopen(url).read()
            data.feed(statusdata)
            data.eval_data()
            #width = curses.tigetnum('cols') or 80
            #height = curses.tigetnum('lines') or 24
            (height, width) = screen.getmaxyx()
            screen.clear()

            info_uptime = info_restart = info_cpu = info_rps = info_requests = ""
            for line in data.performance_info_data:
                line_uptime = RE_UPTIME.match(line)
                if line_uptime:
                    info_uptime = "Uptime: " + line_uptime.group(1)

                line_restart = RE_RESTART.match(line)
                if line_restart:
                    info_restart = "Restart Time: " + line_restart.group(1)

                line_cpu = RE_CPU.match(line)
                if line_cpu:
                    info_cpu = "CPU Usage: " + line_cpu.group(1)

                line_rps = RE_RPS.match(line)
                if line_rps:
                    info_rps = line_rps.group(1)

                line_requests = RE_REQUESTS.match(line)
                if line_requests:
                    info_requests = line_requests.group(1) + "/" + line_requests.group(2)

            display_uptime = info_uptime.replace(" days","d").replace(" day","d").replace(" hours","h").replace(" hour","h").replace(" minutes","m").replace(" minute","m").replace(" seconds","s").replace("second","s") + ", " + info_restart
            display_cpu = info_cpu
            display_requests = info_rps + ", Active/Idle: " + info_requests

            # # imprimim el header
            screen.addstr(0, 0, display_uptime)
            screen.addstr(1, 0, display_cpu)
            screen.addstr(2, 0, display_requests)

            # evaluar scoreboard
            if show_scoreboard:
                y = 6
                screen.addstr(3,0,"  +-------------------------Scoreboard Key-------------------------+")
                screen.addstr(4,0,"  |  _ Waiting for Connection, S Starting up, R Reading Request    |")
                screen.addstr(5,0,"  |  W Sending Reply, K Keepalive (read), D DNS Lookup             |")
                screen.addstr(6,0,"  |  C Closing connection, L Logging, G Gracefully finishing       |")
                screen.addstr(7,0,"  |  I Idle cleanup of worker, . Open slot with no current process |")
                screen.addstr(8,0,"  +----------------------------------------------------------------+")

            # imprimim el scoreboard
            for num in range(0,len(data.scoreboard_data[0]),width):
                 screen.addstr(y+4+num/width,0, data.scoreboard_data[0][num:num+width])

            if len(message) > 0:
                screen.addstr(y+5+num/width,0,message, curses.A_BOLD | curses.A_REVERSE)
                message = ""

            columns = [ 1, 3, 5, 4, 11, 10, 12 ]
            if data.status_format > 2:
                columns = [ 1, 3, 5, 4, 13, 11, 14 ]

            print_proceses(y+6+num/width,0,screen, data.proceses_data, columns=columns, sort=sort, reverse=reverse, width=width, show_only_active=show_only_active )

            #screen.hline(2, 1, curses.ACS_HLINE, 77)
            screen.refresh()
            time.sleep(2)

        except IndexError:
            raise
        except:
            pass

def print_proceses(y,x,screen, proceses, columns, sort, reverse, width, show_only_active = True):
    header = "PID   M SS     CPU  VHost           IP              Request"
    screen.addstr(y,x,header + " "*(width-len(header)), curses.A_REVERSE)

    n = 1

    if sort != None:
        for process in sorted(proceses, key=operator.itemgetter(sort), reverse=reverse):
            n += print_process(y+n,x,screen,process,columns,show_only_active,width)
    else:
        for process in proceses:
            n += print_process(y+n,x,screen,process,columns,show_only_active,width)
    try:
        screen.addstr(y+n,x, " "*width)
    except:
        pass

def print_process(y,x,screen,process,columns,show_only_active,width):
    if not show_only_active or (process[3] != "." and process[3] != "_"):
        try:
            screen.addstr(y,x, " "*width)
            n = x;
            screen.addstr(y,n, str(process[columns[0]])) # SS
            n = n+ 6
            screen.addstr(y,n, process[columns[1]]) # M
            n = n+ 2
            screen.addstr(y,n, str(process[columns[2]])) # PID
            n = n+ 6

            cpu = str(process[columns[3]])
            if len(cpu.split('.')[1]) < 2:
                cpu = cpu + "0"*(2-len(cpu.split('.')[1]))
            screen.addstr(y,n+(4-len(cpu)), cpu) # CPU

            n = n+ 6
            screen.addstr(y,n, str(process[columns[4]])) # VHOST

            n = n+ 16
            screen.addstr(y,n, str(process[columns[5]])) # IP

            n = n+ 15
            screen.addstr(y,n, " " + str(process[columns[6]])) # REQUEST
            return 1
        except:
            return 1
    else:
        return 0

def main(url, stdscr, show_scoreboard, apache_version):
    """Shows the actual status of the Apache web server using the server-status
url. It needs the ExtendedStatus flag

    Usage: apache-top [-s] -u url
        -u url    Url where apache-status is located
          Example: apache-top.py -u http://www.domain.com/server-status
        -s        Show scoreboard


    Interactive keys:
    q    Exit
    P    Sort by PID
    C    Sort by CPU usage
    S    Sort by Seconds since beginning of most recent request
    V    Sort by VirtualHost
    M    Sort by Mopde of operation
    R    Sort by Request
    I    Sort by Ip
    s    Show/Hide mod_status scoreboard
    a    Switch between show all processes and show only active processes (default)
    r    Reverse sort

    """

    cols = {
        "srv":    0,
        "pid":    1,
        "acc":    2,
        "m":    3,
        "cpu":    4,
        "ss":    5,
        "req":    6,
        "conn":    7,
        "child":    8,
        "slot":    9,
        "client":    10,
        "vhost":    11,
        "request":    12
    }

    try:
        print_screen(stdscr,url,show_scoreboard,apache_version)
    except:
        raise


if __name__ == "__main__":

    url = None
    show_scoreboard = False
    try:
        opt_list = getopt.getopt(sys.argv[1:], "u:h:s")
    except:
        usage()

    for opt in opt_list[0]:
        if opt[0]=="-h":
            usage(0)
        elif opt[0]=="-s":
            show_scoreboard = True
        elif opt[0]=="-u":
            url = opt[1]
        else:
            usage

    if url == None:
        print "*** ERROR: Url missing\n"
        usage()

    # detect apache version
    try:
        statusdata = urllib.urlopen(url).read()
        apache_version = re.search('Server Version: Apache/([^ ]+)', statusdata).group(1)
    except:
        print "ERROR parsing the data. Please, make sure you are alowed to read the server-status page and you have ExtendedStatus flag activated"

    try:
        # Initialize curses
        stdscr=curses.initscr()
        # Turn off echoing of keys, and enter cbreak mode,
        # where no buffering is performed on keyboard input
        curses.noecho()
        curses.cbreak()
        curses.curs_set(0)
        # In keypad mode, escape sequences for special keys
        # (like the cursor keys) will be interpreted and
        # a special value like curses.KEY_LEFT will be returned
        stdscr.keypad(1)
        try:
            main(url,stdscr,show_scoreboard,apache_version)                    # Enter the main loop
        except:
            raise
        # Set everything back to normal
        curses.curs_set(1)
        stdscr.keypad(0)
        curses.echo()
        curses.nocbreak()
        curses.endwin()                 # Terminate curses

    except:
        # In event of error, restore terminal to sane state.
        stdscr.keypad(0)
        curses.echo()
        curses.nocbreak()
        curses.endwin()
        #traceback.print_exc()           # Print the exception
        print "ERROR parsing the data. Please, make sure you are alowed to read the server-status page and you have ExtendedStatus flag activated"
