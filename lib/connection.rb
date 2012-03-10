class Connection
  
  attr_accessor :socket, :active
  
  def active? ; @active ; end
  def finish! ; @active = false ; end

end

