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

class Connection
{
   private Socket theSocket;
   private String theHostAndPort;
   private BufferedReader from;
   private PrintWriter to;

   static boolean debug = false;

   Connection(Socket socket)
   {
      theSocket = socket;
      theHostAndPort = theSocket.getInetAddress().getHostName()
                       + ":" + theSocket.getPort();
      try {
         from = new BufferedReader(
                    new InputStreamReader(socket.getInputStream()));
         to = new PrintWriter(
                  new OutputStreamWriter(socket.getOutputStream()),true);
      }
      catch (IOException e) {
         LogWriter.log("Socket Buffer Error: " + theHostAndPort, e);
      }
      if (debug)
         LogWriter.log(1, "Connected to " + theHostAndPort);
   }

   public void close()
   {
      if (theSocket == null)
         return;

      try { theSocket.close(); }
      catch (Exception e) { LogWriter.log(e); }
      theSocket = null;
      if (debug)
         LogWriter.log(1, "Connection to " + theHostAndPort + " closed");
      if (from != null) {
         try { from.close(); } catch(Exception e) {}
      }
      if (to != null) {
         try { to.close(); } catch(Exception e) {}
      }
   }

   public boolean isConnected()
   {
      if (theSocket == null)
         return false;
      else
         return theSocket.isConnected();
   }

   static final String delimit = "%";
   
   void send(String msg)
   {
      to.println(msg);
      to.flush();
      return;
   }

   String getNextMessage(Vector decodeVector)
   {
      try {
         String msg = from.readLine();
         if (msg == null || msg.length() == 0) 
            return null;

         LogWriter.log(1, "Got: " + msg);
         StringTokenizer tk = new StringTokenizer(msg, delimit);
         String msgHeader = tk.nextToken();

         decodeVector.removeAllElements();  
         while ( tk.hasMoreTokens() )
         {
            decodeVector.addElement(tk.nextToken());
         }
         return msgHeader;
      }
      catch ( IOException e )
      {
         LogWriter.log("getNextMessage: "+e.toString()+" "+theHostAndPort);
         close();
         return null;
      }  
   }
   
   void send(String msg, Object one)
   {
      send(msg + delimit + one);
   }

   void send(String msg, int o1, int o2)
   {
      send(msg + delimit + o1 + delimit + o2);
   }

   void send(String msg, Object o1, Object o2)
   {
      send(msg + delimit + o1 + delimit + o2);
   }

   void send(String msg, Vector args)
   {
      StringBuffer buf = new StringBuffer(msg);
      for (Iterator it = args.iterator(); it.hasNext(); )
      {
         buf.append( delimit + (String)it.next() );
      }
      send(buf.toString());
   }
}
