# frozen_string_literal: true

gem 'minitest'
require 'minitest/autorun'
require 'minitest/pretty_diff'
require 'minitest/focus'
require 'minitest/moar'
require 'minitest/bisect'
require 'minitest-bonus-assertions'

require 'cartage/minitest'
require 'cartage/plugins/remote'
require 'fog'

Fog.mock!
