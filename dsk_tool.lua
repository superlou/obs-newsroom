require "helpers"

obs = obslua
dsk_fade_duration = 0

function find_source_by_name_in_list(source_list, name)
  for i, source in pairs(source_list) do
    source_name = obs.obs_source_get_name(source)
    if source_name == name then
      return source
    end
  end

  return nil
end

function dsk_is_active(dsk_name)
  local scenes = obs.obs_frontend_get_scenes()
  local dsk = find_source_by_name_in_list(scenes, dsk_name)
  local is_active = obs.obs_source_active(dsk)
  obs.source_list_release(scenes)
  return is_active
end

function reject_dsk_scenes(scene_list)
  return table.filter(scene_list, function(o, k, i)
    return not string.match(obs.obs_source_get_name(o), "DSK")
  end)
end

function remove_dsk_by_name(dsk_name)
  -- print("Removing "..dsk_name)
  local scenes = obs.obs_frontend_get_scenes()
  local scenes = reject_dsk_scenes(scenes)

  for i, source in pairs(scenes) do
    local scene = obs.obs_scene_from_source(source)
    local items = obs.obs_scene_enum_items(scene)

    for i, item in pairs(items) do
      local item_source = obs.obs_sceneitem_get_source(item)
      local item_name = obs.obs_source_get_name(item_source)
      if item_name == dsk_name then
        obs.obs_sceneitem_remove(item)
      end
    end

    obs.sceneitem_list_release(items)
  end

  obs.source_list_release(scenes)
end

function add_dsk_by_name(dsk_name)
  -- print("Adding "..dsk_name)
  local scenes = obs.obs_frontend_get_scenes()
  local dsk = find_source_by_name_in_list(scenes, dsk_name)
  local scenes = reject_dsk_scenes(scenes)

  for i, source in pairs(scenes) do
    local scene = obs.obs_scene_from_source(source)
    local items = obs.obs_scene_enum_items(scene)
    local found_dsk = false

    for i, item in pairs(items) do
      local item_source = obs.obs_sceneitem_get_source(item)
      local item_name = obs.obs_source_get_name(item_source)
      if item_name == dsk_name then
        found_dsk = true
      end
    end

    if not found_dsk then
      obs.obs_scene_add(scene, dsk)
    end

    obs.sceneitem_list_release(items)
  end

  obs.source_list_release(scenes)
end

function transition_dsk()
  local current_scene_source = obs.obs_frontend_get_current_scene()
  local current_scene = obs.obs_scene_from_source(current_scene_source)

  local transitions = obs.obs_frontend_get_transitions()
  local fade = find_source_by_name_in_list(transitions, "Fade")

  local dup_scene = obs.obs_scene_duplicate(current_scene, nil, obs.OBS_SCENE_DUP_PRIVATE_REFS)
  local dest_source = obs.obs_scene_get_source(dup_scene)

  -- Restore original transition when done
  local original_transition = obs.obs_frontend_get_current_transition()
  local sh = obs.obs_source_get_signal_handler(fade)
  obs.signal_handler_connect(sh, "transition_stop", function(source)
    obs.remove_current_callback()
    obs.obs_frontend_set_current_transition(original_transition)
    obs.obs_source_release(original_transition)
  end)

  -- Execute the transition
  obs.obs_frontend_set_current_transition(fade)
  obs.obs_transition_start(fade, obs.OBS_TRANSITION_MODE_AUTO, dsk_fade_duration, dest_source)

  obs.source_list_release(transitions)
  obs.obs_source_release(current_scene_source)
end

function toggle_dsk(dsk_scene_name)
  if dsk_is_active(dsk_scene_name) then
    remove_dsk_by_name(dsk_scene_name)
  else
    add_dsk_by_name(dsk_scene_name)
  end

  transition_dsk()
end

function get_scene_names_containing(str)
  local scenes = obs.obs_frontend_get_scenes()

  scenes = table.filter(scenes, function(o, k, i)
    return string.match(obs.obs_source_get_name(o), str)
  end)

  return table.map(scenes, function(scene)
    return obs.obs_source_get_name(scene)
  end)
end

function script_properties()
  local props = obs.obs_properties_create()

  obs.obs_properties_add_int(props, "dsk_fade_duration", "Fade duration (ms)", 0, 10000, 1)

  dsk_names = get_scene_names_containing("DSK")

  for i, name in pairs(dsk_names) do
    local callback_name = "toggle_dsk_"..i
    _G[callback_name] = function()
      toggle_dsk(name)
    end

    local hotkey_callback_name = "hotkey_toggle_dsk_"..i
    _G[hotkey_callback_name] = function(pressed)
      if pressed then
        toggle_dsk(name)
      end
    end

    obs.obs_hotkey_register_frontend("hotkey_toggle_dsk_"..i,
                                     "DSK: Toggle "..name,
                                     _G[hotkey_callback_name])

    obs.obs_properties_add_button(props, "toggle_dsk_"..i,
                                  "Toggle " .. name, _G[callback_name])
  end

  return props
end

function script_defaults(settings)
  obs.obs_data_set_default_int(settings, "dsk_fade_duration", 500)
end

function script_update(settings)
  dsk_fade_duration = obs.obs_data_get_int(settings, "dsk_fade_duration")
end

function script_load()
end

function script_description()
  return "DSK Tool"
end
