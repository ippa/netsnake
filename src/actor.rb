class Player < GameObject
  trait :velocity
  
  attr_accessor :direction, :alive, :socket, :start_position, :uuid, :color
  attr_accessor :previous_x, :previous_y
  
  def initialize(options = {})
    super
    
    self.previous_x = self.x
    self.previous_y = self.y
    
    @uuid = options[:uuid]
    @direction = options[:direction]
    
    @start_position = nil
    @socket = nil
    @color = options[:color] || :white

    @alive = true
  end
    
  def self.find_by_uuid(uuid)
    Player.all.select { |player| player.uuid == uuid }.first
  end

  def self.find_by_socket(socket)
    Player.all.select { |player| player.socket == socket }.first
  end

  def self.alive
    all.select{ |x| x.alive == true}
  end
  
  def restart_data
    {:cmd => :restart, :uuid => uuid, :x => x, :y => y, :previous_x => previous_x, :previous_y => previous_y}
  end
  
  def position_data
    {:uuid => @uuid, :cmd => :position, :x => self.x, :y => self.y, :previous_x => self.previous_x, :previous_y => self.previous_y, :color => @color}
  end

  def to_s
    "[##{self.uuid}]: #{self.x}/#{self.y}]"
  end
  
end
