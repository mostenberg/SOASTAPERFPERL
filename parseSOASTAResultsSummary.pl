#!/usr/local/bin/perl

# Written by Mike Ostenberg of SOASTA , Jan 2, 2013
# Usage: This PERL script will allow you to specify the names of CloudTest transactions, as well as 
# threshold values for when those transactions should be considered 'failed'.  It will then review a 
# SOASTA CloudTest results file and find all of the named transactions and compute their response time and do the following:
#   a) If it can't find a transaction of a given name it will fail the script with an error message of 'Transaction not found'
#	b) If a transaction response time is faster than the acceptable response time it will 'pass' the transaction.
#	c) If a transaction response time is slower than the acceptable response time, it will 'fail' the transaction.
#	d) The Pass/Fail status of all transactions will be passed back to CloudTest in jUnit compatible XML
#	e) A file names 'performanceplot.csv' will be created in local directory to allow performance response time graphing in Jenkins.
#   
#

local $/; #Changes end of line character so whole file will be slurped in.

use lib './libwww-perl-master/lib'; #When launching on CloudBees, this will tell it where to find the HTTP libraries.
use lib './libwww-perl-master/lib/LWP'; #When launching on CloudBees, this will tell it where to find the HTTP libraries.
use lib './libwww-perl-master/lib/LWP'; #When launching on CloudBees, this will tell it where to find the HTTP libraries.
use lib './libwww-perl-master/lib/'; #When launching on CloudBees, this will tell it where to find the HTTP libraries.
use lib './libwww-perl/lib/LWP'; #When launching on CloudBees, this will tell it where to find the HTTP libraries.
use lib './http-message-master/lib/HTTP'; #When launching on CloudBees, this will tell it where to find the HTTP libraries.
use lib './HTTP-Cookies-6.01/lib/HTTP'; #When launching on CloudBees, this will tell it where to find the HTTP libraries.
use lib 'HTTP-Cookies-6.01/lib/HTTP'; #When launching on CloudBees, this will tell it where to find the HTTP libraries.
use lib './SOASTA/HTTP-Cookies-6.01/lib/HTTP'; #When launching on CloudBees, this will tell it where to find the HTTP libraries.
use lib 'SOASTA/HTTP-Cookies-6.01/lib/HTTP'; #When launching on CloudBees, this will tell it where to find the HTTP libraries.
use lib './HTTP-Cookies-6.01/lib'; #When launching on CloudBees, this will tell it where to find the HTTP libraries.
use lib './SOASTA/HTTP-Cookies-6.01/lib'; #When launching on CloudBees, this will tell it where to find the HTTP libraries.
use LWP::UserAgent;
use HTTP::Request;
local %shouldPlot;
$soastaUrl="";


print "\n\n***BEGIN  parseSOASTAResultsSummary.pl\n\n";
print ("***STEP 1. Parse the command line arguments to get the thresholds for each value\n");
#Step 1: Parse the command line arguments to get the thresholds for each of the values.
# Enter the transaction SLA values here. Use the format "Transaction Name:Avg:Value  TransactionName:90th:Value 
# TransactionName:Errors:Value  TransactionName:BytesSent:Value  TransactionName:BytesRecieved:Value"
#Use command line arguments if present. Otherwise, use the %SLA File in the 'if' clause.
$length=@ARGV;
#print ("Number of arguments is $length\n");
if ($length >=1) 
{
	print ("Thresholds based on command line arguments\n");
	printf ("     %-6s %-25s %-6s\n","Type","Name","Value");
	for ($x=0; $x < $length; $x++)
	{
		my $argument=$ARGV[$x];
		if ($argument=~/:Avg:/) 
		{
			(my $name,my $threshold)=split(":Avg:",$argument);
			$SLA{$name}=$threshold;
			printf ("     %-6s %-25s %3.3f \n","Avg",$name,$threshold);
			$shouldPlot{$name}="True";
			$numTests++;
		}
		if ($argument=~/:90th:/) 
		{
			(my $name,my $threshold)=split(":90th:",$argument);
			$SLAninetieth{$name}=$threshold;
			printf ("     %-6s %-25s %3.3f \n","90th",$name,$threshold);
			$shouldPlot{$name}="True";
			$numTests++;
		}
		if ($argument=~/:Errors:/) 
		{
			(my $name,my $threshold)=split(":Errors:",$argument);
			$SLAerrors{$name}=$threshold;
			printf ("     %-6s %-25s %-7i \n","Errors",$name,$threshold);
			$shouldPlot{$name}="True";
			$numTests++;
		}
		if ($argument=~/:BytesSent:/) 
		{
			(my $name,my $threshold)=split(":BytesSent:",$argument);
			$SLAbytesSent{$name}=$threshold;
			printf ("     %-6s %-25s %-7i \n","BytesSent",$name,$threshold);
			$shouldPlot{$name}="True";
			$numTests++;			
		}
		if ($argument=~/:BytesRcvd:/) 
		{
			(my $name,my $threshold)=split(":BytesRcvd:",$argument);
			$SLAbytesRcvd{$name}=$threshold;
			printf ("     %-6s %-25s %-7i \n","BytesRcvd",$name,$threshold);
			$numTests++;	
		}
		if ($argument=~/:Min:/) 
		{
			(my $name,my $threshold)=split(":Min:",$argument);
			$SLAmin{$name}=$threshold;
			printf ("     %-6s %-25s %3.3f \n","Min",$name,$threshold);
			$shouldPlot{$name}="True";
			$numTests++;		
		}
		if ($argument=~/:Max:/) 
		{
			(my $name,my $threshold)=split(":Max:",$argument);
			$SLAmax{$name}=$threshold;
			printf ("     %-6s %-25s %3.3f \n","Max",$name,$threshold);
			$shouldPlot{$name}="True";
			$numTests++;		
		}
		if ($argument=~/:Count:/) 
		{
			(my $name,my $threshold)=split(":Count:",$argument);
			$SLAcount{$name}=$threshold;
			printf ("     %-6s %-25s %7i \n","Count",$name,$threshold);
			$shouldPlot{$name}="True";
			$numTests++;	
		}
		if ($argument=~/username/) 
		{
			(my $temp, $username)=split("=",$argument);
			#print ("Username is $username\n");
		}
		if ($argument=~/password/) 
		{
			(my $temp, $password)=split("=",$argument);
			#print ("Password is $password\n");
		}
		if ($argument=~/url=/) 
		{
			(my $temp,$soastaUrl)=split("=",$argument);
			#print ("Url is $soastaUrl\n");
		}

		if ($argument=~/compname=/) 
		{
			(my $temp,$compName)=split("=",$argument);
			#print ("CompName is $compName\n");
		}
		if ($argument=~/compErrors=/) 
		{
			(my $temp,$maxCompErrors)=split("=",$argument);
			printf ("     %-6s %-25s %7i \n","Max","<Overall Errors>",$maxCompErrors);
			$shouldPlot{"compErrors"}="True";
		}
		
		if ($argument=~/scommandoptions=/) 
		{
			(my $temp,$scommandoptions)=split("=",$argument,2);
			printf ("     %-6s %-25s %40s \n","Txt","Scommand Options",$scommandoptions);
			$shouldPlot{"compErrors"}="True";
		}
		else
		{$scommandoptions="";}
	}
}
else
{
	print "No command line arguments, so drawing values from hard-coded thresholds in PERL script.\n";
	#If you don't want to enter transaction names and max times from command line, then enter the transaction SLA values here. Use the format "Transaction Name"=>"maxResponseTime"
	print ("Usage:
	a) Available command line switches are:
		i)    username=<NAME>  		(required) - the Username used to login to the CloudTest server
		ii)   password=<PWD>  		(required) - The password used to login to the CloudTest Server.
		iii)  url=<URL>      		(required) - The URL of the CloudTest server (e.g. http://myserver.com/concerto )
		iv)   compname=<NAME2> 		(required) - The name of the composition to play on the CloudTest server
		v)   '<NAME>:Avg:<VALUE>'  	(optional) - A transaction name and threshold for the average response time.
		vi)  '<NAME>:90th:<VALUE>'  (optional) - A transaction name and threshold for the 90th percentile time
		vii) '<NAME>:Min:<VALUE>'  	(optional) - A transaction name and threshold for the minimum response time
		viii)'<NAME>:Max:<VALUE>   	(optional) - A transaction name and threshold for maximum response time.
		ix)  '<NAME>:BytesSent:<VALUE>'  (optional) - A transaction name and threshold for total bytes sent.
		x)   '<NAME>:BytesRcvd:<VALUE>'  (optional) - A transaction name and threshold for total bytes received.
		xi)  '<NAME>:Errors:<VALUE>'     (optional) - A transaction name and threshold for number of errors in that transaction
		xii) '<NAME>:Count:<VALUE>'		(optional) - A transaction name and threshold for min number of transactions.
		xiii)'compErrors=<VALUE>'       (optional) - A maximum allowable errors on the whole comp (not necessarily associated to a transaction)
		xiii)'scommandoptions=<VALUE>'        (optional) - An additional string to be appended to the scommand call for additional options. Make sure you put the full item in single quotes
4.  Running the PERL script will create several .csv files in your workspace for things like average response time, 90th percentile response time and errors. Install the plot plugin and then 'Add Plot' to your build to create graphs of these values.
5.	Running the PERL script also creates a file in the SOASTA directory of your workspace called : 5_PERF_THRESHOLD_RESULTS.xml . This file contains PASS/FAIL info for each of the transactions you set a threshold for in your load test.  Add a step in the build to 'Publish JUNIT Test Result Report' which will utilize this file for the data.
"	);
	
}

##
## Pull down the package for scommand and decompress tools
##
print("Pulling down sCommand package from instance $soastaUrl\n") ;

my $ua = LWP::UserAgent->new ;
$ua->mirror($soastaUrl . '/downloads/scommand/scommand.zip', 'scommand.zip');

if ( $^O == 'darwin' )
{
    ## MAC ##
    print("Detected MAC | Linix based operating system\n") ;
    system("unzip -o scommand.zip") ;
    
    print("dumping workspace\n") ;
    system("ls -al") ;

    print("dumping scommand bin folder to check permissions\n") ;
    system("ls -al ./scommand/bin") ;

    ##
    ## Getting permission denied on execution.
    ##
    print("might have to chmod the file but not sure yet\n") ;

    ##
    ## Looks like when we decompress things we have to chmod the scommand file
    ## 

    ## todo: need to make sure this worked ##
}
else
{
    print "error: could not decompress tools for OS = " . $^O . "\n" ;
    exit ( 1 ) ;
}
sleep 5 ;



#STEP 2: Run the loadtest composition
$runCompString = "./scommand/bin/scommand cmd=play name=\"/$compName\" username=$username password=$password url=$soastaUrl wait=yes format=junitxml file=1-SOASTA_RESULTS_ID.xml $scommandoptions";

print "\n*** Step 2: Playing the composition by passing the following arguments to SCOMMAND:\n\t$runCompString\n";
    
##
## TODO: If we fail for whatever reason the system picks up the old result.   
##
system($runCompString);
print("error level = $?\n") ;



#Step 3: Get the results ID out of the file 1-SOASTA_RESULTS_ID.xml . We will pass this into comp
print ("\n*** Step 3: Parse file 1-SOASTA_RESULTS_ID.xml to get performance ResultsID \n");
open FILE, "1-SOASTA_RESULTS_ID.xml" or die "Couldn't open file 1-SOASTA_RESULTS_ID.xml";
$results=<FILE>;
#print ("results are $results\n");
$results =~ /resultID=\"(\d+)\"/;
$resultID=$1;
print ("\tCaptured results id from file.  ResultsID was $resultID\n");
$results =~ /timestamp="(.*?)"/;
$timestamp = $1;
print ("\tCaptured timestamp from file.  Timestamp was $timestamp\n");
#2014-02-14T22:59:53.440-08:00
$guidFromTimestamp = $timestamp;
$guidFromTimestamp=~ s/[-:\.T]//g; #remove the dash,colon,dot and T
$guidFromTimestamp=~ s/\://g;
$guidFromTimestamp=~ s/-//;
$guidFromTimestamp=~ s/T//;
$guidFromTimestamp=~ s/\.//;
$guidFromTimestamp=~ s/2014//;
$guidFromTimestamp = substr($guidFromTimestamp, 0, 12);
print "Guid from TimeStamp is $guidFromTimestamp\n";

$results =~ /errors=\"(\d+)\"/;
$compErrors=$1;
print ("\tCaptured errors from filed. Errors was $compErrors\n");

close FILE;

#STEP 4: Get results details
#NOTE: There's 2 versions of this based on if you're on the older or newer build.

print ("\n*** Step 4: Query the CloudTest server to get the results details for resultID=$resultID\n");
#print ("\tWrite details to file 2_SOASTA_RESULTS_DETAILS.xml\n");

use LWP::UserAgent;
use HTTP::Request;
#$soastaUrl="http://ttlabca.soasta.com";
#$username="mostenbergci";
#$password="soasta";
#$resultId="16109";

my $browser = LWP::UserAgent->new;
$browser->cookie_jar({});  #Enable Cookies

#uncomment the below to record calls in CloudTest
# $browser->proxy(['http', 'ftp'], 'http://localhost:4440/');

my $url="$soastaUrl".'/';
 my @ns_headers = (
   'User-Agent' => 'Mozilla/4.76 [en] (Win98; U)',
   'Accept' => 'image/gif, image/x-xbitmap, image/jpeg, 
        image/pjpeg, image/png, */*',
   'Accept-Charset' => 'iso-8859-1,*,utf-8',
   'Accept-Language' => 'en-US',
  );

 $response1 = $browser->post( $url,
   [
	  ],
   'Accept' => 'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, image/png, */*',
   'Accept-Charset' => 'iso-8859-1,*,utf-8',
   'Accept-Language' => 'en-US',
 );

 $myDataBuild=$response1->content;
 $myDataBuild =~ /\<meta name=\"buildnumber\" content=\"(.*?)\"/;
 $buildNumber = $1;
 print ("Build numer is $buildNumber\n");


#NOTE: THERE ARE 3 DIFFERENT VERSIONS HERE BASED ON YOUR BUILD NUMBER:
#These were tested as follows: I haven't checked all the intermediate builds to see if there are other formats.
	# 6937.83 format 'C'
	# 6937.50 format 'B'
	# 6937.39
	# 6872.35 Format 'A'
	# 
if ($buildNumber>6937.51) {
		print ("Using parsing format 'C' based on build number\n");
		print ("Soasta URL is $soastaUrl\n");
		my $url = "$soastaUrl".'/dwr/call/plaincall/__System.generateId.dwr';
		#print ("Url is $url\n");
		 my @ns_headers = (
		   'User-Agent' => 'Mozilla/4.76 [en] (Win98; U)',
		   'Accept' => 'image/gif, image/x-xbitmap, image/jpeg, 
				image/pjpeg, image/png, */*',
		   'Accept-Charset' => 'iso-8859-1,*,utf-8',
		   'Accept-Language' => 'en-US',
		  );

		sleep 10;
		#Send request #1   
		   $response1 = $browser->post( $url,
		   [
			'callCount'=>'1', 
			'c0-scriptName' => '__System', 
			'c0-methodName'=>'generateId',
			'c0-id'=>'0',
			'batchId'=>'0',
			'instanceId'=>'0',
			'page'=>'%2Fconcerto%2F',
			'scriptSessionId'=>'',
			'windowName'=>''   ],
		   'Accept' => 'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, image/png, */*',
		   'Accept-Charset' => 'iso-8859-1,*,utf-8',
		   'Accept-Language' => 'en-US',
		 );
 
 
		 $myData=$response1->content;
 
		print "Response 1 is $myData \n";
		$myData=~/.handleCallback\(\"\d\",\"\d\",\"(.*?)\"\)/;

		$SystemGeneratedId=$1;
		print "SystemGeneratedId= $SystemGeneratedId \n";
		#r.handleCallback("0","0","WEgC9ZM59FEvoGotA7PpjWbb8ek");
		#system (pwd);  #For debugging, find what directory we're in...
		#Send Request #2
		#goto=&userName=mostenbergci&password=soasta
		my $url2 = "$soastaUrl".'/Login';
		#print ("Url2 is $url2 and $password is $password\n");
		   $response2 = $browser->post( $url2,
		   [
				'goto'=>'',
				'userName'=>$username,
				'password'=>$password
			],
		   'Accept' => 'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, image/png, */*',
		   'Accept-Charset' => 'iso-8859-1,*,utf-8',
		   'Accept-Language' => 'en-US',
		   'DWRSESSIONID'=> "$SystemGeneratedId"
		 );

		$myData2=$response2->content ;
		#print ("Response 2 is $myData2\n");

		print "System generated Id is  $systemGeneratedId\n";

		#Send Request #3
		my $url3 = "$soastaUrl".'/dwr/call/plaincall/CommonPollerProxy.doPoll.dwr';
$postBody='callCount=1
windowName=
c0-scriptName=CommonPollerProxy
c0-methodName=doPoll
c0-id=0
c0-e3=string:AnalysisTask
c0-e4=string:getAnalysisData
c0-e8=number:4
c0-e9=string:'.$resultID.'
c0-e10=boolean:false
c0-e11=null:null
c0-e13=string:0%3A%3A%3A%3A%3A%3A%3A%3A%3A%3A
c0-e12=array:[reference:c0-e13]
c0-e17=string:Duration%20Timespan
c0-e18=string:DurationTimespan
c0-e19=string:Effective
c0-e20=boolean:false
c0-e21=boolean:true
c0-e22=string:
c0-e23=string:
c0-e24=string:
c0-e25=null:null
c0-e16=Object_Object:{attribute:reference:c0-e17, attributeType:reference:c0-e18, comparator:reference:c0-e19, copiedFromDashboard:reference:c0-e20, displayInToolbar:reference:c0-e21, secondaryValue:reference:c0-e22, tertiaryValue:reference:c0-e23, value:reference:c0-e24, valueList:reference:c0-e25}
c0-e15=array:[reference:c0-e16]
c0-e26=boolean:true
c0-e27=boolean:true
c0-e28=string:all
c0-e14=Object_Object:{criteria:reference:c0-e15, enabled:reference:c0-e26, showToolbar:reference:c0-e27, unionType:reference:c0-e28}
c0-e30=null:null
c0-e31=null:null
c0-e32=boolean:true
c0-e33=boolean:true
c0-e34=number:90
c0-e35=number:1.29
c0-e29=Object_Object:{includeStoppedClips:reference:c0-e30, includeFailedClips:reference:c0-e31, includeStoppedCollections:reference:c0-e32, includeFailedCollections:reference:c0-e33, percentile:reference:c0-e34, zValue:reference:c0-e35}
c0-e7=Object_Object:{analysisType:reference:c0-e8, resultID:reference:c0-e9, openAllNodes:reference:c0-e10, openedNodes:reference:c0-e11, openNodeDesignators:reference:c0-e12, widgetFilter:reference:c0-e14, widgetDataRequestCustomSettings:reference:c0-e29}
c0-e6=Object_Object:{analysisWidgetDataRequestBean:reference:c0-e7}
c0-e5=array:[reference:c0-e6]
c0-e36=string:86345a4d-b798-d1c5-51d5-'.$guidFromTimestamp.'
c0-e2=Object_Object:{taskName:reference:c0-e3, methodName:reference:c0-e4, methodArgs:reference:c0-e5, callbackUUID:reference:c0-e36}
c0-e1=array:[reference:c0-e2]
c0-e37=string:'.$buildNumber.'
c0-e38=string:5d230adc-3b54-c9db-4985-'.$guidFromTimestamp.'
c0-param0=Object_Object:{methodRequests:reference:c0-e1, clientVersion:reference:c0-e37, pollerUUID:reference:c0-e38}
batchId=672
instanceId=0
page=%2Fconcerto%2FCentral
scriptSessionId='.$SystemGeneratedId.'/ZuWpyhk-xKjl7aUgs
';

		print "PostBody is $postBody\n";
		#print ("Url 3 is $url3\n");

		   $response3 = $browser->post( $url3,
   
				'Content'=>$postBody
				,
		
		   'Accept' => 'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, image/png, */*',
		   'Accept-Charset' => 'iso-8859-1,*,utf-8',
		   'Accept-Language' => 'en-US',
		   'DWRSESSIONID'=> "$SystemGeneratedId"
		 );

		sleep 15;

		#	'scriptSessionId'=> "$systemGeneratedId\/VOovRdk-\$sUkFFRd9"	

		$myData3=$response3->content ;
		print ("Response 3 is $myData3\n");

		#Send request #4
		my $url4 = "$soastaUrl".'/dwr/call/plaincall/CommonPollerProxy.doPoll.dwr';
		#print ("Url 4 is $url4\n");
		   $response4 = $browser->post( $url4,
   
				'Content'=>'callCount=1
windowName=
c0-scriptName=CommonPollerProxy
c0-methodName=doPoll
c0-id=0
c0-e1=array:[]
c0-e2=string:'.$buildNumber.'
c0-e3=string:5d230adc-3b54-c9db-4985-'.$guidFromTimestamp.'
c0-param0=Object_Object:{methodRequests:reference:c0-e1, clientVersion:reference:c0-e2, pollerUUID:reference:c0-e3}
batchId=673
instanceId=0
page=%2Fconcerto%2FCentral
scriptSessionId='.$SystemGeneratedId.'/ZuWpyhk-xKjl7aUgs

'
				,
		
		   'Accept' => 'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, image/png, */*',
		   'Accept-Charset' => 'iso-8859-1,*,utf-8',
		   'Accept-Language' => 'en-US',
		   'DWRSESSIONID'=> "$SystemGeneratedId"
		 );

		#	'scriptSessionId'=> "$systemGeneratedId\/VOovRdk-\$sUkFFRd9"	

		$myData4=$response4->content ;
		print ("Response 4 is $myData4\n");
		open FILE, ">2_SOASTA_RESULTS_DETAILS.xml" or die "Couldn't open file 2_SOASTA_RESULTS_DETAILS.xml for writing";
		print FILE $myData4;
		close FILE;
		sleep 2;

		#Step 5:
		print ("*** Step 5: Parse file 2_SOASTA_RESULTS_DETAILS.xml to:\n");
		print ("\t (a) Create a plot file which will be used to graph the response times of the transactions\n");
		print ("\t (b) Create a pass/fail results which will 'fail' the transactions if they're above threshold time\n");
		open FILE, "2_SOASTA_RESULTS_DETAILS.xml" or die "Couldn't open file 2_SOASTA_RESULTS_DETAILS.xml";
		$results=<FILE>;
		$results=~ /resultSet:"(.*)",stillRunning:false/; #ResultSet is the stuff between 'resultSet:"'  and ',stillRunning:false
		$resultSet=$1;
		print $resultSet;

		@transactionResults = $resultSet =~ /\[(.*?)\]/gms; #Just pull out the stuff between the square brackets as an array of results
		print ("\n\n");
		$numResults=@transactionResults;
		#print ("Numresults is $numResults\n");
		#print $transactionResults[1];
		print ("\n\n");

		printf ("%50s %8s %8s %8s %8s %12s %12s %8s %8s\n", "Name","avg","90th","min","max","bytesSent","bytesRcvd","errors","Count");

		$plotFileData="Name,Avg,90th,min,max,bytesSent,bytesRcvd,errors\n";

		open AVG,">5a_CloudTestPlotFile_Avg.csv" or die ("Couldn't open 3a_CloudTestPlotFile_Avg.csv for writing\n");
		open N90th,">5b_CloudTestPlotFile_90th.csv" or die ("Couldn't open 3a_CloudTestPlotFile_90th.csv for writing\n");
		open MIN,">5c_CloudTestPlotFile_Min.csv" or die ("Couldn't open 3a_CloudTestPlotFile_Min.csv for writing\n");
		open MAX,">5d_CloudTestPlotFile_Max.csv" or die ("Couldn't open 3a_CloudTestPlotFile_Max.csv for writing\n");
		open ERROR,">5e_CloudTestPlotFile_Error.csv" or die ("Couldn't open 3a_CloudTestPlotFile_Avg.csv for writing\n");
		open BYTESSENT,">5f_CloudTestPlotFile_BytesSent.csv" or die ("Couldn't open 3a_CloudTestPlotFile_BytesSent.csv for writing\n");
		open BYTESRCVD,">5g_CloudTestPlotFile_BytesRcvd.csv" or die ("Couldn't open 3a_CloudTestPlotFile_BytesRcvd.csv for writing\n");
		open COUNT,">5h_CloudTestPlotFile_Count.csv" or die ("Couldn't open 3a_CloudTestPlotFile_Count.csv for writing\n");
		open COMPERRORS,">5h_CloudTestPlotFile_CompErrors.csv" or die ("Couldn't open 5h_CloudTestPlotFile_CompErrors.csv for writing\n");

		foreach (@transactionResults)
		{
			#print ("First item is $items[0]\n");
			@items = split (',',$_); 
			$name = $items[0]; $name=~s/\\+//g; $name =~ s/"//g;
			$collections=$items[6];
			$avg=$items[7]/1000;
			$min=$items[8]/1000;
			$max=$items[9]/1000;
			$stdev=$items[10];
			$ninetieth=$items[11]/1000;
			$bytesSent=$items[12];
			$bytesReceived=$items[13];
			$errors=$items[14];
	
			$csv+= "";
			#print "Name is $name and avg is $avg and 90th is $ninetieth and errors are $errors\n\n";
			$actual{$name}=$avg;
			$ninetieth{$name}=$ninetieth;
			$errors{$name}=$errors;
			$bytesRcvd{$name}=$bytesReceived;
			$collections{$name}=$collections;
			$max{$name}=$max;
			$min{$name}=$min;
			printf ("%50s    %-3.3f    %-3.3f     %-3.3f    %-3.3f %12i %12i %6i %6i\n", $name,$avg,$ninetieth,$min,$max,$bytesSent,$bytesReceived,$errors,$collections);
			#print ("Should plot for $name is : $shouldPlot{$name}\n");
			if ($shouldPlot{$name} eq "True")
			{ 		
				$plotFileData.="$name,$avg,$ninetieth,$min,$max,$bytesSent,$bytesReceived,$errors\n";
				$avgHdr.="$name,";$avgData.="$avg,";
				$n90thHdr.="$name,";$n90thData.="$ninetieth,";
				$minHdr.="$name,";$minData.="$min,";
				$maxHdr.="$name,";$maxData.="$max,";
				$bytesSentHdr.="$name,";$bytesSentData.="$bytesSent,";
				$bytesRcvdHdr.="$name,";$bytesRcvdData.="$bytesReceived,";
				$countHdr.="$name,";$countData.="$collections,";
				$errorHdr.="$name,";$errorData.="$errors,";
			}
		}

				print AVG "$avgHdr\n$avgData\n";
				print N90th "$n90thHdr\n$n90thData\n";
				print MIN "$minHdr\n$minData\n";
				print MAX "$maxHdr\n$maxData\n";
				print BYTESSENT "$bytesSentHdr\n$bytesSentData\n";
				print BYTESRCVD "$bytesRcvdHdr\n$bytesRcvdData\n";
				print COUNT "$countHdr\n$countData\n";
				print ERROR "$errorHdr\n$errorData\n";
				print COMPERRORS "Composition Errors\n$compErrors\n";

		close AVG;close N90th;close MIN;close MAX;close BYTESSENT;close BYTESRCVD; close COUNT;close ERROR;close COMPERRORS;
		#print ("Plot file is :\n$plotFileData\n");
		open PLOTFILE, ">Plotfile.csv" or die ("Couldn't open PlotFile for writing\n");
		print PLOTFILE $plotFileData;
		close PLOTFILE;

		$junitxml='<?xml version="1.0" encoding="UTF-8"?>'."\n";
		$junitxml.="<testsuite tests=\"$numTests\" errors=\"$compErrors\" timestamp=\"$timestamp\">\n";

		$junitxml.="\t<testcase name=\"Link to detailed Results: $soastaUrl\/Central\?initResultsTab=$resultID\" classname=\"Performance\" time=\"0\" />\n";		
		#/Central?initResultsTab=16753
		#Step 4a: This does the Average Response Time
		 foreach my $SLA (sort keys %SLA)
		 {
			$status="";$message="";
	
			if    ($actual{$SLA}==NULL) 	 {$status="FAIL"; $message="Transaction \"$SLA\" does not appear in SOASTA composition";}
			elsif ($actual{$SLA} > $SLA{$SLA}) {$status="FAIL"; $message="Transaction $SLA exceeded threshold of $SLA{$SLA}. (it was $actual{$SLA})";}
			else  {$status="PASS"; $message="Transaction $SLA was faster than threshold of $SLA{$SLA}. (it was $actual{$SLA})";}
			#print ("Transaction: \"$SLA\"\t SLA: $SLA{$SLA} \t Actual: $actual{$SLA}\n");
			#print ("Status: $status\nMessage: $message\n\n");
	
			if ($status ne "FAIL") 
				{
					$junitxml.="\t<testcase name=\"$SLA avg should not exceed $SLA{$SLA}\" classname=\"Performance\" time=\"$actual{$SLA}\" />\n";			
				}
			else
				{
					$junitxml.="\t<testcase name=\"$SLA avg should not exceed $SLA{$SLA}\" classname=\"Performance\" time=\"$actual{$SLA}\"> \n\t\t<failure type=\"performance\"> $message</failure>\n\t</testcase>\n";
				}	
		
		 }
 
		#Step 4b: This does the 90th Response Time
		 foreach my $transaction  (sort keys %SLAninetieth)
		 {
			$status="";$message="";
	
			if    ($ninetieth{$transaction}==NULL) 	 {$status="FAIL"; $message="Transaction \"$transaction\" does not appear in SOASTA composition";}
			elsif ($ninetieth{$transaction} > $SLAninetieth{$transaction}) {$status="FAIL"; $message="Transaction $transaction exceeded 90th percentile time of $SLAninetieth{$transaction}. (it was $ninetieth{$transaction})";}
			else  {$status="PASS"; $message="Transaction $transaction was faster than threshold of $SLAninetieth{$transaction}. (it was $ninetieth{$transaction})";}
			#print ("Transaction: \"$SLA\"\t SLA: $SLA{$SLA} \t Actual: $actual{$SLA}\n");
			#print ("Status: $status\nMessage: $message\n\n");
	
			if ($status ne "FAIL") 
				{
					$junitxml.="\t<testcase name=\"$transaction 90th of $SLAninetieth{$transaction}\" classname=\"Performance\" time=\"$ninetieth{$transaction}\" />\n";			
				}
			else
				{
					$junitxml.="\t<testcase name=\"$transaction 90th percentile should be faster than $SLAninetieth{$transaction}\" classname=\"Performance\" time=\"$ninetieth{$transaction}\"> \n\t\t<failure type=\"performance\"> $message</failure>\n\t</testcase>\n";
				}	
		 }

		#Step 4c: This does the Error count 
		 foreach my $transaction  (sort keys %SLAerrors)
		 {
			if    ($SLAerrors{$transaction}==NULL) 	 {$status="FAIL"; $message="Transaction \"$transaction\" does not appear in SOASTA composition";}
			elsif ($errors{$transaction} > $SLAerrors{$transaction}) {$status="FAIL"; $message="Transaction $transaction exceeded allowable error count of $SLAerrors{$transaction}. (it was $errors{$transaction} )";}
			else  {$status="PASS"; $message="Transaction $transaction was less than maximum error count of $SLAerrors{$transaction}. (it was $errors{$transaction})";}
			#print ("Transaction: \"$SLA\"\t SLA: $SLA{$SLA} \t Actual: $actual{$SLA}\n");
			#print ("Status: $status\nMessage: $message\n\n");
	
			if ($status ne "FAIL") 
				{
					$junitxml.="\t<testcase name=\"$transaction max errors of $SLAerrors{$transaction}\" classname=\"Performance\" time=\"$errors{$transaction}\" />\n";			
				}
			else
				{
					$junitxml.="\t<testcase name=\"$transaction errors max of $SLAerrors{$transaction}\" classname=\"Performance\" time=\"$errors{$transaction}\"> \n\t\t<failure type=\"performance\"> $message</failure>\n\t</testcase>\n";
				}	
		  }

		#Step 4c: This does the min time 
		 foreach my $transaction  (sort keys %SLAmin)
		 {
			if    ($SLAmin{$transaction}==NULL) 	 {$status="FAIL"; $message="Transaction \"$transaction\" does not appear in SOASTA composition";}
			elsif ($min{$transaction} > $SLAmin{$transaction}) {$status="FAIL"; $message="Transaction $transaction exceeded allowable minimum time of $SLAmin{$transaction}. (it was $min{$transaction})";}
			else  {$status="PASS"; $message="Transaction $transaction minimum time was less than $SLAmin{$transaction}. (it was $min{$transaction})";}
	
			if ($status ne "FAIL") 
				{
					$junitxml.="\t<testcase name=\"$transaction minimum response time less than of $SLAmin{$transaction}\" classname=\"Performance\" time=\"$min{$transaction}\" />\n";			
				}
			else
				{
					$junitxml.="\t<testcase name=\"$transaction min of $SLAmin{$transaction}\" classname=\"Performance\" time=\"$ninetieth{$transaction}\"> \n\t\t<failure type=\"performance\"> $message</failure>\n\t</testcase>\n";
				}	
		  }


		#Step 4c: This does the max time 
		 foreach my $transaction  (sort keys %SLAmax)
		 {
			if    ($SLAmax{$transaction}==NULL) 	 {$status="FAIL"; $message="Transaction \"$transaction\" does not appear in SOASTA composition";}
			elsif ($max{$transaction} > $SLAmax{$transaction}) {$status="FAIL"; $message="Transaction $transaction exceeded allowable maximum time of $SLAmax{$transaction}. (it was $max{$transaction})";}
			else  {$status="PASS"; $message="Transaction $transaction maximum time was greater than $SLAmax{$transaction}. (it was $max{$transaction})";}
	
			if ($status ne "FAIL") 
				{
					$junitxml.="\t<testcase name=\"$transaction maximum response time less than of $SLAmax{$transaction}\" classname=\"Performance\" time=\"$max{$transaction}\" />\n";			
				}
			else
				{
					$junitxml.="\t<testcase name=\"$transaction max of $SLAmax{$transaction}\" classname=\"Performance\" time=\"$max{$transaction}\"> \n\t\t<failure type=\"performance\"> $message</failure>\n\t</testcase>\n";
				}	
		  }

		#Step 4d: This does the max composition errors 
	
			if    ($compErrors>$maxCompErrors) 	 {$status="FAIL"; $message="Exceeded maximum errors for overall composition";}
			
			else  {$status="PASS"; $message="Overall compositions errors was within bounds";}
	
			if ($status ne "FAIL") 
				{
					$junitxml.="\t<testcase name=\"Overall composition errors did not exceed maximum of $maxCompErrors.  It was $compErrors\" classname=\"Performance\" time=\"$maxCompErrors\" />\n";			
				}
			else
				{
					$junitxml.="\t<testcase name=\"Exceeded maximum of $maxCompErrors \" classname=\"Performance\" time=\"$compErrors\"> \n\t\t<failure type=\"performance\"> $message</failure>\n\t</testcase>\n";
				}	
		  


		 $junitxml.='</testsuite>';
  
		 #Print the Performance Results PlotFile
		 open PERF, ">5_PERF_THRESHOLD_RESULTS.xml";
		 print PERF "$junitxml";
		 close PERF;
 
  
		 print ("JunitXML:\n $junitxml\n");
 
		close FILE;
		close OUTPUT;
}
elsif ($buildNumber>6937.4) {
		print ("Using parsing format 'B' based on build number\n");
		print ("Soasta URL is $soastaUrl\n");
		my $url = "$soastaUrl".'/dwr/call/plaincall/__System.generateId.dwr';
		#print ("Url is $url\n");
		 my @ns_headers = (
		   'User-Agent' => 'Mozilla/4.76 [en] (Win98; U)',
		   'Accept' => 'image/gif, image/x-xbitmap, image/jpeg, 
				image/pjpeg, image/png, */*',
		   'Accept-Charset' => 'iso-8859-1,*,utf-8',
		   'Accept-Language' => 'en-US',
		  );

		sleep 10;
		#Send request #1   
		   $response1 = $browser->post( $url,
		   [
			'callCount'=>'1', 
			'c0-scriptName' => '__System', 
			'c0-methodName'=>'generateId',
			'c0-id'=>'0',
			'batchId'=>'0',
			'instanceId'=>'0',
			'page'=>'%2Fconcerto%2F',
			'scriptSessionId'=>'',
			'windowName'=>''   ],
		   'Accept' => 'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, image/png, */*',
		   'Accept-Charset' => 'iso-8859-1,*,utf-8',
		   'Accept-Language' => 'en-US',
		 );
 
 
		 $myData=$response1->content;
 
		print "Response 1 is $myData \n";
		$myData=~/.handleCallback\(\"\d\",\"\d\",\"(.*?)\"\)/;

		$SystemGeneratedId=$1;
		print "SystemGeneratedId= $SystemGeneratedId \n";
		#r.handleCallback("0","0","WEgC9ZM59FEvoGotA7PpjWbb8ek");
		#system (pwd);  #For debugging, find what directory we're in...
		#Send Request #2
		#goto=&userName=mostenbergci&password=soasta
		my $url2 = "$soastaUrl".'/Login';
		#print ("Url2 is $url2 and $password is $password\n");
		   $response2 = $browser->post( $url2,
		   [
				'goto'=>'',
				'userName'=>$username,
				'password'=>$password
			],
		   'Accept' => 'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, image/png, */*',
		   'Accept-Charset' => 'iso-8859-1,*,utf-8',
		   'Accept-Language' => 'en-US',
		   'DWRSESSIONID'=> "$SystemGeneratedId"
		 );

		$myData2=$response2->content ;
		#print ("Response 2 is $myData2\n");

		print "System generated Id is  $systemGeneratedId\n";

		#Send Request #3
		my $url3 = "$soastaUrl".'/dwr/call/plaincall/CommonPollerProxy.doPoll.dwr';
$postBody='callCount=1
windowName=
c0-scriptName=CommonPollerProxy
c0-methodName=doPoll
c0-id=0
c0-e3=string:AnalysisTask
c0-e4=string:getAnalysisData
c0-e8=number:6
c0-e9=string:'.$resultID.'
c0-e10=boolean:false
c0-e11=null:null
c0-e13=string:0%3A%3A%3A%3A%3A%3A%3A%3A%3A%3A
c0-e14=string:1%3A%3A
c0-e12=array:[reference:c0-e13,reference:c0-e14]
c0-e15=null:null
c0-e17=null:null
c0-e18=null:null
c0-e19=boolean:false
c0-e20=boolean:false
c0-e21=number:90
c0-e22=number:1.29
c0-e16=Object_Object:{includeStoppedClips:reference:c0-e17, includeFailedClips:reference:c0-e18, includeStoppedCollections:reference:c0-e19, includeFailedCollections:reference:c0-e20, percentile:reference:c0-e21, zValue:reference:c0-e22}
c0-e7=Object_Object:{analysisType:reference:c0-e8, resultID:reference:c0-e9, openAllNodes:reference:c0-e10, openedNodes:reference:c0-e11, openNodeDesignators:reference:c0-e12, widgetFilter:reference:c0-e15, widgetDataRequestCustomSettings:reference:c0-e16}
c0-e6=Object_Object:{analysisWidgetDataRequestBean:reference:c0-e7}
c0-e5=array:[reference:c0-e6]
c0-e23=string:f0ddc7f3-c340-0f4f-b6d8-'.$guidFromTimestamp.'
c0-e2=Object_Object:{taskName:reference:c0-e3, methodName:reference:c0-e4, methodArgs:reference:c0-e5, callbackUUID:reference:c0-e23}
c0-e1=array:[reference:c0-e2]
c0-e24=string:'.$buildNumber.'
c0-e25=string:7d667419-1cff-3563-b79a-'.$guidFromTimestamp.'
c0-param0=Object_Object:{methodRequests:reference:c0-e1, clientVersion:reference:c0-e24, pollerUUID:reference:c0-e25}
batchId=157
instanceId=0
page=%2Fconcerto%2FCentral
scriptSessionId='.$SystemGeneratedId.'/fAGzvgk-q*IEFnXOv
';

		print "PostBody is $postBody\n";
		#print ("Url 3 is $url3\n");

		   $response3 = $browser->post( $url3,
   
				'Content'=>$postBody
				,
		
		   'Accept' => 'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, image/png, */*',
		   'Accept-Charset' => 'iso-8859-1,*,utf-8',
		   'Accept-Language' => 'en-US',
		   'DWRSESSIONID'=> "$SystemGeneratedId"
		 );

		sleep 15;

		#	'scriptSessionId'=> "$systemGeneratedId\/VOovRdk-\$sUkFFRd9"	

		$myData3=$response3->content ;
		print ("Response 3 is $myData3\n");

		#Send request #4
		my $url4 = "$soastaUrl".'/dwr/call/plaincall/CommonPollerProxy.doPoll.dwr';
		#print ("Url 4 is $url4\n");
		   $response4 = $browser->post( $url4,
   
				'Content'=>'callCount=1
windowName=
c0-scriptName=CommonPollerProxy
c0-methodName=doPoll
c0-id=0
c0-e1=array:[]
c0-e2=string:6937.50
c0-e3=string:7d667419-1cff-3563-b79a-'.$guidFromTimestamp.'
c0-param0=Object_Object:{methodRequests:reference:c0-e1, clientVersion:reference:c0-e2, pollerUUID:reference:c0-e3}
batchId=158
instanceId=0
page=%2Fconcerto%2FCentral
scriptSessionId='.$SystemGeneratedId.'/fAGzvgk-q*IEFnXOv
'
				,
		
		   'Accept' => 'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, image/png, */*',
		   'Accept-Charset' => 'iso-8859-1,*,utf-8',
		   'Accept-Language' => 'en-US',
		   'DWRSESSIONID'=> "$SystemGeneratedId"
		 );

		#	'scriptSessionId'=> "$systemGeneratedId\/VOovRdk-\$sUkFFRd9"	

		$myData4=$response4->content ;
		print ("Response 4 is $myData4\n");
		open FILE, ">2_SOASTA_RESULTS_DETAILS.xml" or die "Couldn't open file 2_SOASTA_RESULTS_DETAILS.xml for writing";
		print FILE $myData4;
		close FILE;
		sleep 2;

		#Step 5:
		print ("*** Step 5: Parse file 2_SOASTA_RESULTS_DETAILS.xml to:\n");
		print ("\t (a) Create a plot file which will be used to graph the response times of the transactions\n");
		print ("\t (b) Create a pass/fail results which will 'fail' the transactions if they're above threshold time\n");
		open FILE, "2_SOASTA_RESULTS_DETAILS.xml" or die "Couldn't open file 2_SOASTA_RESULTS_DETAILS.xml";
		$results=<FILE>;
		$results=~ /resultSet:"(.*)",stillRunning:false/; #ResultSet is the stuff between 'resultSet:"'  and ',stillRunning:false
		$resultSet=$1;
		print $resultSet;

		@transactionResults = $resultSet =~ /\[(.*?)\]/gms; #Just pull out the stuff between the square brackets as an array of results
		print ("\n\n");
		$numResults=@transactionResults;
		#print ("Numresults is $numResults\n");
		#print $transactionResults[1];
		print ("\n\n");

		printf ("%50s %8s %8s %8s %8s %12s %12s %8s %8s\n", "Name","avg","90th","min","max","bytesSent","bytesRcvd","errors","Count");

		$plotFileData="Name,Avg,90th,min,max,bytesSent,bytesRcvd,errors\n";

		open AVG,">5a_CloudTestPlotFile_Avg.csv" or die ("Couldn't open 3a_CloudTestPlotFile_Avg.csv for writing\n");
		open N90th,">5b_CloudTestPlotFile_90th.csv" or die ("Couldn't open 3a_CloudTestPlotFile_90th.csv for writing\n");
		open MIN,">5c_CloudTestPlotFile_Min.csv" or die ("Couldn't open 3a_CloudTestPlotFile_Min.csv for writing\n");
		open MAX,">5d_CloudTestPlotFile_Max.csv" or die ("Couldn't open 3a_CloudTestPlotFile_Max.csv for writing\n");
		open ERROR,">5e_CloudTestPlotFile_Error.csv" or die ("Couldn't open 3a_CloudTestPlotFile_Avg.csv for writing\n");
		open BYTESSENT,">5f_CloudTestPlotFile_BytesSent.csv" or die ("Couldn't open 3a_CloudTestPlotFile_BytesSent.csv for writing\n");
		open BYTESRCVD,">5g_CloudTestPlotFile_BytesRcvd.csv" or die ("Couldn't open 3a_CloudTestPlotFile_BytesRcvd.csv for writing\n");
		open COUNT,">5h_CloudTestPlotFile_Count.csv" or die ("Couldn't open 3a_CloudTestPlotFile_Count.csv for writing\n");
		open COMPERRORS,">5h_CloudTestPlotFile_CompErrors.csv" or die ("Couldn't open 5h_CloudTestPlotFile_CompErrors.csv for writing\n");

		foreach (@transactionResults)
		{
			#print ("First item is $items[0]\n");
			@items = split (',',$_); 
			$name = $items[16]; $name=~s/\\+//g; $name =~ s/"//g;
			$collections=$items[4];
			$avg=$items[5]/1000;
			$min=$items[6]/1000;
			$max=$items[7]/1000;
			$stdev=$items[8];
			$ninetieth=$items[9]/1000;
			$bytesSent=$items[10];
			$bytesReceived=$items[11];
			$errors=$items[15];
	
			$csv+= "";
			#print "Name is $name and avg is $avg and 90th is $ninetieth and errors are $errors\n\n";
			$actual{$name}=$avg;
			$ninetieth{$name}=$ninetieth;
			$errors{$name}=$errors;
			$bytesRcvd{$name}=$bytesReceived;
			$collections{$name}=$collections;
			$max{$name}=$max;
			$min{$name}=$min;
			printf ("%50s    %-3.3f    %-3.3f     %-3.3f    %-3.3f %12i %12i %6i %6i\n", $name,$avg,$ninetieth,$min,$max,$bytesSent,$bytesReceived,$errors,$collections);
			#print ("Should plot for $name is : $shouldPlot{$name}\n");
			if ($shouldPlot{$name} eq "True")
			{ 		
				$plotFileData.="$name,$avg,$ninetieth,$min,$max,$bytesSent,$bytesReceived,$errors\n";
				$avgHdr.="$name,";$avgData.="$avg,";
				$n90thHdr.="$name,";$n90thData.="$ninetieth,";
				$minHdr.="$name,";$minData.="$min,";
				$maxHdr.="$name,";$maxData.="$max,";
				$bytesSentHdr.="$name,";$bytesSentData.="$bytesSent,";
				$bytesRcvdHdr.="$name,";$bytesRcvdData.="$bytesReceived,";
				$countHdr.="$name,";$countData.="$collections,";
				$errorHdr.="$name,";$errorData.="$errors,";
			}
		}

				print AVG "$avgHdr\n$avgData\n";
				print N90th "$n90thHdr\n$n90thData\n";
				print MIN "$minHdr\n$minData\n";
				print MAX "$maxHdr\n$maxData\n";
				print BYTESSENT "$bytesSentHdr\n$bytesSentData\n";
				print BYTESRCVD "$bytesRcvdHdr\n$bytesRcvdData\n";
				print COUNT "$countHdr\n$countData\n";
				print ERROR "$errorHdr\n$errorData\n";
				print COMPERRORS "Composition Errors\n$compErrors\n";

		close AVG;close N90th;close MIN;close MAX;close BYTESSENT;close BYTESRCVD; close COUNT;close ERROR;close COMPERRORS;
		#print ("Plot file is :\n$plotFileData\n");
		open PLOTFILE, ">Plotfile.csv" or die ("Couldn't open PlotFile for writing\n");
		print PLOTFILE $plotFileData;
		close PLOTFILE;

		$junitxml='<?xml version="1.0" encoding="UTF-8"?>'."\n";
		$junitxml.="<testsuite tests=\"$numTests\" errors=\"$compErrors\" timestamp=\"$timestamp\">\n";

		$junitxml.="\t<testcase name=\"Link to detailed Results: $soastaUrl\/\/Central\?initResultsTab=$resultID\" classname=\"Performance\" time=\"0\" />\n";		
		#/Central?initResultsTab=16753
		#Step 4a: This does the Average Response Time
		 foreach my $SLA (sort keys %SLA)
		 {
			$status="";$message="";
	
			if    ($actual{$SLA}==NULL) 	 {$status="FAIL"; $message="Transaction \"$SLA\" does not appear in SOASTA composition";}
			elsif ($actual{$SLA} > $SLA{$SLA}) {$status="FAIL"; $message="Transaction $SLA exceeded threshold of $SLA{$SLA}. (it was $actual{$SLA})";}
			else  {$status="PASS"; $message="Transaction $SLA was faster than threshold of $SLA{$SLA}. (it was $actual{$SLA})";}
			#print ("Transaction: \"$SLA\"\t SLA: $SLA{$SLA} \t Actual: $actual{$SLA}\n");
			#print ("Status: $status\nMessage: $message\n\n");
	
			if ($status ne "FAIL") 
				{
					$junitxml.="\t<testcase name=\"$SLA avg should not exceed $SLA{$SLA}\" classname=\"Performance\" time=\"$actual{$SLA}\" />\n";			
				}
			else
				{
					$junitxml.="\t<testcase name=\"$SLA avg should not exceed $SLA{$SLA}\" classname=\"Performance\" time=\"$actual{$SLA}\"> \n\t\t<failure type=\"performance\"> $message</failure>\n\t</testcase>\n";
				}	
		
		 }
 
		#Step 4b: This does the 90th Response Time
		 foreach my $transaction  (sort keys %SLAninetieth)
		 {
			$status="";$message="";
	
			if    ($ninetieth{$transaction}==NULL) 	 {$status="FAIL"; $message="Transaction \"$transaction\" does not appear in SOASTA composition";}
			elsif ($ninetieth{$transaction} > $SLAninetieth{$transaction}) {$status="FAIL"; $message="Transaction $transaction exceeded 90th percentile time of $SLAninetieth{$transaction}. (it was $ninetieth{$transaction})";}
			else  {$status="PASS"; $message="Transaction $transaction was faster than threshold of $SLAninetieth{$transaction}. (it was $ninetieth{$transaction})";}
			#print ("Transaction: \"$SLA\"\t SLA: $SLA{$SLA} \t Actual: $actual{$SLA}\n");
			#print ("Status: $status\nMessage: $message\n\n");
	
			if ($status ne "FAIL") 
				{
					$junitxml.="\t<testcase name=\"$transaction 90th of $SLAninetieth{$transaction}\" classname=\"Performance\" time=\"$ninetieth{$transaction}\" />\n";			
				}
			else
				{
					$junitxml.="\t<testcase name=\"$transaction 90th percentile should be faster than $SLAninetieth{$transaction}\" classname=\"Performance\" time=\"$ninetieth{$transaction}\"> \n\t\t<failure type=\"performance\"> $message</failure>\n\t</testcase>\n";
				}	
		 }

		#Step 4c: This does the Error count 
		 foreach my $transaction  (sort keys %SLAerrors)
		 {
			if    ($SLAerrors{$transaction}==NULL) 	 {$status="FAIL"; $message="Transaction \"$transaction\" does not appear in SOASTA composition";}
			elsif ($errors{$transaction} > $SLAerrors{$transaction}) {$status="FAIL"; $message="Transaction $transaction exceeded allowable error count of $SLAerrors{$transaction}. (it was $errors{$transaction} )";}
			else  {$status="PASS"; $message="Transaction $transaction was less than maximum error count of $SLAerrors{$transaction}. (it was $errors{$transaction})";}
			#print ("Transaction: \"$SLA\"\t SLA: $SLA{$SLA} \t Actual: $actual{$SLA}\n");
			#print ("Status: $status\nMessage: $message\n\n");
	
			if ($status ne "FAIL") 
				{
					$junitxml.="\t<testcase name=\"$transaction max errors of $SLAerrors{$transaction}\" classname=\"Performance\" time=\"$errors{$transaction}\" />\n";			
				}
			else
				{
					$junitxml.="\t<testcase name=\"$transaction errors max of $SLAerrors{$transaction}\" classname=\"Performance\" time=\"$errors{$transaction}\"> \n\t\t<failure type=\"performance\"> $message</failure>\n\t</testcase>\n";
				}	
		  }

		#Step 4c: This does the min time 
		 foreach my $transaction  (sort keys %SLAmin)
		 {
			if    ($SLAmin{$transaction}==NULL) 	 {$status="FAIL"; $message="Transaction \"$transaction\" does not appear in SOASTA composition";}
			elsif ($min{$transaction} > $SLAmin{$transaction}) {$status="FAIL"; $message="Transaction $transaction exceeded allowable minimum time of $SLAmin{$transaction}. (it was $min{$transaction})";}
			else  {$status="PASS"; $message="Transaction $transaction minimum time was less than $SLAmin{$transaction}. (it was $min{$transaction})";}
	
			if ($status ne "FAIL") 
				{
					$junitxml.="\t<testcase name=\"$transaction minimum response time less than of $SLAmin{$transaction}\" classname=\"Performance\" time=\"$min{$transaction}\" />\n";			
				}
			else
				{
					$junitxml.="\t<testcase name=\"$transaction min of $SLAmin{$transaction}\" classname=\"Performance\" time=\"$ninetieth{$transaction}\"> \n\t\t<failure type=\"performance\"> $message</failure>\n\t</testcase>\n";
				}	
		  }


		#Step 4c: This does the max time 
		 foreach my $transaction  (sort keys %SLAmax)
		 {
			if    ($SLAmax{$transaction}==NULL) 	 {$status="FAIL"; $message="Transaction \"$transaction\" does not appear in SOASTA composition";}
			elsif ($max{$transaction} > $SLAmax{$transaction}) {$status="FAIL"; $message="Transaction $transaction exceeded allowable maximum time of $SLAmax{$transaction}. (it was $max{$transaction})";}
			else  {$status="PASS"; $message="Transaction $transaction maximum time was greater than $SLAmax{$transaction}. (it was $max{$transaction})";}
	
			if ($status ne "FAIL") 
				{
					$junitxml.="\t<testcase name=\"$transaction maximum response time less than of $SLAmax{$transaction}\" classname=\"Performance\" time=\"$max{$transaction}\" />\n";			
				}
			else
				{
					$junitxml.="\t<testcase name=\"$transaction max of $SLAmax{$transaction}\" classname=\"Performance\" time=\"$max{$transaction}\"> \n\t\t<failure type=\"performance\"> $message</failure>\n\t</testcase>\n";
				}	
		  }



		 $junitxml.='</testsuite>';
  
		 #Print the Performance Results PlotFile
		 open PERF, ">5_PERF_THRESHOLD_RESULTS.xml";
		 print PERF "$junitxml";
		 close PERF;
 
  
		 print ("JunitXML:\n $junitxml\n");
 
		close FILE;
		close OUTPUT;
}
else #NOW DO THE OLDER BUILD CALLS AND PARSING
{
		#print ("Soasta URL is $soastaUrl\n");
		print ("Using parsing format 'A' based on build number\n");
		my $url = "$soastaUrl".'/dwr/call/plaincall/__System.generateId.dwr';
		#print ("Url is $url\n");
		 my @ns_headers = (
		   'User-Agent' => 'Mozilla/4.76 [en] (Win98; U)',
		   'Accept' => 'image/gif, image/x-xbitmap, image/jpeg, 
				image/pjpeg, image/png, */*',
		   'Accept-Charset' => 'iso-8859-1,*,utf-8',
		   'Accept-Language' => 'en-US',
		  );

		#Send request #1   
		   $response1 = $browser->post( $url,
		   [
			'callCount'=>'1', 
			'c0-scriptName' => '__System', 
			'c0-methodName'=>'generateId',
			'c0-id'=>'0',
			'batchId'=>'0',
			'instanceId'=>'0',
			'page'=>'%2Fconcerto%2F',
			'scriptSessionId'=>'',
			'windowName'=>''   ],
		   'Accept' => 'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, image/png, */*',
		   'Accept-Charset' => 'iso-8859-1,*,utf-8',
		   'Accept-Language' => 'en-US',
		 );
 
 
		 $myData=$response1->content;
 
		#print "Response 1 is $myData \n";
		$myData=~/.handleCallback\(\"\d\",\"\d\",\"(.*?)\"\)/;

		$SystemGeneratedId=$1;
		#print "SystemGeneratedId= $SystemGeneratedId \n";
		#r.handleCallback("0","0","WEgC9ZM59FEvoGotA7PpjWbb8ek");
		#system (pwd);  #For debugging, find what directory we're in...
		#Send Request #2
		#goto=&userName=mostenbergci&password=soasta
		my $url2 = "$soastaUrl".'/Login';
		#print ("Url2 is $url2 and $password is $password\n");
		   $response2 = $browser->post( $url2,
		   [
				'goto'=>'',
				'userName'=>$username,
				'password'=>$password
			],
		   'Accept' => 'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, image/png, */*',
		   'Accept-Charset' => 'iso-8859-1,*,utf-8',
		   'Accept-Language' => 'en-US',
		   'DWRSESSIONID'=> "$SystemGeneratedId"
		 );

		$myData2=$response2->content ;
		#print ("Response 2 is $myData2\n");

		#print ("Result id is $resultId\n");
		#Send Request #3
		my $url3 = "$soastaUrl".'/dwr/call/plaincall/CommonPollerProxy.doPoll.dwr';
		#print ("Url 3 is $url3\n");
$postBody='callCount=1
windowName=
c0-scriptName=CommonPollerProxy
c0-methodName=doPoll
c0-id=0
c0-e3=string:AnalysisTask
c0-e4=string:getAnalysisData
c0-e8=number:4
c0-e9=string:'.$resultID.'
c0-e10=boolean:false
c0-e11=null:null
c0-e13=string:0%3A%3A%3A%3A%3A%3A%3A%3A%3A%3A
c0-e12=array:[reference:c0-e13]
c0-e14=null:null
c0-e16=null:null
c0-e17=null:null
c0-e18=boolean:false
c0-e19=boolean:false
c0-e20=number:90
c0-e21=number:1.29
c0-e15=Object_Object:{includeStoppedClips:reference:c0-e16, includeFailedClips:reference:c0-e17, includeStoppedCollections:reference:c0-e18, includeFailedCollections:reference:c0-e19, percentile:reference:c0-e20, zValue:reference:c0-e21}
c0-e7=Object_Object:{analysisType:reference:c0-e8, resultID:reference:c0-e9, openAllNodes:reference:c0-e10, openedNodes:reference:c0-e11, openNodeDesignators:reference:c0-e12, widgetFilter:reference:c0-e14, widgetDataRequestCustomSettings:reference:c0-e15}
c0-e6=Object_Object:{analysisWidgetDataRequestBean:reference:c0-e7}
c0-e5=array:[reference:c0-e6]
c0-e22=string:971d0b40-b078-96c2-8cdf-'.$guidFromTimestamp.'
c0-e2=Object_Object:{taskName:reference:c0-e3, methodName:reference:c0-e4, methodArgs:reference:c0-e5, callbackUUID:reference:c0-e22}
c0-e1=array:[reference:c0-e2]
c0-e23=string:'.$buildNumber.'
c0-e24=string:9a8c1355-c9eb-d0c1-1e9a-'.$guidFromTimestamp.'
c0-param0=Object_Object:{methodRequests:reference:c0-e1, clientVersion:reference:c0-e23, pollerUUID:reference:c0-e24}
batchId=45
instanceId=0
page=%2Fconcerto%2FCentral
scriptSessionId='.$SystemGeneratedId.'/VOovRdk-$sUkFFRd9
';
print ("Post body is \n$postBody\n");

		   $response3 = $browser->post( $url3,
		'Content'=>$postBody
				,

		   'Accept' => 'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, image/png, */*',
		   'Accept-Charset' => 'iso-8859-1,*,utf-8',
		   'Accept-Language' => 'en-US',
		   'DWRSESSIONID'=> "$SystemGeneratedId"
		 );

		sleep 5;

		#	'scriptSessionId'=> "$systemGeneratedId\/VOovRdk-\$sUkFFRd9"	

		$myData3=$response3->content ;
		print ("Response 3 is $myData3\n");

		#Send request #4
		my $url4 = "$soastaUrl".'/dwr/call/plaincall/CommonPollerProxy.doPoll.dwr';
$postBody2='callCount=1
windowName=
c0-scriptName=CommonPollerProxy
c0-methodName=doPoll
c0-id=0
c0-e1=array:[]
c0-e2=string:'.$buildNumber.'
c0-e3=string:9a8c1355-c9eb-d0c1-1e9a-'.$guidFromTimestamp.'
c0-param0=Object_Object:{methodRequests:reference:c0-e1, clientVersion:reference:c0-e2, pollerUUID:reference:c0-e3}
batchId=48
instanceId=0
page=%2Fconcerto%2FCentral
scriptSessionId='.$SystemGeneratedId.'/VOovRdk-$sUkFFRd9
';
		#print ("Url 4 is $url4\n");
		print "Post body2 is \n$postBody2\n";
		
		   $response4 = $browser->post( $url4,
   
'Content'=>$postBody2
				,

		   'Accept' => 'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, image/png, */*',
		   'Accept-Charset' => 'iso-8859-1,*,utf-8',
		   'Accept-Language' => 'en-US',
		   'DWRSESSIONID'=> "$SystemGeneratedId"
		 );

		#	'scriptSessionId'=> "$systemGeneratedId\/VOovRdk-\$sUkFFRd9"	

		$myData4=$response4->content ;
		print ("Response 4 is $myData4\n");
		open FILE, ">2_SOASTA_RESULTS_DETAILS.xml" or die "Couldn't open file 2_SOASTA_RESULTS_DETAILS.xml for writing";
		print FILE $myData4;
		close FILE;
		sleep 2;

		#Step 5:
		print ("*** Step 5: Parse file 2_SOASTA_RESULTS_DETAILS.xml to:\n");
		print ("\t (a) Create a plot file which will be used to graph the response times of the transactions\n");
		print ("\t (b) Create a pass/fail results which will 'fail' the transactions if they're above threshold time\n");
		open FILE, "2_SOASTA_RESULTS_DETAILS.xml" or die "Couldn't open file 2_SOASTA_RESULTS_DETAILS.xml";
		$results=<FILE>;
		$results=~ /resultSet:"(.*)",stillRunning:false/;
		$resultSet=$1;
		#print $resultSet;

		@transactionResults = $resultSet =~ /\[(.*?)\]/gms;
		print ("\n\n");
		$numResults=@transactionResults;
		#print ("Numresults is $numResults\n");
		#print $transactionResults[1];
		print ("\n\n");

		printf ("%50s %8s %8s %8s %8s %12s %12s %8s %8s\n", "Name","avg","90th","min","max","bytesSent","bytesRcvd","errors","Count");

		$plotFileData="Name,Avg,90th,min,max,bytesSent,bytesRcvd,errors\n";

		open AVG,">5a_CloudTestPlotFile_Avg.csv" or die ("Couldn't open 3a_CloudTestPlotFile_Avg.csv for writing\n");
		open N90th,">5b_CloudTestPlotFile_90th.csv" or die ("Couldn't open 3a_CloudTestPlotFile_90th.csv for writing\n");
		open MIN,">5c_CloudTestPlotFile_Min.csv" or die ("Couldn't open 3a_CloudTestPlotFile_Min.csv for writing\n");
		open MAX,">5d_CloudTestPlotFile_Max.csv" or die ("Couldn't open 3a_CloudTestPlotFile_Max.csv for writing\n");
		open ERROR,">5e_CloudTestPlotFile_Error.csv" or die ("Couldn't open 3a_CloudTestPlotFile_Avg.csv for writing\n");
		open BYTESSENT,">5f_CloudTestPlotFile_BytesSent.csv" or die ("Couldn't open 3a_CloudTestPlotFile_BytesSent.csv for writing\n");
		open BYTESRCVD,">5g_CloudTestPlotFile_BytesRcvd.csv" or die ("Couldn't open 3a_CloudTestPlotFile_BytesRcvd.csv for writing\n");
		open COUNT,">5h_CloudTestPlotFile_Count.csv" or die ("Couldn't open 3a_CloudTestPlotFile_Count.csv for writing\n");

		foreach (@transactionResults)
		{
			#print ("First item is $items[0]\n");
			@items = split (',',$_); 
			$name = $items[0]; $name=~s/\\+//g; $name =~ s/"//g;
			$collections=$items[6];
			$avg=$items[7]/1000;
			$min=$items[8]/1000;
			$max=$items[9]/1000;
			$stdev=$items[10];
			$ninetieth=$items[11]/1000;
			$bytesSent=$items[12];
			$bytesReceived=$items[13];
			$errors=$items[14];

			$csv+= "";
			#print "Name is $name and avg is $avg and 90th is $ninetieth and errors are $errors\n\n";
			$actual{$name}=$avg;
			$ninetieth{$name}=$ninetieth;
			$errors{$name}=$errors;
			$bytesRcvd{$name}=$bytesReceived;
			$collections{$name}=$collections;
			$max{$name}=$max;
			$min{$name}=$min;
			printf ("%50s    %-3.3f    %-3.3f     %-3.3f    %-3.3f %12i %12i %6i %6i\n", $name,$avg,$ninetieth,$min,$max,$bytesSent,$bytesReceived,$errors,$collections);
			#print ("Should plot for $name is : $shouldPlot{$name}\n");
			if ($shouldPlot{$name} eq "True")
			{ 		
				$plotFileData.="$name,$avg,$ninetieth,$min,$max,$bytesSent,$bytesReceived,$errors\n";
				$avgHdr.="$name,";$avgData.="$avg,";
				$n90thHdr.="$name,";$n90thData.="$ninetieth,";
				$minHdr.="$name,";$minData.="$min,";
				$maxHdr.="$name,";$maxData.="$max,";
				$bytesSentHdr.="$name,";$bytesSentData.="$bytesSent,";
				$bytesRcvdHdr.="$name,";$bytesRcvdData.="$bytesReceived,";
				$countHdr.="$name,";$countData.="$collections,";
				$errorHdr.="$name,";$errorData.="$errors,";
			}
		}

				print AVG "$avgHdr\n$avgData\n";
				print N90th "$n90thHdr\n$n90thData\n";
				print MIN "$minHdr\n$minData\n";
				print MAX "$maxHdr\n$maxData\n";
				print BYTESSENT "$bytesSentHdr\n$bytesSentData\n";
				print BYTESRCVD "$bytesRcvdHdr\n$bytesRcvdData\n";
				print COUNT "$countHdr\n$countData\n";
				print ERROR "$errorHdr\n$errorData\n";

		close AVG;close N90th;close MIN;close MAX;close BYTESSENT;close BYTESRCVD; close COUNT;close ERROR;
		#print ("Plot file is :\n$plotFileData\n");
		open PLOTFILE, ">Plotfile.csv" or die ("Couldn't open PlotFile for writing\n");
		print PLOTFILE $plotFileData;
		close PLOTFILE;

		$junitxml='<?xml version="1.0" encoding="UTF-8"?>'."\n";
		$junitxml.="<testsuite tests=\"$numTests\" errors=\"$compErrors\" timestamp=\"$timestamp\">\n";

		$junitxml.="\t<testcase name=\"Link to detailed Results: $soastaUrl\/Central\?initResultsTab=$resultID\" classname=\"Performance\" time=\"0\" />\n";		
		#/Central?initResultsTab=16753
		#Step 4a: This does the Average Response Time
		 foreach my $SLA (sort keys %SLA)
		 {
			$status="";$message="";
	
			if    ($actual{$SLA}==NULL) 	 {$status="FAIL"; $message="Transaction \"$SLA\" does not appear in SOASTA composition";}
			elsif ($actual{$SLA} > $SLA{$SLA}) {$status="FAIL"; $message="Transaction $SLA exceeded threshold of $SLA{$SLA}. (it was $actual{$SLA})";}
			else  {$status="PASS"; $message="Transaction $SLA was faster than threshold of $SLA{$SLA}. (it was $actual{$SLA})";}
			#print ("Transaction: \"$SLA\"\t SLA: $SLA{$SLA} \t Actual: $actual{$SLA}\n");
			#print ("Status: $status\nMessage: $message\n\n");
	
			if ($status ne "FAIL") 
				{
					$junitxml.="\t<testcase name=\"$SLA avg should not exceed $SLA{$SLA}\" classname=\"Performance\" time=\"$actual{$SLA}\" />\n";			
				}
			else
				{
					$junitxml.="\t<testcase name=\"$SLA avg should not exceed $SLA{$SLA}\" classname=\"Performance\" time=\"$actual{$SLA}\"> \n\t\t<failure type=\"performance\"> $message</failure>\n\t</testcase>\n";
				}	
		
		 }
 
		#Step 4b: This does the 90th Response Time
		 foreach my $transaction  (sort keys %SLAninetieth)
		 {
			$status="";$message="";
	
			if    ($ninetieth{$transaction}==NULL) 	 {$status="FAIL"; $message="Transaction \"$transaction\" does not appear in SOASTA composition";}
			elsif ($ninetieth{$transaction} > $SLAninetieth{$transaction}) {$status="FAIL"; $message="Transaction $transaction exceeded 90th percentile time of $SLAninetieth{$transaction}. (it was $ninetieth{$transaction})";}
			else  {$status="PASS"; $message="Transaction $transaction was faster than threshold of $SLAninetieth{$transaction}. (it was $ninetieth{$transaction})";}
			#print ("Transaction: \"$SLA\"\t SLA: $SLA{$SLA} \t Actual: $actual{$SLA}\n");
			#print ("Status: $status\nMessage: $message\n\n");
	
			if ($status ne "FAIL") 
				{
					$junitxml.="\t<testcase name=\"$transaction 90th of $SLAninetieth{$transaction}\" classname=\"Performance\" time=\"$ninetieth{$transaction}\" />\n";			
				}
			else
				{
					$junitxml.="\t<testcase name=\"$transaction 90th percentile should be faster than $SLAninetieth{$transaction}\" classname=\"Performance\" time=\"$ninetieth{$transaction}\"> \n\t\t<failure type=\"performance\"> $message</failure>\n\t</testcase>\n";
				}	
		 }

		#Step 4c: This does the Error count 
		 foreach my $transaction  (sort keys %SLAerrors)
		 {
			if    ($SLAerrors{$transaction}==NULL) 	 {$status="FAIL"; $message="Transaction \"$transaction\" does not appear in SOASTA composition";}
			elsif ($errors{$transaction} > $SLAerrors{$transaction}) {$status="FAIL"; $message="Transaction $transaction exceeded allowable error count of $SLAerrors{$transaction}. (it was $errors{$transaction})";}
			else  {$status="PASS"; $message="Transaction $transaction was less than maximum error count of $SLAerrors{$transaction}. (it was $errors{$transaction})";}
			#print ("Transaction: \"$SLA\"\t SLA: $SLA{$SLA} \t Actual: $actual{$SLA}\n");
			#print ("Status: $status\nMessage: $message\n\n");
	
			if ($status ne "FAIL") 
				{
					$junitxml.="\t<testcase name=\"$transaction max errors of $SLAerrors{$transaction}\" classname=\"Performance\" time=\"$errors{$transaction}\" />\n";			
				}
			else
				{
					$junitxml.="\t<testcase name=\"$transaction errors max of $SLAerrors{$transaction}\" classname=\"Performance\" time=\"$errors{$transaction}\"> \n\t\t<failure type=\"performance\"> $message</failure>\n\t</testcase>\n";
				}	
		  }

		#Step 4c: This does the min time 
		 foreach my $transaction  (sort keys %SLAmin)
		 {
			if    ($SLAmin{$transaction}==NULL) 	 {$status="FAIL"; $message="Transaction \"$transaction\" does not appear in SOASTA composition";}
			elsif ($min{$transaction} > $SLAmin{$transaction}) {$status="FAIL"; $message="Transaction $transaction exceeded allowable minimum time of $SLAmin{$transaction}. (it was $min{$transaction})";}
			else  {$status="PASS"; $message="Transaction $transaction minimum time was less than $SLAmin{$transaction}. (it was $min{$transaction})";}
	
			if ($status ne "FAIL") 
				{
					$junitxml.="\t<testcase name=\"$transaction minimum response time less than of $SLAmin{$transaction}\" classname=\"Performance\" time=\"$min{$transaction}\" />\n";			
				}
			else
				{
					$junitxml.="\t<testcase name=\"$transaction min of $SLAmin{$transaction}\" classname=\"Performance\" time=\"$ninetieth{$transaction}\"> \n\t\t<failure type=\"performance\"> $message</failure>\n\t</testcase>\n";
				}	
		  }


		#Step 4c: This does the max time 
		 foreach my $transaction  (sort keys %SLAmax)
		 {
			if    ($SLAmax{$transaction}==NULL) 	 {$status="FAIL"; $message="Transaction \"$transaction\" does not appear in SOASTA composition";}
			elsif ($max{$transaction} > $SLAmax{$transaction}) {$status="FAIL"; $message="Transaction $transaction exceeded allowable maximum time of $SLAmax{$transaction}. (it was $max{$transaction})";}
			else  {$status="PASS"; $message="Transaction $transaction maximum time was greater than $SLAmax{$transaction}. (it was $max{$transaction})";}
	
			if ($status ne "FAIL") 
				{
					$junitxml.="\t<testcase name=\"$transaction maximum response time less than of $SLAmax{$transaction}\" classname=\"Performance\" time=\"$max{$transaction}\" />\n";			
				}
			else
				{
					$junitxml.="\t<testcase name=\"$transaction max of $SLAmax{$transaction}\" classname=\"Performance\" time=\"$max{$transaction}\"> \n\t\t<failure type=\"performance\"> $message</failure>\n\t</testcase>\n";
				}	
		  }



		 $junitxml.='</testsuite>';
  
		 #Print the Performance Results PlotFile
		 open PERF, ">5_PERF_THRESHOLD_RESULTS.xml";
		 print PERF "$junitxml";
		 close PERF;
 
  
		 print ("JunitXML:\n $junitxml\n");
 
		close FILE;
		close OUTPUT;
}
