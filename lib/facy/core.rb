module Facy
  module Core
    def config
      @config ||= {}
    end

    def inits
      @inits ||= []
    end

    def init(&block)
      inits << block
    end

    def _init
      load_config
      login_flow
      inits.each { |block| class_eval(&block) }
      log(:info, "core module init success")
    end

    def load_config
      config.reverse_update(default_config)
      log(:info, "config loaded #{config.to_s}")
    end

    def default_config
      config = YAML.load_file(File.expand_path("../../../config.yml", __FILE__))
      {
        session_file_folder: "/tmp",
        session_file_name: ".facy_access_token.yml",
        log_folder: "/tmp",
        log_file_name: ".facy_log",
        app_id: config['app_id'],
        app_secret: config['app_secret'],
        permission: config['permission'],
        granted: config['granted'],
        redirect_uri: "http://www.facebook.com/connect/login_success.html",
        prompt: "\e[15;48;5;27m f \e[0m >> ",
        stream_fetch_interval: 2,
        notification_fetch_interval: 2,
        output_interval: 3,
        retry_interval: 2,
        comments_view_num: 10,
      }
    end

    def start(options={})
      _init      

      EM.run do
        Thread.start do
          while buf = Readline.readline(config[:prompt], true) 
            execute(buf.strip)
          end
        end

        Thread.start do
          EM.add_periodic_timer(config[:stream_fetch_interval]) do
            facebook_stream_fetch
          end
        end
        
        Thread.start do
          EM.add_periodic_timer(config[:output_interval]) do
            periodic_output 
          end
        end

        Thread.start do
          EM.add_periodic_timer(config[:notification_fetch_interval]) do
            facebook_notification_fetch
          end
        end

        Signal.trap("INT")  { stop_process }
        Signal.trap("TERM") { stop_process }
      end
    end

    def mutex
      @mutex ||= Mutex.new
    end

    def sync(&block)
      mutex.synchronize do
        block.call
      end
    end

    def async(&block)
      Thread.start { block.call }
    end

    def stop_process
      puts "\nfacy going to stop..."
      Thread.new {
        EventMachine.stop 
      }.join
    end
  end

  extend Core
end
