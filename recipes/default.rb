#
# Cookbook Name:: VRTSralus
# Recipe:: default
#
# Copyright 2011, Eugenio Marzo , Bryan W. Berry
#
# Apache 2.0


media_servers = node['vrtsralus']['media_servers']

package "compat-libstdc++-33" do
        :install
end


# load passwd for bexec user from encrypted databags
# http://www.opscode.com/blog/2011/04/29/chef-0-10-preview-encrypted-data-bags
bexec_passwd = Chef::EncryptedDataBagItem.load("stash", "stuff")['bexec_passwd']


user "bexec" do
        home    "/home/bexec"
        shell   "/bin/bash"
        password        bexec_passwd
        supports({ :manage_home => true })
end

group "beoper" do
        members [ "bexec" ]
end


directory "/tmp/VRTSralus" do
  owner "root"
  group "root"
  mode "0755"
  action :create
  not_if { ::File.exists? "/etc/VRTSralus/updated-with-fix-script" }
end


#extract RALUS_RMALS_RAMS-1798.17.tar.gz
script "extract_backup_exec" do
  interpreter "bash"
  user "root"
  code <<-EOH
  cd /tmp/VRTSralus
  [ ! -e /etc/VRTSralus/updated-with-fix-script ] &&  wget http://#{node['VRTSralus']['repo']}/RALUS_RMALS_RAMS-1798.17.tar.gz && tar -zxf /tmp/VRTSralus/RALUS_RMALS_RAMS-1798.17.tar.gz
  exit 0
  EOH
not_if { ::File.exists? "/etc/VRTSralus/updated-with-fix-script" }
end




#Unistall the old version and install the new
script "install_backup_exec" do
   interpreter "ruby"
   user "root"
   cwd "/tmp/VRTSralus/"
   code <<-EOH
   require 'open3'
   require 'fileutils'
   
   File.open('/var/log/VRTSralus_inst_Log', 'w') do |f1| 
   
   # --- unistall the old version --- # 
   stdin, stdout, stderr = Open3.popen3('sh uninstallralus')
   #press RETURN for 5 times
   $i = 0;
    while $i < 5  do
      stdin.puts();
      $i +=1;
    end
   # --- put logs in /var/log/VRTSralus_inst_Log #
   stdout.each do |line|
   f1.puts line
   end
   stdin.close
   stdout.close
   stderr.close
  # --- #
  # --- install new version --- #
  stdin, stdout, stderr = Open3.popen3('sh installralus')
    # press RETURN for 4 times
    $i = 0;
    while $i < 4  do
     stdin.puts();
     $i +=1;
    end
   
   # --- insert backup media serves --- #
   # --- this loop puts n after the last object of array --- #
   $counter=0
   %w{ #{media_servers.join(" ")} }.each  do |server|
    stdin.puts(server)
    if $counter != %w{ #{media_servers.join(" ")} }.size - 1
    stdin.puts("y")
   else
    stdin.puts("n") 
   end
    $counter +=1
   end

  

    # press RETURN for 7 times
    $i = 0;
    while $i < 8  do
     stdin.puts();
     $i +=1;
    end

    
   stdout.each do |line|
    f1.puts line
   if line.include? "Symantec Backup Exec Agent for Linux configured successfully"
    FileUtils.touch '/etc/VRTSralus/updated-with-fix-script'
    end
   end

   stdin.close
   stdout.close
   stderr.close
 end
 EOH
 not_if { ::File.exists? "/etc/VRTSralus/updated-with-fix-script" }
end




#delete /tmp/VRTSralus
script "delete_tmp_vrtsralus" do
  interpreter "bash"
  user "root"
  code <<-EOH
  cd /tmp
  [ -e /tmp/VRTSralus/ ] && rm -rf /tmp/VRTSralus
  exit 0
  EOH
  only_if { ::File.exists? "/tmp/VRTSralus/" }
end










