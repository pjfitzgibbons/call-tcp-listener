require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'call_activity_file'

describe CallActivityFile do
  before(:all) do
    ENV['CALL_FILE_PATH'] ||= 'testdata'
    FileUtils.mkdir_p ENV['CALL_FILE_PATH']

    @call_activity_file = LoadmonCache.new
  end

  describe "setting cachefile path" do
    before(:each) do
      CallActivityFiel.send :public, 'cache_file'
    end
    it "should separate day, hour, minute-seconds into a path" do
      time = Time.now
      time_segment = time - (time.sec % 15)
      path_day, path_hour, path_minute = ["%Y-%m-%d", "%H", "%M.%S"].map {|fmt| time_segment.strftime(fmt)}
      path, file = @call_activity_file.cache_file(time.to_i, "servername")
      path.should == File.join(path_day, path_hour, path_minute)
      file.should == time_segment.strftime("%Y-%m-%d.%H.%M.%S-#{time.to_i}-servername.txt")
    end
  end

end
