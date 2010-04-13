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
    p expression

    case expression
    when Array
      return [] if expression.size == 0
      Rasp.evaluate(expression.first, scope).call(scope, expression[1..-1])
    when Runtime::Expression
      expression.eval(scope)
    else
      expression
    end
  end

  class Program < Treetop::Runtime::SyntaxNode
    def eval(scope)
      convert!
      @data.map{|part| Rasp.evaluate(part, scope)}.last
    end

    def convert!
      @data ||= cells.map{|c| c.eval}
    end

    def cells
      elements.map{|e| e.elements[1]}
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
      elements[1].elements.map{|e| e.elements[1]}
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
