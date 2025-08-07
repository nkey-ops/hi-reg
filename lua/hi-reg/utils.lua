local M = {}

--- @param file_path string:
function M.get_data_file(file_path)
    assert(file_path ~= nil, "File path cannot be nil")
    assert(type(file_path) == "string", "File path should be of a type string")

    local file = assert(io.open(file_path, "r"))
    local read = assert(file:read("a"))

    if read == "" then
        file:close()
        file = assert(io.open(file_path, "w"))
        file:write("{}") -- creating initial JSON object
        file:close()
    end

    return assert(io.open(file_path, "r"))
end

function M.get_json_decoded_data(file_path)
    assert(file_path ~= nil, "File path cannot be nil")
    assert(type(file_path) == "string", "File path should be of a type string")
    assert(string.match(file_path, '%.json$'), "File should of type .json")

    local file = M.get_data_file(file_path)
    local string_data = file:read("*a")
    file:close()

    return vim.json.decode(string_data, { object = true, array = true })
end

--- @param file_path string
--- @param data table
function M.write_data(file_path, data)
    assert(file_path ~= nil, "File path cannot be nil")
    assert(string.match(file_path, '%.json$'), "File should of type .json")
    assert(data ~= nil, "Data cannot be nil")
    assert(type(data) == "table", "Data should be of type table")

    table.sort(data)
    local encoded_data = vim.json.encode(data)
    local file = io.open(file_path, "w")

    assert(file ~= nil,
        string.format("Couldnt write into: '%s'", file_path))

    file:write(encoded_data)
    file:close()
end

-- Removes the values from the table if the value doesn't start with the
-- 'string.* and add a "size" key with current size of the values table
function M.remove_unmatched_values(pattern, values)
    assert(pattern ~= nil or type(pattern) == "string",
        "Matching string should be of a type string and not nil.",
        "String:", pattern)
    assert(values ~= nil, "Values canot be nil")

    local size = 0
    for key, value in pairs(values) do
        assert(value ~= nil, "Value should not be nil")
        assert(type(value) == "string",
            "Values should only contain strings. Value:", value)

        if (pattern.match(value, '^' .. pattern) == nil) then
            values[key] = nil
        else
            size = size + 1;
            values[key] = nil
            table.insert(values, size, value)
        end
    end
    return size
end

--- Listens to the pressed keys as long as a new is not a back tick or the total
--- number of pressed keys doesn't exceed max_seq_keys
--- @return string|nil
function M.get_mark_key(max_key_seq, first_char, confirmation)
    assert(max_key_seq ~= nil
        and type(max_key_seq) == "number"
        and max_key_seq > 0
        and max_key_seq < 50)

    assert(first_char ~= nil, "first_char cannot be nil")
    assert(type(first_char) == "number", "first_char should be of type number")
    assert((first_char >= 65 and first_char <= 90
            or (first_char >= 97 and first_char <= 122)),
        "first_char should be [a-zA-Z] character")

    assert(confirmation ~= nil, "confirmation cannot be nil")
    assert(type(confirmation) == 'boolean', "confirmation should be of type boolean")

    local chars = string.char(first_char)
    if max_key_seq == 1 then return chars end

    for _ = 2, max_key_seq do
        local ch = vim.fn.getchar()

        if (type(ch) ~= "number") then
            return nil
        end

        -- 96 is a back tick sign "`", 39 is a "'" single quote sign
        if (ch == 96) or (ch == 39) then
            return chars
        end

        -- If ch is not [a-zA-Z]
        if ((ch < 65) or (ch > 90 and ch < 97) or (ch > 122)) then
            return nil
        end

        chars = chars .. string.char(ch)
    end

    if confirmation then
        local confirmation_char = vim.fn.getchar()
        if type(confirmation_char) ~= "number"
            or (confirmation_char ~= 96
                and confirmation_char ~= 39) then
            return nil
        end
    end

    return chars
end

--Listens to the pressed keys as long as a new char is not a back tick or
--the total number of pressed keys doesn't exceed max_seq_keys
--if only one mark key remains, it'll be returned immediately
--if zero mark keys remains, a nil will be returned
function M.get_last_mark_key(max_key_seq, mark_keys, first_char)
    assert(max_key_seq ~= nil
        and type(max_key_seq) == "number"
        and max_key_seq > 0
        and max_key_seq < 50)
    assert(mark_keys ~= nil and type(mark_keys) == "table")
    assert(first_char ~= nil
        and type(first_char) == "number"
        and (first_char >= 65 and first_char <= 90
            or (first_char >= 97 and first_char <= 122))) -- [a-zA-Z]


    local mark_key = ""
    local char_counter = 0
    while true do
        local char = char_counter == 0 and first_char or vim.fn.getchar()
        char_counter = char_counter + 1

        -- If ch is not [a-zA-Z] then stop markering
        if (type(char) ~= "number"
                or (char < 65 or (char > 90 and char < 97) or char > 122)
                and char ~= 96) then
            return
        end
        -- 96 is a back tick sign "`"
        if (char == 96) then
            break
        end

        mark_key = mark_key .. string.char(char)

        local mark_keys_remains = M.remove_unmatched_values(mark_key, mark_keys)
        assert(mark_keys ~= nil, "Mark keys cannot be nil")

        if mark_keys_remains == 1 then
            return table.remove(mark_keys, 1)
        elseif mark_keys_remains == 0 then
            return nil
        end
    end
    return mark_key
end

function M.copy_keys(table)
    assert(table ~= nil and type(table) == "table")

    local keys = {}
    local i = 1
    for key, _ in pairs(table) do
        keys[i] = key
        i = i + 1
    end

    return keys
end

--- @param data_dir string: a path where '/hi-reg/' directory will be created,
--- if the directory already exists or some of its sub-directories nothing will be done to them,
--- otherwise sub-directories and/or the 'extended-marks' directory will be created as needed.
--- The 'data_dir' can have expandable wildcards, expandable according to 'help:wildcards'
--- @return string: an expanded path to '/extended-marks' directory
function M.handle_data_dir(data_dir)
    local data_dir_path = data_dir

    assert(data_dir_path, "data_dir cannot be nil")
    assert(type(data_dir_path) == 'string', "data_dir should be of a type string")

    data_dir_path = vim.fn.expand(data_dir_path)
    assert(data_dir_path:len() ~= 0,
        string.format(
            "data_dir:'%s' file wildcards cannot be expanded", data_dir))

    data_dir_path = data_dir_path:gsub('/$', '') .. '/hi-reg'

    -- the directory will exist but might not be readable or writable,
    -- if the directory cannot be create an error is raised
    -- sub-directories are created recursively as needed
    vim.fn.mkdir(data_dir_path, 'p')
    return data_dir_path
end

function M.get_line_separator()
    if vim.loop.os_uname().sysname == "Windows_NT" then
        return "\r\n"
    else
        return "\n"
    end
end

--- Prints the input an if recently there was a message it will hold all of the
--- messages in the window for 500 milliseconds
--- @param ... any to print
function M.print_wihout_hit_enter(...)
    local messages_opt_value = vim.opt.messagesopt._value

    -- setting coppied settings back but excluding "hit-enter" settings
    vim.cmd("set messagesopt=wait:500," .. messages_opt_value:gsub(",?hit%-enter,?", ""))

    print(...)

    -- setting back initial settings
    vim.cmd("set messagesopt=" .. messages_opt_value)
end

--- @param hi_reg HiReg
--- @return string
function M.get_command(hi_reg)
    assert(hi_reg)

    -- Define the command to apply the highlight to the specified filetype
    -- if &filetype == "%s"
    -- endif
    local command = string.format(
        [[
        silent! syntax match %s "%s"
         ]],
        hi_reg.highlight_group, -- Highlight Group Name
        hi_reg.regex            -- Escape slashes in regex
    )

    return command
end

--- @param hi_reg HiReg
--- @param hi_regs [HiReg]
function M.clear_hi_reg_from_buffers(hi_reg, hi_regs)
    assert(type(hi_reg) == 'table', "hi_reg should be non nil and of the type 'table'")
    assert(type(hi_regs) == 'table', "hi_regs should be non nil and of the type 'table'")

    --
    -- 1.* run through each open buffer
    -- 2. check whether the buffer's filetype matches any
    --    hi_reg's filetyps / if matches
    -- 3.* run ':syntax clear "highlight_group"' within the buffer
    -- 4. go through each hi_reg_saved
    -- 5. check whether hi_reg_saved.highlight_group
    --    matches hi_reg.highlight_group / if matches
    -- 6. check if the hi_reg_saved has any filetypes matching
    --    the buffer's filetype of the current iteration / if matches
    -- 7. add the removed :syntax match for the hi_reg_saved
    --
    --
    -- 1.* 'syntax clear' only applies to the current buffer and
    --      needs to be executed within that buffer
    -- 3.* ':syntax clear' will remove all matchings regexes for the "highligh_group"
    --      so we need to restore all others removed with the same regex and buffer
    for _, buf in pairs(vim.api.nvim_list_bufs()) do
        if #hi_reg.filetypes == 0 then
            vim.api.nvim_buf_call(buf, function()
                vim.cmd("syntax clear " .. hi_reg.highlight_group)

                for _, hi_reg_saved in pairs(hi_regs) do
                    if hi_reg.highlight_group == hi_reg_saved.highlight_group then
                        vim.cmd(M.get_command(hi_reg_saved))
                    end
                end
            end)
        end

        for _, hi_reg_filetype in pairs(hi_reg.filetypes) do
            if hi_reg_filetype == vim.bo[buf].filetype then
                vim.api.nvim_buf_call(buf, function()
                    vim.cmd("syntax clear " .. hi_reg.highlight_group)

                    for _, hi_reg_saved in pairs(hi_regs) do
                        if hi_reg.highlight_group == hi_reg_saved.highlight_group then
                            for _, hi_reg_saved_filetype in pairs(hi_reg_saved.filetypes) do
                                if hi_reg_saved_filetype == vim.bo[buf].filetype then
                                    vim.cmd(M.get_command(hi_reg_saved))
                                end
                            end
                        end
                    end
                end)
            end
        end
    end
end

return M
