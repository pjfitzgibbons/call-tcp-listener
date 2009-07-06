
#require 'socket'
require 'rubygems'
require 'eventmachine'
require 'call_activity_file'
require 'logger'

usage = <<EOT
$0 usage:  $0 addr:port
addr:port = address and port for client to bind.  Notice wildcard addr not allowed.
  default addr = 'localhost', default port = 3000, all-defaults assumed if invalid input.

Environment Vars :

LOGGER_LEVEL (optional) : level for logging messages. Can be one of
  Logger::FATAL -	an unhandleable error that results in a program crash
  Logger::ERROR -	a handleable error condition
  Logger::WARN  -	a warning (default)
  Logger::INFO  -	generic (useful) information about system operation
  Logger::DEBUG -	low-level information for developers


EOT


@log = Logger.new('log/tcp_listener.log')
if ENV["LOGGER_LEVEL"] and ENV["LOGGER_LEVEL"] =~ /^Logger::/
  @log.level = eval(ENV["LOGGER_LEVEL"])
else
  @log.level = Logger::WARN
end

@log.add @log.level, "Logger level is #{@log.level}"

def process_args
  if ARGV[0] =~ /.*:\d*/
    @listen_addr, @port = ARGV[0].split(':')
    @listen_addr ||= 'localhost'
    @port ||= 3000
  else
    @listen_addr, @port = 'localhost', '3000'
  end

  if not ENV['CALL_FILE_PATH']
    raise ArgumentError, "Environment var CALL_FILE_PATH must be set"
  elsif not File.directory? File.expand_path(ENV['CALL_FILE_PATH'])
    raise ArgumentError, "CALL_FILE_PATH #{ENV['CALL_FILE_PATH']} is not found"
  end

  @log.warn "Using call-file path #{File.expand_path(ENV['CALL_FILE_PATH'])}"

  @log.warn "Starting server listening on #{@listen_addr}:#{@port}"
end

process_args

module CallActivityTcpListener

  def post_init
    @log = Logger.new('log/tcp_listener.log')
    if ENV["LOGGER_LEVEL"] and ENV["LOGGER_LEVEL"] =~ /^Logger::/
      @log.level = eval(ENV["LOGGER_LEVEL"])
    else
      @log.level = Logger::WARN
    end

    @call_activity_file = CallActivityFile.new :logger => @log

  end
  def receive_data(data)
    @log.debug "data #{data.size} bytes like #{data[0..20]}..#{data[-20..-1]}"

    begin
      (@buffer ||= BufferedTokenizer.new("`")).extract(data).each do |line|
        @log.debug "data #{line.size} bytes #{line[0..10]}..#{line[-10..-1]}"

        @call_activity_file.store line

        #Report cache-file in log when it changes
        cache_file = @call_activity_file.cache_file[1]
        if not @cache_file or @cache_file != cache_file
          @cache_file = cache_file
          @log.info @cache_file
        end

        send_data "OK`"
      end
    rescue Exception => e
      @log.error "#{e.class}:#{e.message}\n" + e.backtrace.join("\n")
    end

  end

end

EM.run {
  EM.start_server @listen_addr, @port.to_i, CallActivityTcpListener
}
