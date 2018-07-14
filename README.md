Сollection of TCL scripts for Cisco IOS penetration testing
=======
With TCLproxy you can use any Cisco IOS hardware as a pivoting station. It's easy to set up and use!

Features
---------------------------

 * TCLmap — Port scanner implementation (nmap)
 * TCLproxy — Proxy server implementation


TCLproxy
--------
TCLproxy is a tool for pivoting through Cisco devices. It's capable to forward any TCP port or launch a proxy server.


```
TCLproxy v0.0.3

Usage: tclsh ./tclproxy.tcl [-L address]... [-D address]...

Proxy server implementation. Binary protocols are supported.

  -L [bind_address:]port:remote_host:remote_port
    Forward a remote port to a local port.
    Multiple connections and multiple forwards are supported.

  -D [bind_address:]port
    Launch a SOCKS4a proxy server.

 Forwarding between VRF tables:
    -D [VRF_table_for_listening@][bind_address]:port[@VRF_table_for_outbound_connections]
    -L [VRF_table_for_listening@][bind_address]:port[@VRF_table_for_outbound_connections]:remote_host:remote_port

  optional arguments:
  -f, --disable-eof-check      Speed increases by 1-15 KB/s, but connections don't close automatically. Dangerous!
  -h, --help                   Show this help message and exit.
  -q, --disable-output         Quite mode. In this mode, you can disconnect from the console without script termination. Dangerous!
  -l, --low-ports              Use privileged source ports. Required for NFS (source port increments from 1 to 1023 every connection)
  -n, --disable-dns            Do not resolve DNS names in SOCKS mode

  The effect of --disable-eof-check and --disable-output options depends on hardware architecture and firmware version.

   example:
    $ sudo py3tftp -p 69
    cisco# configure terminal
    cisco(config)# scripting tcl low-memory 5242880
    cisco(config)# end
    cisco# copy tftp://192.168.1.10/tclproxy.tcl flash:/
    cisco# tclsh tclproxy.tcl -h
    cisco# tclsh tclproxy.tcl -L 5901:10.0.0.1:445 -D :5902@enterpriseVRF -D 5900
    ...
    cisco# del flash:/tclproxy.tcl

```

About TCL
=========
TCL is a high-level, general-purpose, interpreted, dynamic programming language. Cisco IOS implements TCL 8.3.4:

```
cisco# tclsh
cisco(tcl)# puts $tcl_version
8.3

cisco(tcl)# puts $tcl_patchLevel
8.3.4
```

How to use TCLtools?
===========================
TCLtools requires privilege level 15 on the hardware.

There are four methods to upload TCL scripts:

1. Copy tcl script from ftp or tftp server:

```
cisco# copy tftp://192.168.1.10/tclproxy.tcl flash:/
cisco# copy ftp://192.168.1.10/tclproxy.tcl flash:/
cisco# tclsh tclproxy.tcl
```

2. Create new file via tclsh:

```
$ cat tclproxy.tcl | sed -E 's/([{}$\[])/\\\1/g'
cisco# tclsh
cisco(tcl)# puts [open "flash:tclproxy.tcl" w+] {
cisco(tcl)# ; Copy file contents onto this
cisco(tcl)# }
cisco(tcl)# exit
cisco#
cisco# tclsh tclproxy.tcl
```

3. Set $argv var and put script code into tclsh (non-recommended):

```
cisco# tclsh
cisco(tcl)# set argv [list -D 1080]
cisco(tcl)# ; Copy file contents onto this
```

4. Use "scripting tcl init" command (non-recommended):

```
cisco# configure terminal
cisco(config)# scripting tcl init ftp://192.168.1.10/tclproxy.tcl
cisco(config)# end
cisco# tclsh
```

A good practice is to set the minimum size of free memory:

```
cisco# configure terminal
cisco(config)# scripting tcl low-memory 5242880
cisco(config)# end
```

Also you can monitor device performance with the following commands:

```
cisco# show processes cpu | i Tcl
cisco# show processes mem | i Tcl
```

Remarks
=======================

 * Do not use TCLproxy for TCP/IP port scanning. Because Cisco doesn't implement -async socket option, socks server is interrupted for 30 seconds after every connection to any filtered port.
 * Outdated IOS versions can redirect TCL output to another console. It's an IOS bug.
 * If you disconnect from the console, TCL script stops after the next output.


Tested on Cisco 2811 / Cisco 2821 Integrated Services Router, Cisco Catalyst 2960, and Cisco Catalyst 3750-X.

Contact Us
==========

You can Open a New Issue to report a bug or suggest a new feature to improve the project. Or you can drop a few lines at mohemiv@gmail.com.