class Player < GameObject
  trait :velocity
  
  attr_accessor :client_ip, :client_port, :direction, :unanswered_packets, :alive
  attr_reader :uuid
  
  def initialize(options = {})
    super
    
    @uuid = options[:uuid]
    @direction = options[:direction]
    @unanswered_packets = 0
    @alive = true
  end
    
  def self.alive
    all.select{ |x| x.alive == true}
  end
    
  def ping_data
    {:uuid => @uuid, :cmd => :ping}
  end

  def pong_data
    {:uuid => @uuid, :cmd => :pong}
  end

  def direction_data
    {:uuid => @uuid, :cmd => :direction, :direction => self.direction}
  end

  def position_data
    {:uuid => @uuid, :cmd => :position, :x => self.x, :y => self.y, :color => self.color.argb}
  end

  def to_s
    "[uuid #{self.uuid}: #{self.x}/#{self.y}]"
  end
  
end
