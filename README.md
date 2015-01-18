# Reddit WebM Bot
Reddit bot to convert YouTube videos to WebM format.

Requirements
=================
* Ruby (2.1.5 recommended) with Bundler
* youtube-dl (http://rg3.github.io/youtube-dl/download.html)
* ffmpeg
* A reddit account

Usage
=====================
* Clone the repo
* Open app.rb in your favourite text editor. Edit the settings variables to your requirements.
* Install dependencies with bundler ``bundle install`
* **Important!** The Youtube-DL Ruby wrapper gem supplies its own binary of youtube-dl, which is out-of-date and seems to conflict with Ruby. You'll need to find the binary, remove it and symbolic link it to the system binary you installed earlier.
* Run app.rb with Ruby and enjoy!
