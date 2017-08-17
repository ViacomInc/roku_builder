# ********** Copyright 2016 Viacom, Inc. Apache 2.0 **********

class ::String
  def underscore!
    word = self
    word.gsub!(/::/, '/')
    word.gsub!(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
    word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
    word.tr!("-", "_")
    word.downcase!
    nil
  end

  def underscore
    word = self.dup
    word.underscore!
    word
  end
end

