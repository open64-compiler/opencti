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
class TaskAssignment extends Thread
{
   private UnitTask theTask;
   private TestMachine theMachine;

   TaskAssignment(UnitTask task, TestMachine mach)
   {
      theTask = task;
      theMachine = mach;
      task.machine(mach);
      mach.addTask(task);
      task.group().markTaskRunning(task);
      incTaskCount();
   }

   public void run()
   {
      theTask.runningOn(theMachine);
      decTaskCount();
   }

   // We replaced "remsh" with our own "dtm_rexec". As a result,
   // we could have thousand of jobs launching at the same time.
   //
   static public final int activeTaskLimit = 1500;
   static private      int taskCount = 0;

   static synchronized boolean reachMaxTaskLimit()
   {
      return (taskCount >= activeTaskLimit);
   }

   static private synchronized void incTaskCount() { ++taskCount; }
   static private synchronized void decTaskCount() { --taskCount; }
   static public                int taskCount()    { return taskCount; }
}
