require "helpers"

obs = obslua

items = {}

function load_item_config(text)
  items = {}
  local item_num = 1

  for s in text:gmatch("[^\r\n]+") do
    tokens = s:split(",")
    items[item_num] = {}
    items[item_num]["name"] = "_unnamned"
    items[item_num]["format"] = "_default"
    items[item_num]["hide_leading_zero"] = true

    for i, token in pairs(tokens) do
      local token = token:trim()
      if i == 1 then
        items[item_num]["name"] = token
      elseif i == 2 then
        items[item_num]["format"] = token
      elseif token == "keep-zero" then
        items[item_num]["hide_leading_zero"] = false
      end
    end

    item_num = item_num + 1
  end
end

function get_current_time(format, hide_leading_zero)
  text = os.date(format, os.time())

  if hide_leading_zero and string.sub(text, 1, 1) == "0" then
    text = string.sub(text, 2)
  end

  return text
end

function update_item(name, format, hide_leading_zero)
  local source = obs.obs_get_source_by_name(name)
  if source ~= nil then
    local settings = obs.obs_data_create()

    local text = get_current_time(format, hide_leading_zero)
    obs.obs_data_set_string(settings, "text", text)
    obs.obs_source_update(source, settings)
    obs.obs_data_release(settings)
    obs.obs_source_release(source)
  end
end

function timer_callback()
  for i, item in pairs(items) do
    update_item(item["name"], item["format"], item["hide_leading_zero"])
  end
end

function script_properties()
  local props = obs.obs_properties_create()
  obs.obs_properties_add_text(props, "item_config", "Item Configuration", obs.OBS_TEXT_MULTILINE)
  return props
end

function script_update(settings)
  obs.timer_remove(timer_callback)
  load_item_config(obs.obs_data_get_string(settings, "item_config"))
  obs.timer_add(timer_callback, 1000)
end

function script_load(settings)
  obs.timer_add(timer_callback, 1000)
end

function script_description()
  return [[Create text items based on the current date and time.

Configure 1 item per line.
To keep a leading 0, add "keep-zero" to the line.
Formats use Lua date tags.

Examples:
clock, %I:%M
ampm, %p
clock_with_zero, %I:%M, keep-zero]]
end
