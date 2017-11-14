// ====================================================================
//
// Copyright (C) 2011, Hewlett-Packard Development Company, L.P.
// All Rights Reserved.
//
// Open64 is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// Open64 is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
// MA  02110-1301, USA.
//
// ====================================================================
import java.util.*;
import java.io.*;

public class UnitTask
{
   private static Hashtable unitMap = null;

   final private int        theTaskId;
   final private int        theGroupId;
   final private String     theIdString;   // representing the task
   final private TaskGroup  theGroup;
   final private String     theUnit;
   final private Connection conn;
   final String             poolDumpStr;
   private TestMachine      theMachine;
   private Process          theProcess;
   private long             theStartTime;   // for pending and running
   private long             oldStartTime;   // for killing task process
   private boolean          runPerformance;
   private int              theState;
   private String           runcmd;
   private int              errorCount;

   static final int PENDING = 0;
   static final int RUNNING = 1;
   static final int RUNPERF = 2;
   static final int RESCHED = 5;
   static final int KILLED  = 9;
   
   public UnitTask(int taskId, TaskGroup group, 
                   String unit, Connection con)
   {
      theTaskId = taskId;
      theGroup = group;
      theGroupId = group.id();
      theUnit = unit;
      conn = con;
      theMachine = null;
      theProcess = null;
      theStartTime = new Date().getTime();
      oldStartTime = 0;
      theState = PENDING;
      runPerformance = false;
      theIdString = "" + theGroupId + ":" + taskId + ":" + unit;
      poolDumpStr = "" + theGroupId + "#" + taskId + "#" + unit + "#"
                    + group().user().name() + "#"
                    + group().clearcaseView() + "#";
      runcmd = null;
      errorCount = 0;
   }
   
   public int id()          { return theTaskId; }
   public int gid()         { return theGroupId; }
   public TaskGroup group() { return theGroup; }
   public String unit()     { return theUnit; }
   public String idString() { return theIdString; }
   public String toString() { return ""+theGroupId + ":" + theTaskId; }
   public Connection conn() { return conn; }

   public TestMachine machine()   { return theMachine; }
   public void machine(TestMachine m) { theMachine = m; }

   public void killProcess() { if (theProcess != null) theProcess.destroy(); }
   public boolean isRemshKilled() { return theStartTime > oldStartTime; }

   // when a test process makes a request INACTIVE%hostname%gid%tid
   // to sever, put the specified task into inactive list
   public void markInactive()
   {
      runPerformance = true;
      // start time for requesting a performance machine

      LogWriter.log("Inactive: " + idString());

      theStartTime = new Date().getTime();
      theMachine.markInactive(this);
   } 

   public void cancelPerformanceRun()
   {
      if (! runPerformance) return;
      runPerformance = false;
      // what about Performance task queue
      PerfTask.removeTask(false, theGroupId, theTaskId);
   }

   public void writeKillMarker()
   {
      String file = group().workDir() + "/TMmsgs/dtm_cancel." + id();
      try {
         FileOutputStream stream = new FileOutputStream(file);
         new PrintStream(stream).println(unit());
         stream.close();
      }
      catch (IOException ioe) {
         LogWriter.log("Failed to write file: " + file);
      }
   }
   
   // Terminates a running task, TRUE if successful.
   public boolean terminate(int newstate)
   {
      TestMachine mach = machine();
      if (mach == null) {
         return false;
      }

      // remember the start time; it will be used to determine
      // if the remsh command is hanging
      oldStartTime = theStartTime;
      theState = newstate;
      String cmd = dTMConfig.rsh()+" "+mach.name()+" "+ dTMConfig.dtmHomeDir()
                   + "/bin/dtm_killPS.pl -ppid1 -id=" + theIdString;
      try 
      {
         // Kill the task...
         Process p = Exec.exec(cmd);
      }
      catch (Exception e)
      {
         LogWriter.log("Exception occurred when " + cmd, e);
         return false;
      }

      // we don't need to remove the killed task here from the
      // task list of the machine. This is done in runningOn().
      conn.send("MSG", "Killing task: " + theIdString);
      return true;
   }
   
   public String toStringPoolDump()
   {
      return poolDumpStr + runPerformance + "#" + (theStartTime/1000);
   }

   // Returns a string representing the contents of the class
   public String toStringUserDump()
   {
      String name = (machine() == null)? "Pending" : machine().name();
      return unit() + "#" + id() + "#" + (theStartTime/1000) + "#" +
             name + "#" + runPerformance;
   }
   
   public void runningOn(TestMachine mach)
   {
      String runIdString = idString() + " on " + mach.name();
      LogWriter.log("Launching " + runIdString); 
      conn.send("MSG", "Launching " + runIdString);
      long runTime = 0;
      int rexecRet = -99;
      int runUtmRet = -99;
      int runUtmPid = -1;
      theState = RUNNING;

      // Construct the run command and run it
      runcmd = dTMConfig.rsh() + " " + machine().name() + 
         (group().clearcaseView().equals("None")? "" : " " +
           dTMConfig.dtmHomeDir() + "/bin/inview.sh " + group().clearcaseView()) + 
         " " + dTMConfig.dtmHomeDir() + "/bin/dtm_runUTM.pl" +
         " -id=" + theIdString + " -w=" + group().workDir();

      // write the command line out, so that we can use it
      // to reproduce process errors
      String file = group().workDir() + "/TMmsgs/dTMcmdline." + id();
      try {
         FileOutputStream sf = new FileOutputStream (file);
         new PrintStream(sf).println(runcmd);
         sf.close();
      }
      catch (IOException ioe) {
         LogWriter.log("Failed to write file: " + file);
      }

      try {
         // Start a separate thread to run the test unit
         theStartTime = new Date().getTime();
         theProcess = Exec.exec(runcmd);

         StringBuffer outputBuffer = new StringBuffer();
         BufferedReader reader = new BufferedReader(
            new InputStreamReader(theProcess.getInputStream()));

         // deal with the test output in this thread
         try {
            String line;
            while ( (line = reader.readLine()) != null ) {
               if ( line.startsWith("PID ") ) {
                  runUtmPid = Integer.parseInt(line.substring(4));
                  continue;
               }                        
               else if ( line.startsWith("%%RTN%% ") ) {
                  runUtmRet = Integer.parseInt(line.substring(8));
                  continue;
               }
               outputBuffer.append(line + "\n");
            }
         }
         catch (IOException ioe) {
            LogWriter.log("Error catching output from " + theIdString);
         }    
          
         // wait for the run process (thread) to complete
         theProcess.waitFor();
         rexecRet = theProcess.exitValue();
         theProcess = null;
        
         long endTime = new Date().getTime();
         runTime = (endTime - theStartTime)/1000;
         // the time serves as pending time if it backs to the queue
         theStartTime = endTime; 

         // Provide to the client any output that was spit out by the
         // running task.
         if ( outputBuffer.length() != 0 ) {
            conn.send("TASKOUT", outputBuffer.toString());
         }

      }
      catch (Exception e) { 
         LogWriter.log("SERVER ERROR", e);
      }

      // Finished, break the machine and task connection right away
      mach.removeTask(this);
      machine(null);
      String fmsg = "Task Completed("+rexecRet+", "+runUtmRet+
                    ", "+runUtmPid+", "+runTime+") "+runIdString;

      if (theState == KILLED) {
         LogWriter.log(fmsg + " KILLED");
         theGroup.removeRunningTask(this);
         conn.send("FINISH", idString() + " KILLED");
         return;
      }
      else if (theState == RESCHED) {
         // asked for reschedule, put it back on the pending task list
         LogWriter.log(fmsg + " Killed and RESCHED");
         theState = PENDING;
         theGroup.retryTask(this);
         conn.send("MSG", "Killed and Rescheduled: " + idString());
         return;
      }
      LogWriter.log(fmsg);

      // Handle success or failure of the task at this point......
      if ( runUtmRet == 0 ) 
      {
         // We've a successful test on this machine, reset its error count
         // LogWriter.log(fmsg);
         theGroup.removeRunningTask(this);
         mach.resetErrorCount();

         // Tell the user client that the task has finished, whether it
         // finished cleanly or not.
         conn.send("FINISH", idString());
      }
      else {
         // If the task failed because of a process problem, then we disable
         // that machine and put the task back on the pending task list.
         //   dtm_runUTM gets some failures:
         //    1. can't creat work directory
         //
         String rm = "rexecRet="+rexecRet+" runUtmRet="+runUtmRet+
                     " runUtmPid="+runUtmPid+" runTime="+runTime;
         String errMsg = "Process error("+rm+") invoking "+runcmd;
         conn.send("MSG", errMsg);

         // increament the error count for this task, and if it reached 3
         // don't retry it
         if (++errorCount >= 3) {
            theGroup.removeRunningTask(this);
            writeKillMarker();
            String msg = idString() + " with process errors for 3 tries";
            conn.send("FINISH",  msg);
            LogWriter.log("FINISH " + msg);
         }
         else {
            // Put the task back into the pending task list
            theState = PENDING;
            theGroup.retryTask(this);

            // Increase error count on the machine, and disable it if reached 
            // max error count
            mach.incErrorCount("Task process error");

            // Finally, inform the client process
            String msg = "Put "+idString()+" back to pending queue for retry.";
            LogWriter.log(msg);
            conn.send("MSG", msg);
         }
      }
   }
}

