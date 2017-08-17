# ********** Copyright 2016 Viacom, Inc. Apache 2.0 **********

module Git
  class Stashes
    def pop(index=nil)
      @base.lib.stash_pop(index)
    end
    def drop(index=nil)
      @base.lib.stash_drop(index)
    end
  end
  class Lib
    def stash_pop(id = nil)
      if id
        command('stash pop', [id])
      else
        command('stash pop')
      end
    end
    def stash_drop(id = nil)
      if id
        command('stash drop', [id])
      else
        command('stash drop')
      end
    end
  end
end
