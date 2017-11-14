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
 
public class Listener extends Thread 
{
   ServerSocket listenSocket;
   int port;
   boolean stop = false;
      
   public Listener(ThreadGroup group, int port) throws IOException
   {
      super(group,"Listener: " + port);
      listenSocket = new ServerSocket(port);
      listenSocket.setSoTimeout(3600000); // 60 minutes
      this.port = port;
   }
   
   /* This stops the Listener from accepting any further
    * connections
    */
   public void pleaseStop() {
      this.stop = true;  // set the stop flag
      this.interrupt();  // make the accept() call stop blocking
   }
   
   /*
    * Switches the listener over to a different port.
    * We create a new server socket, assign it to the
    * local socket and then close the current one, which
    * will cause an IOException to be received at the
    * call to accept() in Listener::run().
    */
   public void switchSocket(int port)
   {
      ServerSocket oldSS = listenSocket;
      try 
      {
         listenSocket = new ServerSocket(port);
         oldSS.close();
      }
      catch (IOException e) { LogWriter.log(e); }
   }
            
   /*
    * Since Listener is a thread, here is its body.  It simply
    * accepts the connection and sends it to the connection manager
    */
   public void run()
   {
      while (!stop) 
      {
         try
         {
            Socket socket = listenSocket.accept();
            Connection conn = new Connection(socket);
            RequestManager server = new RequestManager(conn);
            server.start();
         }
         catch (SocketTimeoutException e)
         {
            LogWriter.log("Accept 60 minutes timeout.");
         }
         catch (Exception e)
         {
            LogWriter.log("Unexpected exception with accept", e);
         }
      }
   }
}
   
