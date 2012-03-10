require 'socket'
require 'lib/pool'
require 'lib/connection'
require 'lib/events'

class Server
  
  RequestEvent = Struct.new(:connection)
  
  attr_accessor :requests
  
  def initialize(options)
    @worker_count, @worker = options.values_at(:count,:worker)
  end
  
  def start 
    @pool = Pool.new(Connection,4096)
    @pending = []
    @active = []
    @connections = []
    @workers = []
    @worker_count.times do 
      events = Events.new(RequestEvent,4096)
      @workers << events
      @worker.new(events).start
    end
    @current_worker = 0
    @server = TCPServer.new(1337)
    @server.listen(4096)
    Thread.new do
      loop do
        begin
          events = IO.select([@server],nil,nil,0)
          if events
            begin
              loop { @pending << @server.accept_nonblock }
            rescue IO::WaitReadable, Errno::EAGAIN
            end
          end
          inactive = @active.reject do |connection|
            connection.active?
          end
          @active -= inactive
          @connections += inactive.map do |connection|
            socket = connection.socket
            @pool.recycle(connection)
            socket
          end
          @connections = @connections.reject do |connection|
            connection.closed?
          end
          @connections += @pending
          @pending = []
          events = IO.select(@connections,nil,nil,0)
          if events
            @readable = events.first
            @connections -= @readable
            @readable.each do |socket|
              @current_worker = ( @current_worker + 1 ) % @worker_count
              connection = @pool.make do |connection|
                connection.active = true
                connection.socket = socket
              end
              @active << connection
              @workers[@current_worker].enqueue do |event|
                event[:connection] = connection
              end
            end
          end
        rescue => e
          $stderr.puts e.class.name, e.message, e.backtrace.join("\n")
        end
      end
    end
  end
end
