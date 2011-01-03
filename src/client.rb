class Client < Chingu::GameState
  include Network
    
  def initialize(options = {})
    @ip = options[:ip] || "192.168.0.1"
    @port = 7778
    
    unless @ip
      puts "No serverIP given, please snart netsnake like this:"
      puts "ruby netsnake.rb <ip of server>"
      exit
    end
    
    self.input = [:esc, :left, :right, :up, :down]
    @socket = UDPSocket.new
    @socket.connect(@ip, @port)
    
    puts "Connecting to #{@ip}:#{@port}"
    
    @level_image = TexPlay.create_blank_image($window, $window.width, $window.height, :color => :black)
    @level = GameObject.create(:image => @level_image, :rotation_center => :top_left, :factor => $window.factor)
    @player = Player.create(:uuid => (rand * 100000).to_i, :factor => 4)
    @packet_counter = 0    
    
    super
  end
  
  def setup
  end
  def esc; exit; end
  
  def left
    @player.direction = :left
    send_data(@player.direction_data)
  end
  def right
    @player.direction = :right
    send_data(@player.direction_data)
  end
  def up
    @player.direction = :up
    send_data(@player.direction_data)
  end
  def down
    @player.direction = :down
    send_data(@player.direction_data)
  end
  
  def restart
    @level_image.rect(0,0, $window.width, $window.height, :color => :black, :fill => true)
  end
    
  def update
    super
    
    begin
      data, sender = read_data
      handle_data(data, sender) if data
    rescue Errno::ECONNRESET => e # Previous Send resultet in ICMP Port Unreachable
      puts "Can't communicate with server (ICMP Port Unreachable from server)"
    end
    
    Player.each do |player|
      @level_image.pixel(player.x, player.y, :color => :white)
    end
    
    $window.caption = "Snake Online. [UUID: #{@player.uuid}] #{@player.x}/#{@player.y}. Packets recieved: #{@packet_counter} [FPS: #{$window.fps}]"
  end
    
  def handle_data(data, sender)
    @packet_counter += 1
    if data[:uuid]
      game_object = Player.find_by_uuid(data[:uuid]) || Player.create(data)
      case data[:cmd] 
        when :position 
          game_object.x = data[:x]
          game_object.y = data[:y]
        when :destroy
          puts "Destroy: #{game_object.uuid}"
          game_object.destroy
        when :kill
          puts "* Kill: #{game_object.uuid} died @ #{data[:x]}/#{data[:y]}"
          game_object.x = data[:x]
          game_object.y = data[:y]          
          game_object.alive = false
        end
    else
      case data[:cmd]
        when :ping
          send_data(@player.pong_data)
        when :restart
          puts "* Restart"
          restart          
      end
    end
  end
    
end

# If fils is executed, not required.
if __FILE__ == $0
  Game.new.show
end
