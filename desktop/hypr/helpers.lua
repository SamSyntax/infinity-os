o = o or {}

function o.exec(command)
  return hl.dsp.exec_cmd(command)
end

function o.bind(keys, description, dispatcher, options)
  local opts = options or {}
  if description then
    opts.description = description
  end
  if type(dispatcher) == "string" then
    dispatcher = hl.dsp.exec_cmd(dispatcher)
  end
  hl.bind(keys, dispatcher, opts)
end

function o.replace(keys, description, dispatcher, options)
  hl.unbind(keys)
  o.bind(keys, description, dispatcher, options)
end

function o.exec_on_start(command)
  hl.on("hyprland.start", function()
    hl.exec_cmd(command)
  end)
end
