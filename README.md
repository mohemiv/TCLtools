Сollection of TCL scripts for Cisco IOS penetration testing
=======
TCLtools — Сollection of TCL scripts for Cisco IOS penetration testing

What software is featured?
---------------------------

 * TCLproxy — Proxy server implementation

TCLproxy
--------
TCLproxy can be used to create SOCKS4a proxy server or forward a remote port to a local port.

```
TCLproxy v0.0.2

Usage: tclsh ./tclproxy.tcl [-L address]... [-D address]...

Proxy server implementation.

  -L [bind_address:]port:remote_host:remote_port
    The script will forward a remote port to a local port.
    Multiple connections and multiple forwarding are supported.

  -D [bind_address:]port
    The script will create a SOCKS4a proxy.

 You can also use forwarding between some VRF tables if it is possible on this hardware:
    -D [VRF_server_table@][bind_address]:port[@VRF_clients_table]
    -L [VRF_server_table@][bind_address]:port[@VRF_clients_table]:remote_host:remote_port

  optional arguments:
  -f, --upgrade-the-speed      The speed can be increased by 1-15 KB/s, but connections don't close automatically. Dangerous!
  -h, --help                   Show this help message and exit.
  -q, --disable-output         Quite mode. Dangerous, sometimes you can not stop the script after the start!
  -l, --low-ports              Use privileged source ports, for NFS (they will be incremented from 1 to 1023 consistently)
  -n, --disable-dns            Never do DNS resolution with -D

   example:
    $ sudo py3tftp -p 69
    cisco# configure terminal
    cisco(config)# scripting tcl low-memory 5242880
    cisco(config)# end
    cisco# copy tftp://192.168.1.10/tclproxy.tcl flash:/
    cisco# tclsh tclproxy.tcl -h
    cisco# tclsh tclproxy.tcl -L 5901:10.0.0.1:445 -L :5902@enterpriseVRF -D 5900
    ...
    cisco# del flash:/tclproxy.tcl

```

About TCL
=========
TCL is a high-level, general-purpose, interpreted, dynamic programming language. Cisco IOS has a realization of 8.3.4 TCL version:

```
cisco# tclsh
cisco(tcl)# puts $tcl_version
8.3

cisco(tcl)# puts $tcl_patchLevel
8.3.4
```
There are differences between different versions of IOS, but it's possible to write rather stable software for all IOS version.


How to execute the scripts?
===========================
For executing the script you have to obtain privilege level 15 on the hardware.

There are 4 methods to run the scripts:

1. Use command copy:

```
cisco# copy tftp://192.168.1.10/tclproxy.tcl flash:/
cisco# copy ftp://192.168.1.10/tclproxy.tcl flash:/
cisco# tclsh tclproxy.tcl
```

2. Use tclsh to create a file:

```
$ cat tclproxy.tcl | sed -E 's/([{}$\[])/\\\1/g'
cisco# tclsh
cisco(tcl)# puts [open "flash:tclproxy.tcl" w+] {
cisco(tcl)# ; Copy and paste the file contents into the field.
cisco(tcl)# }
cisco(tcl)# exit
cisco#
cisco# tclsh tclproxy.tcl
```

3. Redefine $argv in top of the script and copy one to a tclsh:

```
set argv [list -D 1080]
```

4. Use "scripting tcl init" command:

```
cisco# configure terminal
cisco(config)# scripting tcl init ftp://192.168.1.10/tclproxy.tcl
cisco(config)# end
cisco# tclsh
```

Good practice is setting limit to the minimum size of free memory:

```
cisco# configure terminal
cisco(config)# scripting tcl low-memory 5242880
cisco(config)# end
```

There are commands to control current consumption of CPU or MEM of tcl scripts:

```
cisco# show processes cpu | i Tcl
cisco# show processes mem | i Tcl
```

Remarks for the scripts
=======================

 * Do not use TCLproxy for TCP/IP port scanning. Cisco TCL doesn't support -async option of socket, and the SOCKS will not work about 30 seconds after any connection to a filtered port.
 * On older versions of IOS scripts can write the output to another console. It's an IOS bug.
 * The script should be stopped after the script will write something to the console when the session is broken


The scripts were tested on Cisco 2811 / Cisco 2821 Integrated Services Router, Cisco Catalyst 2960, and Cisco Catalyst 3750-X.

Contact Us
==========

You can Open a New Issue to report a bug or suggest a new feature. Or you can drop a few lines at mohemiv@gmail.com.

