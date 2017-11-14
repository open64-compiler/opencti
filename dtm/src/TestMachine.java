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

public class TestMachine implements Comparable
{
    // The number of client errors tolerated before a machine
    // is disabled from the test pool.
    final int theMaxErrorCount = 3;
    // Disk utilization must be under this number for jobs to be launched
    final int theMaxDiskUsedPercentage = 95;
    // Swap utilization must be under this number for jobs to be launched
    final int theMaxSwapUsedPercentage = 90;

    final private String  theName;  // machine host name
    final private String  theOS;
    final private String  theArch;
    final private String  theImpl;
    final private int     theFreq;
    final private int     theNumberCpus;
    final private String  theWorkDir;
    final private Vector  theServices;
    final private String  excludedMsg;
    // The Maximum tasks allowed on a single machine
    // final private int     theMaxTasks;
    // The Maximum non-performance tasks allowed on a single machine
    // final private int     maxActiveTasks;
    // what percent of computing power one CPU contributes
    // final private int     theCpuPercentage;

    boolean isAvailable;   // Is the server allowed to use this machine?
    boolean theStatus;     // Is the machine up or down?
    int theIdlePercentage; // what percent of computing power is idle
    int theDiskUsedPercentage; // what percent of /dTM dir is used
    int theSwapUsedPercentage; // what percent of swap space is used

    // those make sense only when isAvailable == false
    private String disabler;      // person who disables this machine
    private String disableInfo;   // disabling reason
    private long   disableTime;   // disabling start time 

    // performance machine special fields
    private boolean  isPerf;      // is it a performance machine?
    private PerfTask perfTask;    // null or a PerfTask
    private String   logFile;     // performance lock log file

    // try to run loadd count
    private int     theLoaddStartCount = 0;

    
    Vector<UnitTask>  theCurrentTaskList;
    Vector<UnitTask>  theInactiveTaskList;
    long    theLastFailTime;
    int     theErrorCount;
    Vector<Pool>  thePool;
    Process theLoaddProcess;
    
    //Buffered machine data
    Map<String,String> theLoaddData;

    // all non-performance machines
    public static Vector<TestMachine> allMachines = new Vector<TestMachine>();

    public TestMachine(String host,
                      String osys,
                      String arch,
                      String impl,
                      int    freq,
                      int    CPUs,
                      String workdir,
                      Vector services)
    {
        theName = host;
        theOS = osys;
        theArch = arch;
        theImpl = impl;
        theFreq = freq;
        theNumberCpus = CPUs;
        // theCpuPercentage = 100/CPUs - 1;
        // theMaxTasks = CPUs * 8;
        // maxActiveTasks = CPUs + 1;
        theWorkDir = workdir;
        theServices = services;
        excludedMsg = "** Machine: " + host + " is excluded because ";

        theStatus = true;
        theIdlePercentage = 0;
        theDiskUsedPercentage = 0;
        theSwapUsedPercentage = 0;
        theCurrentTaskList = new Vector<UnitTask>();
        theInactiveTaskList = new Vector<UnitTask>();
        theErrorCount = 0;
        theLastFailTime = 0;
        thePool = new Vector<Pool>();
        theLoaddProcess = null;
        isPerf = false;
        perfTask = null;

        server_disable("initially disabled");
        theMachineMap.put(host,this);
    }

    public TestMachine(String host, TestMachine sameasMach)
    {
        theName = host;
        theOS = sameasMach.theOS;
        theArch = sameasMach.theArch;
        theImpl = sameasMach.theImpl;
        theFreq = sameasMach.theFreq;
        theNumberCpus = sameasMach.theNumberCpus;
        // theCpuPercentage = sameasMach.theCpuPercentage;
        // theMaxTasks = sameasMach.theMaxTasks;
        // maxActiveTasks = sameasMach.maxActiveTasks;
        theWorkDir = sameasMach.theWorkDir;
        theServices = (Vector)sameasMach.theServices.clone();
        excludedMsg = "** Machine: " + host + " is excluded because ";

        theStatus = true;
        theIdlePercentage = 0;
        theDiskUsedPercentage = 0;
        theSwapUsedPercentage = 0;
        theCurrentTaskList = new Vector<UnitTask>();
        theInactiveTaskList = new Vector<UnitTask>();
        theErrorCount = 0;
        theLastFailTime = 0;
        thePool = new Vector<Pool>();
        theLoaddProcess = null;
        isPerf = false;
        perfTask = null;

        server_disable("initially disabled");
        theMachineMap.put(host,this);
    }

    public String name()        { return theName; }
    public Vector services()    { return theServices; }
    public String avservices()  {
        StringBuffer buffer = new StringBuffer();
        Iterator iter = theServices.iterator();
        while (iter.hasNext()) {
            buffer.append(iter.next());
            if (iter.hasNext()) {
                buffer.append("<br>");
            }
        }
        return buffer.toString();
    }
    public String osys()
    {
        if(! theOS.equals("")){
            return theOS;
        }
        // if(theLoaddData == null) theLoaddData = query_loadd();
        if(theLoaddData != null  && theLoaddData.containsKey("Release")){
            return theLoaddData.get("Release").replace(' ', '_');
        }else
            return " ";
    }
    
    public String flavor()
    {
        // if(theLoaddData == null) theLoaddData = query_loadd();
        if(theLoaddData != null  && theLoaddData.containsKey("Flavor")){
            return theLoaddData.get("Flavor");
        }else
            return " ";
    }
    
    public String machine_model()
    {
        // if(theLoaddData == null) theLoaddData = query_loadd();
        if(theLoaddData != null  && theLoaddData.containsKey("Machine model")){
            return theLoaddData.get("Machine model");
        }else
            return " ";
    }
    
    public String memory()
    {
        // if(theLoaddData == null) theLoaddData = query_loadd();
        if(theLoaddData != null  && theLoaddData.containsKey("Memory")){
            String[] token = theLoaddData.get("Memory").split(" ");
            return token[0];
        }else
            return " ";
    }
    
    public String disk_info()
    {
        // if(theLoaddData == null) theLoaddData = query_loadd();
        if(theLoaddData != null  && theLoaddData.containsKey("Disk info")){
            return theLoaddData.get("Disk info");
        }else
            return " ";
    }
    public String uptime()
    {
        // if(theLoaddData == null) theLoaddData = query_loadd();
        if(theLoaddData != null  && theLoaddData.containsKey("Uptime")){
            return theLoaddData.get("Uptime");
        }else
            return " ";
    }

    public String timezone()
    {
        // if(theLoaddData == null) theLoaddData = query_loadd();
        if(theLoaddData != null  && theLoaddData.containsKey("TZ")){
            return theLoaddData.get("TZ");
        }else
            return " ";
    }

    public String auto_test()
    {
        // if(theLoaddData == null) theLoaddData = query_loadd();
        if(theLoaddData != null  && theLoaddData.containsKey("auto.test")){
            return theLoaddData.get("auto.test");
        }else
            return " ";
    }

    public String ip_address()
    {
        // if(theLoaddData == null) theLoaddData = query_loadd();
        if(theLoaddData != null  && theLoaddData.containsKey("IP Address")){
            return theLoaddData.get("IP Address");
        }else
            return " ";
    }

    public String arch()
    { 
        if(! theArch.equals("")){
            return theArch; 
        }
        // if(theLoaddData == null) theLoaddData = query_loadd();
        if(theLoaddData != null  && theLoaddData.containsKey("Machine model")){
            if((theLoaddData.get("Machine model")).indexOf("ia64") >=0){
                return "IPF";
            }else if(theLoaddData.get("Machine model").indexOf("9000/") >= 0){
                return "PA";
            }else if(theLoaddData.get("Machine model").indexOf("x86_64") >= 0){
                return "x86_64";
            }else if(theLoaddData.get("Machine model").indexOf("i686") >= 0){
                return "x86";
            }else
                return theLoaddData.get("Machine model");
        } else return " ";
    }
    public String impl()
    { 
        if(! theImpl.equals("")){
            return theImpl; 
        }
        // if(theLoaddData == null) theLoaddData = query_loadd();
        if(theLoaddData != null  && theLoaddData.containsKey("Processor model"))
            return theLoaddData.get("Processor model");
        else
            return " ";
    }
    
    public String freqGH(){
        if(theFreq != -1){
            return String.format("%.2f", (float)theFreq/1000);
        }
        // if(theLoaddData == null) theLoaddData = query_loadd();
        if(theLoaddData != null  && theLoaddData.containsKey("Clock speed")){
            String[] token = theLoaddData.get("Clock speed").split(" ");
            return token[0];
        }else
            return " ";
    }
    
    public int freq()
    { 
        if(theFreq != -1){
            return theFreq;
        }
        // if(theLoaddData == null) theLoaddData = query_loadd();
        if(theLoaddData != null  && theLoaddData.containsKey("Clock speed")){
            String[] token = theLoaddData.get("Clock speed").split(" ");
        
            float f = Float.valueOf(token[0].trim()).floatValue();
            return (int)(f * 1000);
        }else
            return 0;
    }
    
    public String numberOfCores()
    {
        if(theNumberCpus != -1){
            return Integer.toString(theNumberCpus); 
        }
        // if(theLoaddData == null) theLoaddData = query_loadd();
        if(theLoaddData != null   && theLoaddData.containsKey("Number of Cores")){
            return theLoaddData.get("Number of Cores");
        }
        return " ";
    }
    
    public int    numberCpus() 
    { 
        if(theNumberCpus != -1){
            return theNumberCpus; 
        }
        // if(theLoaddData == null) theLoaddData = query_loadd();
        if(theLoaddData != null   && theLoaddData.containsKey("Number of Cores")){
            int cpu_count = 0;
            try{
                String cpus = theLoaddData.get("Number of Cores");
                if(cpus.indexOf("NHT") >= 0){
                    String s = theLoaddData.get("Number of Cores").replaceFirst("NHT", "");
                    cpu_count = Integer.valueOf(s);
                }else if(cpus.indexOf("HT") >= 0){
                    String s = theLoaddData.get("Number of Cores").replaceFirst("HT", "");
                    cpu_count = Integer.valueOf(s) * 2;
                }else{
                    cpu_count = Integer.valueOf(cpus);
                }
            }catch (NumberFormatException nf) {
                // ignore error cpu_count value 0 will return
            }
            return cpu_count;
        }
        return 0;
    }
    public String workDir()    {return theWorkDir;}
    
    public int CpuPercentage()
    {
        if (numberCpus() == 0)
            return 0;
        else
            return 100/numberCpus() - 1;
    }

    public long lastFailTime()    { return theLastFailTime; }
    public Process loaddProcess() { return theLoaddProcess; }
    public void loaddProcess(Process ps) {
        theLoaddProcess = ps;
        if(ps == null){
            theLoaddData = null;
            theIdlePercentage     = 0;
            theDiskUsedPercentage = 0;
            theSwapUsedPercentage = 0;
        }
    }

   public void disableInfo(String user, String info)
   {
      disabler = user;
      disableInfo = info;
   }
   
   public void inPool(Pool pl)
   {
      if (! thePool.contains(pl))
         thePool.add(pl);
      if (pl.isPerformance()) {
         isPerf = true;
         perfTask = null;
         logFile = dTMConfig.dtmHomeDir()+"/log/lock."+theName+".log";
      }
      else if (! allMachines.contains(this))
         allMachines.add(this);
   }
   public void outOfPool(Pool pl)
   {
      thePool.remove(pl);
      if (pl.name().equals("Performance")) {
         isPerf = false;
         perfTask = null;
      }
      else
         allMachines.remove(this);
   }
   
   public boolean isUsed()  { return isPerf || !thePool.isEmpty(); }
   public boolean hasTask()
   {
      if (isPerf && perfTask != null) 
         return true;
      if (! thePool.isEmpty())
         return !theCurrentTaskList.isEmpty() || !theInactiveTaskList.isEmpty();
      return false;
   }

   public boolean meetConditions(String osys,
                                 String arch,
                                 String impl,
                                 int mfreq,
                                 int mincpus,
                                 String service,
                                 Connection conn)
   {
      if (! osys().startsWith(osys)) {
         conn.send("MSG", excludedMsg + (osys().equals(" ") ? "machine/loadd down" : "OS=" + osys()));
         return false;
      }
      if (! arch.equals(arch())) {
         conn.send("MSG", excludedMsg + (arch().equals(" ") ? "machine/loadd down" : "Arch=" + arch()));
         return false;
      }
      if (impl != null && ! impl().startsWith(impl)) {
         conn.send("MSG", excludedMsg + (impl().equals(" ") ? "machine/loadd down" : "Impl=" + impl()));
         return false;
      }
      if ( mfreq > freq() )
      {
         conn.send("MSG", excludedMsg + (freq() == 0 ? "machine/loadd down" : "Freq=" + freq()));
         return false;
      }
      if ( mincpus > numberCpus() )
      {
         conn.send("MSG", excludedMsg + (numberCpus() == 0 ? "machine/loadd down" : "Cpus=" + numberCpus()));
         return false;
      }
      if (! services().contains(service)) 
      {
         conn.send("MSG", excludedMsg +"of no "+ service +" service");
         return false;
      }
      return true;
   }

   public void addTask(UnitTask task) 
   { 
      theCurrentTaskList.addElement(task); 
   }
   public void removeTask(UnitTask task) 
   { 
      if (! theCurrentTaskList.remove(task) )
         theInactiveTaskList.remove(task);
   }

   public UnitTask findRunningTask(int gid, int tid)
   {
      // find out a task with specified gid and tid
      for ( Enumeration e = theCurrentTaskList.elements();
            e.hasMoreElements(); )
      {
         UnitTask task = (UnitTask)e.nextElement();
         if (task.id() == tid && task.gid() == gid)
            return task;
      }
      return null;
   }

   public void markInactive(UnitTask task)
   {
      theInactiveTaskList.addElement(task);
      theCurrentTaskList.remove(task);
   }
   
   public boolean available() { return isAvailable; }
   public void enable()
   { 
      isAvailable = true;
      theErrorCount = 0;
      disabler = null;
      disableInfo = null;
      theLoaddStartCount = 0;
      if(isPerf) { query_sysinfo(); }
   }

   // there are two ways to disable a machine: either a user can 
   // disable it via dtm -disable command, or the server can disable
   // it after too many errors. The only way for the server to 
   // distinguish these two cases is by the error count. With a 
   // user disabled machine, its error count theErrorCount must be 0.
   //
   public void server_disable(String info)
   {
      isAvailable = false;
      disableInfo = info;
      disabler = "dTM server";
      disableTime = new Date().getTime();
   }
   public void user_disable(String who, String info)
   {
      isAvailable = false;
      theErrorCount = 0;
      disableInfo = info;
      disabler = who;
      disableTime = new Date().getTime();
   }

   public boolean machineStatus()           { return theStatus; }
   public void machineStatus(boolean val)   { theStatus = val; }
   public void idlePercentage(int val)      { theIdlePercentage = val; }
   public void diskUsedPercentage(int val)  { theDiskUsedPercentage = val; }
   public void swapUsedPercentage(int val)  { theSwapUsedPercentage = val; }

   public boolean acceptingTasks(int threshold)
   {
      int activeTasks = theCurrentTaskList.size();
      int totalTasks = activeTasks + theInactiveTaskList.size();
      int compareThreshold = (CpuPercentage() > threshold)?
                              CpuPercentage() : threshold;
      if ( available() &&
           (activeTasks < numberCpus() + 1) &&
           (totalTasks < numberCpus() * 8) &&
            theDiskUsedPercentage < theMaxDiskUsedPercentage &&
            theSwapUsedPercentage < theMaxSwapUsedPercentage &&
            theIdlePercentage >= compareThreshold ) {
                theIdlePercentage -= CpuPercentage();
         return true;
      }
      return false;
   } 

   public boolean reachMaxErrorCount() { return theErrorCount >= theMaxErrorCount; }
   public void resetErrorCount()
   {
      if (theErrorCount >= theMaxErrorCount)
         if (!isAvailable) {
            // currently in AUTO DISABLED state, change to ENABLED
            isAvailable = true;
            theErrorCount = 0;
            if(isPerf) { query_sysinfo(); }
         }
      else
         if (theErrorCount != 0 && isAvailable) {
            // in ENABLED state, but error count != 0, reset error count
            theErrorCount = 0;
         }
   }
   public void incErrorCount(String err_msg) 
   { 
      theLastFailTime = new Date().getTime();
      if ( ++theErrorCount >= theMaxErrorCount )
      {
         server_disable("Hit max error count " + theErrorCount + ": " + err_msg);
         LogWriter.log("Hit max error count (" + theErrorCount
                           + ") on " + name() + ": DISABLED");
      }
   }

   public int compareTo(Object o)
   {
      TestMachine l = this;
      TestMachine r = (TestMachine)o;
      
      if ( l.theIdlePercentage > r.theIdlePercentage )
         return -1;
      if ( l.theIdlePercentage < r.theIdlePercentage )
         return 1;
      
      if ( l.freq() > r.freq() )
         return -1;
      if ( l.freq() < r.freq() )
         return 1;
      
      return 0;
   }
 
   static final private String delimit = ":";

   public String staticState()
   {
      String str;
      str = name()          + delimit
          + osys()          + delimit
          + flavor()        + delimit
          + arch()          + delimit
          + impl()          + delimit
          + freqGH()        + delimit
          + numberOfCores() + delimit
          + memory()        + delimit
          + disk_info()     + delimit
          + auto_test()     + delimit
          + workDir()       + delimit
          + avservices()    + delimit
          + machineStatus() + delimit
          + available()     + delimit
          + disabler        + "<br>"
          + disableInfo;
      return str;
   } 
 
   public String printState()
   {
      String str;
      str = name()          + delimit
          + arch()          + delimit
          + numberCpus()    + delimit
          + machineStatus() + delimit
          + available()     + delimit;
      if (! available()) {
         str += disabler    + delimit
              + disableInfo + delimit
              + disableTime/1000 + delimit;
      }
      return str + printRunningTasks();
   } 
 
   private synchronized String printRunningTasks()
   {
       String runningTasks = ""; 
       Vector<UnitTask> taskList = new Vector<UnitTask>(theCurrentTaskList);
       taskList.addAll(theInactiveTaskList);
       for ( Enumeration e = taskList.elements();
             e.hasMoreElements(); )
       {
           UnitTask task = (UnitTask)e.nextElement();
           runningTasks += task.toStringPoolDump();
           if ( e.hasMoreElements() )
               runningTasks += ";";
       }
       return runningTasks;
   }

   public String dynamicState()
   {
      String dStatus;
      dStatus = name()                + delimit
              + available()           + delimit
              + theStatus             + delimit
              + theErrorCount         + delimit
              + numberCpus()          + delimit
              + theIdlePercentage     + delimit
              + theDiskUsedPercentage + delimit
              + theSwapUsedPercentage + delimit
              + theLastFailTime;
      if (! available()) {
         dStatus += delimit + disabler
                  + delimit + disableInfo
                  + delimit + disableTime;
      }
      return dStatus;
   }

   public void setDynamicState(String state)
   {
      StringTokenizer tk = new StringTokenizer(state,":");
      tk.nextToken(); // machine host name has been checked, skip it
      isAvailable = (new Boolean((String)tk.nextToken())).booleanValue();
      theStatus = (new Boolean((String)tk.nextToken())).booleanValue();
      theErrorCount = Integer.parseInt((String)tk.nextToken()); 
      tk.nextToken(); // skip theNumberCpus
      theIdlePercentage = Integer.parseInt((String)tk.nextToken());
      theDiskUsedPercentage = Integer.parseInt((String)tk.nextToken());
      theSwapUsedPercentage = Integer.parseInt((String)tk.nextToken());
      theLastFailTime = Long.parseLong((String)tk.nextToken());
      if (! isAvailable && tk.hasMoreTokens()) {
         disabler = (String)tk.nextToken();
         disableInfo = (String)tk.nextToken();
         // initial disabled time is updated to the current time
         if ( disabler.equals("dTM server") &&
              disableInfo.equals("initially disabled"))
            disableTime = new Date().getTime();
        else{
            try
            {
                disableTime = Long.parseLong((String)tk.nextToken());
            }catch ( Exception f )
            {
                String msg = "dTM server cannot determine prev machine state, machine will disable "
                         + theName;
                LogWriter.log(msg, f);
                server_disable("Error while machine state");
                disableTime = new Date().getTime();
                return;
            }
        }
      }
   }


   //
   // theMachineMap management functions
   //
   static Hashtable<Object, Object> theMachineMap = new Hashtable<Object, Object>();

   static public int countMachines() { return theMachineMap.size(); }
   
   static public TestMachine get(String machName)
   {
       return (TestMachine)theMachineMap.get(machName);
   }
   static public void removeMachine(TestMachine mach)
   {
      theMachineMap.remove(mach.name());
      for (Enumeration e = mach.thePool.elements();
           e.hasMoreElements(); )
      {
         Pool pool = (Pool) e.nextElement();
         pool.removeMachine(mach);
      }
   }

   public static String printDynamicStatus()
   {
      String dStatus = ""; 
      for ( Enumeration e = allMachines.elements();
              e.hasMoreElements(); )
      {
         TestMachine mach = (TestMachine)e.nextElement();

         dStatus += mach.dynamicState();
         if (e.hasMoreElements())
            dStatus += "#";
      }
      return dStatus;
   }

   public static void outputMachineState() {
      String file = dTMConfig.stateFile();
      // synchronizing the writes to the same file
      synchronized (file) {
         try {
            FileOutputStream sf = new FileOutputStream (file);
            new PrintStream(sf).println(printDynamicStatus());
            sf.close();
            LogWriter.log("Machine state wrtitten to: " + file);
         }
         catch (IOException ioe) {
            LogWriter.log("Failed to write file: " + file);
         }
      }
   }


   //
   // Performachine Machine functions below
   //
   public boolean  isPerfMachine() { return isPerf; }
   public PerfTask getPerfTask()   { return perfTask; }
   public boolean  isUnlocked()    { return perfTask == null; }
   public void     setPerfTask(PerfTask task) { perfTask = task; }

   public String perfString(boolean withMachCandidates)
   {
      if (! isPerfMachine()) return "";

      // Format
      //   host;<availableInfo>;<taskInfo>
      //   <availableInfo> = true | false;disabler;disableTime;disableInfo
      //   <taskInfo> = Free | True;<taskToString>
      //
      String str;
      if (isAvailable)
         str = theName+";true";
      else
         str = theName+";false;"+disabler+";"+disableTime/1000+";"+disableInfo;
      
      if (perfTask == null)
         return str + ";Free";
      else
         return str + ";Locked;" + perfTask.toString(withMachCandidates);
   }

   // used to transfer a running perftask on the mcahine from background
   // server to this server
   public void setPerfState(StringTokenizer tk)
   {
      if (! isPerfMachine()) return;

      // host = tk.nextToken(); host name has been skipped by caller
      isAvailable = (new Boolean(tk.nextToken())).booleanValue();
      if (! isAvailable) {
         disabler = tk.nextToken();
         disableTime = Long.parseLong(tk.nextToken())*1000;
         disableInfo = tk.nextToken();
         } else {
            query_sysinfo();
         }

      // we don'have to inherit tasks if background server is off
      if (! dTMServer.isBgServerOn)
         return;
      
      String machState = tk.nextToken();
      if (machState.equals("Free"))       // no task on the machine
         return;

      perfTask = new PerfTask(this, tk);
   }

   public void appendPerfLog(boolean getLock, PerfTask ptask)
   {
      String msg = (new Date().toString())+"  "+ptask.owner();
      if (getLock) 
         msg += " got lock for "+ ptask.info();
      else
         msg += " released lock for "+ ptask.info();

      synchronized (logFile) {
         try {
            FileOutputStream sf = new FileOutputStream(logFile, true);
            new PrintStream(sf).println(msg);
            sf.close();
         }
         catch (IOException ioe) {
            LogWriter.log("Failed to write file: " + logFile);
         }
      }
   }
   
    public Map<String,String> query_loadd()
    {
        BufferedReader fromDaemon = null;
        Map<String,String> result = new HashMap<String,String>();


        Process ldPs = loaddProcess();
        if ( ldPs != null)
        {
            try { ldPs.exitValue(); }
            catch (IllegalThreadStateException e)
            {
                String msg = "PANIC: Load daemon installing process on "
                             + theName + " was hanging: Killed";
                LogWriter.log(msg);
                MailWriter m = new MailWriter(msg);
                m.write("Load daemon installing process on " + theName
                           + " did not finish over 10 seconds.");
                m.write("It was now forcedly killed by the dTM server.");
                m.write("Please verify if the machine is running properly and");
                m.write("if there is a load daemon running on the machine.");
                m.send();

                ldPs.destroy();
                loaddProcess(null);
                return null;
            }
            loaddProcess(null);
            // fall through if the installing process finished
        }

        Socket socket = null;
        try
        {
            InetSocketAddress isa =
            new InetSocketAddress(theName,dTMConfig.loadMonPort());
            socket = new Socket();
            try
            {  
                LogWriter.log(2, "Update idle for " + theName + ": about to connect");
                // Open the connection to the idle daemon
                socket.connect(isa,2000);
                LogWriter.log(3, "Connected: " + theName);

                // read() operation will only wait for 2 seconds
                int socktimeout = dTMConfig.loadMonTimeout() * 1000;
                socket.setSoTimeout(socktimeout);
            }
            catch ( ConnectException e )
            {
                socket.close();
                /*
                * Now we attempt to start the load daemon on the target machine
                */ 
                theLoaddStartCount++;
                if(theLoaddStartCount > 10){
                    server_disable("Failed to start load daemon");
                    LogWriter.log("Failed to start load daemon on " + theName);
                    loaddProcess(null);
                    return null;
                }
                String loaddcmd = dTMConfig.rsh() + " " + theName + " " +
                            dTMConfig.loadMonitor() + " -p " + dTMConfig.loadMonPort() +
                            " -f " + theWorkDir + " -s " + dTMConfig.sysInfo();
                LogWriter.log("Connection refused to " +  theName + ":"
                            + dTMConfig.loadMonPort() + ", "
                            + "starting load daemon on the machine: "
                            + loaddcmd);
                try 
                {
                    Process theProcess = Exec.exec(loaddcmd);
                    loaddProcess(theProcess);
                    BufferedReader  loaddcmd_error = new BufferedReader(
                        new InputStreamReader(theProcess.getErrorStream ()));
                    String ls_str;
                    if((ls_str = loaddcmd_error.readLine()) != null) {
                        throw new Exception(ls_str);
                    }
                }
                catch ( Exception f )
                {
                    String msg = "PANIC: dTM server cannot start installing "
                            + "load  daemon on " + theName;
                    LogWriter.log(msg, f);
                    MailWriter m = new MailWriter(msg);
                    m.write("The following command failed:");
                    m.write(loaddcmd);
                    m.write("Please verify if the machine is running properly and");
                    m.write("if there is a load daemon running on the machine.");
                    m.send();
                }
                loaddProcess(null);
                return null;
            }
            catch (UnknownHostException e)
            {
                socket.close();
                theStatus = false;
                String msg = "Unable to connect to " + theName + ":"
                  + dTMConfig.loadMonPort() 
                              + " UnknownHostException";
                LogWriter.log(msg);
                MailWriter mail = new MailWriter(msg);
                mail.write("TestMachineMonitor cannot check status for machine "
                           + theName + ".");
                mail.write("Please check if the machine is running properly.");
                mail.send();
                incErrorCount("Unable to connect");
                loaddProcess(null);
                return null;
            }
            catch (SocketTimeoutException e)
            {
                socket.close();
                theStatus = false;
                String msg = "Timeout connecting " + theName + ":"
                             + dTMConfig.loadMonPort()
                             + " SocketTimeoutException";
                LogWriter.log(msg);
                MailWriter mail = new MailWriter(msg);
                mail.write("TestMachineMonitor cannot check status for machine "
                           + theName + ".");
                mail.write("Please ckeck if the machine is running properly.");
                mail.send();
                incErrorCount("Timeout connecting");
                loaddProcess(null);
                return null;
            }catch (SocketException e)
            {
                socket.close();
                theStatus = false;
                String msg = "Connection reseted by " + theName + ":"
                             + dTMConfig.loadMonPort()
                             + " SocketException";
                LogWriter.log(msg);
                MailWriter mail = new MailWriter(msg);
                mail.write("TestMachineMonitor cannot check status for machine "
                           + theName + ".");
                mail.write("Please ckeck if the machine is running properly.");
                mail.send();
                incErrorCount("Connection reseted");
                loaddProcess(null);
                return null;
            }
            fromDaemon = new BufferedReader(
                            new InputStreamReader(socket.getInputStream()));

            String idle = fromDaemon.readLine();
            theStatus = true;
            try
            {
                String[] tokens = idle.split("&");
                for (String s : tokens) {
                    String[] key_val = s.split("=");
                    if(key_val.length == 2){
                        result.put(key_val[0].trim(), key_val[1].trim());
                    }else{
                        String[] load_vals = s.split(":");
                        if(load_vals.length == 3){
                            theIdlePercentage     = Integer.parseInt(load_vals[0]);
                            theDiskUsedPercentage = Integer.parseInt(load_vals[1]);
                            theSwapUsedPercentage = Integer.parseInt(load_vals[2]);
                        }
                    }
                }
            }
            
            
            catch ( NumberFormatException e )
            {
                LogWriter.log("Received bogus idle percentage from "
                        + theName + ": " + idle);
            }
        }
        catch (SocketTimeoutException e)
        {
            LogWriter.log("Timeout communicating with: " + theName + ":"
                        + dTMConfig.loadMonPort() 
                        + " while reading from socket");
        }
        catch (Exception e)   // Catch everything else
        {
            LogWriter.log("Error communicating " + theName + ":"
                        + dTMConfig.loadMonPort(), e);
        }
        finally
        {
            // Close the connection to the idle daemon and its I/O streams
            if ( socket != null )
            try { socket.close(); } catch(Exception e) {}
            if ( fromDaemon != null )
            try { fromDaemon.close(); } catch(Exception e) {}
        }
        
        theLoaddData = result;
        theLoaddStartCount = 0;
        return result;
    }
    
    public void query_sysinfo(){
        Map<String,String> result = new HashMap<String,String>();
        
        String sysinfocmd = dTMConfig.rsh() + " " + theName + " " +
                    dTMConfig.sysInfo();
        try 
        {
            Process theProcess = Exec.exec(sysinfocmd);
            if (theProcess.waitFor() == 0){
                BufferedReader  sysinfo_output = new BufferedReader (
                            new InputStreamReader(theProcess.getInputStream()));
                String ls_str;
                while((ls_str = sysinfo_output.readLine()) != null) {
                    String[] key_val = ls_str.split("=");
                    if(key_val.length == 2){
                        result.put(key_val[0].trim(), key_val[1].trim());
                    }
                }
            }else{
                BufferedReader  sysinfo_output = new BufferedReader (
                            new InputStreamReader(theProcess.getErrorStream()));
                LogWriter.log("unable to run " + sysinfocmd + 
                    "\n" + sysinfo_output.readLine());
                server_disable("Failed to run sysinfo");
                return;
            }
        }
        catch ( Exception f )
        {
            String msg = "dTM server cannot read sysinfo, machine will disable "
                     + theName;
            LogWriter.log(msg, f);
            MailWriter m = new MailWriter(msg);
            m.write("The following command failed:");
            m.write(sysinfocmd);
            m.write("Please verify if the machine is running properly");
            m.send();
            server_disable("error while reading sysinfo");
            return;
        }
        theLoaddData = result;
    }
}
