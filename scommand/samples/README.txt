==========================================
CloudTest Command-Line Utility ("SCommand")
==========================================

------------------------------------------
Introduction
------------------------------------------
The CloudTest Command-Line Utility (a.k.a. "SCommand") is a utility for Windows,
Mac OS X, and Unix that can perform common tasks without using the browser.

------------------------------------------
Requirements
------------------------------------------
On Windows and Unix, SCommand requires a Java(TM) Runtime.  The Oracle Java
Runtime can be downloaded for free from http://www.java.com/getjava.

Mac OS X versions up until OS X 10.6 (Snow Leopard) include a Java runtime out-of-the-box.

For OS X 10.7+, you must now download and install the Java RTE yourself. 
The Java RTE is actively removed by the 10.7+ updater if a user is updating from a previous version of Mac OS X.

------------------------------------------
ZIP File Contents
------------------------------------------
The ZIP file should contain the following:

This file:
scommand/README.txt

Executable files for Windows, Mac OS X, and Unix:
scommand/bin/
scommand/bin/scommand
scommand/bin/scommand.bat
scommand/bin/setclasspath
scommand/bin/setclasspath.bat

Dependencies:
scommand/lib/
scommand/lib/scommand.jar
scommand/lib/core.jar
scommand/lib/axis.jar
scommand/lib/commons-discovery-0.2.jar
scommand/lib/commons-logging-1.0.4.jar
scommand/lib/jaxrpc.jar
scommand/lib/saaj.jar
scommand/lib/wsdl4j-1.6.jar
scommand/lib/stax-api-1.0.1.jar
scommand/lib/wstx-asl-3.2.7.jar
scommand/lib/activation.jar
scommand/lib/mail.jar

------------------------------------------
Running SCommand
------------------------------------------
To run SCommand on Windows, use the following syntax:
C:\> scommand\bin\scommand.bat [parameters]

To run SCommand on Mac OS X or Unix, use the following syntax:
$ scommand/bin/scommand [parameters]

------------------------------------------
Using Built-In Help
------------------------------------------
To use the SCommand built-in help system, use the "help" parameter (e.g.
"scommand help").  You will see a list of supported sub-commands:

   delete
   drain
   export
   help
   import
   list
   play
   start
   status
   stop

To see the built-in help for a given command, use the "help" parameter followed
by the command name (e.g. "scommand help delete").

------------------------------------------
Examples
------------------------------------------
SCommand is invoked by specifying the command type using the "cmd" parameter.
A common mistake is forgetting to put "cmd=" before the command type.  E.g.:

scommand delete (incorrect)
scommand cmd=delete (correct)

The "url", "username", and "password" parameters are always required.  They
should be set to the CloudTest URL, your CloudTest user name, and your CloudTest
password.  For example:

scommand url=http://myserver/concerto username=bob password=secret

Here is a complete example, which will delete the Test Composition named "/My
Comp":

scommand cmd=delete url=http://myserver/concerto username=bob password=secret
         type=composition name="/My Comp"

Please consult the built-in help system for more examples of specific commands.

------------------------------------------
Using an HTTP Proxy
------------------------------------------
To use SCommand with an HTTP proxy, add the "httpproxyhost" and "httpproxyport"
parameters.  For example:

scommand cmd=delete url=http://myserver/concerto username=bob password=secret
         httpproxyhost=myproxyserver httpproxyport=8080
         type=composition name="/My Comp"

In addition, if the proxy requires credentials, you can add the
"httpproxyusername" and "httpproxypassword" parameters.

==========================================
Copyright (C) 2006-2011 SOASTA, Inc.
All rights reserved.

Portions of this software developed by the Apache Software Foundation.
