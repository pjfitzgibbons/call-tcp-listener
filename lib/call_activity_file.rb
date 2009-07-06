# This is not an ActiveRecord.  This model is used to handle reading/writing of raw
# CDRServer Loadmon data into memcache

# require 'rubygems'
require 'fileutils'
require 'logger'

require 'ruby-debug'

class CallActivityFile

  attr_reader :cache

  def initialize(options)
    @log = options[:logger] || Logger.new(STDOUT)

    # server_time_rx capture #1 is throwaway!, #2 = server, #3 = time
    @server_time_rx = /call_activity\|([[:alnum:]]+)\|([[:alnum:]]+)\|/
    if not ENV['CALL_FILE_PATH']
      raise ArgumentError, "Environment var CALL_FILE_PATH must be set"
    elsif not File.directory? ENV['CALL_FILE_PATH']
      raise ArgumentError, "CALL_FILE_PATH #{ENV['CALL_FILE_PATH']} is not found"
    end
  end


  def store(value)

    @data = value
    @time_s, @servername = time_server_from_data

    configure_file # time.to_i, servername
    @log.debug "Configured #{@servername} #{@time_s}"

    fd = nil
    begin
      @log.debug "#{Time.now.to_f} Appending #{@file_path}"
      fd = File.open(@file_path, 'a')
      fd.write value
    rescue Exception => e
      @log.error "#{e.class}:#{e.message}\n" + e.backtrace.join("\n")
    ensure
      fd.close
    end
    #close file
  end

  def time_server_from_data(data = nil)
    data ||= @data
    #get time, server out of data string
    # debugger
    server_time_match = @server_time_rx.match data

    [server_time_match[2], server_time_match[1]]
  end

  def self.time_server_from_data(data)
    new.time_server_from_data(data)
  end

  def self.cache_path(time_i)
    new.cache_file(time_i, '')[0]
  end

  def self.time_segment(time)
    time = Time.at time.to_i
    time = time - (time.sec % 15)
    time.utc
  end

  def cache_file(data = nil)
    data ||= @data
    @time_s, @servername = time_server_from_data(data)
    time = Time.at @time_s.to_i
    time_segment = time - (time.sec % 15)
    path_day, path_hour, path_minute = ["%Y-%m-%d", "%H", "%M.%S"].map {|fmt| time_segment.strftime(fmt)}

    [File.join(path_day, path_hour, path_minute), time_segment.strftime("%Y-%m-%d.%H.%M.%S-#{time.to_i}-#{@servername}.txt")]
  end

  def configure_file

    #get filename, path
    path, file = cache_file

    #ensure path
    full_path = File.expand_path(File.join(ENV['CALL_FILE_PATH'], path))
    FileUtils.mkdir_p File.expand_path(File.join(ENV['CALL_FILE_PATH'], path))

    @file_path = File.join(full_path, file)
  end

end
