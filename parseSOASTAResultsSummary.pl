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
			print ("Should plot for $name is $shouldPlot{$name}\n");
		}
		if ($argument=~/:90th:/) 
		{
			(my $name,my $threshold)=split(":90th:",$argument);
			$SLAninetieth{$name}=$threshold;
			printf ("     %-6s %-25s %3.3f \n","90th",$name,$threshold);
			$shouldPlot{$name}="True";
		}
		if ($argument=~/:Errors:/) 
		{
			(my $name,my $threshold)=split(":Errors:",$argument);
			$SLAerrors{$name}=$threshold;
			printf ("     %-6s %-25s %3.3f \n","Errors",$name,$threshold);
			$shouldPlot{$name}="True";
		}
		if ($argument=~/:BytesSent:/) 
		{
			(my $name,my $threshold)=split(":BytesSent:",$argument);
			$SLAbytesSent{$name}=$threshold;
			$shouldPlot{$name}="True";			
		}
		if ($argument=~/:BytesRcvd:/) 
		{
			(my $name,my $threshold)=split(":BytesRcvd:",$argument);
			$SLAbytesRcvd{$name}=$threshold;
			$shouldPlot{$name}="True";		
		}
		if ($argument=~/username/) 
		{
			(my $temp, $username)=split("=",$argument);
			print ("Username is $username\n");
		}
		if ($argument=~/password/) 
		{
			(my $temp, $password)=split("=",$argument);
			print ("Password is $password\n");
		}
		if ($argument=~/url=/) 
		{
			(my $temp,$soastaUrl)=split("=",$argument);
			print ("Url is $soastaUrl\n");
		}

		if ($argument=~/compname=/) 
		{
			(my $temp,$compName)=split("=",$argument);
			print ("CompName is $compName\n");
		}
	}
}
else
{
	print "No command line argugments, so drawing values from hard-coded thresholds in PERL script.\n";
	#If you don't want to enter transaction names and max times from command line, then enter the transaction SLA values here. Use the format "Transaction Name"=>"maxResponseTime"
	%SLA =
	( 	"Bees Homepage"=> ".500",
		"Bees Product Page"=>".500",
		"Bees Product"=>".500",
		"Bees Add to Cart"=>".500"
	);
}

#STEP 1.5: Run the load test composition
$runCompString = "./scommand/bin/scommand cmd=play name=\"/$compName\" username=$username password=$password url=$soastaUrl wait=yes format=junitxml file=1-SOASTA_RESULTS_ID.xml";

print "Run comp string is $runCompString";
system($runCompString);

#Step 2: Get the results ID out of the file 1-SOASTA_RESULTS_ID.xml . We will pass this into comp
print ("*** Step 2: Parse file 1-SOASTA_RESULTS_ID.xml to get performance ResultsID \n");
open FILE, "1-SOASTA_RESULTS_ID.xml" or die "Couldn't open file 1-SOASTA_RESULTS_ID.xml";
$results=<FILE>;
#print ("results are $results\n");
$results =~ /resultID=\"(\d+)\"/;
$resultID=$1;
print ("\tCaptured results id from file.  ResultsID was $resultID\n");
close FILE;

#Step 2: Query server to get results so that we can get the performance results from that results ID into a file:
print ("*** Step 3: Query the server to get the results details for resultsID=$resultID\n");
print ("\tWrite details to file 2_SOASTA_RESULTS_DETAILS.xml\n");

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

print ("Soasta URL is $soastaUrl\n");
my $url = "$soastaUrl".'/dwr/call/plaincall/__System.generateId.dwr';
print ("Url is $url\n");
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
 
print "Response 1 is $myData \n";
$myData=~/.handleCallback\(\"\d\",\"\d\",\"(.*?)\"\)/;

$SystemGeneratedId=$1;
print "SystemGeneratedId= $SystemGeneratedId \n";
#r.handleCallback("0","0","WEgC9ZM59FEvoGotA7PpjWbb8ek");
system (pwd);  #For debugging, find what directory we're in...
#Send Request #2
#goto=&userName=mostenbergci&password=soasta
my $url2 = "$soastaUrl".'/Login';
print ("Url2 is $url2 and $password is $password\n");
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
print ("Response 2 is $myData2\n");

print ("Result id is $resultId\n");
#Send Request #3
my $url3 = "$soastaUrl".'/dwr/call/plaincall/CommonPollerProxy.doPoll.dwr';
print ("Url 3 is $url3\n");

   $response3 = $browser->post( $url3,
   
		'Content'=>'callCount=1
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
c0-e22=string:971d0b40-b078-96c2-8cdf-669f894ec842
c0-e2=Object_Object:{taskName:reference:c0-e3, methodName:reference:c0-e4, methodArgs:reference:c0-e5, callbackUUID:reference:c0-e22}
c0-e1=array:[reference:c0-e2]
c0-e23=string:6872.81
c0-e24=string:9a8c1355-c9eb-d0c1-1e9a-5308a06f9b76
c0-param0=Object_Object:{methodRequests:reference:c0-e1, clientVersion:reference:c0-e23, pollerUUID:reference:c0-e24}
batchId=45
instanceId=0
page=%2Fconcerto%2FCentral
scriptSessionId='.$SystemGeneratedId.'/VOovRdk-$sUkFFRd9'
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
print ("Url 4 is $url4\n");
   $response4 = $browser->post( $url4,
   
		'Content'=>'callCount=1
windowName=
c0-scriptName=CommonPollerProxy
c0-methodName=doPoll
c0-id=0
c0-e1=array:[]
c0-e2=string:6872.81
c0-e3=string:9a8c1355-c9eb-d0c1-1e9a-5308a06f9b76
c0-param0=Object_Object:{methodRequests:reference:c0-e1, clientVersion:reference:c0-e2, pollerUUID:reference:c0-e3}
batchId=48
instanceId=0
page=%2Fconcerto%2FCentral
scriptSessionId='.$SystemGeneratedId.'/VOovRdk-$sUkFFRd9'
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

#Step 4:
print ("*** Step 4: Parse file 2_SOASTA_RESULTS_DETAILS.xml to:\n");
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
print ("Numresults is $numResults\n");
print $transactionResults[1];
print ("\n\n");

$csvavg = "Name,Avg,90th";
#print ("Name\tavg resp time\t90th\tmin\tmax\tbytesSent\terrors\t\n");
printf ("%50s %8s %8s %8s %8s %8s %8s \n", "Name","avg","90th","min","max","bytesSent","errors");

$plotFileData="Name,Avg,90th,min,max,bytesSent,bytesRcvd,errors\n";
foreach (@transactionResults)
{
	#print ("First item is $items[0]\n");
	@items = split (',',$_);
	$name = $items[0]; $name=~s/\\+//g; $name =~ s/"//g;
	$collections=$items[5];
	$avg=$items[7]/1000;
	$min=$items[8]/1000;
	$max=$items[9];
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
	$bytesRcvd{$name}=$bytesRcvd;
	$collections{$name}=$collections;
	printf ("%50s    %3.3f    %3.3f     %3.3f    %3.3f   %3i    %3i \n", $name,$avg,$ninetieth,$min,$max,$bytesSent,$errors);
	print ("Should plot for $name is : $shouldPlot{$name}\n");
	if ($shouldPlot{$name} eq "True")
	{ 		
		$plotFileData.="$name,$avg,$ninetieth,$min,$max,$bytesSent,$bytesReceived,$errors\n";
	}
}

print ("Plot file is :\n$plotFileData\n");
open PLOTFILE, ">Plotfile.csv" or die ("Couldn't open PlotFile for writing\n");
print PLOTFILE $plotFileData;
close PLOTFILE;

$junitxml='<?xml version="1.0" encoding="UTF-8"?>'."\n";
$junitxml.="<testsuite tests=\"$numSLAItems\">\n";

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
 			$junitxml.="\t<testcase name=\"$SLA max of $SLA{$SLA}\" classname=\"Performance\" time=\"$actual{$SLA}\" />\n";			
 		}
 	else
 		{
 			$junitxml.="\t<testcase name=\"$SLA max of $SLA{$SLA}\" classname=\"Performance\" time=\"$actual{$SLA}\"> \n\t\t<failure type=\"performance\"> $message</failure>\n\t</testcase>\n";
 		}	
 		
 	 #Now add to the plot file which has transaction names on the top row and times on the next row
 	 if ($actual{$SLA}!=NULL)
 	 {
 		if(length($theader)==0){$theader="$SLA";} else  {$theader.=",$SLA"};
		if(length($ttime)==0){$ttime="$actual{$SLA}";} else  {$ttime.=",$actual{$SLA}"};
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
 			$junitxml.="\t<testcase name=\"$transaction 90th of $SLAninetieth{$transaction}\" classname=\"Performance\" time=\"$ninetieth{$SLA}\" />\n";			
 		}
 	else
 		{
 			$junitxml.="\t<testcase name=\"$transaction 90th percentile should be faster than SLAninetieth{$transaction}\" classname=\"Performance\" time=\"$ninetieth{$transaction}\"> \n\t\t<failure type=\"performance\"> $message</failure>\n\t</testcase>\n";
 		}	
 		
 	 #Now add to the plot file which has transaction names on the top row and times on the next row
 	 if ($ninetieth{$transaction}!=NULL )
 	 {
 	 	print ("Inside 90th plotfile \n");
 		if(length($ninetiethheaders)==0){$ninetiethheaders="$transaction";} else  {$ninetiethheaders.=",$transaction"};
		if(length($ninetiethvalues)==0){$ninetiethvalues="$ninetieth{$transaction}";} else  {$ninetiethvalues.=",$ninetieth{$transaction}"};
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
 			$junitxml.="\t<testcase name=\"$transaction max of $SLAninetieth{$transaction}\" classname=\"Performance\" time=\"$ninetieth{$transaction}\"> \n\t\t<failure type=\"performance\"> $message</failure>\n\t</testcase>\n";
 		}	
 		
 	 #Now add to the plot file which has transaction names on the top row and times on the next row
 	 if ($errors{$transaction}!=NULL)
 	 {
 	 	print ("WRITING ERROR STUFF\n");
 	 	if(length($errorsHeader)==0){$errorsHeader="$transaction";} else  {$errorsHeader.=",$transaction"};
		if(length($errorsValues)==0){$errorsValues="$errors{$transaction}";} else  {$errorsValues.=",$actual{$transaction}"};
	 }
 }


 $plotfile="$theader\n$ttime\n"; #Holds the average response time plot Data
 $nplotfile="$ninetiethheaders\n$ninetiethvalues\n"; #Holds the 90th percentile Plot Data
 $eplotfile="BLAH$errorsHeader\n$errorsValues\n"; #Holds the error Plot Data
 $junitxml.='</testsuite>';
 
 #Print the Average Response Time Plot File
 open PLOTOUTPUT , ">3_CloudTestPlotFileAvg.csv";
 print PLOTOUTPUT $plotfile;
 close PLOTOUTPUT;
 
 #Print the Ninetieth Percentile Plot File
 open PLOTNOUTPUT , ">4_CloudTestPlotFile90th.csv";
 print PLOTNOUTPUT $nplotfile;
 close PLOTNOUTPUT;
 
 #Print the Error Plot File
 open PLOTEOUTPUT , ">4b_CloudTestPlotFileErrors.csv";
 print PLOTEOUTPUT $eplotfile;
 close PLOTEOUTPUT;
 
 #Print the Performance Results PlotFile
 open PERF, ">5_PERF_THRESHOLD_RESULTS.xml";
 print PERF "$junitxml";
 close PERF;
 
  
 print ("\n\n Average PLOT FILE: \n $plotfile \n\n Ninetieth Percentile Plotfile:\n $nplotfile\n\n Error PlotFile: $eplotfile\n\nJunitXML:\n $junitxml\n");
 
close FILE;
close OUTPUT;
