# ********** Copyright 2016 Viacom, Inc. Apache 2.0 **********

class ::Hash
  def deep_merger
    merger = proc { |_key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2  }
  end
  def deep_merge(second)
    self.merge(second, &deep_merger)
  end
  def deep_merge!(second)
    self.merge!(second, &deep_merger)
  end
  def deep_dup
    Marshal.load(Marshal.dump(self))
  end
end
