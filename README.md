We're going to build off Tweet Now 2. We've designed a system that lets someone tweet right now. The front-end should be nice and responsive - rather than waiting for the back end to submit the tweet we send of the request asynchronously.

If you didn't get the other Twitter-posting challenges finished take the time to get them finished before starting this one. Seriously.

In the previous applications the front-end is responsive, but the back-end is still held up. Like an old lady paying with pennies in the grocery line, one slow request - where "slow" is greater than 100-200 milliseconds - can cause a huge backlog of requests.

This is where background jobs work. Rather than processing an expensive task inside your web app server, your app server pushes a task onto a queue that a background worker processes. This takes a few milliseconds and frees up the app server to respond to other requests, although it makes your architecture more complicated.

We'll be using Sidekiq, a Redis-based queue, for our background processing.

Look in sidekiq/examples/sinkiq.rb for a Sintra-based example.

The Objectives
Sidekiq
Add the sidekiq and redis gem to your Gemfile and require both in config/environment.rb. Run bundle install to install the gem.

In order for Sidekiq to do its thing, you'll need it to be running in some other tab. You can do that in development by running the following:

$ bundle exec sidekiq -r./config/environment.rb
If this doesn't work find a staff member. Redis might not be configured correctly, but you never know.

Tweeting
We're assuming you have OAuth up and running. Get that working first if that's not the case. You should be storing the access token inside the users table along with a user's Twitter handle.

Create a TweetWorker model that looks like this:

# app/workers/tweet_worker.rb
class TweetWorker
  include Sidekiq::Worker

  def perform(tweet_id)
    tweet = Tweet.find(tweet_id)
    user = tweet.user

    # set up Twitter OAuth client here
    # actually make API call
    # Note: this does not have access to controller/view helpers
    # You'll have to re-initialize everything inside here
  end
end
And define a method User#tweet that works like this:

class User < ActiveRecord::Base
  def tweet(status)
    tweet = tweets.create!(:status => status)
    TweetWorker.perform_async(tweet.id)
  end
end
Does this work? If you have a properly authorized user can you do something like this from the console?

> User.find(1).tweet("Hello, world!")
Make sure you have

require 'sidekiq'
in config/environment.rb.

Create a tweets table and Tweet model to record the tweets a particular user has asked your application to publish.

Sidekiq::Worker.perform_async returns a Sidekiq job ID that we can use to query the server to determine the status of this particular job.

Front-end
You might notice this now greatly complicates your front-end. The server returns immediately every time and you have no way of being notified when the background job is done. Rut roh!

Create a route that looks like

get '/status/:job_id' do
  # return the status of a job to an AJAX call
end
The following helper method can be used to check if a job has completed:

def job_is_complete(jid)
  waiting = Sidekiq::Queue.new
  working = Sidekiq::Workers.new
  pending = Sidekiq::ScheduledSet.new
  return false if pending.find { |job| job.jid == jid }
  return false if waiting.find { |job| job.jid == jid }
  return false if working.find { |process_id, thread_id, work| work["payload"]["jid"] == jid }
  true
end
After a user submits a tweet to be published via AJAX, have the server return the Sidekiq job ID. Then use setTimeout to poll /status/:job_id every so often - you decide the frequency.

Your browser is now like an annoying kid in the back seat of a car. After it submits the request to publish a tweet, it asks "Is it published yet?" over and over until the server finally responds with "Yep!"

You'll have to edit the /status/:job_id code above to return something sensible to the client depending on whether the task has been completed yet or not.

Note : How do you handle the error case? This is also tricky, and we'll leave it to you to investigate. Where does Sidekiq put the job when it fails? Does it retry until it succeeds? If so, do we want it to do that?

Scheduling for the Future
Sidekiq supports scheduling a job for the future. How? Look it up and add that feature to your application.

Deploy to Heroku
Making sure your application configuration is secure, deploy this to Heroku. Read the Sidekiq deployment documentation. You'll need to edit your Procfile to include a worker line. The web line should remain as-is.

If you want to run Sidekiq on your server you'll need to add a credit card and turn on a worker process by running

$ heroku ps:scale worker=1
Make sure you scale this back to 0 when you don't want to use it or else you'll be charged a fair amount of money per day. If you do this properly it should cost you pennies per day to scale a worker.

You might try to autoscaler gem which can potentially start/stop Sidekiq as needed. This is only a suggestion for those who feel like experimenting.

