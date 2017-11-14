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
import java.net.*;
import java.io.*;
import java.util.*;

public class dTMServer extends Thread 
{
   static ThreadGroup threadGroup;
   static final int SleepTime = 10000;   // 10 seconds
   static final int DownTime = 60000;    // 1 minute
   static final int KillTime = 300000;   // 5 minutes
   static final int LogCycleTime = 3600;   // in second, 1 hour
   static String theConfigFile;
   static int count = 0;
   static boolean stop = false;
   static boolean isBgServerOn = true;
   
   // The connections to the user clients
   static Listener listener;
 
   static public void pleaseStop() { stop = true; }

   public dTMServer(String configFile)
   {
      if (++count > 1)
      {
         LogWriter.log("Can't create more than one server object");
         System.exit(1);
      }

      // read in dTM_conf.xml configuration file
      theConfigFile = configFile;
      LogWriter.log("Config file: " + theConfigFile);
      dTMConfig.initConfigWithEH(configFile);
      dTMConfig.currentPort(dTMConfig.serverPort());
      LogWriter.log("The dTM server host: " + dTMConfig.serverHost());
      LogWriter.log("Current Port: " + dTMConfig.currentPort() 
                    + "  Aux Port: " + dTMConfig.auxServerPort());

      // create thread  group
      threadGroup = new ThreadGroup("dTMServer");
      this.setDaemon(true);

      // read in machine states from background server or a file
      Vector testMachineState = new Vector();
      Vector perfMachineState = new Vector();
      // Vector machineStatesVector = bgServerStatus();
      isBgServerOn = bgServerStatus(testMachineState, perfMachineState);
      if (isBgServerOn) {
         setMachineStates((String)testMachineState.get(0));
         LogWriter.log("Test machine states updated from background server.");
         if (perfMachineState.size() >= 3) {
            String min = (String)perfMachineState.get(0);
            String max = (String)perfMachineState.get(1);
            setPerfMachineStates((String)perfMachineState.get(2));
            LogWriter.log("Perf machine states updated from background server.");
            if (perfMachineState.size() >= 4) {
               setPerfTaskStates((String)perfMachineState.get(3));
               LogWriter.log("Performance task queue transtered from from background server.");
            }
            TaskGroup.setupMinMaxGid(min, max);
         }
      } else {
         LogWriter.log("No background server running."); 
         String machineStateStr = getFile(dTMConfig.stateFile());
         if (machineStateStr != null) {
            setMachineStates(machineStateStr);
            LogWriter.log("Test machine states updated from file "
                          + dTMConfig.stateFile());
         }
         if (Pool.perfPool != null) {
            String perfMachStateStr = getFile(dTMConfig.perfStateFile());
            if (perfMachStateStr != null) {
               setPerfMachineStates(perfMachStateStr);
               LogWriter.log("Perf machine states updated from file "
                             + dTMConfig.perfStateFile());
            }
         }
         // Comments this out for now, since, if I start a test server,
         // it can kill jobs launched by the normal server
         // Pool.killZombieProcesses();
      }

      // Start all active monitors
      TaskScheduler.createAndRun();
      TestMachineMonitor.createAndRun();
      PerfScheduler.createAndRun();

      try {
         listener = new Listener(threadGroup,dTMConfig.serverPort());
      } 
      catch (IOException e) 
      {
         LogWriter.log("Exception creating listener.", e);
      }
      listener.start();
      LogWriter.log("dTMServer listener started.");
   }

   // dTMSever monitors other active threads
   public void run()
   {
      WatchdogTimer msgTimer = new WatchdogTimer(LogCycleTime,
                                     0, this, "dTMServer");
      while (!stop) {
         try {
            // wait for a while
            try { sleep(SleepTime); }
            catch (InterruptedException e) {}

            // check each and every active thread
            if (! TaskScheduler.isRunning())
               TaskScheduler.createAndRun();
            if (! TestMachineMonitor.isRunning())
               TestMachineMonitor.createAndRun();
            if (! PerfScheduler.isRunning())
               PerfScheduler.createAndRun();

            // log dTMServer message once an hour
            if (msgTimer.isTimeOut()) {
               msgTimer.update();
               LogWriter.log("The dTMServer is alive.");

               // at some time after 2am, clean up local work dir /dTM
               if (msgTimer.getHour() == 2) {
                  TestMachineMonitor.dTMdirectoryCleanUp();

		  // recycle the server log and error log file
                  String cmd = dTMConfig.dtmHomeDir() + "/bin/recycle_logs.pl";
                  try {
                      Exec.exec(cmd);
                  }
                  catch (Exception ex) {
                      LogWriter.log("Failed to run: " + cmd, ex);
                  }
	       }
            }
         }
         catch (Exception e) {
            LogWriter.log(e.toString());
            e.printStackTrace();
         }
      }
   }

   public static void switchToBackground()
   {
     listener.switchSocket(dTMConfig.auxServerPort());
     dTMConfig.currentPort(dTMConfig.auxServerPort());
   }
   public static boolean isBackground()
   {
      return dTMConfig.currentPort() == dTMConfig.auxServerPort();
   }

   // bgServerStatus querys status of all machines from backgourd server.
   // This information is used to update machine states when starting
   // a new server. This way, the new (foreground) server inherits
   // machine states automatically.
   //
   public static Connection connectServer(int port) 
   {
      Socket socket = null;
      Connection conn = null;
      String host = dTMConfig.serverHost();
      // int port = dTMConfig.auxServerPort();
      try {
         // Open the connection to the the background server
         socket = new Socket();
         InetSocketAddress isa = new InetSocketAddress(host,port);
         socket.connect(isa,1000);
         // read() operation will only wait for 1 seconds
         socket.setSoTimeout(1000);
         conn = new Connection(socket);
         return conn;
      }
      catch (Exception e)
      {
         LogWriter.log("Exception occured connecting background server", e);
         if (socket != null)  {
            try { socket.close(); }
            catch (Exception se) { LogWriter.log(se); }
         } 
         return null;
      }
   }

   public static boolean bgServerStatus(Vector testMach, Vector perfMach)
   {
      Connection conn = connectServer(dTMConfig.auxServerPort());
      if (conn == null)
         return false;

      conn.send("DYNAMACHSTATE");
      String msg = conn.getNextMessage(testMach);
      LogWriter.log("bgServerStatus  "+msg+"  "+testMach);

      // get perf machine state and perf task queue
      if (msg.equals("PerfPool")) {
         conn.send("PERFSTATUS", "idlePerfScheduler");
         msg = conn.getNextMessage(perfMach);
         LogWriter.log("bgServerStatus2  "+msg+"  "+perfMach);
      }
      conn.close();
      return true;
   }

   public static boolean toBgServer(String cmd, Vector result)
   {
      if (! isBgServerOn || isBackground())
         return false;
      
      Connection conn = connectServer(dTMConfig.auxServerPort());
      if (conn == null)
         return false;
      
      conn.send(cmd);
      LogWriter.log(1, "toBgServer " + cmd);
      if (result == null) {
         // don't provide an array to store the result, who cares?
         conn.close();
         return true;
      }

      String msg = conn.getNextMessage(result);
      conn.close();
      LogWriter.log(1, "toBgServer "+cmd+"  "+msg+"  "+result);
      if (! msg.equals("PASS")) {
         LogWriter.log("FAILED: "+cmd+ "  "+result);
         return false;
      }
      return true;
   }

   // used to transfer in-queue perftasks from background server
   // to this server.
   static private void setPerfTaskStates(String mS)
   {
      LogWriter.log("PerfTaskState  ", mS);
      StringTokenizer qtk = new StringTokenizer(mS, "#");
      int tCount = Integer.parseInt(qtk.nextToken());
      while (qtk.hasMoreTokens()) {
         String taskStr = qtk.nextToken();
         StringTokenizer tk = new StringTokenizer(taskStr, ";");
         PerfTask ptask = new PerfTask(null, tk);
         ptask.enQueue();
      }
   }

   static private void setPerfMachineStates(String mS)
   {
      LogWriter.log("PerfMachineState  ", mS);
      StringTokenizer msTk = new StringTokenizer(mS, "#");
      int mCount = Integer.parseInt(msTk.nextToken());
      while (msTk.hasMoreTokens()) {
         String machStr = msTk.nextToken();
         StringTokenizer tk = new StringTokenizer(machStr, ";");
         TestMachine pmach = TestMachine.get(tk.nextToken());
         if (pmach != null)
            pmach.setPerfState(tk);
      }
   }
   static private void setMachineStates(String machineStates)
   {
      StringTokenizer msTk = new StringTokenizer(machineStates, "#");
      while (msTk.hasMoreTokens()) {
         String machStr = msTk.nextToken();
         StringTokenizer tk = new StringTokenizer(machStr, ":");
         TestMachine mach = TestMachine.get(tk.nextToken());
         if (mach != null)
            mach.setDynamicState(machStr);
      }
   }

   private static String getFile(String file)
   {
      try {
         FileInputStream sf = new FileInputStream(file);
         InputStreamReader reader = new InputStreamReader(sf);
         String contentStr = new BufferedReader(reader).readLine();
         sf.close();
         return contentStr;
      }
      catch (IOException ioe) {
         LogWriter.log("Can't open file: " + file);
         return null;
      }
   } 

   //
   // MAIN program
   // Here we simply process the command line arguments, load the
   // configuration file and start the client or server.
   //

   public static void main(String args[])
   {
      int i;
      String configFile = null;
      try {
         if ( args.length < 1 ) // Check number of arguments
            throw new IllegalArgumentException(
                         "Don't know which service to provide");
            
         for ( i = 0; i < args.length; i++ ) {
            if ( args[i].startsWith("-config") ) {
               int startIndex = args[i].indexOf('=') + 1;
               int endIndex = args[i].length();
               configFile = args[i].substring(startIndex,endIndex);
            }
            else if ( args[i].equals("-debug") ) { 
               LogWriter.debugLevel(1);
            }
            else
               throw new IllegalArgumentException("Unknown argument " + args[i]);
         }

         if ( configFile == null ) {
            throw new IllegalArgumentException("Please specify config file.");
         }
      }
      catch ( Exception e ) {
         System.err.println("dTM: " + e);
         System.err.println("Usage: dTM  -mode=[server|client] " +
                            "-config=<filename> [options]\n" +
                            "Options:\n" +
                            "            -debug\n");
         System.exit(1);
      }

      new dTMServer(configFile).start();
   }
}

