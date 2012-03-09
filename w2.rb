require 'socket'
require 'io/wait'

class Events
    
  def initialize(event,size)
    @size = size
    @start = 0
    @end = 0
    @events = []
    @size.times do
      @events << event.new
    end
  end
  
  def enqueue
    new_end = ( @end + 1) % @size
    yield(@events[ new_end ])
    @end = new_end
  end
  
  def dequeue
    @start = ( @start + 1 ) % @size
    @events[ @start ]
  end
  
  def events?
    @start != @end
  end
  
end

class Connection
  
  attr_accessor :socket, :active
  
  def active? ; @active ; end
  def finish! ; @active = false ; end

end

class ConnectionPool
  
  def initialize(size)
    @available = []
    size.times do 
      @available << Connection.new
    end
  end
  
  def make(socket)
    connection = @available.pop
    connection.active = true
    connection.socket = socket
    connection
  end
  
  def recycle(connection)
    @available.push(connection)
  end
  
end
  
class Server
  
  RequestEvent = Struct.new(:connection)
  
  attr_accessor :requests
  
  def initialize(options)
    @worker_count, @worker = options.values_at(:count,:worker)
  end
  
  def start 
    @pool = ConnectionPool.new(4096)
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
              connection = @pool.make(socket)
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

class Worker
  
  def initialize(events)
    @events = events
  end
  
  def start
    Thread.new do
      loop do
        if @events.events?
          event = @events.dequeue
          connection = event[:connection]
          socket = connection.socket
          begin
            request = ""
            while line = socket.gets
              break if line == "\r\n"
              request += line
            end
            socket.print "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 11\r\n\r\nHello World"
          rescue IOError, Errno::ECONNRESET, Errno::EPIPE
            socket.close unless socket.closed?
            next
          ensure
            connection.finish!
          end
        end
      end
    end
  end
end

server = Server.new(:worker => Worker,:count => 1)
server.start.join