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
import java.text.SimpleDateFormat;
import java.io.*;
import java.lang.*;
import java.net.*;

class LogWriter
{
   static private PrintWriter thePrintWriter = new PrintWriter(System.out);
   static private PrintWriter theErrWriter = new PrintWriter(System.err);
   static public boolean withFormatedDate = true;

   public static void initOutputStream(OutputStream output)
   {
      thePrintWriter = new PrintWriter(output);
   }

   // debugLevel==0,  no debug info
   // debugLevel==1,  simple trace info
   // debugLevel==2,  verbose trace info
   // debugLevel==3,  detailed status/action info
   static private int debugLevel = 0;
   
   public static int debugLevel() { return debugLevel; }
   public static void debugLevel(int dbgLevel) { debugLevel = dbgLevel; }
    
   static SimpleDateFormat dateFormatter =
                    new SimpleDateFormat("[EEE MMM d HH:mm:ss yyyy z] ");
   static String currentDate = "None";

   static String formattedDate()
   {
      Date date = new Date();
      return dateFormatter.format(date);
   }
 
   public static void log(String string)
   {
      if (withFormatedDate)
         thePrintWriter.println(formattedDate() + string);
      else
         thePrintWriter.println(string);
      thePrintWriter.flush();
   }
   
   public static void log(Exception e)
   {
      e.printStackTrace(theErrWriter);
      theErrWriter.flush();
   }
  
   public static void log(String string, Exception e)
   {
      log(string);
      log(e);
   }
  
   public static void log(Object o)
   {
      log(o.toString());
   }
  
   public static void log(String s, Object o)
   { 
      log(s + "\n\t" + o.toString());
   }

   public static void log(int dbgLevel, String s)
   { 
      if (dbgLevel <= debugLevel)
         log(s);
   }

   public static void log(int dbgLevel, String s, Object o)
   { 
      if (dbgLevel <= debugLevel)
         log(s + "\n\t" + o.toString());
   }

}
