include_recipe 'chefdm-selenium::logstash'
include_recipe 'base'

include_recipe 'selenium'
include_recipe 'selenium::ruby'
include_recipe 'selenium::headless'
include_recipe 'chefdm-selenium::har_viewer'

cookbook_file "/home/selenium/supernova.rb" do
  mode 0755
  action :create
end

directory "/home/selenium/hars" do
  action :create
end
link "/var/www/html/hars" do
  to "/home/selenium/hars"
  action :create
end

cron "run_production_check" do
  user "selenium"
  minute "*/2"
  mailto "philip.hutchins@mysite.biz"
  home "/home/selenium"
  command "/bin/bash -l -c \"cd /home/selenium && /home/selenium/supernova.rb -u http://mysite.com -l alert@mysite.com -p super_secure_password -s production\""
  action :create
end

cron "run_staging_check" do
  user "selenium"
  minute "*/10"
  mailto "philip.hutchins@mysite.biz"
  home "/home/selenium"
  command "/bin/bash -l -c \"cd /home/selenium && /home/selenium/supernova.rb -u http://staging.mysite.biz -l alert@mysite.com -p super_secure_password -s staging\""
  action :create
end

remote_file "/home/selenium/browsermob-proxy.zip" do
  source node['chefdm-selenium']['browsermobproxy']['download_url']
  notifies :run, "execute[extract_browsermobproxy]", :immediately
end

execute "extract_browsermobproxy" do
  command "cd /home/selenium && unzip browsermob-proxy.zip"
  action :nothing
end

link "/home/selenium/browsermob-proxy" do
  to "/home/selenium/#{node['chefdm-selenium']['browsermobproxy']['extract_dir_name']}"
  action :create
end

