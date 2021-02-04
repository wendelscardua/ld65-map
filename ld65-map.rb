#!/usr/bin/ruby
# frozen_string_literal: true

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'gruff', '~> 0.12.1'
end

require 'gruff'

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

graph = Gruff::StackedBar.new
graph.title = 'Memory usage by category'
graph.labels = categories.keys.map.with_index { |(k, _v), i| [i, k] }.to_h

free = Array.new(categories.size) { 1.0 }

categories.each.with_index do |(_cat_name, cat_data), cat_index|
  cat_data[:segments].each do |seg_name|
    counts = Array.new(categories.size) { 0.0 }
    counts[cat_index] = module_data.flat_map { |mod| mod[:segments] }
                                   .select { |segment| segment[:segment] == seg_name }
                                   .map { |segment| segment[:size] }
                                   .sum * 1.0 / cat_data[:size]
    graph.data seg_name, counts
    puts "#{seg_name}: #{counts}"
    free[cat_index] -= counts[cat_index]
    free[cat_index] = 0.0 if free[cat_index] < 0.0
  end
end
graph.data 'Free', free
puts "Free: #{free}"
graph.write('ld65-map.png')
