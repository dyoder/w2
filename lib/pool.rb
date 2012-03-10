class Pool
  
  def initialize(klass,size)
    @available = []
    size.times do 
      @available << klass.new
    end
  end
  
  def make  
    object = @available.pop
    yield(object)
    object
  end
  
  def recycle(object)
    @available.push(object)
  end
  
end
  
