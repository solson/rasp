require 'rubygems'
require 'treetop'

Treetop.load 'rasp.treetop'

%w[runtime scope data/expression data/identifier callable/function callable/special callable/macro].each do |file|
  require File.join(File.dirname(__FILE__), 'runtime', file)
end

module Rasp
  def self.parse(string)
    @parser ||= RaspParser.new
    @parser.parse(string)
  end

  def self.evaluate(expression, scope)
    case expression
    when Array
      p expression if $DEBUG
      return [] if expression.size == 0

      callable = Rasp.evaluate(expression.first, scope)
      raise "Tried to call '#{callable}', but it has no 'call' method." unless callable.respond_to? :call

      args = expression[1..-1]

#      scope.runtime.stack << callable.to_s

      case callable
      when Runtime::Macro
        expansion = callable.call(args)
        puts "EXPANSION: #{expansion}" if $DEBUG
        self.evaluate(expansion, scope)
      when Runtime::Special
        callable.call(scope, args)
      when Runtime::Function
        callable.call(args.map{|arg| Rasp.evaluate(arg, scope)})
      else
        callable.call(*args)
      end

#      scope.runtime.stack.pop
    when Runtime::Expression
      expression.eval(scope)
    else
      expression
    end
  end

  class Program < Treetop::Runtime::SyntaxNode
    def eval(scope)
      convert!
      p @data if $DEBUG
      @data.map{|part| Rasp.evaluate(part, scope)}.last
    end

    def convert!
      @data ||= cells.map{|c| c.eval}
    end

    def cells
      elements
    end
  end

  class Cell < Treetop::Runtime::SyntaxNode
    def eval
      elements[1].eval
    end
  end

  class QuotedCell < Treetop::Runtime::SyntaxNode
    def eval
      [Runtime::Identifier.new("quote"), elements[1].eval]
    end
  end

  class Number < Treetop::Runtime::SyntaxNode
    def eval
      text_value.to_i
    end
  end

  class Symbol < Treetop::Runtime::SyntaxNode
    def eval
      Runtime::Identifier.new(text_value)
    end
  end

  class List < Treetop::Runtime::SyntaxNode
    def eval
      cells.map{|c| c.eval}
    end

    def cells
      elements[1].elements
    end
  end

  class Vector < Treetop::Runtime::SyntaxNode
    def eval
      [Runtime::Identifier.new("list"), *cells.map{|c| c.eval}]
    end

    def cells
      elements[1].elements
    end
  end

  class String < Treetop::Runtime::SyntaxNode
    def eval
      Kernel.eval(text_value)
    end
  end
end

if $0 == __FILE__
  runtime = Rasp::Runtime.new
  tree = Rasp.parse(ARGF.read)
  p tree
  value = runtime.user_scope.eval(tree)
  p value
end
