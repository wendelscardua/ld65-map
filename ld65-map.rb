#!/usr/bin/ruby
# frozen_string_literal: true

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'tty-progressbar', '~> 0.18.1'
end

require 'tty-progressbar'

def hex(hex_value)
  hex_value.to_i(16)
end

map_text = File.readlines(ARGV[0], chomp: true)

module_data = []

mode = nil

map_text.each do |line|
  case line
  when 'Modules list:'
    mode = :modules_list
  when ''
    mode = nil
  end

  case mode
  when :modules_list
    if m = line.match(/\A\s*(?<name>[^.]*\.o):/)
      module_data << { module: m['name'], segments: [] }
    elsif m = line.match(/\A\s+(?<segment>\S+)\s+Offs=(?<offset>\S+)\s+Size=(?<size>\S+)\s+Align=(?<align>\S+)\s+Fill=(?<fill>\S+)/)
      module_data.last[:segments] << {
        segment: m['segment'],
        offset: hex(m['offset']),
        size: hex(m['size']),
        align: hex(m['align']),
        fill: hex(m['fill'])
      }
    end
  end
end

# TODO: configurable

categories = {
  'HEADER' => { size: 10, segments: ['HEADER'] },
  'PRG' => { size: 0x10000, segments: ['CODE', 'RODATA', 'VECTORS'] },
  'CHR' => { size: 0x10000, segments: ['CHR'] },
  'ZEROPAGE' => { size: 0x100, segments: ['ZEROPAGE'] },
  'STACK' => { size: 0x100, segments: ['STACK'] },
  'RAM' => { size: 0x2000 - 0x200, segments: ['OAM', 'FAMITONE'] }
}
