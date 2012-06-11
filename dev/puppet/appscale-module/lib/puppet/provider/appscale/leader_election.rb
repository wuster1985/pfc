# Leader election helper methods
class LeaderElection
   
   # Do not use attr_reader because your id and your leader's id might change
   # during execution. The only thing that should not change are the files paths.
   
   # Creates a new LeaderElection object.
   def initialize(id_file = ID_FILE, leader_file = LEADER_FILE)

      @id_file     = id_file
      @leader_file = leader_file

   end


   # Gets the ID of the node by reading the node's id_file.
   def get_id
      
      if File.exists?(@id_file)
         id_file = File.open(@id_file, 'r')
         id = id_file.read().chomp()
         id_file.close
      else
         id = -1
      end
      return id
   
   end
   
   
   # Sets the ID of the node.
   def set_id(id)
   
      file = File.open(@id_file, 'w')
      file.puts(id)
      file.close
      
   end
   
   
   # Gets the ID of the leader by reading the node's leader_file.
   def get_leader
   
      if File.exists?(@leader_file)
         leader_file = File.open(@leader_file, 'r')
         leader = leader_file.read().chomp()
         leader_file.close
      else
         leader = -1
      end
      return leader
   
   end
   
   
   # Sets the node's ID on a remote node.
   def vm_set_id(vm, id)
   
      command = "echo #{id} > #{@id_file}"
      out, success = CloudSSH.execute_remote(command, vm)
      return success
      
   end


   # Sets the leader's ID on a remote node.
   def vm_set_leader(vm, leader)
   
      command = "echo #{leader} > #{@leader_file}"
      out, success = CloudSSH.execute_remote(command, vm)
      return success
      
   end
      
      
end