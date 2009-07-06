class TcpTestClient

  def initialize(args)
    @options = args

    @log = @options[:log]

    # @dnis_count = 300 -- use options[:dniss]
    # @test_threads = 5 -- use options[:servers]

    @interval = 2 * minutes # 2 * hours
    # @read_interval = 2 * minutes
    @segment = 15 #15 seconds

    @time = Time.now.to_i - @interval
    #  @intervals = @interval / @segment
    # @interval_count = 10 -- use options[:iterations]

    @msg_size_max = 16384 # 16K

    @servers = (1..@options[:servers]).map {|s| "server#{s}"}

    @intervals = (1..@options[:iterations]).map {|i| time_s_from_interval(i) }

    @log.warn 'Initialize random counts array'
    @counts = (1..100).map { rand(99).to_s }

    @log.warn 'Initialize hostname/dnis array'
    @dniss = []
    (1..@options[:dniss]).each do |i|
      s = "800555" + ("%04d" % i)
      @dniss << {:dnis => s}
    end
  end

  def client_post(conn,data)
    @log.debug "#{Thread.current} #{data.size} data to send"
    results = []
    data.each_with_index do |msg, i|
      sent = conn.write msg #, 0;  # using write instead of puts... no CRLF
      recv = conn.recv(16 * 1024)
      results << "sent #{i}:#{msg.size} #{sent}  recv #{recv}"
    end
    return results.join("\n")
  end


  def data_for_time_segment(time_s, servername)
    data = []

    msg = ""
    @dniss.each do |dnis|
      # @dniss.each do |dnis|
      count_idx = rand(97) #two less than max index so we can pick 3
      #
      #  call_activity
      #  =============
      #  This record has the format:
      #
      #    call_activity|%s|%ld|%s|%d|%d|%d|%d}
      #          0       1   2  3  4  5  6  7
      #  The format specifiers correspond to :
      #
      #    0 'call_activity'
      #    1 hostname,
      #    2 timestamp,
      #    3 DNIS,
      #    4 direction of call (direction codes),
      #    5 no of active calls for that dnis,
      #    6 no of completed calls to the DNIS that ended in the interval T --> T+N,
      #    7 total duration of all calls to DNIS that ended in the interval T --> T+N.
      #
      #    direction codes =>  0:internal,1:inbound,2:outbound
      #

      val = "call_activity|#{servername}|#{time_s}|#{dnis[:dnis]}|0|" + @counts[count_idx..count_idx+2].join('|') + '}'
      if msg.length + val.length < @msg_size_max
        msg << val
      else
        msg << "`" ## <===  The Backtick
        data << msg
        msg = val
      end
    end
    if msg.length > 0
      msg << "`"  ## <===  The Backtick
      data << msg
    end
    count = data.inject(0) {|sum, d| sum += d.split('}').size }
    @log.info "data for segment #{time_s} #{data.size} messages with #{count} records "
    return data
  end

  def collect_interval_data
    @log.warn "Collect data for every interval"
    # @intervals = []
    if File.exists?('interval_data.txt')
      @log.warn "Loading data from interval_data.txt"
      intervals = []
      File.open('interval_data.txt','r') do |interval_data_file|
        break if interval_data_file.eof?
        intervals = Marshal.load(interval_data_file.gets)
        interval_data = Marshal.load(interval_data_file.read)
      end
      if intervals.size == @intervals.size and interval_data.size == (@intervals.size * @servers.size)
        @intervals, @interval_data = intervals, interval_data
        # return
      end
    end

    unless @intervals.size > 0
      # debugger
      @log.warn "Manufacturing data for interval_data.txt\n#{@servers}\n#{@intervals}"
      @interval_data = []
      @servers.each do |server|
        @intervals.each_with_index do |time_s, i|
          k,v = "#{time_s}:#{server}", data_for_time_segment(time_s, server)
          @log.debug "#{time_s}:#{server} #{i}:#{@intervals.size}, #{v.size} messages"
          @interval_data << {:key => k, :data => v}
        end
      end

      @log.debug @interval_data.size
      @log.debug @interval_data[0][:key]
      @log.debug @interval_data[0][:data].map {|d| d.size}

      @log.debug "#{@interval_data.flatten.size} messages total"

      @log.warn "Writing interval data to interval_data.txt"
      interval_data_file = File.new('interval_data.txt','w')
      interval_data_file.puts Marshal.dump(@intervals)
      interval_data_file.write Marshal.dump(@interval_data)
      interval_data_file.close
    end

  end


  def post_dnis_data

    if @options[:mode] == :benchmark
      @log.warn "Post activity data to http server #{@interval_data.size} messages"

      #  require 'httpclient'
      #  http = HTTPClient.new
      wall_start = Time.now
      @threads = []
      #  thread_segments = @interval_data.collect_every(@test_messages_per_thread)
      thread_segments = @interval_data.flatten.subdivide(@options[:servers])

      @log.debug @interval_data.map {|d| "#{d[:key]} #{d[:data].size}"}

      @log.debug thread_segments.map {|ts| ts.map {|d| "#{d[:key]} #{d[:data].size}"}}

      thread_segments.each do |thread_data|

        # @threads << Thread.new do
        conn = TCPSocket.new(@server, @port.to_i)
        @log.debug "begin send thread data"
        thread_data.each do |td|
          begin
            key,data = td[:key], td[:data]
            result = client_post conn, data
            @log.debug "#{Thread.current.to_s}:#{key} post #{data.size} bytes : #{result}"
          rescue Exception => e
            @log.error "#{Thread.current.to_s}:#{key} Error #{e.to_s}\n" + e.backtrace.join("\n")
          end

        end
        #      end

        # end
      end

      #  @threads.each {|i, th| th.join }
      # require 'thwait'
      # ThreadsWait.all_waits(@threads) { |thread| puts "#{thread} completed" }

      wall_time = (Time.now.to_f - wall_start.to_f)

      #collect the sum of intervals from each message in @interval_data
      # each item in @interval data is { :key => 'x', :data => [ ... messages in 16K chunks ...] }
      intervals_posted =  @interval_data.inject(0) {|sum, d| sum += d[:data].size}
      @log.debug "Post DNIS complete: #{wall_time} sec, #{intervals_posted} messages
      #{wall_time / intervals_posted * 1000} ms/msg
      #{intervals_posted / wall_time} msg/sec"

    else #options[:mode] == :continuous
      conn = TCPSocket.new(@options[:server], @options[:port].to_i)
      while true do

        now = Time.now
        time_s = CallActivityFile.time_segment(now)
        @servers.each do |server|
          begin
            # debugger
            data = data_for_time_segment(time_s.to_i, server)
            # key, data = key_data.values_at :key, :data
            # result = data
            result = client_post conn, data
            @log.debug "#{Thread.current.to_s}:#{time_s}#{server} post #{data.size} bytes : #{result}"
          rescue Exception => e
            @log.error "#{Thread.current.to_s}:#{time_s}#{server} Error #{e.to_s}"
          end

        end

        sleep_time = time_s + 15 - now
        @log.warn "now sleeping for #{sleep_time}"
        sleep sleep_time
      end
    end

  end

  protected

  def minutes; 60; end
  def minute; 60; end
  def hours; 3600; end
  def hour; 3600; end
  def day; 86400; end
  def days; 86400; end


  def time_s_from_interval(i)
    (@time + (i * @segment)).to_s
  end


end
