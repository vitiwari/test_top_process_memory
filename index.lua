-- Copyright 2015 Boundary, Inc.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--    http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local framework = require('framework')
local Plugin = framework.Plugin
local CommandOutputDataSource = framework.CommandOutputDataSource
local Accumulator = framework.Accumulator
local PollerCollection = framework.PollerCollection
local DataSourcePoller = framework.DataSourcePoller
local Cache = framework.Cache
local os = require('os')
local table = require('table')
local gsplit = framework.string.gsplit
local clone = framework.table.clone
local notEmpty = framework.string.notEmpty

local params = framework.params
params.pollInterval = notEmpty(tonumber(params.pollInterval), 5000)
params.instance_name = notEmpty(params.instance_name, os.hostname()) 

local cmd = {
  path = 'ps -eo pmem | sort -k 1 -nr | head -1',
  args = { '-1'} -- -n <instance_name>
}

local function createDataSource(params, cmd) 
  if params.items and #params.items > 0 then
    local pollers = PollerCollection:new() 
    for _, item in ipairs(params.items) do
      local item_cmd = clone(cmd)
      item_cmd.info = notEmpty(item.instance_name, params.instance_name)
      table.insert(item_cmd.args, string.format('-n%s', item_cmd.info))
      local poll_interval = notEmpty(tonumber(item.pollInterval), params.pollInterval)
      local poller = DataSourcePoller:new(poll_interval, CommandOutputDataSource:new(item_cmd))
      pollers:add(poller)
    end
    return pollers
  end

  --cmd.info = params.instance_name
  return CommandOutputDataSource:new(cmd)
end

--local cache = Cache:new(function () return Accumulator:new() end)

local ds = createDataSource(params, cmd)

local boundary_metrics = {
  top_process_memory = 'BOUNDARY_TEST_TOP_PROCESS_MEMORY'
}

local plugin = Plugin:new(params, ds)
function plugin:onParseValues(data)
  local result = {}
  print("check parse 1 ",data.output)
  for line in gsplit(data.output, '\n') do
    --local metric, value = string.match(line, '([^%s]+)%s+(%d+)')
     print("check parse 2 ",line)
     local metric,value=line
      local acc={}
      value = acc('BOUNDARY_TEST_TOP_PROCESS_MEMORY',tonumber(value))
      result['BOUNDARY_TEST_TOP_PROCESS_MEMORY']= {value = value, source = data.info}
  end
  return result
end

plugin:run()