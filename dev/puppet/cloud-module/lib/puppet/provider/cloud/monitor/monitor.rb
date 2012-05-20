# Generic monitor functions for a distributed infrastructure
module Monitor

   PING = "ping -q -c 1 -w 4"

   # Checks if the <vm> machine is alive.
   def ping(vm)

      result = `#{PING} #{vm}`
      if $?.exitstatus == 0
         puts "[Monitor]:  #{vm} is up"
         return true
      else
         puts "[Monitor]:  #{vm} is down"
         return false
      end
      
   end


   # Checks if MCollective is installed in <vm>.
   def mcollective_installed(vm)
      
      installed = true
      
      # Client configuration file
      client_file = "/etc/mcollective/client.cfg"
      command = "ssh root@#{vm} 'cat #{client_file} > /dev/null 2> /dev/null'"
      result = `#{command}`
      if $?.exitstatus != 0
         puts "[Monitor]: #{client_file} does not exist on #{vm}"
         installed = false
      end

      # Server configuration file
      server_file = "/etc/mcollective/server.cfg"
      command = "ssh root@#{vm} 'cat #{server_file} > /dev/null 2> /dev/null'"
      result = `#{command}`
      if $?.exitstatus != 0
         puts "[Monitor]: #{server_file} does not exist on #{vm}"
         installed = false
      end
      
      return installed
      
   end


   # Checks if MCollective is running in <vm>.
   def mcollective_running(vm)
      
      command = "ssh root@#{vm} 'ps aux | grep -v grep | grep mcollective'"
      result = `#{command}`
      if $?.exitstatus != 0
         puts "MCollective is not running on #{vm}"
         command = "ssh root@#{vm} '/usr/bin/service mcollective start'"
         result = `#{command}`
         if $?.exitstatus != 0
            puts "[Monitor]: Impossible to start mcollective on #{vm}"
            return false
         else
            puts "[Monitor]: MCollective is running now on #{vm}"
            return true
         end
      else
         puts "[Monitor]: MCollective is running on #{vm}"
         return true
      end
      
   end
   
end
