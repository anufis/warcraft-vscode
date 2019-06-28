package = {}
package.path = '--[[%> print(package.path.join(";")) %]]'

local P
do
    local preloadType = 'string'
    local preload = load

    local package = package

    local _G = _G
    local _PRELOADED = {}
    local _LOADED = {}
    local _LOADING = {}
    local _errorhandler

    local function errorhandler(msg)
        if _errorhandler and msg then
            return _errorhandler(msg)
        end
    end

    local function resolvefile(module)
        module = module:gsub('[./\\]+', '/')

        for item in package.path:gmatch('[^;]+') do
            local filename = item:gsub('^%.[/\\]+', ''):gsub('%?', module)
            if _PRELOADED[filename] then
                return filename
            end
        end
    end

    local function compilefile(filename, mode, env, level)
        local code = _PRELOADED[filename]
        if not code then
            error(string.format('cannot open %s: No such file or directory', filename), level + 1)
        end
        return preload(code, '@' .. filename, mode, env or _G)
    end

    function require(module)
        local loaded = _LOADED[module]
        if loaded then
            return loaded
        end

        local filename = resolvefile(module)
        if not filename then
            error(string.format('module \'%s\' not found', module), 2)
        end

        loaded = _LOADED[filename]
        if loaded then
            return loaded
        end

        if _LOADING[filename] then
            error('critical dependency', 2)
        end

        local f, err = compilefile(filename)
        if not f then
            error(err, 2)
        end

        _LOADING[filename] = true
        local ok, ret = xpcall(f, errorhandler, module, filename)
        _LOADING[filename] = false
        if not ok then
            error()
        end

        ret = ret or true

        _LOADED[filename] = ret
        _LOADED[module] = ret

        return ret
    end

    function loadfile(filename, mode, env)
        return compilefile(filename, mode, env, 2)
    end

    function dofile(filename)
        compilefile(filename, nil, nil, 2)()
    end

    function seterrorhandler(handler)
        if type(handler) ~= 'function' then
            error(string.format('bad argument #1 to `seterrorhandler` (function expected, got %s)', type(handler)), 2)
        end
        _errorhandler = handler
    end

    function geterrorhandler()
        return _errorhandler
    end

    -- hook for errorhandler
    do
        local function tryreturn(ok, ...)
            if ok then
                return ...
            end
        end

        local gens = {}
        local function gen(index, count)
            local k = index << 16 | count
            if gens[k] then
                return gens[k]
            end

            local args = {}
            for i = 1, count do
                table.insert(args, 'ARG' .. i)
            end
            args = table.concat(args, ',')

            local code = [[
local o, r, e = ...
return function({ARGS})
    if ARG{N} then
        local c = ARG{N}
        ARG{N} = function(...)
            return r(xpcall(c, e, ...))
        end
    end
    return o({ARGS})
end
]]
            code = code:gsub('{N}', tostring(index)):gsub('{ARGS}', args)

            gens[k] = load(code)
            return gens[k]
        end

        local apis = {
            {'TimerStart', 4, 4}, {'ForGroup', 2, 2}, {'ForForce', 2, 2}, {'Condition', 1, 1}, {'Filter', 1, 1},
            {'EnumDestructablesInRect', 3, 3}, {'EnumItemsInRect', 3, 3}, {'TriggerAddAction', 2, 2},
        }

        for _, v in ipairs(apis) do
            local name, index, count = v[1], v[2], v[3]
            _G[name] = gen(index, count)(_G[name], tryreturn, errorhandler)
        end
    end

    P = setmetatable({}, {
        __newindex = function(t, k, v)
            if type(v) ~= preloadType then
                error('PRELOADED value must be ' .. preloadType)
            end
            _PRELOADED[k] = v
        end,
        __index = function(t, k)
            error('Can`t read')
        end,
        __metatable = false,
    })
end

--[[%= code %]]

seterrorhandler(function(...)
    return print(...)
end)

dofile('origwar3map.lua')

local __main = main
function main()
    xpcall(function()
        __main()
        dofile('main.lua')
    end, function(msg)
        local handler = geterrorhandler()
        if handler and msg then
            return handler(msg)
        end
    end)
end
