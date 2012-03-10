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
