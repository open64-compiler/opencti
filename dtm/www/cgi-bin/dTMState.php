<!--
 ====================================================================

 Copyright (C) 2011, Hewlett-Packard Development Company, L.P.
 All Rights Reserved.

 Open64 is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 2
 of the License, or (at your option) any later version.

 Open64 is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 MA  02110-1301, USA.

 ====================================================================
-->
<?php

$thisphpscript = "dTMState.php";

### Process the dTM_conf.xml file and read the server, port, auxport and dtmhome from the config file
$xml_file  = "../../conf/dTM_conf.xml"; 
$xml_dtm_server_host_key    = "*DTM*SERVER*HOST"; 
$xml_dtm_server_port_key    = "*DTM*SERVER*PORT"; 
$xml_dtm_server_auxport_key = "*DTM*SERVER*AUXPORT"; 
$xml_dtm_server_loadmonport_key = "*DTM*SERVER*LOADMONPORT"; 
$xml_dtm_server_dtmhome_key = "*DTM*SERVER*DTMHOME"; 
$xml_dtm_server_log_key     = "*DTM*SERVER*LOG"; 
$xml_dtm_server_errorlog_key = "*DTM*SERVER*ERRORLOG"; 

#------------------------------------------
function startTag($parser, $data){
    global $current_tag;
    $current_tag .= "*$data";
}

#------------------------------------------
function endTag($parser, $data){
    global $current_tag;
    $tag_key = strrpos($current_tag, '*');
    $current_tag = substr($current_tag, 0, $tag_key);
} 

#------------------------------------------
function contents($parser, $data){
    global $current_tag, $xml_dtm_server_host_key, $xml_dtm_server_port_key,
           $xml_dtm_server_auxport_key, $xml_dtm_server_dtmhome_key,
           $xml_dtm_server_log_key, $xml_dtm_server_errorlog_key,
           $dtmhost, $port, $auxPort, $DTM_HOME, $serverLog, $serverErrorLog,
           $xml_dtm_server_loadmonport_key, $loadmonPort;
    
    switch($current_tag){
        case $xml_dtm_server_host_key:
            $dtmhost = $data;
            break;
        case $xml_dtm_server_port_key:
            $port = $data;
            break;
        case $xml_dtm_server_auxport_key:
            $auxPort = $data;
            break;
        case $xml_dtm_server_loadmonport_key:
            $loadmonPort = $data;
            break;
        case $xml_dtm_server_dtmhome_key:
            $DTM_HOME = $data;
            break;
        case $xml_dtm_server_log_key:
            $serverLog = $data;
            break;
        case $xml_dtm_server_errorlog_key:
            $serverErrorLog = $data;
            break;
    } 
}

$xml_parser = xml_parser_create();
xml_set_element_handler($xml_parser, "startTag", "endTag");
xml_set_character_data_handler($xml_parser, "contents");
$fp = fopen($xml_file, "r") or die("Could not open file");
$data = fread($fp, filesize($xml_file)) or die("Could not read file");

if(!(xml_parse($xml_parser, $data, feof($fp)))){
    die("Error on line " . xml_get_current_line_number($xml_parser));
}

xml_parser_free($xml_parser);
fclose($fp); 



#
# Allow override of default dtm host for testing.
# 
if ( isset($_GET[server]) ) {
   $dtmhost=$_GET[server];
   $server = "&server=$dtmhost";
}  else {
    $server = "";
}
if ( isset($_GET[webserver]) ) {
   $webhost=$_GET[webserver];
} else {
   $webhost="{CONFIGURE_webserver}";
}

$web_root_cti="http://$webhost/{CONFIGURE_webroot}";
$web_root_dtm="$web_root_cti/dtm/www";

$url="$web_root_dtm/cgi-bin/$thisphpscript";
$debug=0;
if ( isset($_GET[debug]) ) {
   $debug=1;
}
$bgqueue=0;
if ( isset($_GET[bgqueue]) ) {
   $bgqueue=1;
}

#------------------------------------------
function timeHHMM($minutes)
{
   if ($minutes <= 0)
      return "0";

   $hours = (int) ($minutes / 60);
   $minutes = $minutes - ($hours * 60);
   if ($minutes < 10) 
      return "$hours:0$minutes";
   else
      return "$hours:$minutes";
}

#------------------------------------------
function timeElapsed($stime)
{
   global $curTime;

   if ($stime == 0)
      return "0";

   $diffs = $curTime - $stime;
   if ( $diffs <= 0 )
      return "0";

   return timeHHMM((int) ($diffs / 60));
}

#------------------------------------------
function timeDiff($locktime, $stime)
{
   global $curTime;

   if ($stime == 0)
      return "0";

   $diffs = $curTime - $stime;
   if ( $diffs <= 0 )
      return "0";

   return timeHHMM($locktime - (int) ($diffs / 60));
}

#------------------------------------------
# color code for jobs
class JobColors 
{
   var $light_yellow = "#FFFFCC";
   var $dark_yellow  = "#F0F0C0";
   var $light_brown  = "#FFC888";
   var $dark_brown   = "#EFAF6F";
   var $light_blue   = "#66FFFF";
   var $dark_blue    = "#60F0F0";
   var $light_green  = "#4FE8AF";
   var $dark_green   = "#4FCFAF";

   var $whitesmoke     = "#EEEEEE";
   var $red            = "#FF8888";
   var $yellow         = "#FFFF99";
   var $lightsteelblue = "#80C4DE";
   var $steelblue      = "#B0C4DE";
   var $darksteelblue  = "#60C4DE";
}

$serialColors = array( "CC", "88", "44", "BB", "77", "33", "E8",
                       "AA", "66", "25", "DA", "99", "55", "17");

$jobcolor = new JobColors();
$dtmHome = "";
$auxDtmHome = "";

#------------------------------------------
function dump($foo)
{
   echo "<pre>";
   print_r($foo);
   echo "</pre>";
}

#------------------------------------------
function inqueryMachineState($machineName, $loadmonPort)
{
    $sock = fsockopen($machineName,$loadmonPort,$eno,$estr,2);
    $state = array();
    if ( $sock )
    {
        $str = fgets($sock, 1024);
        $tokens = split("&", $str);
        foreach($tokens as $item){
            $kv_pairs = split("=", $item);
            if(count($kv_pairs) < 2){
                $loads = split(":", $item);
                if(count($loads) == 3){
                    $state["idle"] = $loads[0];
                    $state["disk_util"] = $loads[1];
                    $state["swap_util"] = $loads[2];
                }
            }else{
                $state[$kv_pairs[0]] = $kv_pairs[1];
            }
        }
    }
    fclose($sock);
    return $state;
}

#------------------------------------------
function combinePoolList($pools,$auxPools)
{
   return $pools;
   #return $auxPools;
}

#------------------------------------------
function combineUserList($users,$auxUsers)
{
   $auxCount = count($auxUsers);
   if ( $auxCount == 1 && strlen($auxUsers[0]) == 0 )
      return $users;

   $hash = Array();
   $combinedUsers = Array();
   $combinedCount = 0;

   $cnt = count($users);
   $i = 0;
   if ( strlen($users[0]) == 0 )
      $i++;
   for ( ; $i < $cnt; $i++ ) 
   {
      if ( !array_key_exists($users[$i],$hash) ) 
      {
         $combinedUsers[$combinedCount++] = $users[$i];
         $hash[$users[$i]] = 1;
      }
   }
   for ( $i = 0; $i < $auxCount; $i++ )
   {
      if ( !array_key_exists($auxUsers[$i],$hash) ) 
      {
         $combinedUsers[$combinedCount++] = $auxUsers[$i];
         $hash[$auxUsers[$i]] = 1;
      }
   }
   if ( $combinedCount == 0 )
      $combinedUsers[0] = "";

   sort($combinedUsers);
   return $combinedUsers;
}

#------------------------------------------
function combineUserStateData(&$userTasks,$auxUserTasks)
{
   $cnt = count($userTasks);
   $auxcnt = count($auxUserTasks);
   if ( $auxcnt > 0 )
   {
      for ( $j = 0; $j < $auxcnt; $j++, $cnt++ )
      {
	 $userTasks[$cnt] = $auxUserTasks[$j];
      }
   }   
}

#------------------------------------------
function combineStateData($machineState,$auxMachineState)
{
   $combinedState = Array();

   array_shift($machineState);  # remove pool name
   $numCurMachine = array_shift($machineState);
   for ( $j = 0; $j < $numCurMachine; $j++ )
   {
      preg_match("/^(\S+):.+/",$machineState[$j],$matches);
      $curName = $matches[1];
      $mdata = Array("shadow" => 0, "data" => $machineState[$j]);
      $data = Array("shadow" => 0, "mstate" => Array($mdata));
      $combinedState[$curName] = $data;
   }
   array_shift($auxMachineState); # remove pool name
   $numShadowMachine = array_shift($auxMachineState);
   for ( $j = 0; $j < $numShadowMachine; $j++ )
   {
      preg_match("/^(\S+):.+/",$auxMachineState[$j],$matches);
      $curName = $matches[1];
      $mdata = Array("shadow" => 1, "data" => $auxMachineState[$j]);
      if ( array_key_exists($curName,$combinedState) )
      {
         array_push($combinedState[$curName][mstate],$mdata);
      }
      else
      {
         $data = Array("shadow" => 1, "mstate" => Array($mdata));
         $combinedState[$curName] = $data;
      }
   }
   return $combinedState;
}

#------------------------------------------
function machineStateTable($machineState,$loadmonPort, $pattern,$archFilter,$poolName)
{
   global $debug, $jobcolor, $refswitch, $server;

   echo "<TABLE BGCOLOR=\"#CCCCCC\" align=left><TR><TD>";
   echo "<TABLE BORDER=0 CELLPADDING=2 CELLSPACING=2 >\n";
   echo "<TBODY>\n";
   ksort($machineState);

   foreach ( $machineState as $name => $mdata )
   {
      $shadow = $mdata[shadow];
      $mstate = $mdata[mstate];
      if ( $debug ) {
         dump($name);
         dump($mstate);
      }
      $cnt = count($mstate);
      $disableCount = 0;
      for ( $j = 0; $j < $cnt; $j++ )
      {
         $shadowJob = $mstate[$j][shadow];
         $machineData = explode(":",$mstate[$j][data]);
         #dump($machineData);

         $name  = $machineData[0];         #1
         $arch  = $machineData[1];         #2
         $cpus  = $machineData[2];         #3
         $up    = $machineData[3];         #4
         $avail = $machineData[4];         #5
         if ($avail == "false") {
            $person  = $machineData[5];    #6
            $info    = $machineData[6];    #7
            $dtime   = $machineData[7];    #8
            $jobList = $machineData[8];    #9
         } 
         else
            $jobList = $machineData[5];    #6

         # Skip any machines that do not match the non-empty
         # arch filter
         if ( $archFilter != "" && strcasecmp($arch,$archFilter) != 0 )
            continue;
     
         # 
         # Create a machine box for $name
         # 
         if ( $j == 0 )
         {
            echo "\n<TR>";
 
            if ( $up == "false" )
               $color = $jobcolor->red;
            else if ( $avail == "false" )
               $color = $jobcolor->yellow;
            else if ( $shadow )
               $color = $jobcolor->lightsteelblue;
            else
               $color = $jobcolor->steelblue;

            $style = "";
            if ( $shadowJob )
               $style = "id=\"shadow\"";

            if ( !$shadowJob ) {
               $loadd = inqueryMachineState($name, $loadmonPort);
            }
            if ( $loadd['idle'] < 25 ) {
               $idlecolor = "red";
            } else {
               $idlecolor = "green";
            }
            if ( $loadd['disk_util'] < 95 ) {
               $diskcolor = "green";
            } else {
               $diskcolor = "red";
            $color = "brown";
            }
            if ( $loadd['swap_util'] < 90 ) {
               $swapcolor = "green";
            } else {
               $swapcolor = "red";
            $color = "brown";
            }

            #
            # display machine status box
            #
            $sys_release = str_replace(" ", "_", $loadd['Release']);
            echo "<TD ALIGN=CENTER BGCOLOR=\"$color\" style=\"padding-top:8px;padding-bottom:8px\">";
            echo "<FONT $style size=-1><b>$name</b><BR>";
            echo "<FONT $style size=-1>$arch&nbsp;$sys_release<BR>${loadd['Flavor']}</FONT><BR>\n";
            echo "<FONT $style size=-1>${cpus}x</FONT><FONT $style size=-1 COLOR=\"$idlecolor\">${loadd['idle']}%</FONT>&nbsp;";
            echo "<FONT $style size=-1>du:</FONT><FONT $style size=-1 COLOR=\"$diskcolor\">${loadd['disk_util']}%</FONT><FONT $style size=-1>&nbsp;sw:</FONT><FONT $style size=-1 COLOR=\"$swapcolor\">${loadd['swap_util']}%</FONT></TD>\n";
         }

         #
         # Emit running jobs 
         #
         $jobs = explode(";",$jobList);
         for ( $k = 0; $k < count($jobs); $k++ )
         {
            if ( !strcmp($jobs[$k],"") ) continue;
            $jobData = explode("#",$jobs[$k]);
            $gid = $jobData[0];
            $tid = $jobData[1];
            $unit = $jobData[2];
            $user = $jobData[3];
            $view = $jobData[4];
            $runPerformance = $jobData[5];
            $stime = $jobData[6];
            $elapsed = timeElapsed($stime);

            if ( strstr($jobs[$k],$pattern) )
            {
               if ( !$shadowJob )
                  $taskColor = $jobcolor->light_brown;
               else
                  $taskColor = $jobcolor->dark_brown;
            }
            else 
            {
               if ($runPerformance != "true")
               {
                  if ( !$shadowJob )
                     $taskColor = $jobcolor->light_blue;
                  else
                     $taskColor = $jobcolor->dark_blue;
               }
               else
               {
                  if ( !$shadowJob )
                     $taskColor = $jobcolor->light_green;
                  else
                     $taskColor = $jobcolor->dark_green;
               }
            }
            
            if ( $shadowJob ) {
               $style = "id=\"shadow\"";
               $bg = "&bgserver=1";
            } else {
               $style = "";
               $bg = "";
            }
            if ($archFilter != "") 
               $archstr = "&arch=$arch";
            else
               $archstr = ""; 

            if ($user == "{CONFIGURE_webaccount}") 
               $usr = "{CONFIGURE_admin}";
            else
               $usr = $user;

            echo "<TD ALIGN=CENTER BGCOLOR=\"$taskColor\" > ".
                 "<font $style size=-1 >$gid:$tid $user &nbsp;&nbsp;".
                 "<" . $refswitch . $archstr . "&user=$usr" .
                 "&cancel=$gid:$tid&dumpPool=$poolName$bg>cancel!</a>" .
                 "<BR>$view &nbsp;&nbsp;($elapsed)<BR>$unit</font></TD>";
         }

         #
         # Emit disable information if any. There may be two disable items
         # from both foreground and background servers. Used $disableCount
         # to control that only one is displayed.
         # 
         if (++$disableCount <= 1 && $avail == "false") {
            $elapsed = timeElapsed($dtime);
            echo "<TD ALIGN=CENTER BGCOLOR=\"$jobcolor->yellow\" > ".
                 "<font $style size=-1>$person ($elapsed)<br>$info</font></TD>";
         }
      }
   }
   echo "</TBODY></TABLE>\n";
   echo "</TD></TR></TBODY></TABLE>\n";
}

#------------------------------------------
function perfMachineTable($perfMachineList,$pattern,$archFilter,$poolName,$machineState)
{
   global $debug, $jobcolor, $logURL, $server, $fromBgServer, $serialColors, $archUsers;

   # if ($debug) dump($perfMachineList);
   $perfMachines = explode("#", $perfMachineList[1]);
   # if ($debug) dump($perfMachines);
   $perfTaskQueue = explode("#", $perfMachineList[2]);
   # if ($debug) dump($perfTaskQueue);
   array_shift($machineState);
   array_shift($machineState);
   if ($debug) dump($machineState);

   echo "<TABLE BGCOLOR=\"#CCCCCC\" align=left ><TR><TD>";

   #
   # display performace machine list
   #
   $mCount = array_shift($perfMachines);
   #sort($perfMachines);

   echo "<TABLE BORDER=0 CELLPADDING=2 CELLSPACING=2><TBODY>\n";

   $archUsers = array();
   $perfMachPerRow = 4;
   if ($mCount > 0) {
      $cCount = 0;
      for ( $i = 0; $i < $mCount ; $i++ )
      {
         $machine = array_shift($perfMachines);
         if ( strstr($machine, $pattern) ) {
	    $taskColor = $jobcolor->light_brown;
         }
	 else {
            $taskColor = $jobcolor->light_green;
         }

	 if ( $archFilter != "" ) {
	     # get the arch data from $machineState
	     # as it is not available from $perfMachines
	     $machine2 = array_shift($machineState);
             $fields2  = explode(":",$machine2);
	     $name2    = array_shift($fields2);
             $arch2    = array_shift($fields2);

	     # Skip any machines that do not match the non-empty
	     # arch filter
	     if (strcasecmp($arch2,$archFilter) != 0 ) 
	         continue;
	 }

         $fields = explode(";",$machine);
         #if ($debug) dump($fields);

         $mname  = array_shift($fields);  #1 
         $avail  = array_shift($fields);  #2
         $mcolor = $jobcolor->lightsteelblue;
         if ($avail == "false") {
            $person = array_shift($fields);  #3 who disable the machine
            $dtime  = array_shift($fields);  #4 disable time
            $minfo  = array_shift($fields);  #5 disable info
            $mcolor = $jobcolor->light_yellow;
         }
         $machState = array_shift($fields);  #6/3

         #
         # machine name box
         #
         $machLog = $logURL . "lock." . $mname . ".log&last=50";
         if ( $cCount == 0 ) {
             if ( $i != 0 ) {
                echo "</TR>\n";
             }
             echo "<TR>\n";
         }
         if ( ++$cCount == $perfMachPerRow ) {
            $cCount = 0;
         }
         echo "<TD ALIGN=CENTER BGCOLOR=\"$mcolor\"><BR>";
         echo "<B>$mname</B><BR><A HREF=\"$machLog\">log</A><BR><BR></TD>\n";

         #
         # display the task running on the machine, if any
         #
         if ($machState == "Locked") {
            $user      = $fields[0];       #7/4

	    # Capture all the user names who mactched the wanted arch, if any
	    # Otherwise, capture all the user names
	    array_push($archUsers, $user);

            $id        = $fields[1];       #8
            $type      = $fields[2];       #9
            $priority  = $fields[3];       #10
            $locktime  = $fields[4];       #11
            #$waittime = $fields[5];       #12
            $view      = $fields[6];       #13
            $info      = $fields[7];       #14
            #$enqtime  = $fields[8];       #15
            $bgTaskId  = $fields[9];       #16
            $runtime   = $fields[10];      #17 in second
            $time = timeElapsed($runtime);
            if ($locktime > 0) {
               $ltime = timeHHMM($locktime);
            } else {
               $ltime = "";
            }
            # "^[0-9]+\.[0-9]*[a-zA-Z][a-zA-Z0-9]*_[0-9]+" matches something
            # like 164.gzip_3728 or 457.10j_6239
            if ($type == "Rerun" &&
                ereg("^[0-9]+\.[0-9]*[a-zA-Z][a-zA-Z0-9]*_[0-9]+", $info)) {
               $info = "Rerun $info";
            }
            if ($bgTaskId > 0 || $fromBgServer)
               $style = "id=\"shadow\"";
            else
               $style = "";

            echo "<TD ALIGN=CENTER BGCOLOR=\"$taskColor\"><font $style size=-1>";
            echo "$id: $user   priority=$priority<BR>$info<BR>$view  ($time) $ltime";
            #echo "$machine";
            echo "</font></TD>\n";
         }
         elseif ($avail != "false") {
            echo "<TD>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;" .
                 "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</TD>\n";
         }

         #
         # display the disabling info, if any 
         #
         if ($avail == "false") {
            $time = timeElapsed($dtime);
            echo "<TD ALIGN=CENTER BGCOLOR=\"$mcolor\">$person ($time)<BR>$minfo</TD>\n";
         } 
      }
      echo "</TR>\n";
   } else {
      echo "<TR><TD><BR>No performacne test machine<BR><BR></TD></TR>";
   }
   echo "</TBODY></TABLE>\n";


   #
   # display performace task queue
   #
   echo "</TD></TR><TR><TD>\n";

   if ($debug) dump($perfTaskQueue);
   $tCount = array_shift($perfTaskQueue);

   # title bar
   echo "<TABLE WIDTH=100% BORDER=0 CELLPADDING=2 CELLSPACING=2>\n";
   echo "<TR><TD ALIGN=CENTER BGCOLOR=\"#9999CC\"><BR>";
   echo " Performance Task Queue <BR><BR></TD></TR></TABLE>\n";

   # jobs in the queue
   echo "<TABLE WIDTH=100% BORDER=0 CELLPADDING=2 CELLSPACING=2>\n";
   echo "<TR>";
   $taskColor = $jobcolor->light_yellow;

   if ($mCount > 0) {
      $sCount = count($serialColors);
      $cidx = 0;
      $pidx = 0;
      $dtmjobcolors = array();
      $theCount = 0;
      for ($i = 0 ; $i < $tCount ; $i++ )
      {
         if (++$theCount > 5) {
            echo "</TR><TR>\n";
            $theCount = 1;
         }
         
         $task = array_shift($perfTaskQueue);
         $fields = explode(";",$task);
         if ($debug)
            dump($fields);
         $user      = $fields[0];  

	 # continue if $user is not in $archUsers
	 #TODO: If same user runs Performance tests simultaneously on more than one 
	 #      architechture, this code will not work properly
	 if(!in_array($user, $archUsers))
	    continue;

         $id        = $fields[1]; 
         $type      = $fields[2];
         $priority  = $fields[3]; 
         #$locktime = $fields[4];
         $waittime  = $fields[5];
         $view      = $fields[6];
         $info      = $fields[7];
         $enqtime   = timeElapsed($fields[8]);
         $bgTaskId  = $fields[9];
         #$runtime  = timeElapsed($fields[10]);

         if (strstr($task, $pattern)) {
	    $taskColor = $jobcolor->light_brown;
         } elseif ($type == "Rerun" &&
                   ereg("^[0-9]+\.[0-9]*[a-zA-Z][a-zA-Z0-9]*_[0-9]+", $info)) {
            if (substr($info, 0,1) == "4")
               $taskColor = "#FFFF" . $serialColors[$cidx++];
            else
               $taskColor = "#FF" . $serialColors[$pidx++] . "FF";
         } elseif ($type == "dTM") {
            $dtmjob = explode(":", $info);
            if (! $dtmjobcolors[$dtmjob[0]]) {
               if (substr($dtmjob[2], 0,1) == "4") 
                  $dtmjobcolors[$dtmjob[0]] = "#FFFF" . $serialColors[$cidx++];
               else
                  $dtmjobcolors[$dtmjob[0]] = "#FF" . $serialColors[$pidx++] . "FF";
            }
            $taskColor = $dtmjobcolors[$dtmjob[0]];
         } else {   # other interactive jobs
            $taskColor = "#FFFF" . $serialColors[$cidx++];
         }
         if ($cidx == $sCount) $cidx = 0;
         if ($pidx == $sCount) $pidx = 0;

         if ($waittime > 0)
            $otime = timeHHMM($waittime);
         else
            $otime = "";

         if ($bgTaskId > 0 || $fromBgServer)
            $style = "id=\"shadow\"";
         else
            $style = "";
            
         if ($type == "Rerun" &&
             ereg("^[0-9]+\.[0-9]*[a-zA-Z][a-zA-Z0-9]*_[0-9]+", $info)) {
            $info  = "Rerun: $info";
         }

         echo "<TD ALIGN=CENTER BGCOLOR=\"$taskColor\"><font $style size=-1>";
         echo "$id: $user  priority=$priority<BR>$info<BR>$view  ($enqtime) $otime";
         echo "</font></TD>\n";
      }
      if ($tCount > 0) {
         while (++$theCount <= 5) {
            echo "<TD ALIGN=CENTER>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;" .
                 "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</TD>";
         }
      } else {
         echo "<TD ALIGN=CENTER>&nbsp;<BR>&nbsp;<BR>\n";
      }
   }
   echo "</TR></TBODY></TABLE>\n";

   echo "</TD></TR></TBODY></TABLE>\n";
}

#------------------------------------------
function machinePoolSummary($machineState)
{
   global $refswitch;

   $poolCount = array_shift($machineState);

   echo "<TABLE BGCOLOR=\"#CCCCCC\" align=left BORDER=0 CELLPADDING=5 CELLSPACING=2>\n";
   echo "<TBODY>\n";

   $j = 0;
   for ( $i = 0; $i < $poolCount ; $i++ )
   {
      $pool = $machineState[$i + $j];
      echo "<TR><TD ALIGN=CENTER BGCOLOR=\"#9999CC\">Pool : $pool</TD></TR>\n";
      $j += 1;

      $numMachine = $machineState[$i + $j];
      $j += 1;
      echo "<TR><TD ALIGN=CENTER>\n";
      echo "<TABLE BORDER=2 CELLPADDING=5 CELLSPACING=2><TBODY>\n";

      echo "<TR><TD>HostName</TD>";
      echo     "<TD>OS</TD>";
      echo     "<TD>Flavor</TD>";
      echo     "<TD>System Arch</TD>";
      echo     "<TD>Processor Arch</TD>";
      echo     "<TD>Freq (GHz)</TD>";
      echo     "<TD>CPU Cores</TD>";
      echo     "<TD>Memory (GB)</TD>";
      echo     "<TD>Workdir</TD>";
      echo     "<TD>Services</TD>";
      echo     "<TD>Up</TD>";
      echo     "<TD>Enabled</TD>";
      echo     "<TD>Reason</TD>";
      echo "</TR>\n";
      
      for ( $k = 0; $k < $numMachine; $k++ )
      {
         $machineData = explode(":",$machineState[$i + $j + $k]);
         $name   = $machineData[0];
         $osys   = $machineData[1];
         $flavor = $machineData[2];
         $arch   = $machineData[3];
         $impl   = $machineData[4];
         $freq   = $machineData[5];
         $cpus   = $machineData[6];
         $memo   = $machineData[7];
         $disk   = $machineData[8];
         $auto   = $machineData[9];
         $work   = $machineData[10];
         $service= $machineData[11];
         $up     = $machineData[12];
         $inPool = $machineData[13];
         $disres = $machineData[14];
         echo "<TR><TD>$name</TD>";
         echo     "<TD>$osys</TD>";
         echo     "<TD>$flavor</TD>";
         echo     "<TD>$arch</TD>";
         echo     "<TD>$impl</TD>";
         echo     "<TD>{$freq}</TD>";
         echo     "<TD>$cpus</TD>";
         echo     "<TD>$memo</TD>";
         echo     "<TD>$work</TD>";
         echo     "<TD>$service</TD>";
         if ( !strcmp($up,"false") )
            echo  "<TD ALIGN=CENTER>N</TD>";
         else 
            echo  "<TD ALIGN=CENTER>Y</TD>";

         $switch = $refswitch . "&host=$name&switch";
         if ( !strcmp($inPool,"false") )
            echo "<TD ALIGN=CENTER><$switch=enable>N</a></TD><TD>$disres</TD>";
         else 
            echo "<TD ALIGN=CENTER><$switch=disable>Y</a></TD><TD>&nbsp;</TD>";

         echo "</TR>\n";
      }
      $j += ($numMachine - 1);
      
      echo "</TR></TABLE>\n";
      echo "</TD></TR>";
   }
   
   echo "</TBODY></TABLE>\n";
   return;
}

#------------------------------------------
function userTaskTable($user,$userTasks,$nonShadowCount,$log_url, $serverlog)
{
   global $server, $jobcolor, $refswitch, $debug, $web_root_cti;

   echo "<TABLE BGCOLOR=\"#CCCCCC\" align=left><TR><TD>";
   echo "<TABLE BORDER=0 CELLPADDING=5 CELLSPACING=2 >\n";
   echo "<TBODY>\n";
   
   if ($debug) {
      dump($userTasks);
   }

   $numTasks = count($userTasks);
   if ( $numTasks <= 1 ) 
   {
      echo "<TR>\n";
      echo "<TD ALIGN=CENTER BGCOLOR=\"#9999CC\"><BR><FONT COLOR=\"white\">\n";
      echo "<H3>No running or pending tasks...</H3>";
      echo "</TD>\n";
   }
   else 
   {
      if ($user == "{CONFIGURE_webaccount}") 
         $usr = "{CONFIGURE_admin}";
      else
         $usr = $user;

      $align = "ALIGN=CENTER BGCOLOR=\"#9999CC\"";
      $space = "BORDER=0 CELLPADDING=2 CELLSPACING";

      for ( $i = 1; $i < $numTasks; $i++ )
      {
         $groupData = explode("^", $userTasks[$i]);  # TaskGroup.java  printState()
         $gid      = $groupData[0];
         $priority = $groupData[1];
         $view     = $groupData[2];
         $stime    = timeHHMM($groupData[3]);
         $pool     = $groupData[4];
         $jobname  = $groupData[5];
         $log      = $groupData[6];
         $rcount   = $groupData[7];
         $pcount   = $groupData[8];
         
         if ( $i <= $nonShadowCount )
         {
            $style = "";
            $bg = "";
         }
         else
         {
            $style = "id=\"shadow\"";
            $bg = "&bgserver=1";
         }
	
         echo "<TR><TD $align><TABLE $space=0><TBODY><TR>\n";
         echo "<TD $align><font $style size=-1 >\n";
	 echo     "Job: <a href=$web_root_cti/cgi-bin/get-options-file.cgi?file=$jobname&view=$view>$jobname</a> ($stime)";
         echo "</font></TD></TR><TR><TD $align><font $style size=-1>\n";
	 echo     "Log: <a href=$web_root_cti/cgi-bin/get-log-file.cgi?log=$log>$log</a>"; 
	 echo "</font></TD></TR><TR><TD $align><font $style size=-1>\n";
         echo     "Group=<a href=$log_url$serverlog&fi=%20$gid:>$gid</a>, ";
         echo     "View=$view, Pool=$pool, ";
         echo     "Priority=$priority &nbsp;&nbsp;<$refswitch&user=$usr";
         echo     "&cancel=$gid:-1&dumpUser=$user$bg>Cancel!</a>";
	 echo     "</font></TD></TR><TR><TD $align><font $style size=-1>\n";
	 $logcount = fopen($log, r);
         if ($logcount) {
	    while(!feof ($logcount))
	    {
	        $testcount = fgets($logcount);
	        if (strstr($testcount, '# TOTAL')) 
	        echo $testcount;
	    }
	    fclose($log);
         }
         echo "</font></TD></TR></TBODY></TABLE></TD></TR>\n";
      
         echo "<TR><TD>\n";
         echo "<TABLE $space=2>\n";
         echo "<TR>\n";

         $theCount = 0;
         for ( $k = 0; $k < $rcount; $k++ )
         {
            if ( $theCount == 5 )
            {
               echo "</TR>\n";
               echo "<TR>\n";
               $theCount = 0;
            }
            
            $jobData = explode("#",$groupData[9 + $k]);
            $name = $jobData[0];
            $tid = $jobData[1];
            $stime = $jobData[2];
            $machine = $jobData[3];
            $runPerformance = $jobData[4];
	

            if ($runPerformance != "true")
            {
               if ( $i <= $nonShadowCount )
                  $taskColor = $jobcolor->light_blue;
               else
                  $taskColor = $jobcolor->dark_blue;
            }
            else
            {
               if ( $i <= $nonShadowCount )
                  $taskColor = $jobcolor->light_green;
               else
                  $taskColor = $jobcolor->dark_green;
            }
            $elapsed = timeElapsed($stime);
            echo "<TD ALIGN=CENTER BGCOLOR=\"$taskColor\" > ".
                 "<font $style size=-1 >$tid : $machine ($elapsed)".
                 "<BR>$name<BR> <" . $refswitch . "&user=$usr" .
                 "&cancel=$gid:$tid&dumpUser=$user$bg>cancel!</a>" .
                 "</font></TD>";
            $theCount++;
         }

         # Start a new row for pending jobs
         $theCount = 5;
         for ( $l = 0; $l < $pcount; $l++ )
         {
            if ( $theCount == 5 )
            {
               echo "</TR>\n";
               echo "<TR>\n";
               $theCount = 0;
            }
            $jobData = explode("#",$groupData[9 + $rcount + $l]);
            $name = $jobData[0];
            $tid = $jobData[1];
            $stime = $jobData[2];
            $machine = $jobData[3];
            $runPerformance = $jobData[4];

            if ($runPerformance != "true")
            {
               if ( $i <= $nonShadowCount )
                  $taskColor = $jobcolor->light_yellow;
               else
                  $taskColor = $jobcolor->dark_yellow;
            }
            else
            {
               # pending jobs never go here
               # for debugging purpose, we set something
               $style = "id=\"shadow\"";
               $taskColor = "black";
            }
            $elapsed = timeElapsed($stime);
            echo "<TD ALIGN=CENTER BGCOLOR=\"$taskColor\" > ".
                 "<font $style size=-1 >$tid : $name" .
                 "<BR>$machine ($elapsed)</font> " .
                 "<" . $refswitch . "&user=$usr" . "&cancel=" .
                 "$gid:$tid&dumpUser=$user$bg>cancel!</a></TD>";
            $theCount++;
         }
         echo "</TR></TABLE>\n";
         echo "</TD></TR>";
      }
   }

   echo "</TBODY>\n";
   echo "</TABLE>\n";
   echo "</TD></TR></TABLE>\n";
}

#------------------------------------------
function defaultTable()
{
   echo "<TABLE ALIGN=CENTER BORDER=0><TR><TD VALIGN=TOP>\n";
   echo "<img src=\"../images/dTMSplash.jpg\">\n";
   echo "</TD></TR></TABLE>\n";
}

#------------------------------------------
class Menu
{
   
   var $borderSize= 0;  # 0
   var $menuWidth= 140; # 1
   var $borderColor="white";# 2
   var $linkWidth=""; # 3
   var $linkLowColor="white"; # 4 
   var $linkHighColor="#CCCCCC"; #5
   var $linkAlign="left"; # 6
   var $headerBGColor="#9999CC"; # 7 
   var $fontSize="2"; # 8
   var $fontFace="verdana"; # 9
   var $fontColor="black"; # 10
   var $menuType="vertical"; # 11 
   var $highlighCurrent="yes"; # 12

   var $headerFontSize="2";
   var $headerFontColor="white";
   var $headerFontFace="verdana";

   function Menu() { }
   
   function beginLight()
   {
      echo "<TABLE BGCOLOR=\"$this->borderColor\" CELLPADDING=0 CELLSPACING=\"0\"".
           " BORDER=0 WIDTH=$this->menuWidth><TR><TD>";
      echo "<TABLE CELLPADDING=0 CELLSPACING=$this->borderSize BORDER=0".
           " width=\"100%\">\n";
   }

   function addHeader($headerText)
   {
      echo "<TR>";
      echo "<TD WIDTH=$this->menuWidth BGCOLOR=$this->headerBGColor " .
           "ALIGN=$this->linkAlign>\n";
      echo "<FONT SIZE=$this->headerFontSize FACE=$this->headerFontFace " .
           "COLOR=\"$this->headerFontColor\">";
      echo "&nbsp;$headerText&nbsp;</TD>\n";
      echo "</TR>\n";
   }

   function addLink($linkText,$url)
   {
      echo "<TR>";
      echo "<TD WIDTH=$this->menuWidth ALIGN=$this->linkAlign " .
           "BGCOLOR=$this->linkLowColor >\n";
      echo "<A HREF=$url CLASS=\"menuLink\" TARGET=\"\">" .
           "<FONT SIZE=$this->fontSize FACE=\"$this->fontFace\" ".
           "COLOR=\"$this->fontColor\">&nbsp;$linkText&nbsp;</FONT></A>";
      echo "</TD>";
      echo "</TR>\n";
   }

   function addLink2($linkText,$url,$linkText2,$url2)
   {
      echo "<TR><td>";
      echo "<table cellspacing=\"0\" cellpadding=\"0\"><tr>";
      echo "<TD WIDTH=$this->menuWidth ALIGN=$this->linkAlign " .
           "BGCOLOR=$this->linkLowColor >\n";
      echo "<A HREF=$url CLASS=\"menuLink\" TARGET=\"\">" .
           "<FONT SIZE=$this->fontSize FACE=\"$this->fontFace\" ".
           "COLOR=\"$this->fontColor\">&nbsp;$linkText&nbsp;</FONT></A>";
      echo "</TD>";

      echo "<TD WIDTH=$this->menuWidth ALIGN=right " .
           "BGCOLOR=$this->linkLowColor >\n";
      echo "<A HREF=$url2 CLASS=\"menuLink\" TARGET=\"\">" .
           "<FONT SIZE=$this->fontSize FACE=\"$this->fontFace\" ".
           "COLOR=\"$this->fontColor\">&nbsp;$linkText2&nbsp;</FONT></A>";
      echo "</TD>";
      echo "</tr></table>";

      echo "</td></TR>\n";
   }

   function addColorSerials($desc, $spec)
   {
      global $serialColors;

      echo "<TR><TABLE WIDTH=$this->menuWidth CELLPADDING=0 CELLSPACING=0><TR>\n";
      $len = strlen($desc);
      $cnbr = count($serialColors);
      $cidx = 0;
      $color = "";
      for ($i = 0; $i<$len; $i++) {
         $char = substr($desc,$i,1);
         if ($spec == 2006)
            $color = "#FFFF" . $serialColors[$cidx++];
         else
            $color = "#FF" . $serialColors[$cidx++] . "FF";
         echo "<TD BGCOLOR=$color>$char</TD>\n";
         if ($cidx >= $cnbr) 
            $cidx = 0;
      }
      echo "</TR></TABLE></TR>\n";
   }

   function addColorCode($desc, $color)
   {
      echo "<TR> <TD WIDTH=$this->menuWidth ALIGN=$this->linkAlign " .
           "BGCOLOR=$color >$desc\n" . "</TD></TR>\n";
   }

   function endLight()
   {
      echo "</TABLE></TD></TR></TABLE>\n";
   }
}

#------------------------------------------
function freadinfo($fp)
{
   $instr = "";
   while ( !feof($fp) )
   {
      $c = fgetc($fp);
      if ( $c == "\n" )
         break;

      $instr .= $c;
   }
   return $instr;
}

#------------------------------------------
function retrieveUsersPools($fp,&$users,&$pools,&$dtmHome,&$curTime)
{
   global $debug;

   fputs($fp,"SYSPOOLSUSERS\n");
   $sysInfo = freadinfo($fp);
   $sysList = explode("%",$sysInfo);

   if ($debug) {
      dump($sysList);
   }
   $dtmHome = array_shift($sysList);
   $curTime = array_shift($sysList);

   $poolInfo = array_shift($sysList);
   $pools = explode(":",$poolInfo);
   array_shift($pools); # remove pool count
   sort($pools);

   $userInfo = array_shift($sysList);
   $users = explode(":",$userInfo);
   array_shift($users); # remove user count
   sort($users);
}

#------------------------------------------
function retrieveMachineList($fp,&$machineState,$debug)
{
   fputs($fp,"DUMPMACHINELIST\n");
   $machineList = freadinfo($fp);
   $machineState = explode("%",$machineList);
   # Pop off the msg header
   if ($debug) {
      dump($machineState);
   }
   array_shift($machineState); # remove MACHINELIST
}

#------------------------------------------
function retrievePoolState($fp,$poolName,&$machineState,$debug)
{
   fputs($fp,"DUMPPOOLSTATE%$poolName\n");
   $machineList = freadinfo($fp);
   $machineState = explode("%",$machineList);
   # Pop off the msg header
   array_shift($machineState); # remove CURPOOLSTATE
   if ($debug) {
      dump($machineState);
   }
}

#------------------------------------------
function retrievePerfMachine($fp, &$perfMachineList)
{
   fputs($fp,"PERFSTATUS\n");
   $perfmachinesandqueue = freadinfo($fp);
   $perfMachineList = explode("%", $perfmachinesandqueue);
}

#------------------------------------------
function retrieveUserState($fp,$userName,&$userTasks)
{
   fputs($fp,"DUMPUSERSTATE%$userName\n");
   $userTaskList = freadinfo($fp);
   $userTasks = explode("%",$userTaskList);
   array_shift($userTasks);
}

error_reporting(1);

#------------------------------------------
#
# Main code starts here. Begin to query dTM server
#
#------------------------------------------
$fp = fsockopen($dtmhost,$port,&$errno,&$errstr,20);
$fpaux = fsockopen($dtmhost,$auxPort,&$errno,&$errstr,20);

if ( !$fp && !$fpaux )
{
   echo "<HTML>\n";
   echo "<HEAD><TITLE>dTM Status Page</TITLE></HEAD>\n";
   echo "<BODY>\n";
   echo "<CENTER>";
   echo "<H1><B>dTM Status Page</B></H1>\n";
   echo "<H3><B>dTM server is down.</B></H3>\n";
   echo "<P><H3><B>Distributed TM server on host: ".
        "$dtmhost:$port</B></H3></P>\n";
   echo "<P>" . date("D M j G:i:s T Y") . "</P>\n";
   echo "<P>For information on restarting the dTM server, please see the <a href=\"$web_root_cti/doc/dtm_faq.html\">FAQ</a>";
   defaultTable();
   echo "</BODY>\n";
   exit;
}

$curTime = 0;
$fromBgServer = 0;

# From the main server retrieve all data
if ( $fp )
{
   retrieveUsersPools($fp,$users,$pools,$dtmHome,$curTime);
   if ($debug) {
      dump($dtmHome);
   }      
   if ( isset($_GET[dumpPool]) ) {
      if ($_GET[dumpPool] == "null") {
         retrieveMachineList($fp,$machineState,$debug);
      }
      else if ($_GET[dumpPool] == "Performance") {
         retrievePoolState($fp,$_GET[dumpPool],$machineState,$debug);
         retrievePerfMachine($fp, $perfMachineList);
      }
      else 
         retrievePoolState($fp,$_GET[dumpPool],$machineState,$debug);
   } else if ( isset($_GET[dumpUser]) )
      retrieveUserState($fp,$_GET[dumpUser],$userTasks);
   fclose($fp);
}

# From the auxiliary server retrieve all data
if ( $fpaux )
{
   if ($fp) 
      retrieveUsersPools($fpaux,$auxUsers,$auxPools,$auxDtmHome,$auxCurTime);
   else
      retrieveUsersPools($fpaux,$auxUsers,$pools,$dtmHome,$curTime);

   if ( isset($_GET[dumpPool]) ) {
      if ($_GET[dumpPool] == "Performance") {
         if (! $fp || $bgqueue) {
            retrievePoolState($fpaux,$_GET[dumpPool],$auxMachineState,$debug);
            retrievePerfMachine($fpaux, $perfMachineList);
            $fromBgServer = 1;
            # if ($debug) dump(perfmachineList);
         }
      } else {
         retrievePoolState($fpaux,$_GET[dumpPool],$auxMachineState,$debug);
      }
   }
   else if ( isset($_GET[dumpUser]) )
      retrieveUserState($fpaux,$_GET[dumpUser],$auxUserTasks);
   fclose($fpaux);
}

$users=combineUserList($users,$auxUsers);
$pools=combinePoolList($pools,$auxPools);

if ( isset($_GET[dumpPool]) && $_GET[dumpPool] != "null"
     && $_GET[dumpPool] != "Performance")
{
   $combinedState = combineStateData($machineState,$auxMachineState);
}
else if ( isset($_GET[dumpUser]) )
{
   $nonShadowCount = count($userTasks)-1;
   combineUserStateData($userTasks,$auxUserTasks);
}

$refswitch = "a href=./dtmcmd.cgi?phps=$thisphpscript&dtmhome=$dtmHome". $server;
$title = "dTM Status Page";
if  ( isset($_GET[dumpUser]) )
{
   $title = "dTM User Queue: $userTasks[0]";
}
else if ( isset($_GET[dumpPool]) )
{
   $arch_title = $_GET[arch];
   if ($_GET[dumpPool] == "null")
      $title = "dTM Machine Pool Summary";
   else {
      $title = "dTM Machine Pool: $machineState[0]";
      if ($arch_title != "") 
         $title = "$title (Arch: $arch_title)"; 
   }
}

?>


<HTML>
<HEAD>
<link rel="stylesheet" type="text/css" href="../css/homepages-v5.css" />
<!--
<?php
echo "<meta http-equiv=\"refresh\" content=\"60;url=$url\">\n";
?>
-->
<TITLE> <?php echo $title ?> </TITLE>
<STYLE>
#shadow {font-style: italic}
.menuLink {text-decoration:none;}
.menuLink:hover {text-decoration:none;}
</STYLE>
</HEAD>

<BODY>
<script>
<!--
NS4=(document.layers) ? 1 : 0;
//-->
</script>
<CENTER>
<H1><B>

<?php
echo $title;
if ( isset($_GET[dumpUser]) ) 
   {
     echo "&nbsp; &nbsp;<a href=\"./dtmcmd.cgi?phps=dTMState.php&dtmhome=$DTM_HOME&user=$userTasks[0]&cancel=$userTasks[0]&dumpUser=$userTasks[0]\">CANCEL ALL!</a>";
   }
?>

</B></H1>
<P><H3><B>Distributed TM server on host:
<?
echo "$dtmhost" . ":" . "$port";
?>
</B></H3></P>
<P>
<?
echo date("D M j G:i:s T Y");
?>
</P>
<TABLE ALIGN=LEFT BORDER=0>
 <TR>
  <TD VALIGN=TOP>
   <TABLE BORDER=0 CELLPADDING=1 CELLSPACING=2 >
    <TR>
     <TD>

<?php

$logURL = "$web_root_cti/cgi-bin/get-file.cgi?file=$dtmHome/log/";

$menu = new Menu();

$menu->beginLight();
$menu->addHeader("<B>User Task Queues");
$userCount = count($users);
if ( $userCount == 1 && strlen($users[0]) == 0 ) {
   $menu->addLink("None","#");
}
else {
   for ( $u = 0; $u < count($users); $u++ ) {
      $menu->addLink2($users[$u],"$url?dumpUser=$users[$u]" . $server, "log", "$logURL$serverLog&fi=$users[$u]#end");
   }
}

$hasPerformancePool = 0;
$defaultPoolURL = 0;
$perfPoolURL = 0;
$menu->addHeader("<B>Machine Pools");
for ( $k = 0; $k < count($pools); $k++ )
{
   $poolURL = "$url?dumpPool=" . urlencode("$pools[$k]") . $server;
   $menu->addLink($pools[$k], $poolURL);
   if ($pools[$k] == "Default") {
      $defaultPoolURL = $poolURL;
   } elseif ($pools[$k] == "Performance") {
      $perfPoolURL = $poolURL;
      $hasPerformancePool = 1;
   }
}

if ($defaultPoolURL) {
   $menu->addHeader("<B>Quick Links");
   $menu->addLink("Default_x86_64", $defaultPoolURL . "&arch=x86_64");
   $menu->addLink("Performance_x86_64", $perfPoolURL . "&arch=x86_64");
}

$menu->addHeader("<B>Admin");
$menu->addLink("Pool Summary","$url?dumpPool=null" . $server);
$menu->addLink("FAQ","$web_root_cti/doc/dtm_faq.html");
$menu->addLink("Server Log", $logURL . "$serverLog&last=200");
$menu->addLink("Error Log",  $logURL . "$serverErrorLog&last=200");

$menu->addHeader("<B>Color code");
$menu->addColorCode("Running task",$jobcolor->light_blue);
$menu->addColorCode("Pending task",$jobcolor->light_yellow);
if ($hasPerformancePool) {
   $menu->addColorSerials("Pending SPEC2006", 2006);
   $menu->addColorSerials("Pending SPEC2000", 2000);
   $menu->addColorCode("Running SPEC task",$jobcolor->light_green);
}
$menu->addColorCode("Pattern matched task",$jobcolor->light_brown);
$menu->addColorCode("Enabled Machines",$jobcolor->steelblue);
$menu->addColorCode("Disabled Machines",$jobcolor->yellow);
$menu->addColorCode("Performance Machines",$jobcolor->darksteelblue);

$menu->endLight();


?>
     </TD>
    </TR>
   </TABLE>
  </TD>
  <TD valign=top>

<?php

if ( isset($_GET[dumpPool]) )
{
   if ($_GET[dumpPool] == "null")
      machinePoolSummary($machineState);
   else if ($_GET[dumpPool] == "Performance")
      perfMachineTable($perfMachineList,$_GET[pattern],$_GET[arch],$_GET[dumpPool], $machineState);
   else
      machineStateTable($combinedState,$loadmonPort, $_GET[pattern],$_GET[arch],$_GET[dumpPool]);
}
else if ( isset($_GET[dumpUser]) )
   userTaskTable($_GET[dumpUser],$userTasks,$nonShadowCount,$logURL,$serverLog);
else 
   defaultTable();

?>
  </TD>
 </TR>
</TABLE> 
</BODY>
</HTML>
