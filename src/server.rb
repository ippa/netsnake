#
#
#
class Server < Chingu::GameState
  include Network
  trait :timer
  
  def initialize
    super
    
    @ip = "0.0.0.0"
    @port = 7778
    begin
      @socket = UDPSocket.new
      @socket.bind(@ip, @port)
      puts "* UDP-server listening on #{@ip} port #{@port}"
    rescue
      puts "Can't start UDP-server on #{@ip} port #{@port}. Exiting."
      exit
    end
    
    @width = 600
    @height = 400
    @level_array = Array.new(@width) { Array.new(@height) }
    @max_game_objects = 4
        
    # x, y, velocity_x, velocity_y
    @player_start_positions = [ [10, 10, 1, 0],
                                [@width-10,10,-1,0],
                                [10,@height-10,1,0],
                                [@width-10,@height-10,-1,0]
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
      player.x = 0          if player.x > @width-1
      player.x = @width-1   if player.x < 0
      player.y = 0          if player.y > @height-1
      player.y = @height-1  if player.y < 0
      
      # collide with other snakes
      if player.alive == true && collision_at?(player.x, player.y)
        player.stop
        player.alive = false
        send_data_to_all({:cmd => :kill, :uuid => player.uuid, :x => player.x, :y => player.y})
        puts "* player #{player.uuid} died"
      end      
    end
    
    # All players dead, restart level!
    if Player.size > 0 && Player.alive.size == 0
      restart
    end
      
    Player.each { |player| @level_array[player.x][player.y] = true }
    
    update_clients
  end
  
  def restart
    puts "* Restarting game"
    send_data_to_all({:cmd => :restart})
    @level_array = Array.new(@width) { Array.new(@height) }
    Player.all.each_with_index do |player, index|
      player.alive = true
      player.x = @player_start_positions[index][0]
      player.y = @player_start_positions[index][1]
      player.velocity_x = @player_start_positions[index][2]
      player.velocity_y = @player_start_positions[index][3]
    end
  end
  
  def collision_at?(x,y)
    @level_array[x][y]
  end
  
  def send_data_to_all(data)
    Player.each do |player|
      send_data_to_player(player, data)
    end
  end
  
  def send_data_to_player(player, data)
    @socket.send(Marshal.dump(data), 0, player.client_ip, player.client_port)
    @socket.flush
  end  
  
  #
  # Send data for each client to all clients
  #
  def update_clients
    Player.alive.each do |game_object|
      Player.alive.each do |game_object2|
        send_data_to_player(game_object2, game_object.position_data)
      end
    end
  end
  
  def handle_data(data, sender)
    return unless data[:uuid]
    
    # Find existing player
    game_object = Player.find_by_uuid(data[:uuid]) 
    
    # If we didn't an existing player, create new one. Only if max-players isn't reach.
    if game_object == nil
      return if game_objects.size >= @max_game_objects
      game_object = Player.create(data)
      puts "* New player: #{data[:uuid]}"
    end
    
    game_object.client_ip = sender[3]
    game_object.client_port = sender[1]
    
    puts "-> #{data[:cmd].to_s} from #{data[:uuid]}"
    
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
