# Auxiliar functions for generic cloud provider

################################################################################
# Start cloud functions
################################################################################

# Starting function for leader node.
def leader_start(vm_ips, vm_ip_roles, vm_img_roles, pm_up)
   
   # We are the leader
   puts "#{MY_IP} is the leader"
   
   # Check wether virtual machines are alive or not
   alive = {}
   vm_ips.each do |vm|
      alive[vm] = false
   end
   
   puts "Checking whether virtual machines are alive..."
   vm_ips.each do |vm|
      result = `#{PING} #{vm}`
      if $?.exitstatus == 0
         debug "[DBG] #{vm} is up"
         alive[vm] = true
      else
         debug "[DBG] #{vm} is down"
         puts "#{vm} is down"
      end
   end
   
   # Monitor the alive machines. Start and configure the dead ones.
   deads = false
   vm_ips.each do |vm|
      if alive[vm]
         # If they are alive, monitor them
         puts "Monitoring #{vm}..."
         monitor_vm(vm, vm_ip_roles)
         puts "...Monitored"
      else
         # If they are not alive, start and configure them
         puts "Starting #{vm}..."
         start_vm(vm, vm_ip_roles, vm_img_roles, pm_up)
         puts "...Started"
         deads = true
      end
   end
   
   # Wait for all machines to be started
   unless deads
   
      # If not already started, start the cloud
      unless File.exists?("/tmp/cloud-#{resource[:name]}")
         
         # Copy important files to all machines
         puts "Copying important files to all virtual machines"
         #copy_cloud_files(vm_ips, "XXX")      # TODO Move it to monitor and call it each time for one vm?
      
         # Start the cloud
         if start_cloud(vm_ips, vm_ip_roles)
            
            # Make cloud nodes manage themselves
            #auto_manage("XXX")     # Only if cloud was started properly
            
            # Create file
            cloud_file = File.open("/tmp/cloud-#{resource[:name]}", 'w')
            cloud_file.puts(resource[:name])
            cloud_file.close
            
            puts "==================="
            puts "== Cloud started =="
            puts "==================="
         else
            puts "Impossible to start cloud"
         end
      end      # unless File
      
   end      # unless deads

end


# Starting function for common (non-leader) nodes.
def common_start(my_id)

   # We are not the leader or we have not received our ID yet
   puts "#{MY_IP} is not the leader"

   if my_id == -1
      
      # If we have not received our ID, let's assume we will be the leader
      CloudLeader.set_id(0)
      CloudLeader.set_leader(0)
      
      puts "#{MY_IP} will be the leader"
      
      # Create your ssh key
      CloudSSH.generate_ssh_key()
      
   else
      
      # If we have received our ID, try to become leader
      puts "Trying to become leader..."
      
      # Get your ID
      #my_id = CloudLeader.get_id()
      
      # Get all machines' IDs
      mcc = MCollectiveLeaderClient.new("leader")
      ids = mcc.ask_id()
      
      # See if some other machine is leader
      exists_leader = false
      ids.each do |id|
         if id < my_id
            exists_leader = true 
            break
         end
      end
      
      # If there is no leader, we will be the new leader
      if !exists_leader
         mcc.new_leader(my_id.to_s())
         puts "...#{MY_IP} will be leader"
         
         # Create your ssh key
         CloudSSH.generate_ssh_key()
      else
         puts "...Some other machine is/should be leader"
      end
      mcc.disconnect
      
      return
   end

end


# Starting function for cloudes which do not belong to the cloud.
def not_cloud_start()
   
   # Try to find one virtual machine that is already running
   alive = false
   vm_leader = ""
   vm_ips.each do |vm|
      result = `#{PING} #{vm}`
      if $?.exitstatus == 0
         puts "#{vm} is up"
         alive = true
         vm_leader = vm
         break
      end
   end
   
   if !alive
      puts "All virtual machines are stopped"
      puts "Starting one of them..."
   
      # Start one of the virtual machines
      vm = vm_ips[rand(vm_ips.count)]     # Choose one randomly
      puts "Starting #{vm} ..."
      
      start_vm(vm, vm_ip_roles, vm_img_roles, pm_up)
      
      # That virtual machine will be the "leader" (actually the chosen one)
      vm_leader = vm
      
      # Copy important files to it
      #copy_cloud_files(vm_leader, "XXX")
      
      puts "#{vm_leader} is being started"
      puts "Once started, do 'puppet apply manifest.pp' on #{vm_leader}" 
   else
      puts "#{vm_leader} is already running"
      puts "Do 'puppet apply manifest.pp' on #{vm_leader}"
   end

end


def leader_monitoring()

   puts "#{MY_IP} is the leader"
   
   # Do monitoring
   deads = []
   vm_ips, vm_ip_roles, vm_img_roles = obtain_vm_data()
   vm_ips.each do |vm|
      puts "Monitoring #{vm}..."
      unless monitor_vm(vm, vm_ip_roles)
         deads << vm
      end
      puts "...Monitored"
   end
   
   # Check pool of physical machines
   pm_all_up, pm_up, pm_down = check_pool()
   
   if deads.count == 0
      puts "=========================="
      puts "== Cloud up and running =="
      puts "=========================="
   else
      # Raise again the dead machines
      deads.each do |vm|
         start_vm(vm, vm_ip_roles, vm_img_roles, pm_up)
      end
   end
            
end


################################################################################
# Stop cloud functions
################################################################################

# Shuts down physical machines
def shutdown_pms(pms)

   pms.each do |pm|
   
      pm_user = resource[:pm_user]
      ssh_connect = "ssh #{pm_user}@#{pm}"
      
      # Bring the defined domains file from the physical machine to this one
      result = `scp #{pm_user}@#{pm}:#{DOMAINS_FILE} #{DOMAINS_FILE}`
      if $?.exitstatus == 0
      
         puts "#{DOMAINS_FILE} exists in #{pm}"
         
         # Open files
         defined_domains = File.open(DOMAINS_FILE, 'r')
      
         # Stop nodes
         defined_domains.each_line do |domain|
            domain.chomp!
            result = `#{ssh_connect} '#{VIRSH_CONNECT} shutdown #{domain}'`
            if $?.exitstatus == 0
               debug "[DBG] #{domain} was shutdown"
            else
               debug "[DBG] #{domain} impossible to shutdown"
               err "#{domain} impossible to shutdown"
            end
         end
         
         # Undefine local domains
         defined_domains.rewind
         defined_domains.each_line do |domain|
            domain.chomp!
            result = `#{ssh_connect} '#{VIRSH_CONNECT} undefine #{domain}'`
            if $?.exitstatus == 0
               debug "[DBG] #{domain} was undefined"
            else
               debug "[DBG] #{domain} impossible to undefine"
               err "#{domain} impossible to undefine"
            end
         end
         
         # Delete the defined domains file on the physical machine
         result = `#{ssh_connect} 'rm -rf #{DOMAINS_FILE}'`
      
      else
         # Some physical machines might not have any virtual machine defined.
         # For instance, if they were already defined and running when we
         # started the cloud.
         puts "No #{DOMAINS_FILE} file found in #{pm}"
      end
      
   end   # pms.each

end


# Deletes cloud files on all machines.
def delete_files()

   puts "Deleting cloud files on all machines..."
   
   # Create an MCollective client so that we avoid errors that appear
   # when you create more than one client in a short time
   mcc = MCollectiveFilesClient.new("files")
   
   # Delete leader, id, last_id and last_mac files on all machines (leader included)
   mcc.delete_file(CloudLeader::LEADER_FILE)             # Leader ID
   mcc.delete_file(CloudLeader::ID_FILE)                 # ID
   mcc.delete_file(LAST_ID_FILE)                         # Last ID
   mcc.delete_file(LAST_MAC_FILE)                        # Last MAC address
   mcc.disconnect       # Now it can be disconnected
   
   # Delete rest of regular files on leader machine
   files = [DOMAINS_FILE,                                # Domains file
            "/tmp/cloud-#{resource[:name]}"]             # Cloud file
   files.each do |file|
      if File.exists?(file)
         File.delete(file)
      else
         puts "File #{file} does not exist"
      end
   end

end


################################################################################
# Auxiliar functions
################################################################################

# Obtains virtual machines' IP addresses, image disks and roles.
def obtain_vm_data(ip_yaml_function = nil, img_yaml_function = nil)
   
   vm_ips = []
   vm_ip_roles = []
   vm_img_roles = []
   puts "Obtaining cloud data"
   unless ip_yaml_function == nil
      vm_ips, vm_ip_roles = ip_yaml_function.call(resource[:ip_file])
   end
   unless img_yaml_function == nil
      vm_img_roles = img_yaml_function.call(resource[:img_file])
   end
   return vm_ips, vm_ip_roles, vm_img_roles
         
end


# Monitors a virtual machine.
# Returns false if the machine is not alive.
def monitor_vm(vm, ip_roles)

   # Check if it is alive
   alive = CloudMonitor.ping(vm)
   unless alive
      err "#{vm} is not alive. Impossible to monitor"
      
      # If it is not alive there is no point in continuing
      return false
   end
   
   # Send it your ssh key
   # Your key was created when you turned into leader
   puts "Sending ssh key to #{vm}"
   password = resource[:root_password]
   out, success = CloudSSH.copy_ssh_key(vm, password)
   if success
      puts "ssh key sent"
   else
      err "ssh key impossible to send"
   end
   
   # Check if MCollective is installed and configured
   mcollective_installed = CloudMonitor.mcollective_installed(vm)
   unless mcollective_installed
      err "MCollective is not installed on #{vm}"
   end
   
   # Make sure MCollective is running.
   # We need this to ensure the leader election, so ensuring MCollective
   # is running can not be left to Puppet in their local manifest. It must be
   # done explicitly here and now.
   mcollective_running = CloudMonitor.mcollective_running(vm)
   unless mcollective_running
      err "MCollective is not running on #{vm}"
   end
   
   # TODO What if a machine has different roles?
   
   role = :undefined
   ip_roles.each do |r, ips|
      ips.each do |ip|
         if ip == vm then role = r end
      end
   end
   
   # Check if they have their ID
   # If they are running, but they do not have their ID:
   #   - Set their ID before they can become another leader.
   #   - Set also the leader's ID.
   success = CloudLeader.vm_check_id(vm)
   unless success
   
      # Set their ID (based on the last ID we defined)
      id = get_last_id()
      id += 1
      CloudLeader.vm_set_id(vm, id)
      set_last_id(id)
      
      # Set the leader's ID
      leader = CloudLeader.get_leader()
      CloudLeader.vm_set_leader(vm, leader)
      
      # Send the last ID to all nodes
      mcc = MCollectiveFilesClient.new("files")
      mcc.create_file(LAST_ID_FILE, id.to_s)
      #mcc.disconnect
   end
   
   # TODO Copy cloud files each time a machine is monitored?
   # TODO Copy files no matter what or check first if they have them?
   # Use copy_cloud_files if we copy no matter what. Modify it if we check
   # We should copy no matter what in case they have changed
   
   # Depending on the type of cloud we will have to monitor different components
   # XXX_monitor_function()
   
   return true
   
end


# Starts a cloud formed by <vm_ips> performing <vm_ip_roles>.
def start_cloud(vm_ips, vm_ip_roles)

   puts "Starting the cloud"
   return # XXX_start_cloud()

end


# Copies important files to all machines inside <ips>.
def copy_cloud_files(ips, cloud_type)
# Use MCollective?
#  - Without MCollective we are able to send it to both one machine or multiple
#    machines without changing anything, so not really.

   ips.each do |vm|
   
      if vm != MY_IP
         
         # Cloud manifest
         file = "init-#{cloud_type}.pp"
         path = "/etc/puppet/modules/#{cloud_type}/manifests/#{file}"
         out, success = CloudSSH.copy_remote(path, vm, path)
         unless success
            err "Impossible to copy #{file} to #{vm}"
         end
         
         # Cloud description (IPs YAML file)
         out, success = CloudSSH.copy_remote(resource[:ip_file], vm, resource[:ip_file])
         unless success
            err "Impossible to copy #{resource[:ip_file]} to #{vm}"
         end
         
         # Cloud roles (Image disks YAML file)
         out, success = CloudSSH.copy_remote(resource[:img_file], vm, resource[:img_file])
         unless success
            err "Impossible to copy #{resource[:img_file]} to #{vm}"
         end
      end
   end
   
end


# Makes the cloud auto-manageable through crontab files.
def auto_manage(cloud_type)

   cron_file = "crontab-#{cloud_type}"
   path = "/etc/puppet/modules/#{cloud_type}/files/cron/#{cron_file}"
   
   if File.exists?(path)
      file = File.open(path, 'r')
      line = file.read().chomp()
      file.close
      
      # Add the 'puppet apply manifest.pp' line to the crontab file
      mcc = MCollectiveCronClient.new("cronos")
      mcc.add_line(CRON_FILE, line)
      mcc.disconnect
   else
      err "Impossible to find cron file at #{path}"
   end
   
end
