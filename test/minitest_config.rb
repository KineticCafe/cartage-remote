# frozen_string_literal: true

gem 'minitest'
require 'minitest/autorun'
require 'minitest/moar'

require 'cartage/minitest'
require 'cartage/plugins/remote'
require 'fog/core'

Fog.mock!
