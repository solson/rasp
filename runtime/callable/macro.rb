module Rasp
  class Runtime
    class Macro < Function
      def to_s
        "#<Macro:#{@name}>"
      end
      alias inspect to_s
    end
  end
end
