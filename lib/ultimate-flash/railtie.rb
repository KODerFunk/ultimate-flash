# Configure Rails 3.0 to use public/javascripts/ultimate/flash et al
    module Ultimate
      module Flash

    class Railtie < ::Rails::Railtie
      config.before_configuration do
        config.action_view.javascript_expansions[:defaults] << 'ultimate/flash'
      end
    end

  end
end
