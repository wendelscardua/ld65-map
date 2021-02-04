#!/usr/bin/ruby
# frozen_string_literal: true

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  # gem 'gruff', '~> 0.12.1'
end

def hex(hex_value)
  hex_value.to_i(16)
end

if ARGV.size == 0
  puts 'Arguments: input-file prg-banks chr-banks'
  exit 1
end

input = ARGV[0]
prg_banks = ARGV[1].to_i
chr_banks = ARGV[2].to_i

map_text = File.readlines(input, chomp: true)

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
  'PRG' => { size: 0x4000 * prg_banks, segments: ['CODE', 'RODATA', 'VECTORS'] },
  'CHR' => { size: 0x2000 * chr_banks, segments: ['CHR'] },
  'ZEROPAGE' => { size: 0x100, segments: ['ZEROPAGE'] },
  'STACK' => { size: 0x100, segments: ['STACK'] },
  'RAM' => { size: 0x2000 - 0x200, segments: ['OAM', 'FAMITONE'] }
}

segment_usage = {}

puts 'Usage per category:'
categories.each do |cat_name, cat_data|
  puts "#{cat_name}:"
  free = cat_data[:size]
  cat_data[:segments].each do |seg_name|
    usage = segment_usage[seg_name] = module_data.flat_map { |mod| mod[:segments] }
                                                 .select { |segment| segment[:segment] == seg_name }
                                                 .map { |segment| segment[:size] }
                                                 .sum
    puts "  #{seg_name}: #{usage}"
    free -= usage
  end
  puts "  Free: #{free}"
end

puts 'Usage per segment:'

segment_usage.each do |seg_name, seg_size|
  puts "#{seg_name} (#{seg_size} bytes):"
  module_data.map do |mod|
    [
      mod[:module],
      mod[:segments].find { |seg| seg[:segment] == seg_name }
                    .then { |seg| seg ? seg[:size] : nil }
    ]
  end.reject { |m, s| s.nil? }
     .sort_by { |m, s| s }
     .reverse
     .each do |m, s|
    puts "  #{m}: #{s} bytes"
  end
end
