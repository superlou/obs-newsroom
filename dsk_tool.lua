require "helpers"

obs = obslua

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
  print("Removing "..dsk_name)
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
  print("Adding "..dsk_name)
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

  obs.obs_frontend_set_current_transition(fade)
  obs.obs_transition_start(fade, obs.OBS_TRANSITION_MODE_AUTO, 500, dest_source)

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
  scenes = obs.obs_frontend_get_scenes()

  names = {}
  for i, scene in pairs(scenes) do
    name = obs.obs_source_get_name(scene)
    if string.match(name, str) then
      table.insert(names, name)
    end
  end

  obs.source_list_release(scenes)
  return names
end

function get_scene_names_not_containing(str)
  scenes = obs.obs_frontend_get_scenes()

  names = {}
  for i, scene in pairs(scenes) do
    name = obs.obs_source_get_name(scene)
    if not string.match(name, str) then
      table.insert(names, name)
    end
  end

  obs.source_list_release(scenes)
  return names
end

function script_properties()
  local props = obs.obs_properties_create()

  dsk_names = get_scene_names_containing("DSK")

  for i, name in pairs(dsk_names) do
    callback_name = "toggle_dsk_" .. i
    _G[callback_name] = function()
      toggle_dsk(name)
    end

    obs.obs_properties_add_button(props, "toggle_dsk_" .. i,
                                  "Toggle " .. name, _G[callback_name])
  end

  return props
end

function script_load()

end

function script_description()
  return "DSK Tool"
end
