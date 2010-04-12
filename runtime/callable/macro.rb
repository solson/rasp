module Rasp
  class Runtime
    class Macro < Function
      def call(scope, cells)
        @body.call(scope, cells)
      end
    end
  end
end
