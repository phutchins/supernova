#!/usr/bin/env ruby

require 'optparse'
require 'selenium-webdriver'
require 'browsermob-proxy'
require 'browsermob/proxy/webdriver_listener'
require 'benchmark'
require 'headless'
require 'har'

# Defaults
$decimals = 2
$log_file_name = "supernova"
$wait_timeout = 60
$browsermobproxy_path = ENV['BROWSERMOBPROXY_PATH'] || "/home/selenium/browsermob-proxy/bin/browsermob-proxy"


class Supernova
  def options
    $options = {}
    opt_parser = OptionParser.new do |opt|
      opt.banner = "Usage: supernova [OPTIONS]"
      opt.separator ""
      opt.separator "Commands              Description"
      opt.separator "Options"
      opt.on("-u","--url URL","The URL to be tested. I.E. http://www.mysite.com") do |url|
        # Should validate the URL entered here
        $options[:url] = url
      end
      opt.on("-l","--login USERNAME","Username to log in with") do |login|
        $options[:login] = login
      end
      opt.on("-p","--password PASSWORD","Password to log in with") do |password|
        $options[:password] = password
      end
      opt.on("-s","--stack STACKNAME","Name of the stack we are testing") do |stack|
        $options[:stack] = stack
      end
      opt.on("-f","--logfile FILENAME","Name of logfile to log to") do |logfile|
        $options[:logfile] = logfile
      end
    end
    opt_parser.parse!
  end

  def run
    # Begin main block
    begin
      log_file_name = $options[:logfile] || $log_file_name
      log_file = File.open(log_file_name + "_#{$options[:stack]}.log", 'a')
      error_file = File.open($log_file_name + "_#{$options[:stack]}.error", 'a')
      log_line = "#{DateTime.now.iso8601} -"

      headless = Headless.new
      headless.start

      server = BrowserMob::Proxy::Server.new($browsermobproxy_path)
      server.start

      proxy = server.create_proxy

      profile = Selenium::WebDriver::Firefox::Profile.new
      profile.proxy = proxy.selenium_proxy

      driver = Selenium::WebDriver.for :firefox, :profile => profile

      proxy.new_har "homepage_load"
      total_load_time = 0

      log_line += " [STACK] #{$stack}"

      # Load site
      begin
        dm_load_time = Benchmark.realtime do
          driver.get $test_url
        end

        load_end = driver.execute_script("return window.performance.timing.loadEventEnd;")
        dom_loaded = driver.execute_script("return window.performance.timing.responseEnd;")
        nav_start = driver.execute_script("return window.performance.timing.navigationStart;")
        puts "nav_start: #{nav_start}  load_end: #{load_end}  Dom Load Time: #{(dom_loaded - nav_start) / 1000.00}  Full Load Time: #{(load_end - nav_start) / 1000.00}"
        onLoad = load_end - nav_start
        onContentLoad = dom_loaded - nav_start
        homepage_har_json_obj = JSON.load(proxy.har.to_json)
        homepage_har_json_obj['log']['entries'].each_with_index do |entry, i|
          sum_of_timings = 0
          entry['timings'].each do |field,t|
            next if t == -1 || t == ""
            sum_of_timings = sum_of_timings + t.to_i
          end
          index = i
          homepage_har_json_obj['log']['entries'][index]['time'] = sum_of_timings
        end
        homepage_har_json_obj['log']['pages'][0]['pageTimings']['onLoad'] = onLoad
        homepage_har_json_obj['log']['pages'][0]['pageTimings']['onContentLoad'] = onContentLoad
        homepage_har_json_obj['log']['pages'][0]['title'] = "Site Home Load"
        homepage_har_obj = HAR::Archive.from_string(homepage_har_json_obj.to_json)


        total_load_time += dm_load_time
      rescue Exception => e
        puts e.message
        #puts e.backtrace.inspect
        error_file.puts "#{DateTime.now.iso8601} - #{e.message}"
        error_file.puts "#{DateTime.now.iso8601} - #{e.backtrace.inspect}"
      end
      time_result = "ERROR"
      time_result = dm_load_time.round($decimals) unless dm_load_time.nil?
      puts "Home page load time: #{time_result} seconds"
      log_line += " [HOME] #{time_result}"

      # LogIn to Site
      begin
        proxy.new_har "signin_load"
        username = driver.find_element(:id, "user_email")
        password = driver.find_element(:id, "user_password")

        username.send_keys($login_username)
        password.send_keys($login_password)

        dm_login_time = Benchmark.realtime do
          if $stack == 'production'
            signIn = driver.find_element(:xpath, "//img[@alt='Log in to DealerMatch - Auto Dealer to Dealer Buying-Selling-Trading']")
          else
            signIn = driver.find_element(:xpath, "//input[@value='Sign In']")
          end
          signIn.click
        end

        load_end = driver.execute_script("return window.performance.timing.loadEventEnd;")
        dom_loaded = driver.execute_script("return window.performance.timing.responseEnd;")
        nav_start = driver.execute_script("return window.performance.timing.navigationStart;")
        puts "nav_start: #{nav_start}  load_end: #{load_end}  Dom Load Time: #{(dom_loaded - nav_start) / 1000.00}  Full Load Time: #{(load_end - nav_start) / 1000.00}"
        onLoad = load_end - nav_start
        onContentLoad = dom_loaded - nav_start
        signin_har_json_obj = JSON.load(proxy.har.to_json)
        signin_har_json_obj['log']['entries'].each_with_index do |entry, i|
          sum_of_timings = 0
          entry['timings'].each do |field,t|
            #puts "Field: #{field} Timing: #{t}"
            next if t == -1 || t == ""
            sum_of_timings = sum_of_timings + t.to_i
          end
          #puts "Index: #{i} Total: #{sum_of_timings}"
          index = i
          signin_har_json_obj['log']['entries'][index]['time'] = sum_of_timings
        end
        signin_har_json_obj['log']['pages'][0]['pageTimings']['onLoad'] = onLoad
        signin_har_json_obj['log']['pages'][0]['pageTimings']['onContentLoad'] = onContentLoad
        signin_har_json_obj['log']['pages'][0]['title'] = "DealerMatch.com Sign In"
        signin_har_obj = HAR::Archive.from_string(signin_har_json_obj.to_json)

        total_load_time += dm_login_time

      rescue Exception => e
        puts e.message
        #puts e.backtrace.inspect
        error_file.puts "#{DateTime.now.iso8601} - #{e.message}"
        error_file.puts "#{DateTime.now.iso8601} - #{e.backtrace.inspect}"
      end
      time_result = "ERROR"
      time_result = dm_login_time.round($decimals) unless dm_login_time.nil?
      puts "Sign in time: #{time_result} seconds"
      log_line += " [SIGNIN] #{time_result}"

      # Load SRP and wait until ajax completes
      begin
        proxy.new_har "srp_load"
        srp_load_time = Benchmark.realtime do
          find_vehicles_link = driver.find_element(:link_text, "Find Vehicles")
          find_vehicles_link.click

          wait = Selenium::WebDriver::Wait.new(:timeout => $wait_timeout)
          wait.until { driver.find_element(:class_name, "vehicle") }

        end

        load_end = driver.execute_script("return window.performance.timing.loadEventEnd;")
        dom_loaded = driver.execute_script("return window.performance.timing.responseEnd;")
        nav_start = driver.execute_script("return window.performance.timing.navigationStart;")
        puts "nav_start: #{nav_start}  load_end: #{load_end}  Dom Load Time: #{(dom_loaded - nav_start) / 1000.00}  Full Load Time: #{(load_end - nav_start) / 1000.00}"
        onLoad = load_end - nav_start
        onContentLoad = dom_loaded - nav_start
        srp_har_json_obj = JSON.load(proxy.har.to_json)
        srp_har_json_obj['log']['entries'].each_with_index do |entry, i|
          sum_of_timings = 0
          entry['timings'].each do |field,t|
            #puts "Field: #{field} Timing: #{t}"
            next if t == -1 || t == ""
            sum_of_timings = sum_of_timings + t.to_i
          end
          #puts "Index: #{i} Total: #{sum_of_timings}"
          index = i
          srp_har_json_obj['log']['entries'][index]['time'] = sum_of_timings
        end
        srp_har_json_obj['log']['pages'][0]['pageTimings']['onLoad'] = onLoad
        srp_har_json_obj['log']['pages'][0]['pageTimings']['onContentLoad'] = onContentLoad
        srp_har_json_obj['log']['pages'][0]['title'] = "DealerMatch.com SRP Load"
        srp_har_obj = HAR::Archive.from_string(srp_har_json_obj.to_json)
        total_load_time += srp_load_time
      rescue Exception => e
        puts e.message
        #puts e.backtrace.inspect
        error_file.puts "#{DateTime.now.iso8601} - #{e.message}"
        error_file.puts "#{DateTime.now.iso8601} - #{e.backtrace.inspect}"
      end
      time_result = "ERROR"
      time_result = srp_load_time.round($decimals) unless srp_load_time.nil?
      puts "Load SRP page time: #{time_result} seconds"
      log_line += " [SRP] #{time_result}"

      # Show All Vehicles
      begin
        show_all_vehicles_time = Benchmark.realtime do
          all_vehicles_link = driver.find_element(:link_text, "Show all vehicles")
          all_vehicles_link.click
          #driver.click_link("Show all vehicles")

          wait = Selenium::WebDriver::Wait.new(:timeout => $wait_timeout)
          wait.until { driver.find_element(:xpath, "//*[contains(.,'Show only member vehicles')]") }
        end

        vehicle_count = driver.find_element(:class_name, "vehicle-count").text.tr(',','')
        puts "Vehicle Count: #{vehicle_count}"


        load_end = driver.execute_script("return window.performance.timing.loadEventEnd;")
        dom_loaded = driver.execute_script("return window.performance.timing.responseEnd;")
        nav_start = driver.execute_script("return window.performance.timing.navigationStart;")
        #puts "nav_start: #{nav_start}  load_end: #{load_end}  Dom Load Time: #{(dom_loaded - nav_start) / 1000.00}  Full Load Time: #{(load_end - nav_start) / 1000.00}"
        onLoad = load_end - nav_start
        onContentLoad = dom_loaded - nav_start
        #srp_all_har_json_obj = JSON.load(proxy.har.to_json)
        #srp_all_har_json_obj['log']['entries'].each_with_index do |entry, i|
        #  sum_of_timings = 0
        #  entry['timings'].each do |field,t|
        #    #puts "Field: #{field} Timing: #{t}"
        #    next if t == -1 || t == ""
        #    sum_of_timings = sum_of_timings + t.to_i
        #  end
        #  #puts "Index: #{i} Total: #{sum_of_timings}"
        #  index = i
        #  srp_all_har_json_obj['log']['entries'][index]['time'] = sum_of_timings
        #end
        #srp_all_har_json_obj['log']['pages'][0]['pageTimings']['onLoad'] = onLoad
        #srp_all_har_json_obj['log']['pages'][0]['pageTimings']['onContentLoad'] = onContentLoad
        #srp_all_har_json_obj['log']['pages'][0]['title'] = "DealerMatch.com SRP All Vehicles Load"
        #srp_all_har_obj = HAR::Archive.from_string(srp_all_har_json_obj.to_json)
        total_load_time += show_all_vehicles_time
      rescue Exception => e
        puts e.message
        error_file.puts "#{DateTime.now.iso8601} - #{e.message}"
        error_file.puts "#{DateTime.now.iso8601} - #{e.backtrace.inspect}"
      end
      time_result = "ERROR"
      time_result = show_all_vehicles_time.round($decimals) unless show_all_vehicles_time.nil?
      puts "Load All SRP page time: #{time_result} seconds"

      log_line += " [SRPALL] #{time_result}"
      log_line += " [TOTALTIME] #{total_load_time.round($decimals)}"
      vehicle_count_result = vehicle_count || "ERROR"
      log_line += " [VEHICLECOUNT] #{vehicle_count_result}"
      log_line += " [HAR]"

      begin
        driver.quit
        har = HAR::Archive.by_merging([homepage_har_obj, signin_har_obj, srp_har_obj])
        #hars = proxy_listener.hars
        file_time = DateTime.now.iso8601
        har.save_to "./hars/#{file_time}_dealermatch.com_#{$stack}.har"
        log_line += " http://headless.dealermatch.biz/?path=hars/#{file_time}_dealermatch.com_#{$stack}.har"
      rescue Exception => e
        log_line += " ERROR"
        puts e.message
        error_file.puts "#{DateTime.now.iso8601} - #{e.message}"
        error_file.puts "#{DateTime.now.iso8601} - #{e.backtrace.inspect}"
      end

      log_file.puts log_line

      proxy.close

      headless.destroy
    rescue Exception => e
      puts e.message
      puts e.backtrace.inspect
      error_file.puts "#{DateTime.now.iso8601} - #{e.message}"
      error_file.puts "#{DateTime.now.iso8601} - #{e.backtrace.inspect}"
      abort
    end
  end
end

Supernova.new.options

# Options
$test_url = $options[:url]
$login_username = $options[:login]
$login_password = $options[:password]
$stack = $options[:stack]

Supernova.new.run
