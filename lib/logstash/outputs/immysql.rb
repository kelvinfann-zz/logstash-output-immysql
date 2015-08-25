# encoding: utf-8
require "logstash/outputs/base"
require "logstash/namespace"

require 'rubygems'
require 'java'
require 'dbi'
require 'dbd/jdbc'
require 'jdbc/mysql'
require 'json'
# An mysql output that writes to a specified mysql database/table.
class LogStash::Outputs::IMMysql < LogStash::Outputs::Base
  config_name "immysql"

  config :host, :validate => :string, :default => 'localhost'
  config :port, :validate => :number, :default => '3306'
  config :username, :validate => :string, :default => 'root'
  config :password, :validate => :string, :default => ''
  config :database, :validate => :string, :required => true
  config :table, :validate => :string, :required => true
  # The regex of the fields you want to go into the mysql database
  config :match, :validate => :string, :default => '.count'
  config :json_counter, :validate => :boolean, :default => false


  # Plugin Initialization. Starts the connection to the mysql database
  public
  def register
    Jdbc::MySQL.load_driver
    @dbh = DBI.connect(
      "DBI:Jdbc:mysql://#{@host}:#{@port}/#{@database}",
      "#{@username}", "#{@password}",
      "driver" => "com.mysql.jdbc.Driver"
    )
    @im_append = '.count'
    @match_regex = Regexp.new(@match)
  end

  # parses the message looking for data to insert to mysql.  
  public
  def receive(event)
    event.to_hash.each do |k, v|
      if k.to_s =~ @match_regex
        write_im_to_sql(k, v, event)
      end
    end
  end # def receive

  # Last function called on shutdown
  public
  def teardown
    @dbh.disconnect
  end # def teardown


  # A generalized insert statement
  private
  def gen_insert_stat(descipt, values)
    return "INSERT INTO #{@table} (#{descipt}) VALUES (#{values});"
  end

  # Inserts an interval metric counter into mysql 
  private
  def write_im_to_sql(counter, count_hash, event)
    count_hash.each do |i, c|
      counter_parsed = counter[0..counter.index(@im_append)-1]
      exec_statement = parse_im_event(counter_parsed, i, c, event)
      begin
        @dbh.do exec_statement # Autocommit is already on
      rescue Exception => e
        raise Exception.new("Bad SQL statement #{exec_statement}")
      end
    end
  end # write_im_to_sql

  # Parses out the counter's info and returns the general sql insert statement
  # with the counter's info
  private
  def parse_im_event(counter, bucket_start, count, event)
    interval_len = event['count_interval']
    msg_interval = event['curr_interval']
    bucket_end = bucket_start + interval_len
    counter_s = counter[0..254]

    descript = "msg_interval, counter, bucket_start, bucket_end, count"
    values = [
      %Q('#{msg_interval}', '#{counter_s}',),
      %Q('#{bucket_start}', '#{bucket_end}', '#{count}')
    ].join(' ')

    if @json_counter
      to_append_stat = parse_im_counter(counter)
      descript = descript + to_append_stat[0] 
      values = values + to_append_stat[1] 
    end
    return gen_insert_stat(descript, values)
  end # parse_im_event

  private 
  def parse_im_counter(counter)
    counter_hash = JSON.parse(counter)
    keys = counter_hash.keys
    vals = []
    keys.each { |k| vals << ('"' +  "#{counter_hash[k]}"[0..254] + '"') }

    descript_counter = ', ' + keys.join(', ')
    values_counter = ', ' + vals.join(', ')

    return [descript_counter, values_counter]
  end
end # class LogStash::Outputs::IMMysql
