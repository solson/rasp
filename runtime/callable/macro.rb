module Rasp
  class Runtime
    class Macro < Function
      def call(scope, params)
      end

      def to_s
        "#<Macro:#{@name}>"
      end
      alias inspect to_s
    end
  end
end
