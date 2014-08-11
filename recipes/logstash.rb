#cookbook_file "/opt/logstash/agent/etc/conf.d/logstash.conf" do
#  owner "logstash"
#  group "logstash"
#  action :create
#  notifies :restart, 'service[logstash_agent]', :immediately
#end
node.override['logstash']['agent']['base_config'] = 'agent.conf.erb'
node.override['logstash']['agent']['base_config_cookbook'] = 'chefdm-selenium'

node.normal['logstash']['agent']['inputs'] = %{
  file {
    type => "supernova"
    path => ["/home/selenium/supernova*.log"]
  }
}
node.normal['logstash']['agent']['filters'] = %{
  if [type] == "supernova" {
    grok {
      'match' => ["message", "%{TIMESTAMP_ISO8601:timestamp} - \\[STACK\\] %{WORD:stack} \\[HOME\\] %{NUMBER:home_load_time:float} \\[SIGNIN\\] %{NUMBER:signin_load_time:float} \\[SRP\\] %{NUMBER:srp_load_time:float} \\[SRPALL\\] %{NUMBER:srp_all_load_time:float} \\[TOTALTIME\\] %{NUMBER:total_load_time:float} \\[VEHICLECOUNT\\] %{NUMBER:vehicle_count:int} \\[HAR\\] %{URI:har_url}"]     }
    date {
      add_tag => [ 'ts' ]
      match => [ "timestamp", "ISO8601" ]
    }
  }
}
node.normal['logstash']['agent']['outputs'] = %{
  redis {
    'data_type' => "list"
    'host' => "logs.dealermatch.biz"
    'key' => "logstash"
    'port' => "16379"
  }
}
