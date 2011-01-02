begin
  require '../chingu/lib/chingu'
rescue LoadError
  require 'chingu'
end
require 'socket'
require 'texplay'
require 'msgpack'
include Gosu
include Chingu
require './actor'
require './network'
require './server'
require_all './game_states/*'

class Game < Chingu::Window 
  def initialize(options = nil)
    self.factor = 1
    retrofy
    #super(600, 400, false, 33.33)
    super(600, 400, false)
    self.input = {:esc => :exit}
    push_game_state(Server)    
  end
end

# If fils is executed, not required.
if __FILE__ == $0
  Game.new.show
end
