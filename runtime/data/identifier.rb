module Rasp
  class Runtime
    class Identifier
      include Expression
      attr_accessor :name

      def initialize(name)
        @name = name
      end

      def to_s
        @name
      end
      alias inspect to_s

      def eval(scope)
        scope[self]
      end
    end
  end
end
