$LOAD_PATH.unshift(File.join(File.dirname(__FILE__)))
require 'rasp'
require 'readline'

module Rasp
  class REPL
    attr_accessor :runtime

    HISTORY_FILE = "~/.rasp-history"

    def initialize(runtime = Runtime.new)
      @runtime = runtime
    end

    def repl
      # Load the history
      load_history
      # Store the state of the terminal
      stty_save = `stty -g`.chomp
      
      loop do
        begin
          line = readline_history
          break unless line
          p @runtime.eval(line)
        rescue RuntimeError => e
          puts 'Error: ' + e.message
        rescue Interrupt
          puts
        end
      end
      puts # Add a newline after C-d
    ensure
      # Save the history
      save_history
      # Restore the terminal
      system('stty', stty_save)
    end

    def load_history
      history_file = File.expand_path(HISTORY_FILE)
      if File.exist?(history_file)
        File.open(history_file) do |f|
          f.each{|line| Readline::HISTORY << line.chomp}
        end
      end
    end

    def save_history
      history_file = File.expand_path(HISTORY_FILE)
      File.open(history_file, "w") do |f|
        hist = Readline::HISTORY.to_a
        f.puts(hist[-1000..-1] || hist)
      end
    end

    #
    # Smarter Readline to prevent empty and dups
    #   1. Read a line and append to history
    #   2. Quick Break on nil
    #   3. Remove from history if empty or dup
    #
    def readline_history
      line = Readline.readline('Rasp> ', true)
      return nil if line.nil?
      if line =~ /^\s*$/ or Readline::HISTORY.to_a[-2] == line
        Readline::HISTORY.pop
      end
      line
    end
  end
end
