SOASTAPERFPERL
==============

PERL Script to allow you to capture SOASTA CloudTest Performance Test data back into Jenkins with plotting and alerting.

Purpose: This PERL script is designed to allow you to automatically provide performance testing results and trending information at every build step. The PERL script will allow you to define a load test on a CloudTest server, and capture results of that load test back into Jenkins, where it can fail the build based on user-defined performance criteria, as well as show trending information for each build.

Setup:
1.  Install the Plot Plugin in Jenkins
2.  In source code management for one of your builds:
	a) Switch to multiple SCM
	b) Add a pull from GitHub for https://github.com/mostenberg/SOASTAPERFPERL  This will pull down the PERL script and libraries, as well as the SCOMMAND tool which allows us to kick off the load test.
	c) Have the repository placed into a separate sub-directory called 'SOASTA'
3.  Add a build step to first switch to the SOASTA directory , and then run the PERL script
	a) Available command line switched are:
		i)    username=<NAME>  		(required) - the Username used to login to the CloudTest server
		ii)   password=<PWD>  		(required) - The password used to login to the CloudTest Server.
		iii)  url=<URL>      		(required) - The URL of the CloudTest server (e.g. http://myserver.com/concerto )
		iv)   compname=<NAME2> 		(required) - The name of the composition to play on the CloudTest server
		v)   '<NAME>:avg:<VALUE>'  	(optional) - A transaction name and threshold for the average response time.
		vi)  '<NAME>:90th:<VALUE>'  (optional) - A transaction name and threshold for the 90th percentile time
		vii) '<NAME>:min:<VALUE>'  	(optional) - A transaction name and threshold for the minimum response time
		viii)'<NAME>:max:<VALUE>   	(optional) - A transaction name and threshold for maximum response time.
		ix)  '<NAME>:BytesSent:<VALUE>  (optional) - A transaction name and threshold for total bytes sent.
		x)   '<NAME>:BytesRcvd:<VALUE>  (optional) - A transaction name and threshold for total bytes received.
		xi)  '<NAME>:Errors:<VALUE>     (optional) - A transaction name and threshold for number of errors in that transaction
		xii) '<NAME>:Count:<VALUE>		(optional) - A transaction name and threshold for min number of transactions.
4.  Running the PERL script will create several .csv files in the SOASTA folder of your workspace for things like average response time, 90th percentile response time and errors. Use the 'Add Plot' option on the build to create graphs of these values.
5.	Running the PERL script created a file in the SOASTA directory of your workspace called : 5_PERF_THRESHOLD_RESULTS.xml . This file contains PASS/FAIL info for each of the transactions you set a threshold for in your load test.  Add a step in the build to 'Publish JUNIT Test Result Report' which will utilize this file for the data.