module Rasp
  class Runtime
    attr_accessor :top_level, :user_scope

    def initialize
      @top_level = Scope.new(self)
      @user_scope = Scope.new(@top_level)

      Runtime.define_builtins(@top_level)
    end

    def self.define_builtins(scope)
      # This is the Ruby const_get function. Important for Ruby interop.
      scope.syntax('::') do |scope, cells|
        case cells.count
        when 0
          raise "Must give at least one argument to the '::' function."
        when 1
          Object.const_get(cells[0].to_s)
        when 2
          Rasp.evaluate(cells[0], scope).const_get(cells[1].to_s)
        else
          raise "Too many arguments given to the '::' function."
        end
      end

      # This is the Ruby 'send' function. Very important for Ruby interop.
      scope.syntax('.') do |scope, cells|
        raise "Must give at least one argument to the '.' function." if cells.count < 1
        Rasp.evaluate(cells[0], scope).__send__(cells[1].cells[0].to_s, *cells[1].cells[1..-1].map{|cell| Rasp.evaluate(cell, scope)})
      end

      scope.syntax('def') do |scope, cells|
        name = cells[0]
        scope[name] = Rasp.evaluate(cells[1], scope)
      end

      scope.syntax('fn') do |scope, cells|
        Function.new(scope, cells[0], cells[1..-1])
      end
    end
  end
end
