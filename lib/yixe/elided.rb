module Yixe # :nodoc:
  # Wraps a value so it's not listed when inspecting (for example with +pp+)
  class Elided
    def initialize(value)
      @value = value
    end

    def __value()
      @value
    end

    def __inspect()
      @value.inspect()
    end

    def inspect()
      "(Elided: #{@value.class.name})"
    end

    def method_missing(*args, **kw)
      @value.send(*args, **kw)
    end

    def respond_to_missing?(name, include_private)
      @value.respond_to?(name, include_private) || super
    end
  end
end
