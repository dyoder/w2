require 'lib/server'
require 'lib/worker'


server = Server.new(:worker => Worker,:count => 1)
server.start.join