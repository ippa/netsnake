#
#
#
class Server < Chingu::GameState
  include Network
  trait :timer
  
  def initialize
    super
    
    @socket = UDPSocket.new
    @socket.bind("0.0.0.0", 7778)
    
    $window.factor = 2
    @level_image = TexPlay.create_blank_image($window, $window.width, $window.height, :color => :black)
    @level = GameObject.create(:image => @level_image, :rotation_center => :top_left, :factor => $window.factor)
    @max_game_objects = 4
    
    self.input = {:esc => :exit, :r => :restart}
    
    # x, y, velocity_x, velocity_y
    @player_start_positions = [ [10, 10, 1, 0],
                                [$window.width-10,10,-1,0],
                                [10,$window.height-10,1,0],
                                [$window.width-10,$window.height-10,-1,0]
                              ]
  end
  
  def update    
    begin
      data, sender = read_data
    rescue Errno::ECONNRESET => e # Previous Send resultet in ICMP Port Unreachable
      puts "* SyncNetwork"
      push_game_state(SyncNetwork)
    end
        
    handle_data(data, sender) if data

    super
    
    # World logic, collision detection etc.
    Player.each do |player|      
      # Wrap around when reaching window border
      player.x = 0                if player.x > $window.width-1
      player.x = $window.width-1  if player.x < 0
      player.y = 0                if player.y > $window.height-1
      player.y = $window.height-1 if player.y < 0
      
      # collide with other snakes
      if player.alive == true && collision_at?(player.x, player.y)
        player.stop
        player.alive = false
        send_data_to_all({:cmd => :kill, :uuid => player.uuid, :x => player.x, :y => player.y})
        puts "* player #{player.uuid} died"
      end      
    end
    
    # All players dead, restart level!
    if Player.alive.size == 0
      restart
    end
    
    info_string = Player.all.map { |player| player.to_s}.join(" ")
    $window.caption = "[FPS: #{$window.fps}] #{info_string}"
  
    Player.each do |player|
      @level_image.pixel(player.x, player.y, :color => :white)
    end
    
    update_clients
  end
  
  def restart
    send_data_to_all({:cmd => :restart})
    @level_image.rect(0,0, $window.width, $window.height, :color => :black, :fill => true)
    Player.all.each_with_index do |player, index|
      player.alive = true
      player.x = @player_start_positions[index][0]
      player.y = @player_start_positions[index][1]
      player.velocity_x = @player_start_positions[index][2]
      player.velocity_y = @player_start_positions[index][3]
    end
  end
  
  def collision_at?(x,y)
    @level_image.get_pixel(x, y, :color_mode => :gosu).argb == Color::WHITE.argb
  end
  
  #def draw
    #@level_image.draw(0,0,10)
  #end
  
  def send_data_to_all(data)
    Player.each do |player|
      send_data_to_game_object(player, data)
    end
  end
  
  def send_data_to_game_object(game_object, data)
    @socket.send(Marshal.dump(data), 0, game_object.client_ip, game_object.client_port)
    # @socket.send(data.to_msgpack, 0, game_object.client_ip, game_object.client_port)
  end  
  
  #
  # Send data for each client to all clients
  #
  def update_clients
    Player.alive.each do |game_object|
      Player.alive.each do |game_object2|
        send_data_to_game_object(game_object2, game_object.position_data)
      end
    end
  end
  
  def handle_data(data, sender)
    return unless data[:uuid]
    
    # Find existing player
    game_object = game_object_by_uuid(data[:uuid]) 
    
    # If we didn't an existing player, create new one. Only if max-players isn't reach.
    if game_object == nil
      return if game_objects.size >= @max_game_objects
      game_object = Player.create(data)
    end
    
    game_object.client_ip = sender[3]
    game_object.client_port = sender[1]
    
    puts "* #{data[:cmd].to_s}"
    
    case data[:cmd] 
      when :pong
        game_object.unanswered_packets = 0
      when :position 
        game_object.x = data[:x]
        game_object.y = data[:y]
      when :direction
        game_object.stop
        return  if  game_object.alive == false
        
        case data[:direction]
          when :right then game_object.velocity_x = 1
          when :left  then game_object.velocity_x = -1
          when :up    then game_object.velocity_y = -1
          when :down  then game_object.velocity_y = 1
        end
    end
  end    
end

# If fils is executed, not required.
if __FILE__ == $0
  Server.new.show
end
