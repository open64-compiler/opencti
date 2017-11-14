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

class PerfScheduler extends Thread
{
   private static boolean stop = false;
   private static boolean idle = false;
   private static WatchdogTimer watchDogTimer = null;
   private static PerfScheduler perfScheduler = null;
   final private int sleepTime = 2000;  // 2 second

   public PerfScheduler()
   {
      perfScheduler = this;
      idle = false;
      watchDogTimer = new WatchdogTimer(60, 300, this, "PerfScheduler");
      setDaemon(true);
   }

   public static void createAndRun()
   {
      // don't make sense to run if there is no performance pool
      if (Pool.perfPool != null) {
         perfScheduler = new PerfScheduler();
         LogWriter.log("PerfScheduler started");
         perfScheduler.start();
      }
   }
   public static void pleaseStop()   { stop = true; }
   public static void pleaseIdle()   { idle = true; }
   public static boolean isRunning()
   {
      if (perfScheduler == null)
         return true;
      else
         return watchDogTimer.isRunning();
   }


   public void run()
   {
      // it doesn't make sense to run without a performance pool
      if (Pool.perfPool == null)
         return;

      Vector MachineList = Pool.perfPool.machines();
      TestMachine pmach = null;
      int taskQueueTimer = 0;
      while (! stop) {
         try { sleep(sleepTime); }
         catch ( InterruptedException e ) {}
         watchDogTimer.update();

         // if it is idle, all perftasks have been transtered
         // to foreground server. So we don't have to schedule
         // any task. But we still need to go through this 
         // while loop to update watchdog timer. 
         if (idle)
            continue;

         // Try to find a perf machine that is available and free
         // and assign a tast to it.
         boolean changed = false;
         pmach = null;
         for ( Enumeration e = MachineList.elements();
               e.hasMoreElements(); )
         {
            pmach = (TestMachine)e.nextElement();
            if (pmach.available() && pmach.isUnlocked()) {
               // pmach is free now and try to get a task in the queue
               PerfTask ptask = PerfTask.selectTaskFor(pmach);
               if (ptask != null) {
                  // Allocate ptask on pmach
                  if (ptask.assignPerfMachine(pmach)) {
                     LogWriter.log("Getlock: "+pmach.name()+ " for task "
                                + ptask.ownerAndInfo());
                     changed = true;
                  }
               }
            }
            else if (! pmach.isUnlocked()) {
               // There is a task is running on pmach (which may or may
               // not be disabled)
               // check if the task has its timeout setting
               PerfTask ptask = pmach.getPerfTask();
               if (ptask.lockTimeOut()) {
                  // release the machine lock
                  ptask.releaseLock(true, true);
                  LogWriter.log("Releaselock: due to LOCKTIME out on "+pmach.name()
                                 + " for task " + ptask.ownerAndInfo());
                  changed = true;
               }
            }
         }

         if (changed)
            Pool.outputPerfMachineState();

         // check TaskQueue once every 15 second, to see if any task
         // has timed out 
         //
         if ((taskQueueTimer += sleepTime) >= 15) {
            taskQueueTimer = 0;
            PerfTask.monitorTaskQueue();
         }
      } // end of while
      LogWriter.log("PerfScheduler stopped.");
   }

   // used when one cancel a dTM job or a group
   static public void killRunningPerfTask(int gid, int tid)
   {
      if (gid == -1) return;
      if (Pool.perfPool == null) return;

      Vector MachineList = Pool.perfPool.machines();
      for ( Enumeration e = MachineList.elements();
            e.hasMoreElements(); )
      {
         TestMachine pmach = (TestMachine)e.nextElement();
         if (pmach.isUnlocked()) 
            continue;

         PerfTask ptask = pmach.getPerfTask();
         if (! ptask.isDtmType())
            continue;
         if (ptask.gid != gid) 
            continue;

         if (tid == -1 || tid == ptask.tid)
            ptask.releaseLock(true, false);
      }
   }
}
