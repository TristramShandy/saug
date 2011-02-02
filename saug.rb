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

require 'rss/1.0'
require 'rss/2.0'

Sources = ["http://www.econlib.org/library/EconTalk.xml"]

class AggregatorFeed

  def get_rss
    open(@source) {|s| @rss = RSS::Parser.parse(s.read)}
  end

  def download_conditional(directory, min_date, only_new = true)
    get_rss unless @rss
    @rss.items.each_with_index do |an_item, item_nr|
      if an_item.date > min_date && ! (only_new && @downloaded.include?(an_item.guid))
        download(item_nr, directory)
      end
    end
  end

  def download(item_nr, directory)
    get_rss unless @rss
    url = @rss.items[item_nr].enclosure.url
    # download url and add guid to @downloaded
    # ... #
  end
end

if $0 == __FILE__
end

