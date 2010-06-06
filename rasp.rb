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

  def self.sym(name)
    Runtime::Identifier.new(name)
  end

  def self.quote(form)
    [QUOTE, form]
  end

  def self.list(*args)
    [LIST, *args]
  end
  
  LIST             = self.sym("list")
  CONCAT           = self.sym("concat")
  QUOTE            = self.sym("quote")
  UNQUOTE          = self.sym("unquote")
  UNQUOTE_SPLICING = self.sym("unquote-splicing")

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
      Rasp.quote(elements[1].eval)
    end
  end

  class BackquotedCell < Treetop::Runtime::SyntaxNode
    def eval
      syntax_quote(elements[1].eval)
    end

    def syntax_quote(form)      
      if form.is_a? Runtime::Identifier
        Rasp.quote(form)
      elsif is_unquote?(form)
        form[1]
      elsif is_unquote_splicing?(form)
        raise "Splicing unquote (~@) was found outside a list."
      elsif form.is_a? Array
        [CONCAT] + expand_list(form)
        # *form.map{|f| convert(f)}
      else
        form
      end
    end

    def expand_list(list)
      ret = []

      list.each do |form|
        if is_unquote?(form)
          ret << Rasp.list(form[1])
        elsif is_unquote_splicing?(form)
          ret << form[1]
        else
          ret << Rasp.list(syntax_quote(form)) 
        end
      end

      ret
    end

    def is_unquote?(form)
      form.is_a?(Array) && form.first == UNQUOTE
    end

    def is_unquote_splicing?(form)
      form.is_a?(Array) && form.first == UNQUOTE_SPLICING
    end
  end
  
  class UnquotedCell < Treetop::Runtime::SyntaxNode
    def eval
      [UNQUOTE, elements[1].eval]
    end
  end
  
  class UnquotedSplicingCell < Treetop::Runtime::SyntaxNode
    def eval
      [UNQUOTE_SPLICING, elements[1].eval]
    end
  end

  class Number < Treetop::Runtime::SyntaxNode
    def eval
      text_value.to_i
    end
  end

  class Symbol < Treetop::Runtime::SyntaxNode
    def eval
      Rasp.sym(text_value)
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
      Rasp.list(*cells.map{|c| c.eval})
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
  value = tree.eval(runtime.user_scope)
end
