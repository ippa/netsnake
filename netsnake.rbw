#
# NetSnake by ippa (http://ippa.se/gaming)
# (C) 2010
#
#
#
#
begin
  require '../chingu/lib/chingu'
rescue LoadError
  require 'chingu'
end

require 'socket'
require 'json'
require 'yaml'
require 'timeout'
include Gosu
include Chingu
require_all './src/*'

#
# Client
#
class StartGame < Chingu::Window 
  attr_accessor :server
  
  def initialize
    super(600, 400, false)
    on_input(:esc, :pop_game_state)
    
    @server = "192.168.0.1"
    #push_game_state(Menu)
    push_game_state(Client.new(:ip => ARGV.first))
  end
end

#
# Server
#
class StartServer < Chingu::Console
  def setup
    push_game_state(Server)
  end
end

# If fils is executed, not required.
if __FILE__ == $0
  if ARGV.first == "server"
    StartServer.new.show
  else
    require 'texplay'
    StartGame.new.show
  end
end
