require 'socket'

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
        else
          # if there are no events, let's focus on
          # processing requests for a millisecond
          sleep(0.001)
        end
      end
    end
  end
end