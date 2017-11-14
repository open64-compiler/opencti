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

public class User
{
   private String theUserName;
   private Pool   theDefaultPool;
   private Vector theTaskGroupList;
  
   static private Hashtable usersQueue = new Hashtable();
 
   public String name()          { return theUserName; }
   public Pool defaultPool()     { return theDefaultPool; }
   public Vector taskGroupList() { return theTaskGroupList; }
   
   public User(String name, int priority, Pool defPool)
   {
      theUserName = name;
      theDefaultPool = defPool;
      theTaskGroupList = new Vector();
      usersQueue.put(name, this);
   }

   public synchronized void addTaskGroup(TaskGroup group)
   {
      theTaskGroupList.addElement(group);
   }
  
   public synchronized void removeTaskGroup(TaskGroup group)
   {
      theTaskGroupList.removeElement(group);
   }
 
   static public User get(String userName)
   {
      return (User)usersQueue.get(userName);
   }

   static public String printUserList()
   {
      StringBuffer buf = new StringBuffer();
      int count = 0;
      for ( Enumeration e = usersQueue.elements();
            e.hasMoreElements(); )
      {
         User u = (User)e.nextElement();
         if ( u.taskGroupList().isEmpty() )
            continue;
         buf.append(":" + u.name());
         ++count;
      }
      return count + buf.toString();
   }

   public String printUserState()
   {
      StringBuffer buf = new StringBuffer();
      buf.append(name());
      for ( Enumeration e = taskGroupList().elements();
            e.hasMoreElements(); )
      {
         TaskGroup g = (TaskGroup)e.nextElement();
         buf.append("%" + g.printState());
      }
      return buf.toString();
   }
}

