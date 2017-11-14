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

//
// We are getting "too many open files" problem quite often because
// of heavy use of dTM by all teams. Looks like if a
// Java app does a lot of Runtime.exec()s, without GC, the file
// descriptors may be lingering there. So we need to clean them 
// up with GC explicitly before reaching the max number of FDs.
//
// Unfortunately, a solution that invokes GC on as needed basis does
// not work, because there is no way to tell if a GC is executing and
// finished. In stead, we count the number of exec()s; when it reaches
// the threshold, which is 200, we launch a GC. 
//
//

public class Exec
{
   static private int count = 0;
   static private String eStr = "Too many open files";

   static public synchronized Process exec(String command) throws Exception
   {
      // for every 200 exec()'s, we fire off a GC
      if (++count > 200) {
         count = 0;
         System.gc();
      }

      try {
         Process p = Runtime.getRuntime().exec(command);
         return p;
      }
      catch(Exception e) {
         if (e.toString().indexOf(eStr) != -1) {
            // "Too many open files" exception, fire off a GC
            System.gc();
            LogWriter.log("Too many open files: cleaning up for " + command);
            // wait for a minute for gc to finish hopefully
            try { Thread.sleep(1000); }
            catch ( InterruptedException et ) {}

            int exception_count = 1;
            while (true) {
               try {
                  Process p = Runtime.getRuntime().exec(command);
                  LogWriter.log("Too many open files exception count = "
                                + exception_count + " for " + command);
                  return p;
               }
               catch(Exception ioe) {
                  e = ioe;
                  ++exception_count;
                  if (e.toString().indexOf(eStr) != -1) {
                     System.gc();
                     try { Thread.sleep(1000); }
                     catch ( InterruptedException et ) {}
                  }
                  else {
                     // other exceptions, escalate it.
                     LogWriter.log(e.toString() + 
                                   "  TMOF count = " + exception_count);
                     throw e;
                  }
               }
            }
         }
         else {
            // other exceptions, escalate it.
            throw e;
         }
      }
   }
}

