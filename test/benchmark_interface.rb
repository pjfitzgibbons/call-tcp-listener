# == Synopsis
#
# tcp-listener-benchmark: benchmark or pseudo-post to CC-Loadmon-Listener
#
# == Usage
#
# tcp-listener-benchmark [OPTIONS] server:addr
#
# -h, --help:
#    show help
#
# --servers i:
#    number of servers to emulate, (default: 3)
#
# --dniss i:
#    number of pseudo-dnis to send with each post per server, (default: 10)
#
# --continuous:
#    send pseudo-data to CC-Loadmon-Listener every 15 sec., (default)
#    excludes --benchmark
#
# --benchmark:
#    send all possible pseudo-data as quickly as possible (multi-threaded)
#    excludes --continuous
#
# --iterations:
#    number of 15-sec time-segments to send during --benchmark burst-test
#    (default: 20)
#
#

begin #requires
  require 'net/http'
  require 'uri'
  require 'benchmark'

  require 'socket'

  # require 'digest/sha1'
  require 'fileutils'   # for mkdir, etc.
  require 'getoptlong'  # for cmdline options parsing
  require 'rdoc/usage'  # for fancy cmdline help display
  require 'logger'

  require 'rubygems'
  require 'ruby-debug'

  require 'call_activity_file'
  require 'array_extension'
  require 'tcp_test_client'
end

begin #GetOptLong
  opts = GetoptLong.new(
    [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
    [ '--servers', GetoptLong::OPTIONAL_ARGUMENT ],
    [ '--continuous', GetoptLong::NO_ARGUMENT ],
    [ '--benchmark', GetoptLong::NO_ARGUMENT ],
    [ '--dniss', GetoptLong::OPTIONAL_ARGUMENT ]
  )


  #set default options
  @options = {
    :servers => 3, :dniss => 10, :mode => :continuous, :logfile => STDOUT, :iterations => 20
  }
  opts.each do |opt, arg|
    case opt
    when '--help'
      RDoc::usage # displays the RDoc style documentation at the top of the file.
      exit
    when '--servers'
      @options[:servers] = arg.to_i
    when '--dniss'
      @options[:dniss] = arg.to_i
    when '--continuous'
      @options[:mode] = :continuous
    when '--benchmark'
      @optoins[:mode] = :benchmark
    when '--iterations'
      @options[:iterations] = arg.to_i
    when '--logfile'
      @options[:logfile] = arg
    end
  end

  log = Logger.new(@options[:logfile])
  if ENV["LOGGER_LEVEL"] and ENV["LOGGER_LEVEL"] =~ /^Logger::/
    log.level = eval(ENV["LOGGER_LEVEL"])
  else
    log.level = Logger::WARN
  end
  log.add log.level, "Logger level is #{log.level}"
  @options[:log] = log


  if ARGV[0] =~ /.*:\d*/

    server, port = ARGV[0].split(':')
    server ||= 'localhost'
    port ||= 3000
    @options.merge! :server => server, :port => port
  else
    RDoc::usage; exit
  end


end

client = TcpTestClient.new(@options)

client.collect_interval_data if @options[:mode] == :benchmark

client.post_dnis_data
