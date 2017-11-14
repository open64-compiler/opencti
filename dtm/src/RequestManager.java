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

class RequestManager extends Thread
{
   Connection conn;

   RequestManager(Connection con)
   { 
      conn = con;
   }
    
   /*
    * The server accepts the commands from the client
    * and process them.
    */

   public void run()
   {
      Vector decodeVector = new Vector();
      String msg = null;
      boolean wantToCloseConnection = true;

      while ((msg = conn.getNextMessage(decodeVector)) != null) 
      {
         wantToCloseConnection = true;
         if (msg.equals("OPENGRP"))
         {
            // OPENGRP 
            if (dTMServer.isBackground()) {
               conn.send("FAIL", "Server no longer accepting tasks.");
               break;
            }
            
            String userName = (String)decodeVector.get(0);
            User user = User.get(userName);
            if ( user == null ) {
               // if the user has not been registering in dTM server
               // register it now
               Pool defaultPool = Pool.get("Default");
               if ( defaultPool == null ) {
                  conn.send("FAIL","Error: no Default pool in dTM server.");
                  break;
               }
               user = new User(userName, 2, defaultPool);
            }

            TaskGroup group;
            try {
               group = new TaskGroup(conn, decodeVector, user);
            }
            catch (Exception e) {
               conn.send("FAIL", e.toString());
               break;
            }
            conn.send("GRPOPEN");

            // RUN command for each task
            // format: RUN%unit_name
            int taskId = 0;
            msg = conn.getNextMessage(decodeVector);
            LogWriter.log(3, "Got message:" + msg + ":\n");
            while (msg.startsWith("RUN"))
            {
               String unit = (String)decodeVector.get(0);
                 
               // create a new test object 
               UnitTask task = new UnitTask(++taskId,group,unit,conn);
               group.submitPendingTask(task);
               conn.send("ACCEPT", task.idString());

               // get next task
               msg = conn.getNextMessage(decodeVector);
               LogWriter.log(3, "Got message:" + msg + ":\n");
            }

            if (msg.equals("CLSGRP")) {
               user.addTaskGroup(group);
               TaskScheduler.addGroup(group);
               LogWriter.log("Group "+group.id()+": " + taskId+" task(s) added");
            } else {
               conn.send("FAIL", "No CLSGRP command received");
               break;
            }
         }
         else if (msg.equals("KILL"))
         {
            // Kill previously submitted tasks
            String userName = (String)decodeVector.get(0);
            int gid = Integer.parseInt((String)decodeVector.get(1));
            int tid = Integer.parseInt((String)decodeVector.get(2));
            TaskGroup group = TaskScheduler.findGroupWith(gid);
            if (group == null) {
               conn.send("MSG", "Group not found for the task.");
               break;
            }
            // Admin or web account plays as a supper user (can kill any job)
            if (! (userName.equals(group.user().name())
                   || userName.equals(dTMConfig.webAccount())
                   || userName.equals(dTMConfig.admin()))) {
               conn.send("MSG", "You are not the owner of the task.");
               break;
            }
            LinkedList killed = group.terminateTask(tid, UnitTask.KILLED);
            conn.send("KILLED", gid, tid);
            if (Pool.perfPool != null) {
               if (! dTMServer.isBackground()) {
                  // remove PerfTasks from the waiting queue
                  PerfTask.removeTask(false, gid, tid);
                  // remove PerfTasks from the running machines
                  PerfScheduler.killRunningPerfTask(gid, tid);
               } else {
                  Connection sconn = dTMServer.connectServer(dTMConfig.serverPort());
                  if (sconn != null) {
                     sconn.send("BGKILL", (String)decodeVector.get(1),
                                          (String)decodeVector.get(2));
                     sconn.close();
                  }
               }
            }

            // wait for a second to see if all remshs get returned
            try {  sleep(1000); }
            catch ( InterruptedException e ) {}
            Iterator ki = killed.iterator();
            while (ki.hasNext()) {
               UnitTask task = (UnitTask) ki.next();
               if (! task.isRemshKilled()) {
                  task.killProcess();
               }
            }
            break;
         }
         else if (msg.equals("PERFKILL"))
         {
            String user = (String)decodeVector.get(0);
            int tid = Integer.parseInt((String)decodeVector.get(1));
            PerfTask ptask = PerfTask.findTaskWith(tid);
            if (ptask == null) {
               conn.send("MSG", "Task not found in Performance queue.");
               break;
            }
            if (! (ptask.owner().equals(user)
                   || dTMConfig.webAccount().equals(user)
                   || dTMConfig.admin().equals(user))) {
               conn.send("ERR", "You are not the job owner");
               break;
            }
            PerfTask.removeTask(ptask);
            conn.send("MSG", "Task cancelled");
            break;
         }
         else if (msg.equals("BGKILL"))
         {
            int gid = Integer.parseInt((String)decodeVector.get(0));
            int tid = Integer.parseInt((String)decodeVector.get(1));
            PerfTask.removeTask(true, gid, tid);
         }
         else if (msg.equals("INACTIVE"))
         {
            String machName = (String)decodeVector.get(0);
            TestMachine mach = TestMachine.get(machName);
            if ( mach == null ) {
               conn.send("MSG", "Unknown machine: " + machName);
               break;
            }
            int gid = Integer.parseInt((String)decodeVector.get(1));
            int tid = Integer.parseInt((String)decodeVector.get(2));
            UnitTask task = mach.findRunningTask(gid, tid);
            if ( task == null ) {
               conn.send("MSG", "Unknown task " + gid +":"+ tid);
               break;
            }
            task.markInactive();
            break;
         }
         else if (msg.equals("ENABLE"))
         {
            String machName = (String)decodeVector.get(0);
            //String userName = (String)decodeVector.get(1);
            TestMachine mach = TestMachine.get(machName);
            if (mach == null) {
               conn.send("MSG", "Unknown machine: " + machName);
               break;
            }
            mach.enable();
            conn.send("ENABLED", machName);
            if (mach.isPerfMachine()) {
               Pool.outputPerfMachineState();
            } else {
               TestMachine.outputMachineState();
            }
         }
         else if (msg.equals("DISABLE"))
         {
            String machName = (String)decodeVector.get(0);
            String userName = (String)decodeVector.get(1);
            String info = (String)decodeVector.get(2);
            TestMachine mach = TestMachine.get(machName);
            if (mach == null) {
               conn.send("MSG", "Unknown machine: " + machName);
               break;
            }
            mach.user_disable(userName, info);
            conn.send("DISABLED", machName);
            if (mach.isPerfMachine()) {
               Pool.outputPerfMachineState();
            } else {
               TestMachine.outputMachineState();
            }
         }
         else if (msg.equals("SYSPOOLSUSERS"))
         {
            long querytime = new Date().getTime()/1000;
            conn.send(dTMConfig.dtmHomeDir()
                      + "%" + querytime
                      + "%" + Pool.currentPoolList() 
                      + "%" + User.printUserList());
         }
         else if (msg.equals("DUMPMACHINELIST"))
         {
            conn.send("MACHINELIST", Pool.dumpMachineList());
         }
         else if (msg.equals("DUMPPOOLSTATE"))
         {
            String poolName = (String)decodeVector.get(0);
            Pool pool = Pool.get(poolName);
            if ( pool == null ) {
               conn.send("MSG", "not found: " + poolName);
            }
            else {
               conn.send("CURPOOLSTATE", pool.dumpPoolState(true));
            }
         }
         else if (msg.equals("DUMPUSERSTATE"))
         {
            String userName = (String)decodeVector.get(0);
            User user = User.get(userName);
            if ( user == null ) {
               conn.send("MSG", "Unknown user: " + userName);
            }
            else {
               conn.send("CURUSERSTATE", user.printUserState());
            }
         }
         else if (msg.equals("DYNAMACHSTATE"))
         {
            // query dynamic status for test machines
            if (Pool.perfPool == null)
               conn.send("NoPerfPool", TestMachine.printDynamicStatus());
            else
               conn.send("PerfPool", TestMachine.printDynamicStatus());
         }
         else if (msg.equals("DEBUG"))
         {
            String component = (String)decodeVector.get(0);
            if (component.equals("level")) {
               int level = Integer.parseInt((String)decodeVector.get(1));
               LogWriter.debugLevel(level);
               conn.send("MSG", "Debug level: " + level);
            }
            else if (component.equals("scheduler")) {
               String value = (String)decodeVector.get(1);
               if (value.equals("on")) {
                  TaskScheduler.debug = true;
                  TaskGroup.debug = true;
                  conn.send("MSG", component+" debug is on");
               } else {
                  TaskScheduler.debug = false;
                  TaskGroup.debug = false;
                  conn.send("MSG", component+" debug is off");
               }
            }
            else if (component.equals("connection")) {
               String value = (String)decodeVector.get(1);
               if (value.equals("on"))
                  Connection.debug = true;
               else
                  Connection.debug = false;
            }
            break;
         }
         else if (msg.equals("RESCHED"))
         {
            // Kill a running submitted task for rescheduling
            int gid = Integer.parseInt((String)decodeVector.get(0));
            int tid = Integer.parseInt((String)decodeVector.get(1));
            TaskGroup group = TaskScheduler.findGroupWith(gid);
            if (group == null) {
               conn.send("MSG", "Unknown task: " + gid + ":" + tid);
            } else {
               LinkedList killed = group.terminateTask(tid, UnitTask.RESCHED);
               conn.send("RESCHED", gid, tid);
               if (Pool.perfPool != null && !dTMServer.isBackground()) {
                  // remove PerfTasks from the waiting queue
                  PerfTask.removeTask(false, gid, tid);
                  // remove PerfTasks from the running machines
                  PerfScheduler.killRunningPerfTask(gid, tid);
               }

               // wait for a second to see if all remshs get returned
               try {  sleep(1000); }
               catch ( InterruptedException e ) {}
               Iterator ki = killed.iterator();
               while (ki.hasNext()) {
                  UnitTask task = (UnitTask) ki.next();
                  if (! task.isRemshKilled()) {
                     task.killProcess();
                  }
               }
            }
         }
         else if (msg.equals("GETLOCK"))
         {
            if (Pool.perfPool == null) {
               conn.send("ERR", "No performance machine pool in dTM server");
               break;
            }
            PerfTask ptask;
            try {
               ptask = new PerfTask(decodeVector, conn);
               ptask.enQueue();
            }
            catch (Exception e) { 
               conn.send("FAIL", e.toString());
               break;
            }
            if (ptask.isUserType()) {
               conn.send("PASS");
            } else {
               wantToCloseConnection = false;
            }
            // A task going into performance queue doesn't change 
            // performance machines state until it grab a lock. Thus
            // no need to call Pool.outputPerfMachineState() here.
            break;
         }
         else if (msg.equals("BGGETLOCK"))
         {
            int gid = Integer.parseInt((String)decodeVector.get(0));
            int tid = Integer.parseInt((String)decodeVector.get(1));
            String machines = (String)decodeVector.get(2);
            TaskGroup group = TaskScheduler.findGroupWith(gid);
            if (group == null) {
               conn.send("FAIL", "Can't find the group on background server");
               break;
            }
            UnitTask unitTask = group.findTask(tid);
            if (unitTask == null) {
               conn.send("FAIL", "Can't find the task on background server");
               break;
            }
            unitTask.markInactive();
            // send information to foreground server
            String info = unitTask.idString();
            conn.send("PASS", ""+group.priority()+"%"+group.user().name()
                             +"%"+info+"%"+group.clearcaseView());
            // send message to TM invoker
            group.conn().send("MSG", "Request lock ("+machines+") for "+info);
            break;
         }
         else if (msg.equals("RELEASELOCK"))
         {
            if (Pool.perfPool == null) {
               conn.send("ERR", "No performance machine pool in dTM server");
               break;
            }
            String machName = (String)decodeVector.get(0);
            String user = (String)decodeVector.get(1);
            TestMachine pmach = Pool.perfPool.getMachine(machName);
            if (pmach == null) {
               conn.send("ERR", "Machine not found: "+machName);
               break;
            }
            PerfTask ptask = pmach.getPerfTask();
            if (ptask == null) {
               conn.send("ERR", "No job running on "+machName);
               break;
            }
            if (! (ptask.owner().equals(user)||dTMConfig.admin().equals(user))) {
               conn.send("ERR", "You are not the job owner");
               break;
            }
            ptask.releaseLock(false, false);
            conn.send("Machine released: " + pmach.name());
            Pool.outputPerfMachineState();
            break;
         }
         else if (msg.equals("BGRELEASELOCK"))
         {
            String machName = (String)decodeVector.get(0);
            String info = (String)decodeVector.get(1);
            StringTokenizer tk = new StringTokenizer(info, ":");
            int gid = Integer.parseInt(tk.nextToken());
            // int tid = Integer.parseInt(tk.nextToken());
            TaskGroup group = TaskScheduler.findGroupWith(gid);
            if (group == null) {
               conn.send("FAIL", "Can't find the group on bachground server");
               break;
            } else {
               // send message to TM invoker
               group.conn().send("MSG", "Release lock on "+machName+" from "+info);
            }
            conn.send("PASS"); 
            break;
         }
         else if (msg.equals("BGLOCKED"))
         {
            String machName = (String)decodeVector.get(0);
            String info = (String)decodeVector.get(1);
            int ptId = Integer.parseInt((String)decodeVector.get(2));
            PerfTask ptask = PerfTask.findTaskWith(ptId);
            if (ptask == null) {
               // reply to the foreground server
               conn.send("FAIL", "Can't find the task on bachground server");
               break;
            }
            // notify getlock command made to this bg server
            ptask.conn().send(machName);
            ptask.conn().close();
            // send message to TM invoker
            ptask.gconn().send("MSG", "Get lock on "+machName+" for "+info);
            PerfTask.removeTask(ptask);
            // send fg server a "PASS"
            conn.send("PASS"); 
            break;
         }
         else if (msg.equals("ADDMACHINE"))
         {
            // Format of the command
            //            0    1        2
            // ADDMACHINE user poolname machine_descriptor
            int mcount = decodeVector.size();
            if (mcount < 3) {
               conn.send("MSG", "No machine was specified.");
               break;
            }
            // verify if he or she is the administrator
            String user = (String)decodeVector.get(0);
            if (! user.equals(dTMConfig.admin())) {
               conn.send("MSG", "You are not the dTM administrator");
               break;
            }
            String poolName = (String)decodeVector.get(1);
            Pool pool = Pool.get(poolName);
            if (pool == null) {
               conn.send("MSG", "Pool not found: " + poolName);
               break;
            }

            // The  format for machine decriptor
            //  # 1    2         3   4        5    6 7    8
            // host_name:HP-UX_11.23:IPF:Itanium2:1300:4:/dTM:sevices
            // or  host_name1:sameas:host_name2
            // or  host_name:1frompool:Default
            //
            String hostStr = (String)decodeVector.get(2);
            String[] tk = hostStr.split(":");
            String host = tk[0];    // #1
            TestMachine mach = TestMachine.get(host);
            try{
                String os   = "";
                String arch = "";
                if(tk[1] != null && tk[1].trim().length() != 0)
                    os   = tk[1];    // #2  sameas   or frompool
                if(tk[2] != null && tk[2].trim().length() != 0)
                    arch = tk[2];    // #3  hostname or poolname
                if (os.equals("sameas")) {
                   if (mach != null && mach.isUsed()) {
                      conn.send("ERR", "Machine already exists: " + host);
                      break;
                   }
                   TestMachine sameasMach = TestMachine.get(arch);
                   if (sameasMach == null) {
                      conn.send("ERR", "The sameas machine not found: " + arch);
                      break;
                   }
                   mach = new TestMachine(host, sameasMach);
                   // fall through to add a machine
                } else if (os.equals("frompool")) {
                   if (mach == null || ! mach.isUsed()) {
                      conn.send("ERR", "Machine does not exists: " + host);
                      break;
                   }
                   if (poolName.equals(arch)) {
                      conn.send("ERR", "The same pool is specified: "+ arch);
                      break;
                   }
                   Pool fromPool = Pool.get(arch);
                   if (fromPool == null) {
                      conn.send("ERR", "The frompool not found: "+ arch);
                      break;
                   }
                   if (! fromPool.contains(mach)) {
                      conn.send("ERR", "Machine is not in frompool: "+ arch);
                      break;
                   }
                   // fall through to add a machine
                } else {
                   // format:
                   // host_name:HP-UX_11.23:IPF:Itanium2:1300:4:/dTM:sevices
                   if (mach != null && mach.isUsed()) {
                      conn.send("ERR", "Machine already exists: " + host);
                      break;
                   }
                   String impl    = "";
                   int    freq    = -1;
                   int    CPUs    = -1;
                   String workDir = dTMConfig.defWorkDir();
                   Vector<String> sv = dTMConfig.defservices();
                   if(tk[3] != null && tk[3].trim().length() != 0)
                          impl    = tk[3]; // #4
                   if(tk[4] != null && tk[4].trim().length() != 0)
                          freq    = Integer.parseInt(tk[4]);// (tk.nextToken()); // #5
                   if(tk[5] != null && tk[5].trim().length() != 0)
                          CPUs    = Integer.parseInt(tk[5]); //(tk.nextToken()); // #6
                   if(tk[6] != null && tk[6].trim().length() != 0)
                          workDir = tk[6]; // #7
                   // String service = tk.nextToken(); // #8
                   if(tk[7] != null && tk[7].trim().length() != 0){
                       sv = new Vector<String>();
                       for(int i = 7; i < tk.length; i++){
                            sv.add(tk[i]);
                       }
                   }
                   mach = new TestMachine(host, os, arch, impl,
                                          freq, CPUs, workDir, sv);
                   // fall through to add a machine
                }
             }
             catch (Exception e){
                conn.send("ERR", " Machine String is invalid: " + hostStr);
                break;
             }
            pool.addMachine(mach);
            conn.send("MSG", " Machine "+ host +" added to pool "+poolName);
            if (pool.isPerformance()) {
               Pool.outputPerfMachineState();
            } else {
               TestMachine.outputMachineState();
            }
            break;
         }
         else if (msg.equals("REMOVEMACHINE"))
         {
            int mcount = decodeVector.size();
            if (mcount <= 1) {
               conn.send("MSG", " No machine was specified.");
               break;
            }
            // verify if he or she is the administrator
            String user = (String)decodeVector.get(0);
            if (! user.equals(dTMConfig.admin())) {
               conn.send("MSG", "You are not the dTM administrator");
               break;
            }
            String host = (String)decodeVector.get(1);
            TestMachine mach = TestMachine.get(host);
            if (mach == null || ! mach.isUsed()) {
               conn.send("MSG", " Machine "+ host +" was not in dTM server");
               break;
            }
            if (mach.hasTask()) {
               conn.send("MSG", " There are still tasks running on machine "+ host);
               break;
            }
            if (mach.available()) {
               conn.send("MSG", " Machine "+ host +" was not disabled");
               break;
            }
             
            boolean isInPerfPool = mach.isPerfMachine();
            // remove the machine from the candidate list for all groups
            if (! isInPerfPool) {
               TaskScheduler.rmCandidateMachine(mach);
            }
            // remove it from theMachineMap, allMachines and all pools 
            TestMachine.removeMachine(mach);
            conn.send("MSG", " Machine was removed from all pools: "+host);
            if (isInPerfPool) {
               Pool.outputPerfMachineState();
            } else {
               TestMachine.outputMachineState();
            }
            break;
         }
         else if (msg.equals("PERFSTATUS"))
         {
            if (Pool.perfPool == null) {
               conn.send("FAIL", " No performance machine pool");
               break;
            }
            Pool pp = Pool.perfPool;
            if (decodeVector.size() == 0) {
               // machine states with tasks without machine candidates
               conn.send("PERFSTATUS", pp.printPerfString(false),
                                       PerfTask.printToString(false));
               break;
            }
            
            String idleCmd = (String)decodeVector.get(0);
            if (idleCmd == null ||
                ! idleCmd.equals("idlePerfScheduler")) {
               conn.send("FAIL", "Extra argument: " + idleCmd);
               break;
            }
            PerfScheduler.pleaseIdle();
            LogWriter.log("performance task scheduler is idle.");
            // wait for half second to give PerfScheduler some time 
            // to finishes its current schedule cycle
            try { Thread.sleep(500); }
            catch ( InterruptedException e ) {}
            Vector<String> minmaxMachsTasks = new Vector<String>();
            TaskScheduler.getMinMaxGid(minmaxMachsTasks);
            minmaxMachsTasks.add(pp.printPerfString(true));
            minmaxMachsTasks.add(PerfTask.printToString(true));
            // machine states with tasks with machine candidates   
            conn.send("PASS", minmaxMachsTasks);
            break;
         }
         else if (msg.equals("BGSERVERDIE"))
         {
            dTMServer.isBgServerOn = false;
            // The task ids used in BgSever can now be reused
            TaskGroup.setupMinMaxGid("0", "0");
            // remove ALL perftasks that were from background server, if any
            PerfTask.removeTask(true, -1, -1);
         }
         else if (msg.equals("STOPSERVER"))
         {
            Vector testMachState = new Vector();
            Vector perfMachState = new Vector();
            if (dTMServer.bgServerStatus(testMachState, perfMachState)) {
               conn.send("MSG", "There is already a background server alive!");
               conn.send("FAIL", "You can't have two background servers at the same time.");
               break;
            }

            // Switch to the auxiliary port to be a backgroud server
            dTMServer.switchToBackground();
            String serverName = "Server on " + dTMConfig.serverHost() +
                                 ":" + dTMConfig.serverPort();
            String msg1 = serverName + " is no longer accepting tasks.";
            conn.send("MSG", msg1);
            LogWriter.log(msg1);

            // write out machine states
            TestMachine.outputMachineState();
            if (Pool.perfPool != null)
               Pool.outputPerfMachineState();

            String auxName = "Server :" + dTMConfig.currentPort();
            String msg2 = auxName+" is accepting status queries only.";
            conn.send("MSG", msg2);
            LogWriter.log(msg2);
            
            LogWriter.log("Wait for 3 minutes for foreground server"
                           + " to query machine states");
            try { sleep(3*60*1000); }
            catch ( InterruptedException e ) {}

            String msg3 = auxName + " there are pending tasks.";
            while ( TaskScheduler.hasPendingTasks()
                    || PerfTask.queueHasDtmRerunTask() )
            {
               conn.send("MSG", msg3);
               LogWriter.log(msg3);
               try { sleep(30000); }
               catch ( InterruptedException e ) {}
            }
            LogWriter.log(auxName + " there are no more pending tasks.");

            // Stop accepting connections from clients.
            dTMServer.listener.pleaseStop();
            LogWriter.log(auxName + " listener stopped.");

            // Stop monitoring the task queue once all queues are empty.
            TaskScheduler.pleaseStop();
            LogWriter.log(auxName + " task queue monitor stopped.");

            // Stop monitoring the test machine state
            TestMachineMonitor.pleaseStop();
            LogWriter.log(auxName + " test machine monitor stopped.");

            // Stop monitoring the performance machine state
            PerfScheduler.pleaseStop();
            LogWriter.log(auxName + " performance machine monitor stopped.");

            // Stop the main server thread
            dTMServer.pleaseStop();
            LogWriter.log(auxName + " server is now terminated.");

            Connection sconn = dTMServer.connectServer(dTMConfig.serverPort());
            if (sconn != null) {
               sconn.send("BGSERVERDIE");
               sconn.close();
            }
         }
         else if (msg.equals("SETLAUNCH")){
            try{
                String launchSetting = (String)decodeVector.get(0);
                String[] tk = launchSetting.split(":");
                if(tk[0] != null && tk[0].trim().length() != 0)
                    TaskScheduler.setLaunchCount(Integer.parseInt(tk[0]));
                if(tk.length == 2 && tk[1] != null && tk[1].trim().length() != 0)
                    TaskScheduler.setLaunchWait(Integer.parseInt(tk[1]));
                conn.send("PASS"," changing launch setting successful");
            }catch (Exception e) {
               conn.send("FAIL", " changing launch setting failed with " + (String)decodeVector.get(0));
            }
         }
         else if (msg.equals("CREATEPOOL")){
                String poolName = (String)decodeVector.get(0);
                Pool pool = Pool.get(poolName);
                if(pool == null){
                    new Pool(poolName, new Vector<TestMachine>());
                    conn.send("PASS"," new pool " + poolName + " is successfully created");
                }else{
                    conn.send("FAIL", " pool name " + poolName + " is already in use!");
                }
         }
         else if (msg.equals("DELETEPOOL")){
            String poolName = (String)decodeVector.get(0);
            if(Pool.removePool(poolName)){
                conn.send("PASS", " pool name " + poolName + " removed successfully");
            }else{
                conn.send("FAIL", " pool name " + poolName + " isn't empty or doesn't exist to remove!");
            }
         }
         else {
            conn.send("MSG", "Unknown message: " + msg);
         }

      } // end of while loop
      if (wantToCloseConnection) conn.close();

   } // end of function
}

