#
#
#
class Server < Chingu::GameState
  trait :timer
  
  def initialize
    super
    
    @sockets = []
    @ip = "0.0.0.0"
    @port = 7778
    
    begin
      @socket = TCPServer.new(@ip, @port)
      @socket.setsockopt(Socket::IPPROTO_TCP,Socket::TCP_NODELAY,1)
      puts "* Server listening on #{@ip} port #{@port}"
    rescue 
      puts "Can't start server on #{@ip} port #{@port}. Exiting."
      puts $!
      exit
    end
    
    @width = 600
    @height = 400
    @level_array = Array.new(@width) { Array.new(@height) }
    @max_players = 4
    
    # x, y, velocity_x, velocity_y
    @start_positions = [ 
                       [10, 10, 1, 0],
                       [@width-10,@height-10,-1,0],
                       [@width-10,10,-1,0],
                       [10,@height-10,1,0]
                       ]
    @colors = [:red, :blue, :yellow, :green]
  end
    
  def update    
    
    begin
      socket = @socket.accept_nonblock
      (Player.size >= @max_players) ? socket.close : new_player_from_socket(socket)
    rescue IO::WaitReadable, Errno::EINTR
    end
    
    Player.each do |player|    
      if IO.select([player.socket], nil, nil, 0.0)
        begin
          packet, sender = player.socket.recvfrom(1000)
          data = YAML.load(packet)
          #data = JSON.parse(packet)
          handle_data(player, data) if data
        rescue Errno::ECONNABORTED, Errno::ECONNRESET
          puts "* Player #{player.uuid} disconnected"
          player.destroy
        end
      end
    end
    
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
        puts "* player #{player.uuid} died"
        
        packet = []
        packet << {:cmd => :kill, :uuid => player.uuid, :x => player.x, :y => player.y}
        

        if Player.alive.size == 1
          winner = Player.alive.first
          puts "* Winner: #{winner}"
          
          packet << {:cmd => :winner, :uuid => winner.uuid}
          send_data_to_all(packet)
          
          sleep(0.5)
          
          restart
        else
          send_data_to_all(packet)
        end
      end
    end
    
    # All players dead, restart level
    if Player.size > 0 && Player.alive.size == 0
      restart
    else
      Player.alive.each { |player| @level_array[player.x][player.y] = true }
      update_clients
    end
        
  end
  
  def restart
    puts "* Restarting game ..."
    sleep 0.5
    send_data_to_all({:cmd => :restart})
    sleep 0.5
    @level_array = Array.new(@width) { Array.new(@height) }
    restart_players
  end
  
  def restart_players
    Player.each_with_index do |player, index|
      player.alive = true    
      player.start_position = index
      player.x = @start_positions[index][0]
      player.y = @start_positions[index][1]
      player.velocity_x = @start_positions[index][2]
      player.velocity_y = @start_positions[index][3]
      puts "Started player #{player.uuid} @ postion ##{index}"
    end
  end  
  
  def collision_at?(x,y)
    @level_array[x][y]
  end
  
  def send_data_to_all(data)
    Player.each { |player| send_data_to_player(player, data) }
  end
  
  def send_data_to_player(player, data)
    begin
      #player.socket.puts(data.to_json)
      player.socket.puts(data.to_yaml)
      player.socket.flush
    rescue Errno::ECONNABORTED, Errno::ECONNRESET, Errno::EPIPE
      puts "* Player #{player.uuid} disconnected"
      player.destroy
    end
  end
  
  #
  # Send data for each client to all clients
  #
  def update_clients
    if Player.size > 0
      all_players = []
      big_update = Player.all.collect { |player| player.position_data }
      send_data_to_all(big_update)
    end
  end
  
  def new_player_from_socket(socket)
    player = Player.create
    player.color = (@colors - Player.all.collect{|player| player.color}).first
    
    player.socket = socket
    puts "* New player: #{socket.inspect}"
    
    # If 0 or 1 players, restart game and go
    # If 2+ ppl are playing, new player has to wait
    (Player.size > 2) ? (player.alive = false) : restart_players
    return player
  end
  
  def handle_data(player, data)
    return unless data[:uuid]
        
    puts "-> #{data[:cmd].to_s} from #{data[:uuid]}"
    
    case data[:cmd]
      when :start
        player.uuid = data[:uuid]
      when :pong
        player.unanswered_packets = 0
      when :position 
        player.x = data[:x]
        player.y = data[:y]
      when :direction
        player.stop
        return  if  player.alive == false
        
        case data[:direction]
          when :right then player.velocity_x = 1
          when :left  then player.velocity_x = -1
          when :up    then player.velocity_y = -1
          when :down  then player.velocity_y = 1
        end
    end
  end
end

# If fils is executed, not required.
if __FILE__ == $0
  Server.new.show
end
