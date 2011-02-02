#!/usr/bin/env ruby
#
# saug.rb
#
# My personal podcast aggregator
#
# This is still work in progress and not yet usable
#
#   Copyright 2011 Michael Ulm
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.

#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.

#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'uri'
require 'time'
require 'open-uri'
require 'rss/1.0'
require 'rss/2.0'
require 'yaml'

# For test purposes, use fixed data
ConfigFile = "~/.saugrc/config.yml"
DownloadsFile = "~/.saugrc/downloads.yml"

TargetDirectory = "~/pod/"
Verbose = true
Debug = true
WeekInSeconds = 7 * 24 * 3600


class AggregatorFeed
  attr_reader :source, :downloads

  def initialize(source = nil, downloads = nil)
    @source = source
    @downloads = (downloads || [])
    @rss = nil
  end

  def get_rss
    open(@source) {|s| @rss = RSS::Parser.parse(s.read, false)}
  end

  def download_conditional(directory, min_date, only_new = true)
    get_rss unless @rss
    @rss.items.each_with_index do |an_item, item_nr|
      if an_item.date > min_date && ! (only_new && @downloads.include?(extract_guid(an_item)))
        download(item_nr, directory)
      end
    end
  end

  def download(item_nr, directory)
    get_rss unless @rss
    url = @rss.items[item_nr].enclosure.url

    # determine filename of file to download
    uri = URI.parse(url)
    filename = File.join(File.expand_path(directory), File.basename(uri.path))

    # download url and add guid to @downloads
    unless Debug
      of = open(filename, 'wb')
      of.write(open(url).read)
      of.close
    end

    @downloads << extract_guid(@rss.items[item_nr])

    puts "Downloaded #{url} to #{filename}" if Verbose
  end

  private

  # Get guid from feed if existent - else take filename
  def extract_guid(item)
    if item.guid && item.guid.content
      item.guid.content
    else
      item.enclosure.url
    end
  end
end

class FeedCollection
  def initialize(config_file, downloads_file)
    @config_file = File.expand_path(config_file)
    @downloads_file = File.expand_path(downloads_file)

    @sources = YAML::load(File.read(@config_file))

    begin
      @downloads = YAML::load(File.read(@downloads_file))
    rescue SystemCallError
      # It is OK when downloads file doesn't exist.
    end
    @downloads ||= {}

    @feeds = []
    @sources.each do |a_source|
      @feeds << AggregatorFeed.new(a_source, @downloads[a_source])
    end
  end

  def download(directory, min_date)
    @feeds.each do |a_feed|
      a_feed.download_conditional(directory, min_date)
    end
  end

  def save
    download_data = {}
    @feeds.each do |a_feed|
      download_data[a_feed.source] = a_feed.downloads
    end

    of = File.open(@downloads_file, 'w')
    of.puts download_data.to_yaml
    of.close
  end
end

if $0 == __FILE__
  collection = FeedCollection.new(ConfigFile, DownloadsFile)
  collection.download(TargetDirectory, Time.now - WeekInSeconds)
  collection.save
end

