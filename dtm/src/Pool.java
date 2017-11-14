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

class Pool 
{
   private String theName;
   private Vector<TestMachine> theMachines;

   private static Hashtable<String,Pool> thePoolMap = new Hashtable<String,Pool>();

   public static Pool perfPool = null;

   public Pool(String name, Vector<TestMachine> machineVector)
   {
      theName = name;
      theMachines = machineVector;
      thePoolMap.put(theName, this);
      if (isPerformance()) {
         perfPool = this;
      }
      for ( Enumeration e = machineVector.elements();
            e.hasMoreElements(); )
      {
         TestMachine tm = (TestMachine)e.nextElement();
         tm.inPool(this);
      }
   }

   public String name()     { return theName;  }
   public int    size()     { return theMachines.size();  }
   public Vector machines() { return theMachines;  }

   public boolean isPerformance()
   {
      return theName.equals("Performance");
   }
   public boolean contains(TestMachine testMachine)
   {
      return theMachines.contains(testMachine);
   }

   public void addMachine(TestMachine mach)
   {
      mach.disableInfo(dTMConfig.admin(), "newly added");
      theMachines.add(mach);
      mach.inPool(this);
   }

   public void removeMachine(TestMachine mach)
   {
      theMachines.remove(mach);
      mach.outOfPool(this);
   }

   public String dumpPoolState(boolean dumpTasks)
   {
      StringBuffer buf = new StringBuffer();
      for ( Enumeration e = theMachines.elements();
            e.hasMoreElements(); )
      {
         TestMachine m = (TestMachine)e.nextElement();
         if (dumpTasks)
            buf.append("%" + m.printState());
         else
            buf.append("%" + m.staticState());
      }
      return name() + "%" + theMachines.size() + buf.toString();
   }

   public TestMachine getMachine(String machine)
   {
      synchronized (theMachines) {
         for (Enumeration e = theMachines.elements();
              e.hasMoreElements(); ) {
            TestMachine mach = (TestMachine)e.nextElement();
            if (mach.name().equals(machine)) {
               return mach;
            }
         }
      }
      return null;
   }

   public String printPerfString(boolean withMachCandidates)
   {
      if (! isPerformance())  return "";

      String str = ""+ theMachines.size();
      for (Enumeration e = theMachines.elements();
           e.hasMoreElements(); ) {
         TestMachine pm = (TestMachine)e.nextElement();
         str += "#"+pm.perfString(withMachCandidates);
      }
      return str;
   }

   public void killZombieProcess()
   {
      for (Enumeration e = theMachines.elements();
           e.hasMoreElements(); ) {
         TestMachine tm = (TestMachine)e.nextElement();
         String cmd = dTMConfig.rsh() + " " + tm.name() + " " +
                      dTMConfig.dtmHomeDir() + "/bin/dtm_killPS.pl -9 -allps";
         try {
            Exec.exec(cmd);
         }
         catch (Exception ex) {
            LogWriter.log("Failed to run: " + cmd, ex);
         }
      }
   }

   // output the performance machine states and the performance queue
   // to PerfMachineState.log file under the log directory
   public static void outputPerfMachineState()
   {
      if (perfPool == null)  return;

      String file = dTMConfig.perfStateFile();
      synchronized (file) {
         try {
            FileOutputStream sf = new FileOutputStream (file);
            new PrintStream(sf).print(perfPool.printPerfString(false));
            sf.close();
         }
         catch (IOException ioe) {
            LogWriter.log("Failed to write file: " + file);
         }
      }
   }


   //
   // Static functions below to maintain thePoolMap
   //

   static public Pool get(String poolName) 
   {
      return (Pool)thePoolMap.get(poolName);
   }

   static public String currentPoolList()
   {
      StringBuffer buf = new StringBuffer();
      for ( Enumeration e = thePoolMap.elements();
            e.hasMoreElements(); )
      {
         Pool p = (Pool)e.nextElement();
         buf.append(":" + p.name());
      }
      return thePoolMap.size() + buf.toString();
   }

   static public String dumpMachineList()
   {
      StringBuffer buf = new StringBuffer();
      for ( Enumeration e = thePoolMap.elements();
            e.hasMoreElements(); )
      {
         Pool pool = (Pool)e.nextElement();
         buf.append("%" + pool.dumpPoolState(false));
      }
      return thePoolMap.size() + buf.toString();
   }

   static void killZombieProcesses()
   {
      for ( Enumeration e = thePoolMap.elements();
            e.hasMoreElements(); )
      {
         Pool pool = (Pool)e.nextElement();
         pool.killZombieProcess();
      }
   }
   
    static boolean removePool(String poolName){
        try{
            Pool pool = get(poolName);
            if(pool != null && pool.size() == 0){
               thePoolMap.remove(poolName);
               return true;
            }
        }catch (Exception e) {}
        return false;
    }

}
