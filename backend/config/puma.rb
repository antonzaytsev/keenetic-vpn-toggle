# frozen_string_literal: true

threads_count = ENV.fetch('MAX_THREADS', 5).to_i
threads threads_count, threads_count

bind "tcp://0.0.0.0:#{ENV.fetch('PORT', 4567)}"

environment ENV.fetch('RACK_ENV', 'development')

