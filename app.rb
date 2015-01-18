#!/usr/bin/env ruby

#Settings
username = "webm_bot"
password = "o2TaDRssW2DV"
@subreddit = "montageparodies"
#End Settings

#Bundler
require 'rubygems'
require 'bundler/setup'

#Dependencies
require "sqlite3"
require "redd"
require "youtube_url"
require "youtube_dl"
require "streamio-ffmpeg"
require "curb"
require "pry"
require "json"

#Create new SQLite Database
private def createDatabase()
  if !File.file?('database.db')
    puts "> No database found. Creating one..."

    db = SQLite3::Database.new "database.db"

    tables = db.execute <<-SQL
    create table CompletedJobs(
      SubmissionID	VARCHAR(20) primary key,
      Processed_At DATETIME DEFAULT CURRENT_TIMESTAMP
    );
    SQL

    db.close()
  end
end

#Check if submission has already been processed
private def databaseContains(submission, database)
  query = database.execute('SELECT * FROM CompletedJobs WHERE SubmissionID=?', submission.id)
  if(query.count > 0)
    return true
  else
    return false
  end
end

#Loop through submissions
private def checkSubmissions(reddit_browser, reddit_user, database)
  puts "> Grabbing submissions from Reddit"
  submissions = reddit_browser.get_new(@subreddit)
  submissions.to_a.each do |submission|
    if(!databaseContains(submission, database))
      if(YouTubeURL::Identifier.new(submission.url).valid?)
          processSubmission(submission, reddit_user, database)
      end
    end
  end
end

#Download + Convert
private def processSubmission(submission, reddit_user, database)
  #Get canonical Youtube URL
  youtubeURL = YouTubeURL::Identifier.new(submission.url).canonical_url

  #Download!
  puts "> Downloading YouTube Video... #{submission.title}"
  youtubeDownloader = YoutubeDl::YoutubeVideo.new(youtubeURL)
  youtubeVideo = youtubeDownloader.download_video

  #Transcode to WebM
  puts "> Transcoding to WebM Format"
  movie = FFMPEG::Movie.new(youtubeVideo)
  movie.transcode("tmp/downloads/#{submission.id}.webm")

  #Delete Original File
  FileUtils.rm(youtubeVideo)

  #Upload file to Pomf
  puts "> Uploading to Pomf"
  uploader = Curl::Easy.new("http://pomf.se/upload.php")
  uploader.multipart_form_post = true
  uploader.http_post(Curl::PostField.file('files[]', "tmp/downloads/#{submission.id}.webm"))

  #Parse Json for Pomf URL
  j = JSON.parse(uploader.body)

  if(j["success"])
    pomfURL = "http://a.pomf.se/#{j["files"][0]["url"]}"
    puts "> Uploaded to #{pomfURL}"
    addComment(submission, reddit_user, pomfURL)
  end

  #Delete WebM
  FileUtils.rm("tmp/downloads/#{submission.id}.webm")

  #Add record of conversion to SQL
  database.execute("INSERT INTO CompletedJobs (SubmissionID) VALUES (?)", submission.id)
end

private def addComment(submission, reddit_user, url)
  puts "> Posting Comment"
  text = "This is an automated (BETA!) comment. I've done you the honor of converting this video to WebM format! You can view it here: #{url}."

  begin
    reddit_user.add_comment(submission, text)
  rescue Redd::Error::RateLimited => e
    time_left = e.time
    puts "> We've been rate limited. Waiting #{time_left} seconds."
    sleep(time_left)
    puts "> Posting comment again."
    reddit_user.add_comment(submission, text)
  end
end

#Initialize Stuff
createDatabase()
puts "> Connecting to Database"
database = SQLite3::Database.new "database.db"

reddit_browser = Redd::Client::Unauthenticated.new
reddit_user = Redd::Client::Authenticated.new_from_credentials "#{username}", "#{password}", user_agent: "WebM Bot v1.0 by /u/ben_uk"

while true
  checkSubmissions(reddit_browser, reddit_user, database)
  puts "> Done! Resting for 60 seconds..."
  sleep 60
end
