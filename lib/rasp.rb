require 'rubygems'
require 'treetop'

Treetop.load(File.join(File.dirname(__FILE__), 'rasp.treetop'))

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

      expression = Rasp.macroexpand(expression, scope)

      callable = Rasp.evaluate(expression.first, scope)
      raise "Tried to call '#{callable}', but it has no 'call' method." unless callable.respond_to? :call

      args = expression[1..-1]

      case callable
      when Runtime::Special
        callable.call(scope, args)
      when Runtime::Function
        callable.call(args.map{|arg| Rasp.evaluate(arg, scope)})
      else
        callable.call(*args.map{|arg| Rasp.evaluate(arg, scope)})
      end
    when Runtime::Expression
      expression.eval(scope)
    else
      expression
    end
  end

  def self.macroexpand_1(form, scope)
    return form unless form.is_a?(Array)

    first = form.first

    # rescue nil because scope will raise an exception if the var
    # isn't found
    val = scope[first] rescue nil
    if val.is_a? Runtime::Special
      form
    elsif val.is_a? Runtime::Macro
      val.call(form[1..-1])
    elsif first.is_a?(Runtime::Identifier) && first.name[0,1] == "."
      raise "Method call expression badly formed, expecting (.method object ...)" if form.length < 2

      [DOT, form[1], Rasp.sym(first.name[1..-1]), *form[2..-1]]
    else
      form
    end
  end

  def self.macroexpand(form, scope)
    exp = Rasp.macroexpand_1(form, scope)
    if exp == form
      form
    else
      Rasp.macroexpand(exp, scope)
    end
  end

  def self.next_gensym_id
    @@gensym_id ||= 1
    
    id = @@gensym_id
    @@gensym_id += 1
    id
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

  DOT              = self.sym(".")
  AMP              = self.sym("&")
  FN               = self.sym("fn")
  LIST             = self.sym("list")
  CONCAT           = self.sym("concat")
  QUOTE            = self.sym("quote")
  UNQUOTE          = self.sym("unquote")
  UNQUOTE_SPLICING = self.sym("unquote-splicing")

  class Program < Treetop::Runtime::SyntaxNode
    def eval(scope)
      convert!
      p @data if $DEBUG
      @data.map{|part| Rasp.evaluate(part, scope)}
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
    def initialize(*args)
      super
      @gensyms = {}
    end

    def gensym(name)
      @gensyms[name] ||= Rasp.sym(name + "__" + Rasp.next_gensym_id.to_s + "__auto__")
    end
    
    def eval
      syntax_quote(elements[1].eval)
    end

    def syntax_quote(form)      
      if form.is_a? Runtime::Identifier
        if form.name.end_with? "#"
          form = gensym(form.name[0..-2])
        end
        Rasp.quote(form)
      elsif is_unquote?(form)
        form[1]
      elsif is_unquote_splicing?(form)
        raise "Splicing unquote (~@) was found outside a list."
      elsif form.is_a? Array
        [CONCAT, *expand_list(form)]
      else
        form
      end
    end

    def expand_list(list)
      list.map do |form|
        if is_unquote?(form)
          Rasp.list(form[1])
        elsif is_unquote_splicing?(form)
          form[1]
        else
          Rasp.list(syntax_quote(form)) 
        end
      end
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

  class AnonymousFunc < Treetop::Runtime::SyntaxNode
    def initialize(*args)
      super
      @gensyms = {}
      @highest_arg = 0
      @rest_arg = false
    end

    def gensym(name)
      @gensyms[name] ||= Rasp.sym(name + "__" + Rasp.next_gensym_id.to_s)
    end
    
    def eval
      translated_body = translate_argument(body)
      [FN, create_arg_list, translated_body]
    end

    # change %n arguments to real gensym-named arguments
    def translate_argument(form)
      if form.is_a?(Runtime::Identifier) && form.name.start_with?('%')
        s = form.name[1..-1]
        case s
        when '' # handle % without a number as %1
          @highest_arg = [1, @highest_arg].max
          gensym("p1")
        when '0'..'9'
          @highest_arg = [s.to_i, @highest_arg].max
          gensym("p#{s}")
        when '&'
          @rest_arg = true
          gensym("rest")
        else
          raise "Arg literal '#{form.name}' is bad. Must be %, %&, or %integer."
        end
      elsif form.is_a?(Array)
        form.map{|f| translate_argument(f) }
      else
        form
      end
    end

    def create_arg_list
      arg_list = (1..@highest_arg).map do |arg|
        gensym("p#{arg}")
      end
      arg_list << AMP << gensym("rest") if @rest_arg
      arg_list
    end

    def body
      elements[1].eval
    end
  end

  class Number < Treetop::Runtime::SyntaxNode
    def eval
      text_value.to_i
    end
  end

  class Keyword < Treetop::Runtime::SyntaxNode
    def eval
      elements[1].text_value.intern
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
