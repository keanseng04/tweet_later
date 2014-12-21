# app/workers/tweet_worker.rb
class TweetWorker
  include Sidekiq::Worker

  def perform(tweet_id)
    puts "TweetWorker"
    tweet = Tweet.find(tweet_id)
    user = tweet.user
    user.post_tweet(tweet)
  end

    # puts "TweetWorker runs"
    # tweet = Tweet.find(tweet_id)
    # @user = tweet.user
    # twitter_client = MyWorker.client(@user.access_token, @user.access_token_secret)
    # twitter_client.update(tweet.body)

    # actually make API call
    # Note: this does not have access to controller/view helpers
    # You'll have to re-initialize everything inside here


  # private
  #    def self.client(access_token1, access_token_secret1)
  #    Twitter::REST::Client.new do |config|
  #       config.consumer_key        = "iTEl8b229alG0TaNiECTejKwS" #YOUR CONSUMER KEY
  #       config.consumer_secret     = "y7MtEqJrpU7KoOnwF5yroG2ZZhTBT6V5q53AikQNG5dBCnBj3c" #YOUR CONSUMER KEY SECRET
  #        config.access_token        = access_token1
  #        config.access_token_secret = access_token_secret1
  #   end
end
