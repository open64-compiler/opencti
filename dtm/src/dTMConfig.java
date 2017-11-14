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
import java.io.*;
import java.util.*;
import java.net.*;

import javax.xml.parsers.DocumentBuilder; 
import javax.xml.parsers.DocumentBuilderFactory;  
import javax.xml.parsers.FactoryConfigurationError;  
import javax.xml.parsers.ParserConfigurationException;
 
import org.xml.sax.SAXException;  
import org.xml.sax.SAXParseException;  
import org.w3c.dom.Document;
import org.w3c.dom.DOMException;
import org.w3c.dom.*;


public class dTMConfig
{
   static String theConfigFile;
   static boolean verify = false;

   static private int    theCurrentPort   = -1;
   static private int    theServerPort    = -1;
   static private int    theAuxServerPort = -1;
   static private String theServerHost    = null;
   static private String theLoadMonitor   = null;
   static private int    theLoadMonPort   = 5010;
   static private int    theLoadMonTimeout= 10;
   static private String theSysInfo       = null;
   static private String theDtmHomeDir    = null;
   static private String theDtmServerLog  = null;
   static private String theDtmServerErrorLog  = null;
   static private String theRsh           = null;
   static private String theAdministrator = null;
   static private String theWebAccount    = null;
   static private String theDefWorkDir    = null;
   static private Vector<String> theDefServices = new Vector<String>();
   static private String machineStateFile = null;
   static private String perfStateFile    = null;

   static public void currentPort(int port) { theCurrentPort = port; }
   static public int  currentPort()     { return theCurrentPort; }
   static public int  serverPort()      { return theServerPort; }
   static public int  auxServerPort()   { return theAuxServerPort; }
   static public String serverHost()    { return theServerHost; }
   static public String loadMonitor()   { return theLoadMonitor;  }
   static public int  loadMonPort()     { return theLoadMonPort; }
   static public int  loadMonTimeout()  { return theLoadMonTimeout; }
   static public String sysInfo()       { return theSysInfo;  }
   static public String dtmHomeDir()    { return theDtmHomeDir; }
   static public String dtmServerLog()       { return theDtmServerLog; }
   static public String dtmServerErrorLog()  { return theDtmServerErrorLog; }
   static public String rsh()           { return theRsh; }
   static public String admin()         { return theAdministrator; }
   static public String webAccount()    { return theWebAccount; }
   static public String defWorkDir()    { return theDefWorkDir; }
   static public Vector<String> defservices() { return theDefServices; }
   static public String stateFile()     { return machineStateFile; }
   static public String perfStateFile() { return perfStateFile; }

   public static Document readConfig(String configFile)
   {
      Document cf = null;
      // Use the default validating parser
      DocumentBuilderFactory factory =
            DocumentBuilderFactory.newInstance();
      factory.setValidating(true);
      try {
         // Parse the input
         DocumentBuilder builder = factory.newDocumentBuilder();
         builder.setErrorHandler(
            new org.xml.sax.ErrorHandler() {
                  // ignore fatal errors (an exception is guaranteed)
                  public void fatalError(SAXParseException exception)
                     throws SAXException
                  { }

                  // treat validation errors as fatal
                  public void error(SAXParseException e)
                     throws SAXParseException
                  { throw e; }

                  // dump warnings too
                  public void warning(SAXParseException err)
                     throws SAXParseException
                  {
                     LogWriter.log("** Warning"
                                    + ",line " + err.getLineNumber()
                                    + ", uri " + err.getSystemId());
                     LogWriter.log("   " + err.getMessage());
                  }
               }
            );
         cf = builder.parse(configFile);
      } catch (SAXParseException spe) {
         // Error generated by the parser
         LogWriter.log("\n** Parsing error"
                            + ", line " + spe.getLineNumber()
                            + ", uri " + spe.getSystemId());
         LogWriter.log("   " + spe.getMessage() );

         // Use the contained exception, if any
         Exception  x = spe;
         if (spe.getException() != null)
            x = spe.getException();

      } catch (SAXException sxe) {
         // Error generated by this application
         // (or a parser-initialization error)
         Exception  x = sxe;
         if (sxe.getException() != null)
            x = sxe.getException();
      } catch (ParserConfigurationException pce) {
         // Parser with specified options can't be built
         pce.printStackTrace();

      } catch (IOException ioe) {
         // I/O error
         ioe.printStackTrace();
      }
      return cf;
   }

   static public void printNode(Node node, int level)
   {
      int type = node.getNodeType();
      for ( int i = 0; i < level; i++ )
      {
         LogWriter.log(" ");
      }
      switch ( type )
      {
         case Node.ELEMENT_NODE:
            LogWriter.log("<" + node.getNodeName() + ">\n");
            break;
         case Node.TEXT_NODE:
            LogWriter.log("<" + node.getNodeName() + "> "
                           + node.getNodeValue());
            break;
         case Node.ATTRIBUTE_NODE:
         default:
            LogWriter.log("Type = " + type);
      }
   }
   
   static public void printDom(Node node, int level)
   {
      printNode(node,level);
      if ( node.hasChildNodes() ) 
      {
         NodeList children = node.getChildNodes();
         for ( int i = 0; i < children.getLength(); i++ )
         {
            printDom(children.item(i),level+1);
         }
      }
   }

   private static void serverConfig(Node serverNode)
   {
      if ( serverNode.hasChildNodes() )
      {
         NodeList nodeList = serverNode.getChildNodes();
         for ( int i = 0; i < nodeList.getLength(); i++ )
         {
            Node node = nodeList.item(i);
            int type = node.getNodeType();
            if ( type == Node.ELEMENT_NODE )
            {
               String nodeName = node.getNodeName();
               Node childNode = node.getFirstChild();
               if ( nodeName.equals("host") )
               {
                  theServerHost = childNode.getNodeValue();
                  if ( verify ) {
                     LogWriter.log("Creating server " + theServerHost);
                  }
               }
               else if ( nodeName.equals("port") )
               {
                  theServerPort = Integer.parseInt(childNode.getNodeValue());
               }
               else if ( nodeName.equals("auxport") )
               {
                  theAuxServerPort = Integer.parseInt(childNode.getNodeValue());
               }
               else if ( nodeName.equals("loadmonitor") )
               {
                  theLoadMonitor = childNode.getNodeValue();
                  theLoadMonitor = theDtmHomeDir + "/bin/" + theLoadMonitor;
               }
               else if ( nodeName.equals("loadmonport") )
               {
                  theLoadMonPort = Integer.parseInt(childNode.getNodeValue());
               }
               else if ( nodeName.equals("loadmontimeout") )
               {
                  theLoadMonTimeout = Integer.parseInt(childNode.getNodeValue());
               }
               else if( nodeName.equals("sysinfo") )
                {
                  theSysInfo = childNode.getNodeValue();
                  theSysInfo = theDtmHomeDir + "/bin/" + theSysInfo;
               }
               else if ( nodeName.equals("dtmhome") )
               {
                  theDtmHomeDir = childNode.getNodeValue();
                  machineStateFile = theDtmHomeDir + "/log/TestMachineState.log";
                  perfStateFile = theDtmHomeDir + "/log/PerfMachineState.log";
               }
               else if ( nodeName.equals("rsh") )
               {
                  theRsh = childNode.getNodeValue();
                   }
               else if ( nodeName.equals("admin") )
               {
                  theAdministrator = childNode.getNodeValue();
                   }
               else if ( nodeName.equals("webaccount") )
               {
                  theWebAccount = childNode.getNodeValue();
                   }
               else if ( nodeName.equals("defworkdir") )
               {
                  theDefWorkDir = childNode.getNodeValue();
                   }
               else if ( nodeName.equals("defservice") )
               {
                  theDefServices.addElement(childNode.getNodeValue());
               }
               else if ( nodeName.equals("log") )
               {
                      theDtmServerLog  = childNode.getNodeValue();
                   }
               else if ( nodeName.equals("errorlog") )
               {
                  theDtmServerErrorLog  = childNode.getNodeValue();
               }
               else if ( nodeName.equals("launchgroupcount") )
               {
                  TaskScheduler.setLaunchCount(Integer.parseInt(childNode.getNodeValue()));
               }
               else if ( nodeName.equals("launchgroupwait") )
               {
                  TaskScheduler.setLaunchWait(Integer.parseInt(childNode.getNodeValue()));
               }
               else
               {
                  LogWriter.log("Unknown field for server: " + nodeName);
               }
            }
         }
      }
   }
   
   private static void machineConfig(Node machineNode)
   {
      String host = "";
      String osys = "";
      String arch = "";
      String impl = "";
      int    freq = -1;
      int    cpus = -1;
      String workdir = theDefWorkDir;
      Vector<String> services = new Vector<String>();
      if ( machineNode.hasChildNodes() )
      {
         NodeList nodeList = machineNode.getChildNodes();
         for ( int i = 0; i < nodeList.getLength(); i++ )
         {
            Node node = nodeList.item(i);
            int type = node.getNodeType();
            if ( type == Node.ELEMENT_NODE )
            {
               String nodeName = node.getNodeName();
               Node childNode = node.getFirstChild();
               String nodeString = "";
               if(childNode != null)
                    nodeString = childNode.getNodeValue();
               if ( nodeName.equals("host") )
               {
                  host = nodeString;
                  if ( verify ) {
                     LogWriter.log("Creating machine " + host);
                  }
               }
               else if ( nodeName.equals("arch") )
               {
                  arch = nodeString;
               }
               else if ( nodeName.equals("os") )
               {
                  osys = nodeString;
               }
               else if ( nodeName.equals("impl") )
               {
                  impl = nodeString;
               }
               else if ( nodeName.equals("freq") )
               {
                  try 
                  {
                        if(nodeString == "")
                            freq = 0;
                        else
                            freq = Integer.parseInt(nodeString);
                  }
                  catch (Exception e)
                  {
                     LogWriter.log("Frequency should be an integer (in MHz): "
                                   + nodeString);
                     System.exit(1);
                  }
               }
               else if ( nodeName.equals("cpus") )
               {
                  try 
                  {
                    if(nodeString == "")
                        cpus = 0;
                    else
                        cpus = Integer.parseInt(nodeString);
                  }
                  catch (Exception e)
                  {
                     LogWriter.log("Number of CPUs should be an integer (in MHz): "
                                   + nodeString);
                     System.exit(1);
                  }
               }
               else if ( nodeName.equals("workdir") )
               {
                  workdir = nodeString;
               }
               else if ( nodeName.equals("service") )
               {
                  services.addElement(nodeString);
               }
            }
         }
         if ( TestMachine.get(host) != null )
         {
            LogWriter.log("Machine \"" + host + "\" defined more than once.");
            System.exit(1);
         }
         if (services.isEmpty())
             services = theDefServices;
         // Add to the machine list
         new TestMachine(host,osys,arch,impl,freq,cpus,workdir,services);
      }
   }
   
   private static void poolConfig(Node poolNode)
      throws Exception
   {
      String name = null;
      Vector<TestMachine> machineVector = new Vector<TestMachine>();
      if ( poolNode.hasChildNodes() )
      {
         NodeList nodeList = poolNode.getChildNodes();
         for ( int i = 0; i < nodeList.getLength(); i++ )
         {
            Node node = nodeList.item(i);
            int type = node.getNodeType();
            if ( type == Node.ELEMENT_NODE )
            {
               String nodeName = node.getNodeName();
               if ( nodeName.equals("name") )
               {
                  Node nameNode = node.getFirstChild();
                  name = nameNode.getNodeValue();
                  if ( verify )
                  {
                     LogWriter.log("Creating pool " + name);
                  }
               }
               if ( nodeName.equals("host") )
               {
                  Node hostNode = node.getFirstChild();
                  String host = hostNode.getNodeValue();
                  TestMachine mach = TestMachine.get(host);
                  if ( mach == null )
                  {
// TODO: if host not in TestMachine then request loadd for machine info
                     // throw new Exception("Pool \"" + name
                        // + "\" references unknown machine \"" + host + "\".");
                      String osys = "";
                      String arch = "";
                      String impl = "";
                      int    freq = -1;
                      int    cpus = -1;
                      String workdir = "";
                      mach = new TestMachine(host,osys,arch,impl,freq,cpus,theDefWorkDir,theDefServices);
                  }
                  machineVector.addElement(mach);
               }
            }
         }
         if ( Pool.get(name) != null )
         {
            throw new Exception(
               "Machine Pool \"" + name + "\" defined more than once.");
         }
         Pool pool = new Pool(name,machineVector);
      }
   }
   
   private static void userConfig(Node userNode)
      throws Exception
   {
      String name = "";
      Pool defaultPool = null;
      int priority = 0;
      if ( userNode.hasChildNodes() )
      {
         NodeList nodeList = userNode.getChildNodes();
         for ( int i = 0; i < nodeList.getLength(); i++ )
         {
            Node node = nodeList.item(i);
            int type = node.getNodeType();
            if ( type == Node.ELEMENT_NODE )
            {
               String nodeName = node.getNodeName();
               if ( nodeName.equals("name") )
               {
                  Node nameNode = node.getFirstChild();
                  name = nameNode.getNodeValue();
                  if ( verify )
                  {
                     LogWriter.log("Creating user " + name);
                  }
               }
               else if ( nodeName.equals("mpool") )
               {
                  Node poolNode = node.getFirstChild();
                  String poolName = poolNode.getNodeValue();
                  defaultPool = Pool.get(poolName);
                  if ( defaultPool == null )
                  {
                     throw new Exception(
                        "User \"" + name + "\" references unknown pool \"" +
                        poolName + "\".");
                  }
               }
               else if ( nodeName.equals("priority") )
               {
                  Node priorityNode = node.getFirstChild();
                  priority = Integer.parseInt(priorityNode.getNodeValue());
               }
            }
         }
         if ( User.get(name) != null )
         {
            throw new Exception(
               "User \"" + name + "\" defined more than once.");
         }
         User user = new User(name,priority,defaultPool);
      }
   }
  
 
   static public void initConfigWithEH(String configFile)
   {
      theConfigFile = configFile;
      initConfigWithEH();
   }

   static public void initConfigWithEH()
   {
      boolean wasException = false;
      try
      {
         initConfig();
      }
      catch (Exception e)
      {
         LogWriter.log("Configuration (re)initialization failed!");
         LogWriter.log(e);
         wasException = true;
         System.exit(1);
      }
      if ( TestMachine.countMachines() == 0 )
      {
         LogWriter.log("Number of test machines = 0");
         System.exit(1);
      }
      else
      {
         // Is the server running on the correct machine?
         String localHost = "";
         try
         {
           // InetAddress localAddress = InetAddress.getLocalHost();
            //localHost = localAddress.getHostName();
            
            InetAddress localAddress = InetAddress.getLocalHost();
            InetAddress localAddress2 = InetAddress.getByName(localAddress.getHostAddress());
            localHost = localAddress2.getHostName();
         }
         catch (UnknownHostException e)
         {
            localHost = "Unknown";
         }
         if ( !serverHost().equals(localHost) )
         {
            LogWriter.log("Configured host (" + serverHost()
                          + ") does not match current host: "
                          + localHost);
            System.exit(1);
         }
      }
   }

   public static void initConfig(String configFile)
       throws Exception
   {
      theConfigFile = configFile;
      initConfig();
   }

   public static void initConfig()
       throws Exception
   {
      Document cf = readConfig(theConfigFile);
      NodeList configElems = cf.getElementsByTagName("dTM");
      Node dTMNode = configElems.item(0);
      if ( dTMNode.hasChildNodes() )
      {
         NodeList nodeList = dTMNode.getChildNodes();
         for ( int i = 0; i < nodeList.getLength(); i++ )
         {
            Node node = nodeList.item(i);
            int type = node.getNodeType();
            if ( type == Node.ELEMENT_NODE ) 
            {
               String nodeName = node.getNodeName();
               if ( nodeName.equals("server") )
                  serverConfig(node);
               else if ( nodeName.equals("machine") )
                  machineConfig(node);
               else if ( nodeName.equals("pool") )
                  poolConfig(node);
               else if ( nodeName.equals("user") )
                  userConfig(node);
            }
         }
      }
   }
   
   
   public static void main (String argv [])
   {
      if (argv.length != 1) {
         System.out.println("Usage: java dTMConfig config_file");
         System.exit(1);
      }
      verify = true;
      LogWriter.withFormatedDate = false;

      initConfigWithEH(argv[0]);
      System.out.println();
      System.out.println("Config file "+argv[0]+" is validated.");
      System.exit(0);
   }
}

