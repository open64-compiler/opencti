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

public class TaskGroup
{
   private int     theId;
   private User    theUser;
   private int     thePriority;
   private String  theOS;
   private String  theArch;
   private String  theImpl;
   private int     theFreq;
   private int     theMinimumCpus;
   private String  theService;
   private String  theLog;
   private String  theWorkDir;
   private String  theView;
   private String  theDTM_POOL;
   private Vector  thePrimaryPool;
   private Vector  theSecondaryPool;
   private int[]   theThreshold;    // for theSecondaryPool
   private Vector  thePendingTasks;
   private Vector  theRunningTasks;
   private String  theJobName;
   private Connection conn;
   private long    theTime;
   final   String  idString;

   static public boolean debug = false;

   public TaskGroup(Connection con, Vector decodeVector, User user)
      throws Exception
   {
      // initialize the fields
      theId = getNewGid();
      theRunningTasks = new Vector();
      thePendingTasks = new Vector();
      conn = con;
      theUser = user;

      // 
      // Note: slot zero contains user name. We don't look at it
      // here in this function, but this is a real slot and can't
      // be used for other things.
      //

      // String userName = (String)decodeVector.get(0);
      String priority = (String)decodeVector.get(1);
      thePriority = Integer.parseInt(priority);
      theDTM_POOL = (String)decodeVector.get(2);
      theOS = (String)decodeVector.get(3);
      theArch = (String)decodeVector.get(4);
      theImpl = (String)decodeVector.get(5);
      String freq = (String)decodeVector.get(6);
      theFreq = Integer.parseInt(freq);
      theLog = (String)decodeVector.get(7);
      theService = (String)decodeVector.get(8);
      theView = (String)decodeVector.get(9);
      theWorkDir = (String)decodeVector.get(10);
      theJobName = (String)decodeVector.get(11);
      theMinimumCpus = 0;
      String mincpus = "0";
      if (decodeVector.size() > 12) {
	  mincpus = (String)decodeVector.get(12);
	  theMinimumCpus = Integer.parseInt(mincpus);
      }
      theTime = new Date().getTime();
      idString = "" + theId + ":" + user().name() + ":" + theWorkDir;

      if (theImpl.equals("null"))
         theImpl = null;
      if ( theDTM_POOL.equals("null") ) {
         // DTM_POOL is empty, use user's default pool
         Pool pl = user.defaultPool();
         theDTM_POOL = pl.name();
      }

      conn.send("MSG", "The conditions specified to select machines:");
      conn.send("MSG", "  DTM_POOL=" + theDTM_POOL);
      conn.send("MSG", "  DTM_OPSYS=" + (theOS==null?  "":theOS));
      conn.send("MSG", "  DTM_CPUARCH=" + (theArch==null?"":theArch));
      conn.send("MSG", "  DTM_CPUIMPL=" + (theImpl==null?"":theImpl));
      conn.send("MSG", "  DTM_CPUFREQ=" + (theFreq==0 ? "" : freq));
      conn.send("MSG", "  DTM_MINCPUS=" + (theMinimumCpus==0 ? "" : mincpus));
      conn.send("MSG", "  DTM_PRIORITY=" + priority);

      // Split the pool string into primary and secondary pools
      //    DTM_POOL=PrimaryPools[/SecondaryPools]
      //
      String[] pools = theDTM_POOL.split("/");
      if ( pools[0].equals("") ) {
         throw new Exception("Primary pool is empty in " + theDTM_POOL);
      }
      
      // primary pool list is in pools[0]
      thePrimaryPool = new Vector();
      checkPools(pools[0], thePrimaryPool, null);
      if (thePrimaryPool.isEmpty()) {
         throw new Exception("Primary pool is empty in " + theDTM_POOL);
      }

      // handle secondary pool
      if (pools.length > 1 && !pools[1].equals("")) {
         // secondary pool list is in pools[1]
         theSecondaryPool = new Vector();
         theThreshold = new int[200];
         checkPools(pools[1], theSecondaryPool, theThreshold);
         if (theSecondaryPool.isEmpty()) {
            theSecondaryPool = null;
            theThreshold = null;
         }
      } else {
         // secondary pool list is empty
         theSecondaryPool = null;
         theThreshold = null;
      }

      LogWriter.log("New group " + idString);
   }

   //
   // Format of DTM_POOL setting:
   // 
   // export DTM_POOL=PrimaryPools[/SecondaryPools]
   // where PrimaryPools   = [PoolDesc[,PoolDesc]*][:MachDesc[,MachDesc]*]
   //       SecondaryPools = [PoolDesc[,PoolDesc]*][:MachDesc[,MachDesc]*]
   //       PoolDesc       = poolname[#threshold]
   //       MachDesc       = machinename[#threshold]
   //       Meta Symbols     [ ] *
   //       Delimiters       : ; # ,
   //

   // checkPools checks syntax for PrimaryPools or SecondaryPools and puts
   // the selected machines and their thresholds into mpool and threshold 
   // respectively
   //
   private void checkPools(String poolstr, Vector mpool, int[] threshold)
      throws Exception
   {
      // Split the pool string into pool list and machine list
      String[] ps = poolstr.split(":");
      if (ps.length == 0) {
         throw new Exception("Syntax error for machine pool: "+ poolstr);
      }

      Vector tmpools = new Vector();
      int plthreshold[] = new int[20];

      if ( ! ps[0].equals("") ) {
         // pool list is provided with ps[0]
         StringTokenizer pls = new StringTokenizer(ps[0],",");
         while (pls.hasMoreTokens()) {
            String pDesc[] = pls.nextToken().split("#");
            // pDesc[0] contains pool name, and pDesc[1] the threshold if any
            if (pDesc.length == 0 || pDesc[0].equals(""))
               continue;

            Pool pl = Pool.get(pDesc[0]);
            if ( pl == null ) {
               throw new Exception("Unknown machine pool: " + pDesc[0]);
            }
            if (threshold == null) { 
               conn.send("MSG", "Your primary pool: " + pDesc[0]);
            } else {
               conn.send("MSG", "Your secondary pool: " + pDesc[0]);
               if (pDesc.length == 1 || pDesc[1].equals(""))
                  plthreshold[tmpools.size()] = -1;
               else
                  plthreshold[tmpools.size()] = Integer.parseInt(pDesc[1]);
            }
            tmpools.add(pl);
         }
      }

      if (ps.length == 1 || ps[1].equals("")) {
         // machine list is not specified, so check out the machines in tmpools.
         // give up, if the pool list is empty.
         if ( tmpools.isEmpty()) {
            throw new Exception("Syntax error for machine pool: "+ poolstr);
         }

         // put machines that meet the conditions in any pool into
         // the real machine list mpool
         for (int pi = 0; pi < tmpools.size(); ++pi) {
            Pool pl = (Pool)tmpools.get(pi);
            for (Enumeration e = pl.machines().elements(); e.hasMoreElements(); ) {
               TestMachine mach = (TestMachine)e.nextElement();
               if (mach.meetConditions(theOS, theArch, theImpl, theFreq,
				       theMinimumCpus,
                                       theService, conn)) {
                  if (threshold != null) {
                     threshold[mpool.size()] = plthreshold[pi];
                     conn.send("MSG", "Machine: " + mach.name() + " is selected with "
                                      + plthreshold[pi]);
                  } else 
                     conn.send("MSG", "Machine: " + mach.name() + " is selected");
                  mpool.add(mach);
               }
            }
         }
      }
      else {
         // machine list is specified with ps[1], and check the list
         if (threshold == null)
            conn.send("MSG", "Check primary machine list: " + ps[1]);
         else
            conn.send("MSG", "Check secondary machine list: " + ps[1]);
         StringTokenizer machTkList = new StringTokenizer(ps[1], ",");
         while ( machTkList.hasMoreTokens() ) {
            String mDesc[] = machTkList.nextToken().split("#");
            if (mDesc.length == 0 || mDesc[0].equals(""))
               continue;

            String mName = mDesc[0];
            int mthreshold = -1;
            if (mDesc.length > 1 && !mDesc[1].equals(""))
               mthreshold = Integer.parseInt(mDesc[1]);

            TestMachine tm = TestMachine.get(mName);
            if ( tm == null ) {
               conn.send("MSG", "** Machine: " + mName + " is excluded because"
                             + " it is not in any machine pool");
               continue;
            }

            // check if machine mNname is in tmpools
            if (! tmpools.isEmpty()) {
               Pool pool = null;
               for (int i=0; i < tmpools.size(); ++i) {
                  pool = (Pool)tmpools.get(i);
                  if (pool != null && pool.contains(tm)) {
                     if (mthreshold == -1)
                        mthreshold = plthreshold[i];
                     break;
                  }
                  pool = null;
               }
               if (pool == null) {
                  conn.send("MSG", "** Machine: " + mName + " is excluded because"
                                + " it is not in pool " + poolNames(tmpools));
                  continue;
               }
            }
            if (threshold != null) {
               conn.send("MSG", "Machine: " + mName + " is selected with " + mthreshold);
               threshold[mpool.size()] = mthreshold;
            } else 
               conn.send("MSG", "Machine: " + mName + " is selected");
            mpool.add(tm);
         }
      }
   }

   public String toString()      { return ""+theId; }
   public int id()               { return theId; }
   public User user()            { return theUser; }
   public int priority()         { return thePriority; }
   public Connection conn()      { return conn; }
   public String workDir()       { return theWorkDir; }
   public String clearcaseView() { return theView; }
   public String jobname()       { return theJobName; }
   public Vector primaryPool()   { return thePrimaryPool; }
   public Vector secondaryPool() { return theSecondaryPool; }

   public void rmCandidateMachine(TestMachine mach)
   {
      thePrimaryPool.remove(mach);
      if (theSecondaryPool != null)
         theSecondaryPool.remove(mach);
   }

   public synchronized void submitPendingTask(UnitTask task)
   {
      // LogWriter.log("Adding " + task.idString());
      thePendingTasks.addElement(task);
   }

   static private String poolNames(Vector poolVector) 
   {
      Iterator pi = poolVector.iterator();
      String names = ((Pool)pi.next()).name();
      while (pi.hasNext())
         names += "," + ((Pool)pi.next()).name();
      return names;
   }

   public synchronized boolean hasPendingTask()
   {
      return thePendingTasks.size() > 0;
   }

   public synchronized TaskAssignment taskAssignment(boolean secondary)
   {
      if (thePendingTasks.isEmpty())
         return null;

      Vector candMachines = thePrimaryPool;
      if (secondary) {
         if (theSecondaryPool == null)
            return null;
         else
            candMachines = theSecondaryPool;
      }

      if (candMachines.isEmpty()) {
         String msg = "WARNING: The number of machines reduced to 0 in your "
                      + (secondary? "secondary":"primary") + " pool. Your tasks"
                      + " in group " + theId + " may may not go furthur.";
         LogWriter.log(msg);
         conn.send("MSG", msg);
         return null;
      }

      // sort the machine list on remaining idle CPU percentage
      Collections.sort(candMachines);
      if (debug) {
         LogWriter.log("Machine list: "+candMachines.toString());
      }

      UnitTask task = (UnitTask)thePendingTasks.firstElement();
      for (int i=0; i < candMachines.size(); ++i) {
         // If the machine is available for use and is not currently
         // oversubscribed, assign a task to it.
         TestMachine mach = (TestMachine) candMachines.get(i);
         int threshold = -1;
         if (secondary) threshold = theThreshold[i];
         if ( mach.acceptingTasks(threshold) ) 
            return new TaskAssignment(task, mach);
      }
      return null;
   }

   public synchronized UnitTask findTask(int tid)
   {
      // check the theRunningTasks list
      for (Enumeration e = theRunningTasks.elements();
           e.hasMoreElements(); )
      {
         UnitTask task = (UnitTask) e.nextElement();
         if (task.id() == tid)
             return task;
      }

      // check the thePendingTasks list
      for (Enumeration e = thePendingTasks.elements();
           e.hasMoreElements(); )
      {
         UnitTask task = (UnitTask) e.nextElement();
         if (task.id() == tid)
             return task;
      }
      return null;
   }
 
   public synchronized boolean finished()
   {
      return (thePendingTasks.isEmpty() && theRunningTasks.isEmpty());
   }
   
   public synchronized void retryTask(UnitTask task)
   {
      thePendingTasks.addElement(task);
      theRunningTasks.removeElement(task);
      task.cancelPerformanceRun();
   }

   public synchronized void removeRunningTask(UnitTask task)
   {
      theRunningTasks.removeElement(task);
   }
   
   public synchronized void markTaskRunning(UnitTask task)
   {
      theRunningTasks.addElement(task);
      thePendingTasks.removeElement(task);
   }

   private synchronized void removePendingTask(UnitTask task)
   {
      thePendingTasks.removeElement(task);
   }
   
   public synchronized LinkedList terminateTask(int tid, int state)
   {
      LinkedList killedList = new LinkedList();
      // for pending tasks
      if (state == UnitTask.KILLED) {
         for ( Enumeration e = thePendingTasks.elements();
               e.hasMoreElements(); ) {
            UnitTask task = (UnitTask)e.nextElement();
            if (tid == -1 || task.id() == tid) {
               // Make sure the client receives a finish message
               // for a pending task. The client need it to count
               // down the number of submitted tasks.
               task.conn().send("FINISH", task.idString() + " cancelled");
               task.writeKillMarker();
               LogWriter.log("Pending task " + task.idString() + " cancelled");
               if (task.id() == tid) {
                  thePendingTasks.removeElement(task);
                  return killedList;
               }
            }
         }
         if (tid == -1)
            thePendingTasks.clear();
      }

      // for running tasks
      for ( Enumeration e = theRunningTasks.elements();
            e.hasMoreElements(); ) {
         UnitTask task = (UnitTask)e.nextElement();
         if (tid == -1 || task.id() == tid) {
            // issue a kill command
            task.terminate(state);
            if (state == UnitTask.KILLED)
               task.writeKillMarker();
            killedList.add(task);
            // runningOn() will take care of removing the task
            // from theRunningTasks.
         }
         if (task.id() == tid) 
            break;
      }
      return killedList;
   }

   final static String delimit = "^";

   public String printState()
   {
      long time = ((new Date().getTime()) - theTime)/60000; // in minute

      StringBuffer buf = new StringBuffer();
      buf.append(id());                         // 0
      buf.append(delimit + priority());         // 1
      buf.append(delimit + clearcaseView());    // 2
      buf.append(delimit + time);               // 3
      buf.append(delimit + theDTM_POOL);        // 4 
      buf.append(delimit + jobname());          // 5
      buf.append(delimit + theLog);             // 6

      int rCount = theRunningTasks.size();
      int pCount = thePendingTasks.size();
      buf.append(delimit + rCount);             // 7
      buf.append(delimit + pCount);             // 8

      // Dump running tasks
      if (rCount > 0) {
         for ( Enumeration r = theRunningTasks.elements();
               r.hasMoreElements(); )
         {
            UnitTask t = (UnitTask)r.nextElement();
            buf.append(delimit + t.toStringUserDump());
         }
      }

      // Dump pending tasks
      if (pCount > 0) {
         for ( Enumeration p = thePendingTasks.elements();
               p.hasMoreElements(); )
         {
            UnitTask t = (UnitTask)p.nextElement();
            buf.append(delimit + t.toStringUserDump());
         }
      }
      return buf.toString();
   } 

   //
   // Unique group id management
   // 
   static private int theGroupCounter = 1;
   static private String theLock = "Lock for theGroupCounter";
   static private int bgServerMin = 0;
   static private int bgServerMax = 0;

   // prohibit to use ids which is currently in use on BgServer
   private static int getNewGid() 
   {
      synchronized (theLock) {
         ++theGroupCounter;
         if (theGroupCounter > bgServerMax) 
            return theGroupCounter;
         if (theGroupCounter < bgServerMin) 
            return theGroupCounter;
         theGroupCounter = bgServerMax + 1;
         return theGroupCounter;
      } 
   }

   public static void setupMinMaxGid(String min, String max)
   {
      LogWriter.log("  bgServerMin="+min+"  bgServerMax="+max);
      bgServerMin = Integer.parseInt(min);
      bgServerMax = Integer.parseInt(max);
   }
}

