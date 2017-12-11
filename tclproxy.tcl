#!/usr/bin/env tclsh

# Help implementation

proc help {} {
    puts "TCLproxy v0.0.2"
    puts ""
    puts "Usage: tclsh $::argv0 \[-L address]... \[-D address]..."

    puts ""
    puts "Proxy server implementation."
    puts ""
    puts "  -L \[bind_address:]port:remote_host:remote_port"
    puts "    The script will forward a remote port to a local port."
    puts "    Multiple connections and multiple forwarding are supported."
    puts ""
    puts "  -D \[bind_address:]port"
    puts "    The script will create a SOCKS4a proxy."
    puts ""
    puts " You can also use forwarding between some VRF tables if it is possible on this hardware:"
    puts "    -D \[VRF_server_table@]\[bind_address]:port\[@VRF_clients_table]"
    puts "    -L \[VRF_server_table@]\[bind_address]:port\[@VRF_clients_table]:remote_host:remote_port"
    puts ""
    puts "  optional arguments:"
    puts "  -f, --upgrade-the-speed      The speed can be increased by 1-15 KB/s, but connections don't close automatically. Dangerous!"
    puts "  -h, --help                   Show this help message and exit."
    puts "  -q, --disable-output         Quite mode. Dangerous, sometimes you can not stop the script after the start!"
    puts "  -l, --low-ports              Use privileged source ports (they will be incremented from 1 to 1023 consistently)"
    puts "  -n, --disable-dns            Never do DNS resolution with -D"
    puts ""
    puts "   example:"
    puts "    $ sudo py3tftp -p 69"
    puts "    cisco# configure terminal"
    puts "    cisco(config)# scripting tcl low-memory 5242880"
    puts "    cisco(config)# end"
    puts "    cisco# copy tftp://192.168.1.10/tclproxy.tcl flash:/" ;# copy tftp://192.168.88.100/tclproxy.tcl flash:/
    puts "    cisco# tclsh tclproxy.tcl -h"
    puts "    cisco# tclsh tclproxy.tcl -L 59001:10.0.0.1:445 -D 59000"
    puts "    ..."
    puts "    cisco# del flash:/tclproxy.tcl"
}

if {$argc == 0} {
    help

    puts ""
    puts "no command line argument passed"

    return
}

# Configuration

set default_fconfigure_options [list -translation {binary binary} -encoding binary -buffering none]

# Options
set L_option FALSE
set L_option_list [list]

set D_option FALSE
set D_disable_dns FALSE
set D_option_list [list]

set upgrade_the_speed 0
set low_ports 0

# Debug implementation

set DEBUG 1

proc debug {str} {
    global DEBUG

    if {$DEBUG >= 1} {
        puts "debug: $str"
    }
}

proc bgerror {error} {
    catch {debug $error}
}

# Functions for -r, --root-ports             Use privileged source ports

# /**
#  * The function generates numbers between 1 and 1023 consistently
#  *
#  * @return The number between 1 and 1023
#  */

set source_port_inc 0

proc generate_source_port {} {
    global source_port_inc

    incr source_port_inc

    if {$source_port_inc >= 1024} {
        set source_port_inc 1
    }

    return $source_port_inc
}

# Functions for parsing command-line options

# /**
#  * Auxiliary function for parsing -L and -D options.
#  * The function splits the string by a char, checks number of options, and
#  * adds one optional option if one is missed
#  *
#  * @param str String to parse
#  * @param char Delimiter
#  * @param num Number of options
#  * @param insert_pos Position of an optional option
#  *
#  *
#  * @return List with the options or empty string
#  */

proc specific_parse_arg_string {str char num insert_pos} {
    set option_list [split $str $char]
    set len [llength $option_list]

    if {$len == $num} {
        return $option_list
    } elseif {$len == ($num - 1)} {
        set option_list [linsert $option_list $insert_pos ""]
        return $option_list
    }

    return ""
}

# /**
#  * Parse the string as -D argument
#  *
#  * @param str String to parse
#  *
#  * @return [list
#  *                /* Options for binding to some port on the local host */
#  *                /* Options for new chains for remote hosts*/
#  *                /* A string to debug */
#  *         ]
#  */

proc parse_D_option {str} {
    set recept_chain_args [list]
    set transmiss_chain_args [list]
    set debug ""

    set plist [specific_parse_arg_string $str ":" 2 0]

    if {$plist == ""} {
        return ""
    }

    set part1 [specific_parse_arg_string [lindex $plist 0] "@" 2 0]
    set part2 [specific_parse_arg_string [lindex $plist 1] "@" 2 1]

    if {$part1 != ""} {
        set recept_vrf [lindex $part1 0]
        set recept_bind_addr [lindex $part1 1]

        if {$recept_vrf != ""} {
            lappend recept_chain_args -myvrf $recept_vrf
            append debug "VRF \"$recept_vrf\" "
        }

        if {$recept_bind_addr != ""} {
            lappend recept_chain_args -myaddr $recept_bind_addr
            append debug "$recept_bind_addr"
        }
    } else {
        append debug "0.0.0.0"
    }

    if {$part2 == ""} {
        return ""
    }

    set recept_bind_port [lindex $part2 0]
    set transmiss_vrf [lindex $part2 1]

    lappend recept_chain_args $recept_bind_port
    append debug ":$recept_bind_port"

    if {$transmiss_vrf != ""} {
        lappend transmiss_chain_args -myvrf $transmiss_vrf
        append debug " VRF \"$transmiss_vrf\""
    }

    return [list $recept_chain_args $transmiss_chain_args $debug]
}

# /**
#  * Parse the string as -L argument
#  *
#  * @param str String to parse
#  *
#  * @return [list
#					/* Options for binding to some port on the local host */
#					/* Options for new chains for remote hosts*/\
#					/* A string to debug */
#			 ]
#  */

proc parse_L_option {str} {
    set plist [specific_parse_arg_string $str ":" 4 0]

    if {$plist == ""} {
        return ""
    }

    set bind_options [join [lrange $plist 0 1] ":"]
    set remote_host [lindex $plist 2]
    set remote_port [lindex $plist 3]

    set part1 [parse_D_option $bind_options]

    set recept_chain_args [lindex $part1 0]
    set transmiss_chain_args [lindex $part1 1]
    set debug [lindex $part1 2]

    lappend transmiss_chain_args $remote_host $remote_port
    append debug " => $remote_host:$remote_port"

    return [list $recept_chain_args $transmiss_chain_args $debug]
}

# Parsing command-line options

for {set i 0} {$i < $argc} {incr i} {
    set arg [lindex $argv $i]

    if {$arg == "-L"} {
        set L_option TRUE
        incr i

        if {$argc == $i} {
            puts "option requires an argument -- $arg"
            return
        }

        set option_list [parse_L_option [lindex $argv $i]]

        if {$option_list == ""} {
            puts "Bad local forwarding specification '[lindex $argv $i]'"
            return
        }

        lappend L_option_list $option_list
    } elseif {$arg == "-D"} {
        set D_option TRUE
        incr i

        if {$argc == $i} {
            puts "option requires an argument -- $arg"
            return
        }

        set option_list [parse_D_option [lindex $argv $i]]

        if {$option_list == ""} {
            puts "Bad dynamic forwarding specification '[lindex $argv $i]'"
            return
        }

        lappend D_option_list $option_list
    } elseif {$arg == "-h" || $arg == "--help"} {
        help
        return
    } elseif {$arg == "-q" || $arg == "--disable-output"} {
        set DEBUG 0
    } elseif {$arg == "-f" || $arg == "--upgrade-the-speed"} {
        set upgrade_the_speed 1
    } elseif {$arg == "-r" || $arg == "--low-ports"} {
        set low_ports 1
    } elseif {$arg == "-n" || $arg == "--disable-dns" } {
        set D_disable_dns TRUE
    } else {
        puts "$arg: invalid option"
        return
    }
}

# Port forwarding

# /**
#  * Copy data from chain to chain
#  *
#  * @param a Inout chain
#  * @param b Output chain
#  * @param debug Debug string
#  *
#  */

proc read_chan_from_a_to_b {a b debug} {
    if {[catch {puts -nonewline $b [read $a 4096]} error]} {
        debug "$error for $debug"

        close $a
        close $b
        return
    }

    if {[eof $a] || [eof $b]} {
        close $a
        close $b
    }
}

# /**
#  * Copy data from hain to chain
#  *
#  * @param a Inout chain
#  * @param b Output chain
#  *
#  */

proc read_chan_from_a_to_b_2 {a b} {
    puts -nonewline $b [read $a 4096]
}

# /**
#  * Handler for client connections (-L option)
#  * The arguments сan be formed through "parse_D_option" or "parse_L_option" functions and a fileevent
#  *
#  * @param transmiss_chain_args
#  * @param debug
#  * @param chan_client
#  * @param client_addr
#  * @param client_port
#  *
#  */

proc forward_port_handler {transmiss_chain_args debug chan_client client_addr client_port} {
    global default_fconfigure_options
    global upgrade_the_speed
    global low_ports

    if {$low_ports == 1} {
         set source_port [generate_source_port]
	 set source_port_debug "sp $source_port "

         set transmiss_chain_args [linsert $transmiss_chain_args 0 -myport $source_port]
    } else {
        set source_port_debug ""
    }

    set debug_str "$client_addr:$client_port $source_port_debug=> $debug"
    debug "TCP $debug_str"





    if {[catch {set chan_remote_host [eval socket $transmiss_chain_args]} error]} {
         debug "$error for connect to remote address ($debug)"

         close $chan_client
         return
    }

    eval fconfigure $chan_client $default_fconfigure_options -blocking 0
    eval fconfigure $chan_remote_host $default_fconfigure_options -blocking 0

    if {$upgrade_the_speed == 1} {
        fileevent $chan_client readable [list read_chan_from_a_to_b_2 $chan_client $chan_remote_host ]
        fileevent $chan_remote_host readable [list read_chan_from_a_to_b_2 $chan_remote_host $chan_client]
    } else {
        fileevent $chan_client readable [list read_chan_from_a_to_b $chan_client $chan_remote_host $debug]
        fileevent $chan_remote_host readable [list read_chan_from_a_to_b $chan_remote_host $chan_client $debug]
    }
}

# /**
#  * Listen a local port and forward any connections to a remote port
#  * The arguments сan be formed through "parse_D_option" or "parse_L_option" functions
#  *
#  * @param recept_chain_args
#  * @param transmiss_chain_args
#  * @param debug
#  */

proc forward_port {recept_chain_args transmiss_chain_args debug} {
    set server_handler [list forward_port_handler $transmiss_chain_args $debug]

    debug "Forward listener: $debug"
    set recept_chain_args [linsert $recept_chain_args 0 -server $server_handler]

    if {[catch {eval socket $recept_chain_args} err]} {
        debug "$err $debug"
    }
}

# SOCKS proxy

# /**
#  * Convert the ip from "binary scan c4" format to text
#  *
#  * @param ip Ip-sddres
#  *
#  * @return Ip-addres debug
#  */

proc ip_c4_to_text {ip} {
    set ret [list]

    foreach octet $ip {
        lappend ret [expr {$octet & 0xff}]

    }

    return [join $ret "."]
}

# /**
#  * Handler for client CONNECTIONS (-D option)
#  * The arguments сan be formed through "parse_D_option" or "parse_L_option" functions and a fileevent
#  *
#  * @param transmiss_chain_args
#  * @param debug
#  * @param chan_client
#  * @param client_addr
#  * @param client_port
#  *
#  */

proc dynamic_forward_port_handler {transmiss_chain_args debug chan_client client_addr client_port} {
    global D_disable_dns
    global default_fconfigure_options
    global upgrade_the_speed
    global low_ports

    set protocol_error "Client $client_addr:$client_port: protocol mismatch"
    set socks4_error "Error while reading SOCKS4 header (connection from $client_addr:$client_port). "
    append socks4_error "The header must be in one TCP frame without an application data."

    eval fconfigure $chan_client $default_fconfigure_options -blocking 1

    if {![binary scan [read $chan_client 1] "c" socks_version]} {
        debug "Client $client_addr:$client_port has been disconnected before transferring"
        close $chan_client
        return
    }

    if {$socks_version == 4} { ;# SOCKS4
        if {![binary scan [read $chan_client 7] "cSc4" connection_type remote_port ip]} {
            debug $protocol_error
            close $chan_client
            return
        }

        if {$connection_type == 2} { ;# establish a TCP/IP port binding
            debug "Client $client_addr:$client_port: Socks binding is not supported, use -L option"
            close $chan_client
            return
        } elseif {$connection_type == 1} { ;# establish a TCP/IP stream connection
            eval fconfigure $chan_client  -blocking 0

            set c_strings [split [read $chan_client 256] "\x00"] ;# Read an identity string and SOCKS4a domain name
            set c_strings_len [llength $c_strings]

            if {[lindex $ip 0] == 0 && [lindex $ip 1] == 0 && [lindex $ip 2] == 0 && [lindex $ip 3] != 0} { ;# SOCKS4a
                set protocol "SOCKS4a"

                if {$c_strings_len != 3} {
                    debug $socks4_error
                    close $chan_client
                    return
                }

                set remote_host [lindex $c_strings 1]

                if {$D_disable_dns} { ;# -n, --disable-dns
                    puts -nonewline $chan_client "\x00\x5B\xE2\xE4\xE7\xE5\xF2\xF4" ;
                    debug "Client $client_addr:$client_port: DNS resolving is disabled, host $remote_host"
                    close $chan_client
                    return
                }
            } else { ;# SOCKS4
                set protocol "SOCKS4"

                if {$c_strings_len != 2} {
                    debug $socks4_error
                    close $chan_client
                    return
                }
                set remote_host [ip_c4_to_text $ip]
            }

            if {$low_ports == 1} {
                 set source_port [generate_source_port]
		 set source_port_debug "sp $source_port "

                 lappend transmiss_chain_args -myport $source_port
            } else {
		 set source_port_debug " "
            }

            debug "TCP $client_addr:$client_port => $protocol $debug $source_port_debug=> $remote_host:$remote_port"

            if {[catch {set chan_remote_host [eval socket $transmiss_chain_args $remote_host $remote_port]} error]} {
                debug "TCP $client_addr:$client_port => $debug => $remote_host:$remote_port: $error"

                puts -nonewline $chan_client "\x00\x5B\xE2\xE4\xE7\xE5\xF2\xF4" ;# request rejected or failed
                close $chan_client
                return
            }

            eval fconfigure $chan_remote_host $default_fconfigure_options -blocking 0

            puts -nonewline $chan_client "\x00\x5A\xE2\xE4\xE7\xE5\xF2\xF4" ;# request granted

            if {$upgrade_the_speed == 1} {
                fileevent $chan_client readable [list read_chan_from_a_to_b_2 $chan_client $chan_remote_host ]
                fileevent $chan_remote_host readable [list read_chan_from_a_to_b_2 $chan_remote_host $chan_client]
            } else {
                fileevent $chan_client readable [list read_chan_from_a_to_b $chan_client $chan_remote_host $debug]
                fileevent $chan_remote_host readable [list read_chan_from_a_to_b $chan_remote_host $chan_client $debug]
            }
        } else {
            debug $protocol_error
            close $chan_client
            return
        }
    } elseif {$socks_version == 5} { ;# SOCKS5
        debug "Client $client_addr:$client_port: SOCKS5 protocol is not supported, use SOCKS4a"
        close $chan_client
        return
    } else {
        debug $protocol_error
        close $chan_client
    }
}

# /**
#  * Create SOCKS on a local port
#  * The arguments сan be formed through "parse_D_option" or "parse_L_option" functions
#  *
#  * @param recept_chain_args
#  * @param transmiss_chain_args
#  * @param debug
#  */

proc dynamic_forward_port {recept_chain_args transmiss_chain_args debug} {
    set server_handler [list dynamic_forward_port_handler $transmiss_chain_args $debug]
    debug "SOCKS listener: $debug"

    set recept_chain_args [linsert $recept_chain_args 0 -server $server_handler]

    if {[catch {eval socket $recept_chain_args} err]} {
        debug "$err $debug"
    }
}

if {$L_option} {
    foreach item $L_option_list {
        eval forward_port $item
    }
}

if {$D_option} {
    foreach item $D_option_list {
        eval dynamic_forward_port $item
    }
}

if {$L_option || $D_option} {
     if {[catch {vwait forever} error]} {
        catch {debug "$error"}
     }
}
