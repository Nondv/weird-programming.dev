module UtilFilter
  # This is just for testing purposes. NEVER use it outside localhost
  # Usage:
  # - {{ "@context.registers[:site].config['url']" | unsafe_eval | escape }}
  # - {{ "arg.class.inspect" | unsafe_eval: page | escape }}
  def unsafe_eval(input, arg = nil)
    eval(input)
  end
end

Liquid::Template.register_filter(UtilFilter)
