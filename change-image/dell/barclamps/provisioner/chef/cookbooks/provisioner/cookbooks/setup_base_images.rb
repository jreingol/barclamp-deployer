# Copyright 2011, Dell
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied
# See the License for the specific language governing permissions and
# limitations under the License
#

machine_install_key = ::File.read("/etc/crowbar.install.key").chomp.strip
serial_console = node[:provisioner][:use_serial_console] ? "console=tty0 console=ttyS1,115200n8" : ""

#
# Setup links from centos image to our other two names
#
["update", "hwinstall"].each do |dir|
  link "/tftpboot/ubuntu_dvd/#{dir}" do
    action :create
    to "discovery"
    not_if "test -L /tftpboot/ubuntu_dvd/#{dir}"
  end
end

#
# Update the kernel lines and default configs for our
# three boot environments (centos images are updated
# with discovery).
#
[ "execute", "discovery"].each do |image|
  install_path = "/tftpboot/ubuntu_dvd/#{image}"
  
  # Make sure the directories need to net_install are there
  directory "#{install_path}"
  directory "#{install_path}/pxelinux.cfg"
  
  # Everyone needs a pxelinux.0
  link "#{install_path}/pxelinux.0" do
    action :create
    to "../isolinux/pxelinux.0"
    not_if "test -L #{install_path}/pxelinux.0"
  end
  
  case 
    when image == "discovery"
    template "#{install_path}/pxelinux.cfg/default" do
      mode 0644
      owner "root"
      group "root"
      source "default.erb"
      variables(:append_line => "append initrd=initrd0.img #{serial_console} root=/sledgehammer.iso rootfstype=iso9660 rootflags=loop crowbar.install.key=#{machine_install_key}",
                :install_name => image,  
                :kernel => "vmlinuz0")
    end
    next
    
    when image == "execute"
    cookbook_file "#{install_path}/pxelinux.cfg/default" do
      mode 0644
      owner "root"
      group "root"
      source "localboot.default"
    end 
  end
end


web_app "install_app" do
  server_name node[:fqdn]
  docroot "/tftpboot"
  template "install_app.conf.erb"
end

bash "copy validation pem" do
  code <<-EOH
  cp /etc/chef/validation.pem /tftpboot/ubuntu_dvd
  chmod 0444 /tftpboot/ubuntu_dvd/validation.pem
EOH
  not_if "test -f /tftpboot/ubuntu_dvd/validation.pem"  
end

directory "/tftpboot/curl"

[ "/usr/bin/curl",
  "/usr/lib/libcurl.so.4",
  "/usr/lib/libidn.so.11",
  "/usr/lib/liblber-2.4.so.2",
  "/usr/lib/libldap_r-2.4.so.2",
  "/usr/lib/libgssapi_krb5.so.2",
  "/usr/lib/libssl.so.0.9.8",
  "/usr/lib/libcrypto.so.0.9.8",
  "/usr/lib/libsasl2.so.2",
  "/usr/lib/libgnutls.so.26",
  "/usr/lib/libkrb5.so.3",
  "/usr/lib/libk5crypto.so.3",
  "/usr/lib/libkrb5support.so.0",
  "/lib/libkeyutils.so.1",
  "/usr/lib/libtasn1.so.3",
  "/lib/librt.so.1",
  "/lib/libcom_err.so.2",
  "/lib/libgcrypt.so.11",
  "/lib/libgpg-error.so.0"
].each { |file|
  basefile = file.gsub("/usr/bin/", "").gsub("/usr/lib/", "").gsub("/lib/", "")
  bash "copy #{file} to curl dir" do
    code "cp #{file} /tftpboot/curl"
    not_if "test -f /tftpboot/curl/#{basefile}"
  end  
}

