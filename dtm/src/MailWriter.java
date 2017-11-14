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
import java.lang.*;
import java.net.*;

class MailWriter {

   String theReceiver;
   String theSubject;
   ArrayList theMessages;
   boolean isNew;

   static Random randGen = new Random();
   static Hashtable SubjectTime = new Hashtable();

   final static long DURATION = 3 * 3600 * 1000; // 3 hours

   public MailWriter(String subject) 
   {
      // default receiver is ctiguru
      theReceiver = "ctiguru";
      theSubject = subject;
      long curTime = new Date().getTime();
      Long oldTime = (Long)SubjectTime.get(subject);

      if (oldTime == null || (curTime-oldTime.longValue() > DURATION)) {
         isNew = true;
         theMessages = new ArrayList();
         SubjectTime.put(subject, new Long(curTime));
      }
      else {
         isNew = false;
         theMessages = null;
      }
   }

   public MailWriter(String receiver, String subject) 
   {
      theReceiver = receiver;
      theSubject = subject;
      long curTime = new Date().getTime();
      Long oldTime = (Long)SubjectTime.get(subject);

      if (oldTime == null || (curTime-oldTime.longValue() > DURATION)) {
         isNew = true;
         theMessages = new ArrayList();
         SubjectTime.put(subject, new Long(curTime));
      }
      else {
         isNew = false;
         theMessages = null;
      }
   }

   public MailWriter(int a, String receiver, String subject) 
   {
      theReceiver = receiver;
      theSubject = subject;
      isNew = true;
      theMessages = new ArrayList();
   }

   public void write(String msg) { if (isNew) theMessages.add(msg); }
   public void send()            { send(theReceiver); }

   public void send(String receiver)
   {
      if (! isNew)
         return;

      // default receiver is ctiguru
      if (receiver == null || receiver.equals("")) 
         receiver = "ctiguru";

      String cmd;
      try
      {
         String file = "/tmp/dTM.mail" + randGen.nextInt();
         PrintStream ps = new PrintStream(new FileOutputStream(file));
         for ( Iterator e = theMessages.iterator();
               e.hasNext(); )
         {
            ps.println((String)e.next());
         }
         ps.println();
         ps.println("The mail was sent by the dTM server on "
                    + dTMConfig.serverHost());
         ps.close();
         cmd = "cat " + file ;  
         cmd += " | mailx -s \"" + theSubject + "\" " + receiver;
         Exec.exec(cmd);
      }
      catch( Exception e ) { LogWriter.log(e); }
   }

}
