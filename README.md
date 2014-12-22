<div class="container">
<div id="challenge" class="row">
<div class="col-sm-8">
<div class="row">
<div class="col-sm-12">
<div class="tab-content">
<div id="body" class="tab-pane fade in active">

We're going to build off <a href="http://learn.codedivision.my/challenges/140">Tweet Now 2</a>. We've designed a system that lets someone tweet right now. The front-end should be nice and responsive - rather than waiting for the back end to submit the tweet we send of the request asynchronously.

If you didn't get the other Twitter-posting challenges finished take the time to get them finished before starting this one. Seriously.

In the previous applications the front-end is responsive, but the back-end is still held up. Like an old lady paying with pennies in the grocery line, one slow request - where "slow" is greater than 100-200 milliseconds - can cause a huge backlog of requests.

This is where background jobs work. Rather than processing an expensive task inside your web app server, your app server pushes a task onto a queue that a background worker processes. This takes a few milliseconds and frees up the app server to respond to other requests, although it makes your architecture more complicated.

We'll be using <a href="https://github.com/mperham/sidekiq">Sidekiq</a>, a <a href="http://en.wikipedia.org/wiki/Redis">Redis-based</a> queue, for our background processing.

Look in <a href="https://github.com/mperham/sidekiq/blob/master/examples/sinkiq.rb">sidekiq/examples/sinkiq.rb</a> for a Sintra-based example.
<h2>Objectives</h2>
<h3>Sidekiq</h3>
Add the <code>sidekiq</code> and <code>redis</code> gem to your <code>Gemfile</code> and require both in <code>config/environment.rb</code>. Run bundle install to install the gem.

In order for Sidekiq to do its thing, you'll need it to be running in some other tab. You can do that in development by running the following:
<div class="highlight">
<pre><span class="nv">$ </span>bundle <span class="nb">exec </span>sidekiq -r./config/environment.rb
</pre>
</div>
If this doesn't work find a staff member. Redis might not be configured correctly, but you never know.
<h3>Tweeting</h3>
We're assuming you have OAuth up and running. Get that working first if that's not the case. You should be storing the access token inside the <code>users</code> table along with a user's Twitter handle.

Create a <code>TweetWorker</code> model that looks like this:
<div class="highlight">
<pre><span class="c"># app/workers/tweet_worker.rb</span>
class TweetWorker
  include Sidekiq::Worker

  def perform<span class="o">(</span>tweet_id<span class="o">)</span>
    <span class="nv">tweet</span> <span class="o">=</span> Tweet.find<span class="o">(</span>tweet_id<span class="o">)</span>
    <span class="nv">user</span> <span class="o">=</span> tweet.user

    <span class="c"># set up Twitter OAuth client here</span>
    <span class="c"># actually make API call</span>
    <span class="c"># Note: this does not have access to controller/view helpers</span>
    <span class="c"># You'll have to re-initialize everything inside here</span>
  end
end
</pre>
</div>
And define a method <code>User#tweet</code> that works like this:
<div class="highlight">
<pre>class User &lt; ActiveRecord::Base
  def tweet<span class="o">(</span>status<span class="o">)</span>
    <span class="nv">tweet</span> <span class="o">=</span> tweets.create!<span class="o">(</span>:status <span class="o">=</span>&gt; status<span class="o">)</span>
    TweetWorker.perform_async<span class="o">(</span>tweet.id<span class="o">)</span>
  end
end
</pre>
</div>
Does this work? If you have a properly authorized user can you do something like this from the console?
<div class="highlight">
<pre>&gt; User.find<span class="o">(</span>1<span class="o">)</span>.tweet<span class="o">(</span><span class="s2">"Hello, world!"</span><span class="o">)</span>
</pre>
</div>
Make sure you have
<div class="highlight">
<pre>require <span class="s1">'sidekiq'</span>
</pre>
</div>
in <code>config/environment.rb</code>.

Create a <code>tweets</code> table and <code>Tweet</code> model to record the tweets a particular user has asked your application to publish.

<code>Sidekiq::Worker.perform_async</code> returns a Sidekiq job ID that we can use to query the server to determine the status of this particular job.
<h3>Front-end</h3>
You might notice this now greatly complicates your front-end. The server returns immediately every time and you have no way of being notified when the background job is done. Rut roh!

Create a route that looks like
<div class="highlight">
<pre>get <span class="s1">'/status/:job_id'</span> <span class="k">do</span>
  <span class="c"># return the status of a job to an AJAX call</span>
end
</pre>
</div>
The following helper method can be used to check if a job has completed:
<div class="highlight">
<pre>def job_is_complete<span class="o">(</span>jid<span class="o">)</span>
  <span class="nv">waiting</span> <span class="o">=</span> Sidekiq::Queue.new
  <span class="nv">working</span> <span class="o">=</span> Sidekiq::Workers.new
  <span class="nv">pending</span> <span class="o">=</span> Sidekiq::ScheduledSet.new
  <span class="k">return </span><span class="nb">false </span><span class="k">if </span>pending.find <span class="o">{</span> |job| job.jid <span class="o">==</span> jid <span class="o">}</span>
  <span class="k">return </span><span class="nb">false </span><span class="k">if </span>waiting.find <span class="o">{</span> |job| job.jid <span class="o">==</span> jid <span class="o">}</span>
  <span class="k">return </span><span class="nb">false </span><span class="k">if </span>working.find <span class="o">{</span> |process_id, thread_id, work| work<span class="o">[</span><span class="s2">"payload"</span><span class="o">][</span><span class="s2">"jid"</span><span class="o">]</span> <span class="o">==</span> jid <span class="o">}</span>
  <span class="nb">true</span>
end
</pre>
</div>
After a user submits a tweet to be published via AJAX, have the server return the Sidekiq job ID. Then use <a href="http://stackoverflow.com/questions/10312963/javascript-settimeout">setTimeout</a> to poll <code>/status/:job_id</code> every so often - you decide the frequency.

Your browser is now like an annoying kid in the back seat of a car. After it submits the request to publish a tweet, it asks "Is it published yet?" over and over until the server finally responds with "Yep!"

You'll have to edit the <code>/status/:job_id</code> code above to return something sensible to the client depending on whether the task has been completed yet or not.

<strong>Note</strong> : How do you handle the error case? This is also tricky, and we'll leave it to you to investigate. Where does Sidekiq put the job when it fails? Does it retry until it succeeds? If so, do we want it to do that?
<h3>Scheduling for the Future</h3>
Sidekiq supports scheduling a job for the future. How? Look it up and add that feature to your application.
<h3>Deploy to Heroku</h3>
Making sure your application configuration is secure, deploy this to Heroku. Read the <a href="https://github.com/mperham/sidekiq/wiki/Deployment">Sidekiq deployment documentation</a>. You'll need to edit your <code>Procfile</code> to include a <code>worker</code> line. The <code>web</code> line should remain as-is.

If you want to run Sidekiq on your server you'll need to add a credit card and turn on a worker process by running
<div class="highlight">
<pre><span class="nv">$ </span>heroku ps:scale <span class="nv">worker</span><span class="o">=</span>1
</pre>
</div>
Make sure you scale this back to <code>0</code> when you don't want to use it or else you'll be charged a fair amount of money per day. If you do this properly it should cost you pennies per day to scale a worker.

You might try to <a href="https://github.com/JustinLove/autoscaler/">autoscaler gem</a> which can potentially start/stop Sidekiq as needed. This is only a suggestion for those who feel like experimenting.

</div>
</div>
</div>
</div>
</div>
</div>
</div>
&nbsp;
