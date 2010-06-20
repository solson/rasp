module Rasp
  class Runtime
    class Special < Function
      def call(scope, params)
        @body.call(scope, params)
      end

      def to_s
        "#<Special:#{@name}>"
      end
      alias inspect to_s
    end
  end
end
