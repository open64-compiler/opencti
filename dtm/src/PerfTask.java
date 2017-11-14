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
import java.lang.*;
import java.util.*;
import java.net.*;
import java.io.*;

public class PerfTask
{
   private static int        perfTaskCount = 0;
   private static String     theLock = "Lock for perfTaskCount";
 
   final private int         taskId;
   final private String      taskType;
   final private String      taskOwner;
   final private int         priority;
   final private String      info;
   final private Connection  conn;      // used to pass hostname to getlock
   final private String      view;
   final private int         bgTaskId;  // a perftask on background server
   final private Connection  gconn;     // used to pass msg to user for dTM job
   final         int         gid;
   final         int         tid;
   private       int         locktime;  // how long to hold a lock
   private       int         waittime;  // how long to wait for a lock
   private       String      idString;
   private       boolean     mailout;
   private       TestMachine machineLocked;
   private       long        enQueueTime;
   private       long        startTime;
   private       LinkedList  machCandidates;

   public PerfTask(Vector para, Connection con)  throws Exception
   {
      if (Pool.perfPool == null)
         throw new Exception("No performance machine pool in dTM server");
      
      conn = con;  // send the hostname via this connection to getlock
      synchronized (theLock) { taskId = ++perfTaskCount; };
      enQueueTime = new Date().getTime();
      machineLocked = null;
      mailout = false;

      taskType = (String)para.get(0);
      String machines = (String)para.get(1);
      machCandidates(machines);
      if (machCandidates.size() == 0) {
         throw new Exception("No candidate machine was found.");
      }
      locktime = Integer.parseInt((String)para.get(2));
      waittime = Integer.parseInt((String)para.get(3));

      if (isDtmType()) {
         // 0   1         2         3         4    5    6
         // dTM $machines $locktime $waittime $gid $tid $info
         gid = Integer.parseInt((String)para.get(4));
         tid = Integer.parseInt((String)para.get(5));
         info = ""+gid+":"+tid+":"+(String)para.get(6);
         
         TaskGroup group = TaskScheduler.findGroupWith(gid);
         if (group != null) {
            UnitTask unitTask = group.findTask(tid);
            if (unitTask == null) {
               throw new Exception("Task not found " + gid+":"+tid);
            }
            gconn = group.conn();
            bgTaskId = 0;
            priority = group.priority();
            taskOwner = group.user().name();
            view = group.clearcaseView();
            // move the task from running queue to inactive queue
            unitTask.markInactive();
            gconn.send("MSG", "Request lock ("+machines+") for "+info);
         } else {
            if (! dTMServer.isBgServerOn) {
               throw new Exception("Taskgroup not found " + gid+":"+tid);
            }
            gconn = null;
            bgTaskId = 1; // Non zero representing a task on bgServer
            Vector msgV = new Vector();
            if (! dTMServer.toBgServer("BGGETLOCK%"+gid+"%"+tid+"%"+machines,
                  msgV)) {
               throw new Exception("Taskgroup not found " + gid+":"+tid);
            }
            priority  = Integer.parseInt((String)msgV.get(0));
            taskOwner = (String)msgV.get(1);
            view      = (String)msgV.get(3);
         }
      } else {
         if (! isRerunType() && ! isUserType()) {
            throw new Exception("Task type is not supported: " + taskType);
         }
         // 0     1         2         3         4         5     6    7     8
         // Rerun $machines $locktime $waittime $priority $host $who $info $view
         // User  $machines $locktime $waittime $priority $host $who $info $view
         priority = Integer.parseInt((String)para.get(4));
         // (String)para.get(5);  skip host name
         taskOwner = (String)para.get(6);
         info = (String)para.get(7);
         view = (String)para.get(8);
         gconn = null;
         bgTaskId = 0;
         gid = 0;
         tid = 0;
      }
      startTime = 0;
      idString = taskOwner+";"+taskId+";"+taskType+";"+priority+";"+locktime+";"
                 +waittime+";"+view+";"+info+";"+enQueueTime/1000+";"+bgTaskId;
   }

   public String toString(boolean withMachCandidates) {
      String stime = ";" + startTime/1000;
      if (withMachCandidates)
         return idString + stime + ";" + machCandidates();
      else
         return idString + stime;
   }

   PerfTask(TestMachine mach, StringTokenizer taskTk) 
   {
      taskId = ++perfTaskCount;
      machineLocked = mach;
      taskOwner = taskTk.nextToken();
      bgTaskId  = Integer.parseInt(taskTk.nextToken());
      taskType  = taskTk.nextToken();
      priority  = Integer.parseInt(taskTk.nextToken());
      locktime  = Integer.parseInt(taskTk.nextToken());
      waittime  = Integer.parseInt(taskTk.nextToken());
      view      = taskTk.nextToken();
      info      = taskTk.nextToken();
      if (isDtmType()) {
         StringTokenizer tk = new StringTokenizer(info, ":");
         gid = Integer.parseInt(tk.nextToken());
         tid = Integer.parseInt(tk.nextToken());
      } else {
         gid = 0;
         tid = 0;
      }
      enQueueTime = Long.parseLong(taskTk.nextToken())*1000;
                    taskTk.nextToken();         // ignore bgTaskId
      startTime   = Long.parseLong(taskTk.nextToken())*1000;
      machCandidates(taskTk.nextToken());

      mailout = false;
      conn = null;   // lock request was made to bg server
      gconn = null;
      idString = taskOwner+";"+taskId+";"+taskType+";"+priority+";"+locktime+";"
                 +waittime+";"+view+";"+info+";"+enQueueTime/1000+";"+bgTaskId;
   }

   public boolean isUserType()     { return taskType.equals("User"); }
   public boolean isDtmType()      { return taskType.equals("dTM"); }
   public boolean isRerunType()    { return taskType.equals("Rerun"); }
   public Connection conn()        { return conn; }
   public Connection gconn()       { return gconn; }
   public int priority()           { return priority; }
   public String owner()           { return taskOwner; }
   public boolean hasLock()        { return machineLocked != null; }
   public TestMachine getMachine() { return machineLocked; }
   public String ownerAndInfo()    { return taskOwner +" "+ info; }
   public String info()            { return info; }

   public void releaseLock(boolean killPs, boolean killTask)
   {
      String machname = machineLocked.name();
      if (isDtmType()) {
         if (killPs) {
            // there might be some ctiguru processes running on the machine,
            // clean them up prior to releasing the lock.
            String cmd = dTMConfig.rsh() + " " + machname + " " +
                         dTMConfig.dtmHomeDir() + "/bin/dtm_killPS.pl -allps";
            try {
               Exec.exec(cmd);
            } 
            catch (Exception e) {
               LogWriter.log("Failed to run: " + cmd, e);
            }
         }
         if (killTask) {
            // kill the dtm task if it is still running
            TaskGroup group = TaskScheduler.findGroupWith(gid);
            if (group != null) {
               group.terminateTask(tid, UnitTask.KILLED);
            }
         }
      }
      machineLocked.setPerfTask(null);
      machineLocked.appendPerfLog(false, this);
      machineLocked = null;
      // send message to user's TM process
      if (!killPs && isDtmType()) {
         if (gconn != null)
            gconn.send("MSG", "Release lock on "+machname+" from "+info);
         else {
            dTMServer.toBgServer("BGRELEASELOCK%"+machname+"%"+info, null); 
         }
      }
   }

   public boolean assignPerfMachine(TestMachine pm)
   {
      machineLocked = pm;
      pm.setPerfTask(this);
      pm.appendPerfLog(true, this);
      startTime = new Date().getTime(); 
      mailout = false;

      // notify the requester
      if (isUserType()) {
         // send mail to the requester
         LogWriter.log(owner() +" got machine lock "+ pm.name());
         String msg = "You got machine lock: "+pm.name();
         MailWriter m = new MailWriter(0, owner(), msg);
         m.write(msg + " for your task "+ info +".");
         m.write("You can log on and use the machine now. When you "
                 +"complete your tasks,");
         m.write("log out the machine and release the lock via command");
         m.write("      releaselock "+pm.name());
         m.send();
      } else {
         if (gconn != null) {
            // this is a dTM job running on fg server
            // send message to user, i. e. TM invoker
            gconn.send("MSG", "Get lock on "+pm.name()+" for "+info);
         } else {
            if (conn == null) {
               // lock request was made on bg server,
               // so notify via bg server
               Vector result = new Vector();
               if (! dTMServer.toBgServer("BGLOCKED%"+pm.name()+"%"
                                   +info +"%"+bgTaskId, result)) {
                  machineLocked = null;
                  pm.setPerfTask(null);
                  return false;
               } 
            }
         }
         // if the request was made on fg server
         // send machine name to the requester: "getlock" command
         if (conn != null) {
            conn.send(pm.name());
            conn.close();
         }
      }
      return true;
   }

   public boolean isInCandidateList(TestMachine pmach)
   {
      return machCandidates.contains(pmach.name());
   }

   public void enQueue() {
      synchronized (perfTaskQueue) {
         int size = perfTaskQueue.size();
         if (size == 0) {
            perfTaskQueue.add(this);
            return;
         }
         PerfTask lastTask = (PerfTask)perfTaskQueue.get(size - 1);
         if (lastTask.priority() >= priority()) {
            perfTaskQueue.add(this);
            return;
         }
         for (int i=0; i < size; i++) {
            PerfTask ptask = (PerfTask)perfTaskQueue.get(i);
            if (ptask.priority() < priority()) {
               perfTaskQueue.add(i, this);
               return;
            }
         }
         perfTaskQueue.add(this);
      }
   }

   public boolean lockTimeOut()
   {
      if (locktime <= 0)  return false;
      long currenttime = new Date().getTime();

      // check if the locktime is time-out for a running user task
      // time diffs in minute
      int timeDiff = (int) (currenttime - startTime)/60000;
      int timeLeft = locktime - timeDiff;
      // LogWriter.log("tid="+taskId+" "+"mailout="+mailout+" timeLeft="+timeLeft);
      if (! mailout && 0 < timeLeft && timeLeft <= 10) {
         mailout = true;
         // notify the user of 10 minute left for the lock.
         String msg = "10 minutes left to hold the machine lock: "
                      + machineLocked.name();
         LogWriter.log(owner() +" has "+ msg);
         MailWriter m = new MailWriter(0, owner(), msg);
         m.write("You have " + msg);
         m.write("for your task \""+info+"\".");
         m.send();
         return false;
      }
      if (timeLeft <= 0) {
         mailout = true;
         // notify that the lock has been released.
         String msg = "Your machine lock " + machineLocked.name()
                      +" has been released by dTM server";
         LogWriter.log("Sent message to "+owner()+": "+msg);
         MailWriter m = new MailWriter(0, owner(), msg);
         m.write(msg);
         m.write("because of running out of locktime ("+locktime+" minutes),");
         m.write("for your task \""+info+"\".");
         m.send();
         return true;
      }
      return false;
   }

   private void machCandidates(String machines)
   {
      machCandidates = new LinkedList();
      StringTokenizer tk = new StringTokenizer(machines,",");
      while (tk.hasMoreTokens()) {
         String machname = tk.nextToken();
         TestMachine pmach = Pool.perfPool.getMachine(machname);
         if (pmach != null)
            machCandidates.add(machname);
      }
   }
   private String machCandidates()
   {
      String str = "";
      Iterator mit = machCandidates.iterator();
      if (mit.hasNext())
         str = (String)mit.next();
      while (mit.hasNext())
         str += "," + (String)mit.next();
      return str;
   }

   private void sendFailToGetlock()
   {
      // notify the requester
      if (! isUserType()) {
         // lock request was made on bg server,
         // so notify via bg server
         if (gconn == null && conn == null && ! dTMServer.isBackground()) {
            dTMServer.toBgServer("PERFKILL%"+taskId, null);
         }

         // the request was made on fg server
         // send machine name to the requester: "getlock" command
         if (conn != null) {
            conn.send("FAIL");
            conn.close();
         }
      }
   }


   //
   // Performance task queue monitor bellow
   //

   static private Vector perfTaskQueue = new Vector();

   public static boolean queueIsEmpty() { return perfTaskQueue.size() == 0; }
   public static boolean queueHasDtmRerunTask()
   {
      for (Enumeration e = perfTaskQueue.elements();
           e.hasMoreElements(); ) {
         PerfTask ptask = (PerfTask)e.nextElement();
         if (! ptask.isUserType())
            return true;
      }
      return false;
   }

   public static String printToString(boolean withMachCandidates) 
   {
      String str = ""+perfTaskQueue.size();
      for (Enumeration e = perfTaskQueue.elements();
           e.hasMoreElements(); ) {
         PerfTask ptask = (PerfTask)e.nextElement();
         str += "#"+ptask.toString(withMachCandidates);
      }
      return str;
   }
   
   public static PerfTask selectTaskFor(TestMachine pmach)
   {
      for (Iterator e = perfTaskQueue.iterator();
           e.hasNext(); )
      {
         PerfTask ptask = (PerfTask)e.next();
         if (ptask.isInCandidateList(pmach)) {
            e.remove();
            return ptask;
         }
      }
      return null;
   }

   public static void removeTask(boolean background,
                                 int gid, int tid)
   {
      if (Pool.perfPool == null) return;

      synchronized (perfTaskQueue) {
         for (Iterator e = perfTaskQueue.iterator();
              e.hasNext(); )
         {
            PerfTask pt = (PerfTask)e.next();
            if (! pt.isDtmType()) continue;
            boolean cond = (! background && pt.bgTaskId == 0) ||
                           (background && pt.bgTaskId > 0);
            if (! cond)
               continue;

            boolean removed = false;
            // remove all perf task in the queue
            if (gid == -1) {
               e.remove();
               removed = true;
            }
            // remove all perftask in group gid 
            else if (gid == pt.gid &&
                     (tid == -1 || tid == pt.tid)) {
               e.remove();
               removed = true;
            }
            // remove one perftask with the specified gid and tid
            else if (gid == pt.gid && tid == pt.tid) {
               e.remove();
               removed = true;
            }
            if (removed)
               pt.sendFailToGetlock();
         }
      }
   }
   
   public static PerfTask findTaskWith(int tid)
   {
      for (Enumeration e = perfTaskQueue.elements();
           e.hasMoreElements(); ) {
         PerfTask ptask = (PerfTask)e.nextElement();
         if (ptask.taskId == tid) 
            return ptask;
      }
      return null;
   }

   public static void removeTask(PerfTask ptask)
   {
      boolean removed;
      synchronized (perfTaskQueue) {
         removed = perfTaskQueue.remove(ptask);
      }
      if (removed)
         ptask.sendFailToGetlock();
   }

   // If there is an User task which is about to expire in 10 minutes, notify
   // the user. If there is an expired task, release the request with a 'FAIL'.
   public static void monitorTaskQueue()
   {
      long currenttime = new Date().getTime();
 
      synchronized (perfTaskQueue) {
         for (Iterator e = perfTaskQueue.iterator();
              e.hasNext(); )
         {
            PerfTask ptask = (PerfTask)e.next();
            if (ptask.waittime > 0) {
               // time diff in minute
               int timeDiff = (int) (currenttime - ptask.enQueueTime)/60000;
               int timeLeft = ptask.waittime - timeDiff;
               if ((! ptask.mailout) && (timeLeft < 10)) {
                  ptask.mailout = true;
                  // notify the user of 10 minute left for time out.
                  String msg = "less than 10 minutes left for requesting a machine lock";
                  LogWriter.log(ptask.owner() +" has " + msg);
                  MailWriter m = new MailWriter(0, ptask.owner(), msg);
                  m.write("You have " +msg+ " from machines");
                  m.write(ptask.machCandidates+ " for your task \""+ptask.info+"\".");
                  m.send();
               }
               if (timeLeft < 0) {
                  e.remove();
                  ptask.sendFailToGetlock();
                  // notify that the lock has been released.
                  String msg = "Your request for machine lock has expired";
                  LogWriter.log("Sent message to "+ptask.owner()+": "+msg);
                  MailWriter m = new MailWriter(0, ptask.owner(), msg);
                  m.write("Your request for one of the machines "+ptask.machCandidates
                          + ",\nfor your task \""+ptask.info+"\" has expired.");
                  m.write("It has been canceled by the dTM server.");
                  m.send();
               }
            }
         }
      }
   }
}

