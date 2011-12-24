require "ultimate-flash/version"

module Ultimate
  module Flash
    module Rails
      if ::Rails.version < "3.1"
        require "ultimate-flash/railtie"
      else
        require "ultimate-flash/engine"
      end
    end
  end
end
