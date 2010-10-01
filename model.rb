require 'redis'
require 'digest/sha1'
require 'json'

$redis = Redis.new

class User
  attr_reader :username, :password
  
  def self.create username, password
    raise if $redis.exists "user:#{username}"
    
    $redis.hset "user:#{username}", 'password', sha1(password)
  end
  
  def self.load username
    User.new(username, $redis.hgetall("user:#{username}"))
  end
  
  def initialize username, data
    @username = username
    @password = data['password']
  end
  
  def timeline
    json_tweets = $redis.sort("user:#{@username}:timeline", :get => "status:*", :by => 'nosort')
    json_tweets.inject([]) { |output, tweet| output << Status.from_json(tweet) }
  end
  
  def tweets
    json_tweets = $redis.sort("user:#{@username}:tweets", :get => "status:*", :by => 'nosort')
    json_tweets.inject([]) { |output, tweet| output << Status.from_json(tweet) }
  end
  
  def following
    $redis.smembers "user:#{@username}:following"
  end
  
  def followers
    $redis.smembers "user:#{@username}:followers"
  end
  
  def follow other
    tweets = $redis.lrange "user:#{other}:tweets", 0, 4
    $redis.multi do
      $redis.sadd "user:#{@username}:following", other
      $redis.sadd "user:#{other}:followers", @username
      tweets.each do |t|
        $redis.lpush "user:#{@username}:timeline", t
      end
      $redis.sort "user:#{@username}:timeline", :order => 'desc', :store => "user:#{@username}:timeline"
    end
  end
  
  def follows? other
    $redis.sismember "user:#{@username}:following", other
  end
end

class Status
  attr_accessor :status, :username
  
  def self.create user, status
    status_id = $redis.incr "statuses:next_id"
    data = {
      'status' => status,
      'username' => user.username
    }
    
    followers = user.followers
    
    $redis.multi do
      $redis.set "status:#{status_id}", data.to_json
      $redis.lpush "user:#{user.username}:tweets", status_id
      $redis.lpush "user:#{user.username}:timeline", status_id
      followers.each do |follower|
        $redis.lpush "user:#{follower}:timeline", status_id
      end
    end
  end
  
  def self.from_json json
    Status.new JSON::parse(json)
  end
  
  def initialize data
    @status, @username = data['status'], data['username']
  end
end

def sha1 d
  Digest::SHA1.hexdigest d
end