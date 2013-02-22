#!/usr/bin/env ruby

# import needed packages
require 'fileutils'

# check for incoming arguments
project_name = ARGV[0] if ARGV[0]
repo_url = ARGV[1] if ARGV[1]
project_domain = ARGV[2] if ARGV[2]

# display help if needed
if (project_name == '--help' || !(project_name && repo_url && project_domain)) then
    puts %(
This script sets up new Drupal sites.

Given a project name, it will create the vhost entry, create the db, git clone the repo, and restart the server.

It expects three parameters: the name of the project, the url to the git repo, and the domain for the project on this server.

For example:
  site_setup.rb foo git@example.github.com:/foo.git foo.example.com

Will checkout code into /var/www/foo from the repo at git@example.github.com:/foo.git and setup a vhost entry for foo.example.com

It also assumes you\'ve set the MYSQL_PASSWORD and ADMIN_EMAIL environment variables for root
)
    exit
end

# create the directory in /var/www
project_dir = '/var/www/' + project_name
FileUtils.mkdir_p project_dir

# set dir ownership
FileUtils.chown 'git', 'ubuntu', project_dir
FileUtils.chmod 0775, project_dir

# clone repo into directory
FileUtils.cd '/var/www'
system "sudo -u git git clone #{repo_url} #{project_name}"

# create site/default/files
files_dir = project_dir + '/sites/default/files'
FileUtils.mkdir_p files_dir

# create sites/default/settings.php
default_settings = project_dir + '/sites/default/default.settings.php'
real_settings = project_dir + '/sites/default/settings.php'
FileUtils.cp default_settings, real_settings

# set permissions on both
FileUtils.chmod 0777, real_settings

# set permissions on dir
FileUtils.chmod 0777, files_dir

# create new db
mysql_pass = ENV.fetch 'MYSQL_PASSWORD', 'drupal'
system "mysqladmin --user=root --password=#{mysql_pass} create #{project_name}"

# grant permissions to db
grant_command = "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, LOCK TABLES, CREATE TEMPORARY TABLES ON `#{project_name}`.* TO 'drupal'@'localhost' IDENTIFIED BY 'drupal';"

open("/var/tmp/#{project_name}_grant.sql", 'w') do |f|
  f.puts(grant_command)
end

system "mysql -u root --password=#{mysql_pass} < /var/tmp/#{project_name}_grant.sql"

# create vhost entry
server_admin = ENV.fetch 'ADMIN_EMAIL', 'dev@example.com'
vhost_template = %(
<VirtualHost *:80>
  ServerAdmin #{server_admin}
  ServerName #{project_domain}

  DocumentRoot #{project_dir}

  ErrorLog ${APACHE_LOG_DIR}/error.log
  LogLevel warn
  CustomLog ${APACHE_LOG_DIR}/access.log combined

  <Directory #{project_dir}>
   RewriteEngine on
   RewriteBase /
   RewriteCond %{REQUEST_FILENAME} !-f
   RewriteCond %{REQUEST_FILENAME} !-d
   RewriteRule ^(.*)$ index.php?q=$1 [L,QSA]
   AllowOverride All
  </Directory>

</VirtualHost>
)

open("/etc/apache2/sites-available/#{project_domain}", "w") do |f|
  f.puts(vhost_template)
end

# enable the site
system "a2ensite #{project_domain}"
system "service apache2 reload"

# direct user to update dns entry
puts "That's it!\nBe sure to update the dns entry for #{project_name}.mjdinteractive.com to point to this IP\n"
