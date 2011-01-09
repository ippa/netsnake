class Player < GameObject
  trait :velocity
  
  attr_accessor :direction, :unanswered_packets, :alive, :socket, :start_position, :uuid
  
  def initialize(options = {})
    super
    
    @uuid = options[:uuid]
    @direction = options[:direction]
    @unanswered_packets = 0
    @start_position = nil
    @socket = nil

    @alive = true
  end
    
  def self.find_by_uuid(uuid)
    Player.all.select { |player| player.uuid == uuid }.first
  end

  def self.alive
    all.select{ |x| x.alive == true}
  end

  def start_data
    {:uuid => @uuid, :cmd => :start}
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
    "[##{self.uuid}]: #{self.x}/#{self.y}]"
  end
  
end
