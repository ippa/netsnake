#
#
#
class Client < Chingu::GameStates::NetworkClient
  trait :timer
    
  def initialize(options = {})
    super
    
    #@ip = options[:ip] || "192.168.0.1"
    @ip = options[:ip] || "127.0.0.1"
    @port = 7778
    
    unless @ip
      puts "No IP given, please run with 'ruby netsnake.rb <ip of server>'"; exit
    end
        
    self.input = [:esc, :left, :right, :up, :down]
    
    @level_image = TexPlay.create_blank_image($window, $window.width, $window.height, :color => :black)
    @level = GameObject.create(:image => @level_image, :rotation_center => :top_left, :zorder => 10)
    @player = Player.create(:uuid => (rand * 100000).to_i)
    @player.alive = false
    
    connect(@ip, @port)
  end
  
  def on_connect
    send_start
    after(2000) { send_ping }
    every(6000, :name => :ping) { send_ping }
  end
    
  #
  # We call super here so so NetworkClient calls handle_incoming_data() that in turn will call on_msg(msgs)
  # for incoming messages.
  #
  def update
    super

    Player.alive.each do |player|
      @level_image.line(player.previous_x, player.previous_y, player.x, player.y, :color => player.color)
    end   

    $window.caption = "Netsnake! #{@player.alive ? "Alive! :-) " : "Dead X-/"}  Ping: #{self.latency}ms   UUID: #{@player.uuid}  Players: #{Player.size}  FPS: #{$window.fps}"  if self.socket
  end
  
  #
  # We override NetworkClient#on_msg and put our game logic there
  #
  def on_msg(msg)
    @packet_counter += 1
    return unless msg && msg[:uuid]
    
    player = Player.find_by_uuid(msg[:uuid]) || Player.create(msg)
      
    case msg[:cmd]
      when :winner
        if @player.uuid == msg[:uuid]
          PuffText.create("YOU WON!")
        else
          PuffText.create("You LOST! #{msg[:alias]||msg[:uuid]} won.")
        end
      when :position
        player.x, player.y = msg[:x], msg[:y]
        player.previous_x, player.previous_y = msg[:previous_x], msg[:previous_y]
        player.color = msg[:color]
        player.alive = true
      when :destroy
        puts "Destroy: #{player.uuid}"
        player.destroy
      when :kill
        puts "* Kill: #{player.uuid} died @ #{msg[:x]}/#{msg[:y]}"
        player.alive = false
      when :restart
        player.alive = false
        restart
      when :ping
        send_msg(:cmd => :pong, :uuid => player.uuid, :milliseconds => msg[:milliseconds])
      when :pong
        @latency = (Gosu::milliseconds - msg[:milliseconds])
      end
  end

  #
  # Player Controls, don't allow 180 degree turns (suicide ;)..)
  #
  def left
    send_direction(:left)   unless  @player.direction == :right 
  end
  def right
    send_direction(:right)  unless  @player.direction == :left  
  end
  def up
    send_direction(:up)     unless  @player.direction == :down  
  end
  def down
    send_direction(:down)   unless  @player.direction == :up    
  end
  def esc; exit; end
  
  def send_direction(direction)
    @player.direction = direction
    send_msg(:uuid => @player.uuid, :cmd => :direction, :direction => direction)
  end
  
  def send_ping
    send_msg(:uuid => @player.uuid, :cmd => :ping, :milliseconds => Gosu::milliseconds)
  end  
  
  def send_start
    send_msg(:uuid => @player.uuid, :cmd => :start)
  end
  
  def restart
    @level_image.rect(0,0, $window.width, $window.height, :color => :black, :fill => true)
  end
end

class PuffText < Text
  traits :timer, :effect, :velocity

  def initialize(text, options = {})    
    super(text, {:y => $window.height/2+50, :size => 30, :center_x => 0.5}.merge(options))
    self.x = ($window.width / 2)
    self.rotation_center = :center
    puff_effect
    self.zorder = 100
  end
  
  def puff_effect
    self.fade_rate = -1
    self.scale_rate = 0.01
    self.velocity_y = -1
    after(4000) { destroy }
  end
end

# If fils is executed, not required.
if __FILE__ == $0
  `netsnake.rbw`
end

