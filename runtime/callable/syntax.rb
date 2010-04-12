module Rasp
  class Runtime
    class Syntax < Function
      def call(scope, cells)
        @body.call(scope, cells)
      end
    end
  end
end
