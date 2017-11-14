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

class TaskScheduler extends Thread
{
   static int launchCount = 4;    // 4 jobs launch each time
   static int launchWait = 3000;  // 3 seconds
   static boolean stop = false;
   static WatchdogTimer watchDogTimer;
   static TaskScheduler taskScheduler;
   static boolean debug = false;
   static Vector<TaskGroup>  theQueue = new Vector<TaskGroup>();

   public TaskScheduler() 
   {
      watchDogTimer = new WatchdogTimer(60, 300, this, "TaskScheduler");
      this.setDaemon(true);
   }

   public static void createAndRun() 
   {
      LogWriter.log("TaskScheduler started");
      taskScheduler = new TaskScheduler();
      taskScheduler.start();
   }

   public static boolean isRunning() { return watchDogTimer.isRunning(); }
   public static void pleaseStop()   { stop = true; }
   
   public static void setLaunchCount(int groupCount){ 
        launchCount = groupCount;
        LogWriter.log("Schedule setting changed! Will continuousely launch " + 
                     + groupCount  
                     + " jobs at the same time");
   
   }
   public static void setLaunchWait(int waitInSec)  { 
        launchWait = waitInSec; 
        LogWriter.log("Schedule setting changed! " + 
                     String.format("%.2f", (float)waitInSec/1000)
                     + " Seconds sleep between continuous launches");
   }

   //
   // This is the task scheduler for dTM server
   //
   public void run()
   {
      int  gcount, tcount;
      List<User> cur_users = new LinkedList<User>();
      List<TaskGroup> cur_groups = new LinkedList<TaskGroup>();
      Set<TestMachine>  cur_machines;
      TaskGroup group, firstGroup, lastGroup = null;
      boolean task_scheduled;
      TaskAssignment TA;
      boolean needSleep;
      Vector<TaskGroup> assignedGroups = new Vector<TaskGroup>();
      Vector<TaskGroup> priorityGroups = new Vector<TaskGroup>();
      Vector<TaskGroup> relativeGroups = new Vector<TaskGroup>();
      Iterator iter;

      while (! stop) {

         try {
            // update watchdog timer for a new iteration
            watchDogTimer.update();
            cur_users.clear();
            cur_groups.clear();
            assignedGroups.clear();
            needSleep = true;
            gcount = 0;
            cur_machines = null;
            relativeGroups.clear();
            priorityGroups.clear();

            if (TaskAssignment.reachMaxTaskLimit()) {
               LogWriter.log("WARNING: Reaching Max Task Limit(" + 
                             + TaskAssignment.activeTaskLimit 
                             + "): " + TaskAssignment.taskCount());
               try { sleep(launchWait * 20); }
               catch ( InterruptedException e ) {}
               continue;
            }

            // remove finished jobs first and select out absolute priority
            // groups and relative priority groups that have pending tasks.
            //
            iter = theQueue.iterator();
            while (iter.hasNext()) {
               group = (TaskGroup)iter.next();
               if ( group.finished() ) {
                  // remove group from theQueue
                  synchronized (theQueue) {
                     iter.remove();
                  }
                  // remove group from user's task list
                  group.user().removeTaskGroup(group);
                  group.conn().close();
                  needSleep = false;
               } else if (group.hasPendingTask()) {
                  if (group.priority() >= 9000)
                     priorityGroups.add(group);
                  else
                     relativeGroups.add(group);
               }
            }

            // scheduling for absolute priority tasks: the hightest priority
            // tasks get machines first.
            //
            tcount = 0;
            cur_machines = new TreeSet<TestMachine>(TestMachine.allMachines);
            if (! priorityGroups.isEmpty()) {
               iter = priorityGroups.iterator();
               while (iter.hasNext()) {
                  group = (TaskGroup)iter.next();
                  cur_machines.removeAll(group.primaryPool());
                  TA = null;
                  do {
                     // TA == null means that the group may not have a pending task,
                     // or has a pending task but there is no machine available in 
                     // the pool
                     TA = group.taskAssignment(false);   // try primary pool
                     if (TA == null)
                        TA = group.taskAssignment(true); // try secondary pool
                     if (TA != null) {
                        TA.start();     // start a thread to run the new task
                        ++tcount;
                     }
                  } while (TA != null && group.hasPendingTask());
               }
            }

            // For relative priority tasks, we have two-step scheduling:
            // first select certain groups from the queue and then allocate
            // machines among the tasks in the selected groups.
            
            // This is the first step of scheduling: select groups based on
            // fairness. To make it fair to all users, we always pick up
            // the first group for a user. If a user has more groups in the
            // queue, we'll only select groups that use machines that all
            // other selected groups have not used.
            // 
            iter = relativeGroups.iterator();
            firstGroup = null;
            while (iter.hasNext()) {
               group = (TaskGroup)iter.next();
 
               int mcount = cur_machines.size();
               cur_machines.removeAll(group.primaryPool());
               if (! cur_users.contains(group.user())) {
                  // choose new user's first group. Everyone has at least
                  // one group selected, to be fair to all users. If last
                  // round we didn't schedule a task from the group, this
                  // time we put it to be first in cur_groups for scheduling.
                  //
                  if (firstGroup == null && group != lastGroup) {
                     firstGroup = group;
                     cur_groups.add(0, (group));
                  } else {
                     cur_groups.add(group);
                  }
                  cur_users.add(group.user());
               }
               else {
                  // the user already has one group selected. If this group
                  // uses machines that the currently selected groups don't use 
                  // then select it
                  //
                  if (mcount != cur_machines.size())
                     cur_groups.add(group);
               }

               // if all machines are covered by the selected groups, we
               // continue to select 8 more groups, in case someone selects
               // all machines in dTM with his couple of groups.
               if (cur_machines.isEmpty() && ++gcount >= 8)
                  break;
            }

            if (debug && ! cur_groups.isEmpty()) {
               LogWriter.log("Scheduled group == "+cur_groups.toString());
            }

            // Step 2: assign primary and then secondary machine to tasks
            // in the selected group.
            // We schedule launchCount tasks for each group, but do it in different
            // order, to be fair to the users involved
            //
            tcount = 0;
            for (int i=0; i < launchCount; ++i) {
               iter = cur_groups.iterator();
               boolean done = true;
               while (iter.hasNext()) {
                  group = (TaskGroup)iter.next();
                  // TA == null means that the group may not have a pending task,
                  // or has a pending task but there is no machine available in 
                  // the pool
                  TA = group.taskAssignment(false);   // try primary pool
                  if (TA != null) {
                     TA.start();   // start a thread to run a new task
                     ++tcount;
                     lastGroup = group;
                     if (! assignedGroups.contains(group))
                        assignedGroups.add(group);
                     done = false;
                  }
               }
               if (done) break;
            }

            // try secodary pools
            cur_groups.removeAll(assignedGroups);
            if (! cur_groups.isEmpty()) {
               for (int i=0; i < 3; ++i) {
                  iter = cur_groups.iterator();
                  while (iter.hasNext()) {
                     group = (TaskGroup)iter.next();
                     TA = group.taskAssignment(true);  // try secondary pool
                     if (TA != null) {
                        TA.start();   // start a thread to run a new task
                        ++tcount;
                        lastGroup = group;
                     }
                  }
               }
            }
         }
         catch (ConcurrentModificationException e) {
            needSleep = false;
         }
         catch (Exception e) {
            needSleep = false;
            LogWriter.log("==== ", e);
         }

         if (needSleep) {
            try { sleep(launchWait); }
            catch ( InterruptedException e ) {}
         }
      }
      LogWriter.log("TaskScheduler stopped.");
   }

   static boolean hasPendingTasks() 
   {
      synchronized (theQueue) { return (theQueue.size() > 0); }
   }

   static void addGroup(TaskGroup group)
   {
      synchronized (theQueue) {
         int priority = group.priority(); 
         int pos = 0;
         for (Iterator i = theQueue.iterator(); i.hasNext(); ++pos) {
            if (priority > ((TaskGroup)i.next()).priority())
               break;
         } 
         theQueue.add(pos, group);
      }
   }

   static public TaskGroup findGroupWith(int gid)
   {
      synchronized (theQueue) {
         for (Iterator i = theQueue.iterator(); i.hasNext();  ) {
            TaskGroup group = (TaskGroup)i.next();
            if (group.id() == gid)
               return group;
         }
         return null;
      }
   }

   // remove a machine from the candidate list for all groups
   static public void rmCandidateMachine(TestMachine mach)
   {
      for (Enumeration e = theQueue.elements();
            e.hasMoreElements(); )
      {
         TaskGroup group = (TaskGroup)e.nextElement();
         group.rmCandidateMachine(mach);
      }
   }

   static public void getMinMaxGid(Vector<String> minmax)
   {
      int min = 0;   // Integer.MAX_VALUE;
      int max = 0;   // Integer.MIN_VALUE;
      int count = 0;
      for (Enumeration e = theQueue.elements();
            e.hasMoreElements(); )
      {
         TaskGroup group = (TaskGroup)e.nextElement();
         if (count++ == 0) {
            max = group.id();
            min = group.id();
         } 
         if (group.id() > max)
            max = group.id();
         if (group.id() < min)
            min = group.id();
      }
      minmax.add(Integer.toString(min));
      minmax.add(Integer.toString(max));
   }
}

