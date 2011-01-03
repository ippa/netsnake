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
require 'yaml'
include Gosu
include Chingu
require_all './src/*'

class StartGame < Chingu::Window 
  def initialize
    super(600, 400, false)
    push_game_state(Client)
  end
end

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
