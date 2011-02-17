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
require 'getoptlong'

# For test purposes, use fixed data
DefaultConfigFile = "~/.saugrc/config.yml"
DefaultDownloadsFile = "~/.saugrc/downloads.yml"
DefaultTargetDirectory = "~/pod/"
DefaultNrDays = 7

DayInSeconds = 24 * 3600


class AggregatorFeed
  attr_reader :source, :downloads

  def initialize(source = nil, downloads = nil, verbosity = 1, debug = false)
    @source = source
    @downloads = (downloads || [])
    @rss = nil
    @verbosity, @debug = verbosity, debug
  end

  def get_rss
    begin
      open(@source) {|s| @rss = RSS::Parser.parse(s.read, false)}
    rescue OpenURI::HTTPError
      puts "WARNING: Unable to open #{@source}"
      puts "  Error Message #{$!}"
    end
  end

  def set_update(update)
    @update = update
  end

  def download_conditional(directory, min_date, only_new = true)
    get_rss unless @rss

    # @rss Feed may not be available
    if @rss
      @rss.items.each_with_index do |an_item, item_nr|
        if (! min_date || an_item.date > min_date) && ! (only_new && @downloads.include?(extract_guid(an_item)))
          download(item_nr, directory)
        end
      end
    end
  end

  def download(item_nr, directory)
    get_rss unless @rss
    url = @rss.items[item_nr].enclosure.url

    # determine filename of file to download
    uri = URI.parse(url)
    filename = File.join(File.expand_path(directory), File.basename(uri.path))

    puts "Start downloading of #{url} to #{filename}" if @verbosity > 0 && ! @update

    # download url and add guid to @downloads
    unless @debug || @update
      of = open(filename, 'wb')
      begin 
        of.write(open(url).read)
      rescue
        puts "WARNING: Unable to open #{url}"
        puts "  Error Message #{$!}"
      end
      of.close
    end

    @downloads << extract_guid(@rss.items[item_nr])

    if @verbosity > 0
      if @update
        puts "Updated #{url}"
      else
        puts "Downloaded #{url} to #{filename}"
      end
    end
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
  def initialize(config_file, downloads_file, verbosity = 1, debug = false)
    @config_file = File.expand_path(config_file)
    @downloads_file = File.expand_path(downloads_file)
    @verbosity, @debug = verbosity, debug

    @sources = YAML::load(File.read(@config_file))


    begin
      @downloads = YAML::load(File.read(@downloads_file))
    rescue SystemCallError
      # It is OK when downloads file doesn't exist.
    end
    @downloads ||= {}

    @feeds = []
    @sources.each do |a_source|
      @feeds << AggregatorFeed.new(a_source, @downloads[a_source], @verbosity, @debug)
    end
  end

  def download(directory, min_date)
    @feeds.each do |a_feed|
      a_feed.download_conditional(directory, min_date)
    end
  end

  def set_update(update)
    @feeds.each {|a_feed| a_feed.set_update(update)}
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

def usage
  puts <<-EOF
usage: ruby saug.rb [OPTIONS]
  Downloads new items from the configured feeds.

  At the moment most features are not implemented yet

  Possible options are:

    -h, --help:
      Show this help and exit.

    -d dir, --download_directory dir:
      Set download directory.

    -u, --update:
      Update feeds only, don't download anything.

    -l, --list:
      List currently configured feeds.

    -t [nr], --time [nr]:
      Only download files that are younger than nr days. Default is #{DefaultNrDays}.
      If the argument is omitted, no time restriction is enforced.

    -f name, --feed name:
      Use only the given feed and ignore all other feeds.

    --config_file file file:
      Use the given config file instead of the default one at #{DefaultConfigFile}

    --downloads_file file:
      Use the given file to store information on downloaded files
      instead of the default one at #{DefaultDownloadsFile}

    --D, --debug:
      Use debug mode with high verbosity and downloads are deactivated.
      No downloads information is written.

    --V n, --verbosity n:
      Set verbosity to the given level. The level should be one of
      0: No output (useful for cron jobs)
      1: (default) Normal output.
      2: Loquatious output.

  EOF
end

if $0 == __FILE__
  opts = GetoptLong.new(
    ['-h', '--help', GetoptLong::NO_ARGUMENT],
    ['-d', '--download_directory', GetoptLong::REQUIRED_ARGUMENT],
    ['-u', '--update', GetoptLong::NO_ARGUMENT],
    ['-l', '--list', GetoptLong::NO_ARGUMENT],
    ['-t', '--time', GetoptLong::OPTIONAL_ARGUMENT],
    ['-f', '--feed', GetoptLong::REQUIRED_ARGUMENT],
    ['--config_file', GetoptLong::REQUIRED_ARGUMENT],
    ['--downloads_file', GetoptLong::REQUIRED_ARGUMENT],
    ['-D', '--debug', GetoptLong::NO_ARGUMENT],
    ['-V', '--verbose', GetoptLong::REQUIRED_ARGUMENT] )

  # variables that manage the behaviour of the program
  target_directory = DefaultTargetDirectory
  config_file = DefaultConfigFile
  downloads_file = DefaultDownloadsFile
  update = false
  debug = false
  verbosity = 1
  diff_time = DefaultNrDays

  opts.each do |opt, arg|
    case opt
    when '-h'
      usage
      exit(0)
    when '-d'
      target_directory = arg
    when '-u'
      update = true
    when '-l'
      # TODO: list feeds
      exit(0)
    when '-t'
      diff_time = (arg == '' ? nil : arg.to_i)
    when '-f'
      feed = arg.to_i
    when '--config_file'
      config_file = arg
    when '--downloads_file'
      downloads_file = arg
    when '-D'
      debug = true
    when '-V'
      verbosity = arg.to_i
    end
  end

  min_download_time = (diff_time ? Time.now - diff_time * DayInSeconds : nil)

  collection = FeedCollection.new(config_file, downloads_file, verbosity, debug)
  collection.set_update(update)
  collection.download(target_directory, min_download_time )
  collection.save
end

