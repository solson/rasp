module Rasp
  class Runtime
    class Identifier
      include Expression
      attr_accessor :name

      def initialize(name)
        @name = name.to_s
      end

      def to_s
        @name
      end
      
      def inspect
        "'" + @name
      end

      def ==(other)
        other.is_a?(Identifier) && @name == other.name
      end

      def eval(scope)
        scope[@name]
      end
    end
  end
end
