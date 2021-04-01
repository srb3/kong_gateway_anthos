api = input('kong-admin-endpoint')
proxy = input('kong-proxy-endpoint')
token = input('kong-super-admin-token')

require_relative '../../libraries/kong_util'
wait("#{api}/clustering/status", 500, token)

post("#{api}/services", { 'name' => 'test', 'url' => 'http://httpbin.org' }, token)

post("#{api}/services/test/routes", { 'name' => 'testRoute', 'paths' => '/test' }, token)

members = JSON.parse(http("#{api}/clustering/status",
                          method: 'GET',
                          headers: { 'Kong-Admin-Token' => token },
                          ssl_verify: false).body)

describe members do
  it { should_not be_empty }
end

describe http("#{api}/services/test",
              method: 'GET', headers: { 'Kong-Admin-Token' => token },
              ssl_verify: false) do
                its('status') { should cmp 200 }
              end

describe http("#{api}/services/test/routes/testRoute",
              method: 'GET', headers: { 'Kong-Admin-Token' => token },
              ssl_verify: false) do
                its('status') { should cmp 200 }
              end

sleep(10) # wait for route to propergate
describe http("#{proxy}/test/get",
              method: 'GET', headers: { 'Kong-Admin-Token' => token },
              ssl_verify: false) do
                its('status') { should cmp 200 }
              end
