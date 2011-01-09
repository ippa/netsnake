class Client < Chingu::GameState
  trait :timer
    
  def initialize(options = {})
    super
    
    #@ip = options[:ip] || "192.168.0.1"
    @ip = options[:ip] || "127.0.0.1"
    @port = 7778
    
    unless @ip
      puts "No serverIP given, please snart netsnake like this:"
      puts "ruby netsnake.rb <ip of server>"
      exit
    end
        
    self.input = [:esc, :left, :right, :up, :down]

    @socket = nil
    
    @level_image = TexPlay.create_blank_image($window, $window.width, $window.height, :color => :black)
    @level = GameObject.create(:image => @level_image, :rotation_center => :top_left, :factor => $window.factor, :zorder => 10)
    @player = Player.create(:uuid => (rand * 100000).to_i)
    @player.alive = false
    @packet_counter = 0
    @latency = nil
    @packet_buffer = ""
    
    connect_to_server
  end
  
  def ping
    send_data( {:uuid => @player.uuid, :cmd => :ping, :milliseconds => Gosu::milliseconds} )
  end
    
  def connect_to_server
    return if @socket
    
    begin
      $window.caption = "Connecting to #{@ip}:#{@port} ... "
      status = Timeout::timeout(4) do
        @socket = TCPSocket.new(@ip, @port)
        @socket.setsockopt(Socket::IPPROTO_TCP,Socket::TCP_NODELAY,1)
        send_data(@player.start_data)
        ping; every(6000, :name => :ping) { ping }
      end
    rescue Errno::ECONNREFUSED
      $window.caption = "Server: CONNECTION REFUSED, retrying in 3 seconds..."
      after(3000) { connect_to_server }
    rescue Timeout
      $window.caption = "Server: CONNECTION TIMED OUT, retrying in 3 seconds..."
      after(3000) { connect_to_server }
    end
  end
  
  def send_data(data)
    @socket.puts(data.to_yaml)
  end
  
  def read_network
    return unless @socket
    
    if IO.select([@socket], nil, nil, 0.0)
      begin
        packet, sender = @socket.recvfrom(1000)        
        begin
          packets = packet.split("--- ")          
          if packets.size > 1
            @packet_buffer << packets[0...-1].join("--- ")
            YAML::load_documents(@packet_buffer) { |doc| on_packet(doc) }
            @packet_buffer = packets.last
          else
            @packet_buffer << packets.join
          end
        rescue ArgumentError
          puts "!! bad yaml !!\n#{packet}"
        end
        
      rescue Errno::ECONNABORTED
        puts "* Server disconnected"
        connect_to_server
      end
    end    
  end
    
  def update
    super
    
    read_network
        
    Player.alive.each do |player|
      @level_image.line(player.previous_x, player.previous_y, player.x, player.y, :color => player.color)
      #@level_image.pixel(player.x, player.y, :color => player.color)
    end
    
    $window.caption = "Netsnake! #{@player.alive ? "Alive! :-) " : "Dead X-/"}  Ping: #{@latency}ms   UUID: #{@player.uuid}  Players: #{Player.size}  FPS: #{$window.fps}" if @socket
  end
    
  def on_packet(data)
    @packet_counter += 1
    
    if data[:uuid]
      player = Player.find_by_uuid(data[:uuid]) || Player.create(data)
      
      case data[:cmd]
        when :winner
          if @player.uuid == data[:uuid]
            PuffText.create("YOU WON!")
          else
            PuffText.create("You LOST! #{data[:alias]||data[:uuid]} won.")
          end
        when :position
          player.x, player.y = data[:x], data[:y]
          player.previous_x, player.previous_y = data[:previous_x], data[:previous_y]
          player.color = data[:color]
          player.alive = true
        when :destroy
          puts "Destroy: #{player.uuid}"
          player.destroy
        when :kill
          puts "* Kill: #{player.uuid} died @ #{data[:x]}/#{data[:y]}"
          player.alive = false
        when :restart
          player.alive = false
          restart
        when :ping
          send_data( {:cmd => :pong, :uuid => player.uuid, :milliseconds => data[:milliseconds]} )
        when :pong
          @latency = (Gosu::milliseconds - data[:milliseconds])
          #puts "PONG from SERVER, latency #{@latency}"          
        end
    #else
      #case data[:cmd]
        #when :ping
        #  send_data( {:cmd => :pong, :uuid => player.uuid, :milliseconds => data[:milliseconds]} )
        #when :pong
        #  @latency = (data[:milliseconds] - Goso::milliseconds)
        #  puts "PONG from SERVER, latency #{@latency}"
        #when :restart
        #  puts "* Restart"
        #  Player.each { |player| player.alive = false }
        #  restart   
      #end
      #end
    end
  end

  def esc
    exit
  end
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
