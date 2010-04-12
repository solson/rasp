module Rasp
  class Runtime
    class List
      include Expression
      attr_accessor :cells

      def initialize(cells)
        @cells = cells
      end

      def eval(scope)
        Rasp.evaluate(cells.first, scope).call(scope, cells[1..-1])
      end
    end
  end
end
