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

class TestMachineMonitor extends Thread
{
    static boolean stop = false;
    static WatchdogTimer watchDogTimer;
    static TestMachineMonitor testMachineMonitor;

    final static long DownTime = 600000;    // 10 minutes
    final static long SleepTime = 10000;    // 10 seconds

    public TestMachineMonitor()
    {
        testMachineMonitor = this;
        watchDogTimer = new WatchdogTimer(60, 300, this, "TestMachineMonitor");
        this.setDaemon(true);
    }

    public static void createAndRun() 
    {
        LogWriter.log("TestMachineMonitor started");
        testMachineMonitor = new TestMachineMonitor();
        testMachineMonitor.start();
    }
    public static boolean isRunning() { return watchDogTimer.isRunning(); }
    public static void pleaseStop()   { stop = true; }

    public void run()
    {
        while ( !stop )
        {
            // check out every machine on the list
            for ( Enumeration e = TestMachine.allMachines.elements();
                        e.hasMoreElements(); )
            {
                TestMachine mach = (TestMachine)e.nextElement();

                // update watchdog timer
                watchDogTimer.update();

                // if a machine is disabled, we don't need to query it.
                // However we still check machines that were down, hope
                // we can pick it up automaticly.
                if ( mach.available() )
                {
                    // call machine to update load itself
                   mach.query_loadd();
                   //LogWriter.log(mach.printToStr());
                }

                // for a machine being disabled automatically due to reaching
                // max error count, we enable it after a period of time.
                //
                if (! mach.available() && mach.reachMaxErrorCount())
                {
                   long curTime = new Date().getTime();
                   if (curTime - mach.lastFailTime() > DownTime) 
                    {
                      mach.enable();
                      LogWriter.log("After " + DownTime/60000 + " minutes, "
                                + mach.name() + " ENABLED."); 
                    }
                }
            }

            // wait for 10 seconds to go another cycle
            try { sleep(SleepTime); }
            catch ( InterruptedException e ) {}
        }
        LogWriter.log("TestMachineMonitor stopped.");
    }

    public static void dTMdirectoryCleanUp()
    { 
        for ( Enumeration e = TestMachine.allMachines.elements();
            e.hasMoreElements(); )
        {
            TestMachine mach = (TestMachine)e.nextElement();
         
            //  Usage: clean_by_day -days=N dir ... [-keep=file] [-REMV]
            String cmd = dTMConfig.rsh() + " " + mach.name() + " "
                        + dTMConfig.dtmHomeDir() + "/bin/cleanup_by_day.pl "
                        + "-days=5 " + mach.workDir() + " -REMV";
            try {
                Exec.exec(cmd);
            }
            catch ( Exception ex ) {
                LogWriter.log("Cleanup exception", ex);
            }
        }
    }
}

