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
import java.text.SimpleDateFormat;

// Watchdog Timer class
public class WatchdogTimer
{
   private Date   theTimer;
   private Thread theThread;
   final private String threadName;
   final private int downTime;  // in second. interval time to determine its down
   final private int killTime;  // in second. interval time to kill the thread

   private static  SimpleDateFormat hourFormatter = new SimpleDateFormat("HH");
 
   WatchdogTimer(int down, int kill, Thread thread, String name)
   {
      theTimer = new Date();
      theThread = thread;
      threadName = name;
      downTime = down;
      killTime = kill;
   } 

   public int getHour()
   {
      String hourStr = hourFormatter.format(theTimer);
      return Integer.parseInt(hourStr);
   }
  
   public boolean isTimeOut()
   {
      long curtime = new Date().getTime();
      long timeDiff = (int)((curtime - theTimer.getTime())/1000);
      if (downTime <= 0) {
         LogWriter.log("Wrong usage of WatchdogTimer for "+threadName);
      }
      return (timeDiff >= downTime);
   }

   public void update()
   {
      theTimer = new Date();
   } 

   public boolean isRunning() 
   {
      long curtime = new Date().getTime();
      long timeDiff = (int)((curtime - theTimer.getTime())/1000);
      if (timeDiff >= downTime) {
         if (theThread == null) {
            return false;
         }
         boolean alive = theThread.isAlive();
         String status = alive? "alive": "die";
         LogWriter.log("Thread "+threadName+" hanging about "
                        + timeDiff + " seconds: " + status);
         // theThread.dumpStack();
         if (killTime > 0 && timeDiff >= killTime) {
            LogWriter.log("Killing thread: " + threadName);
            theThread.stop();
            try { Thread.sleep(1000); }  // wait for a second
            catch (InterruptedException e) {}
            theThread = null;
            return false;
         }
      }
      return true;
   }
}

